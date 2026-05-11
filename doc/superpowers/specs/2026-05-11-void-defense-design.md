# VOID Defense Layer — Resilience & Self-Preservation Design Spec

## Overview

**VOID Defense** is a 6-layer resilience subsystem grafted onto the existing VOID terminal (`2026-04-06-void-terminal-design.md`). It does not change VOID's terminal semantics — it adds external pressure detection, state persistence, and crash survival so VOID survives (or recovers gracefully from) the *kind of system event observed on 2026-05-11 00:12 KST*.

- **Trigger incident:** `bedrock/state/session_logs/2026-05-11_void_crash_postmortem.md`
- **Root cause class:** external system OOM + WindowServer watchdog timeout (Void itself was a bystander)
- **Goal:** when the OS goes hostile, VOID (a) detects early, (b) saves state, (c) reduces its own footprint, (d) recovers cleanly on next launch
- **Non-goal:** prevent every macOS-level crash. The OS can still SIGKILL us; we just promise the *next* launch loses nothing important

## Threat Model — 6 Failure Modes

| # | Failure | Source | VOID's leverage |
|---|---|---|---|
| 1 | System OOM / Jetsam wave | external (sibling process leak) | detect early, shrink self |
| 2 | WindowServer watchdog timeout | external (GUI stack hang) | persist state, exit cleanly |
| 3 | Self RSS bloat (scrollback / glyph atlas) | internal | self-cap, GC |
| 4 | PTY child fork-bomb (user shell or AI plugin) | internal | rate limit, refuse |
| 5 | Native crash (SIGSEGV/SIGBUS/abort) | internal | last-gasp dump + relaunch |
| 6 | Hung event loop (no SIGKILL yet) | internal | external watchdog → restart |

## Architecture — 6 Defense Layers (D1–D6)

```
D6 ─ External Watchdog       launchd peer, XPC heartbeat, force-restart
D5 ─ Crash Capture           uncaught exception + signal handlers, minidump
D4 ─ Spawn Throttle          per-surface fork rate limiter
D3 ─ Session Snapshot        atomic tab/scrollback persist + recovery
D2 ─ Self RSS Cap            task_info polling + cache trim
D1 ─ Pressure Sensor         memory pressure + WindowServer health monitors
```

Layers are independent. Each can ship alone. **MVP = D1 + D3 + D5.**

## Layer D1 — Pressure Sensor

Two parallel signal sources. Both are passive listeners — zero overhead until OS asserts.

### D1a: Memory Pressure (Mach kernel notification)

```hexa
@link("libSystem")
extern fn dispatch_source_create(type: *Void, handle: Int, mask: Int, queue: *Void) -> *Void
extern fn dispatch_source_set_event_handler_f(src: *Void, handler: *Void) -> Void
extern fn dispatch_resume(src: *Void) -> Void

// DISPATCH_SOURCE_TYPE_MEMORYPRESSURE is a global symbol
@link("libSystem")
extern var _dispatch_source_type_memorypressure: *Void

// mask: NORMAL=1, WARN=2, CRITICAL=4
let src = dispatch_source_create(
  _dispatch_source_type_memorypressure, 0, 6 /* WARN|CRITICAL */, nil
)
dispatch_source_set_event_handler_f(src, on_pressure)
dispatch_resume(src)
```

**Swift fallback (current build):**
```swift
let src = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])
src.setEventHandler { handlePressure(src.data) }
src.resume()
```

Reactions:

| Level | Action |
|---|---|
| `.warning` | trim scrollback to last 1000 lines/tab, drop glyph atlas LRU half, fire D3 snapshot |
| `.critical` | also: refuse new PTY spawn, dim UI + show "system under pressure" banner, `kill -USR2` to plugin host |

### D1b: WindowServer Health Heartbeat

WindowServer hang precedes its watchdog kill by ~60s. We can detect it before the OS does.

```swift
// fire every 6s on a dedicated DispatchQueue
let dict = CGSessionCopyCurrentDictionary() as? [String: Any]
if dict == nil || (Date() - lastSuccess) > 30 {
    enterDegradedMode()  // → D3 immediate snapshot, refuse new windows
}
```

If WS recovers: heartbeat clears degraded mode automatically. If we get killed during degraded mode, D3 already saved.

## Layer D2 — Self RSS Cap

```hexa
@link("libSystem")
extern fn task_info(task: Int, flavor: Int, info_out: *Void, count: *Int) -> Int
// TASK_VM_INFO = 22, returns task_vm_info_data_t with phys_footprint
```

Poll every 6s on a low-priority queue. Compare against config thresholds:

| Threshold | Default | Action |
|---|---|---|
| `softCapMB` | 800 | trim glyph atlas, GC scrollback older than 1h |
| `hardCapMB` | 1500 | + close hidden tabs (with D3 snapshot first), refuse new PTY |
| `panicCapMB` | 2400 | + force exit after D3 (faster than waiting for Jetsam) |

Rationale from incident: Void was at 1162 MB when the GUI stack collapsed. A 1500 MB hard cap would have triggered self-trim *before* the system event.

## Layer D3 — Session Snapshot

The contract: **at any moment, a complete-enough state lives on disk**, atomically.

### Layout

```
~/Library/Application Support/com.dancinlab.void/sessions/
├── current.json              # symlink → latest snapshot
├── 2026-05-11T001200Z.json  # one snapshot per save event
└── crashes/
    └── 2026-05-11T001230Z/   # crash bundle (see D5)
        ├── snapshot.json
        ├── stack.txt
        └── system.txt
```

### Snapshot schema (v1)

```json
{
  "version": 1,
  "savedAt": "2026-05-11T00:12:00Z",
  "reason": "periodic | pressure_warn | pressure_critical | ws_degraded | shutdown",
  "windows": [
    {
      "frame": [x, y, w, h],
      "tabs": [
        {
          "title": "...",
          "cwd": "/Users/ghost/core/void",
          "shell": "/bin/zsh",
          "argv": ["zsh", "-l"],
          "env_diff": { "FOO": "bar" },
          "scrollback_tail": "<last 200 lines, gzipped+base64>",
          "cursor": [row, col],
          "size": [cols, rows]
        }
      ],
      "split_tree": { "...": "..." }
    }
  ]
}
```

We **do not** save: full scrollback (too big — last 200 lines is the recoverable horizon), child PIDs (dead by next launch), pasteboard.

### Save triggers (debounced — min interval 6s except `*shutdown*` and `*critical*`)

- Periodic: every 30s
- D1a `.warning`
- D1a `.critical` (immediate, no debounce)
- D1b WindowServer degraded
- D2 hardCap exceeded
- D5 crash handler (last-gasp)
- App will-terminate

### Atomicity

```swift
let tmp = path + ".tmp"
try data.write(to: tmp, options: .atomic)
try FileManager.default.replaceItemAt(path, withItemAt: tmp)
```

`current.json` symlink is updated last via `symlink(2)` rename.

### Recovery on launch

If `current.json` exists AND `savedAt` < 24h old AND `reason ∈ {ws_degraded, pressure_*, crash}`:
- show "Restore previous session?" prompt (or auto if config `restore.auto = true`)
- replay tabs: re-`fork+exec` into saved cwd with saved argv, paint scrollback_tail as static text above the prompt

## Layer D4 — Spawn Throttle

A surface (PTY-backed view) tracks fork events from its child shell tree.

```
window: 6 seconds
maxForksPerWindow: 60        # ≈ 10/s sustained
burstAllow: 36               # short bursts of 36 are fine
```

When exceeded:
- log `spawn_storm` event with shell + recent argv to `~/Library/Logs/com.dancinlab.void/events.jsonl`
- send a soft warning into the surface ("VOID: high fork rate detected, slowing acceptance")
- after 2 consecutive windows over limit: SIGSTOP the offending child group, prompt user

This is defense against the *internal* analogue of what `hexa_interp.real` did to the system.

## Layer D5 — Crash Capture

```swift
NSSetUncaughtExceptionHandler { exc in writeCrashBundle(exc) }

let sigs: [Int32] = [SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE, SIGTRAP]
for s in sigs {
    var sa = sigaction()
    sa.__sigaction_u.__sa_handler = { sig in
        writeCrashBundle(signal: sig)
        signal(sig, SIG_DFL); raise(sig)
    }
    sigaction(s, &sa, nil)
}
```

`writeCrashBundle` is **async-signal-safe**: pre-allocated buffers, only `write(2)`/`mkdir(2)`. Writes:
- `snapshot.json` — copy of last D3 snapshot
- `stack.txt` — `backtrace_symbols_fd` output
- `system.txt` — last 60s of D1/D2 readings (kept in a ring buffer)

Bundle goes to `~/Library/Logs/com.dancinlab.void/crashes/<ISO8601>/`. Rotation: keep last 6.

## Layer D6 — External Watchdog (optional, off by default)

A separate LaunchAgent — bundle ID `com.dancinlab.void.watchdog`, ~200 LOC — that:

1. Pings VOID's XPC service `com.dancinlab.void.heartbeat` every 6s
2. If 5 consecutive misses (30s): captures a `sample` of the VOID pid, then `SIGTERM` → 6s grace → `SIGKILL`
3. On next user launch of VOID, watchdog plays the recorded sample alongside D3 recovery

Defers to D5 if VOID crashes on its own; only fires when VOID is *hung but alive*.

`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dancinlab.void.watchdog.plist`

Off by default because (a) it's an extra moving part, (b) most hangs in the postmortem class are short-lived.

## Configuration — extends `config.void`

```toml
[defense]
enabled = true                    # master switch

[defense.pressure]
on_warning  = ["trim_scrollback", "snapshot"]
on_critical = ["snapshot", "refuse_pty", "show_banner"]

[defense.rss]
soft_cap_mb  = 800
hard_cap_mb  = 1500
panic_cap_mb = 2400

[defense.snapshot]
periodic_seconds = 30
restore_window_hours = 24
restore_auto = false
keep_snapshots = 6

[defense.spawn]
window_seconds = 6
max_forks_per_window = 60
burst_allow = 36

[defense.watchdog]
enabled = false
miss_count = 5
miss_seconds = 6
```

All keys optional; defaults match the table above.

## Telemetry — `events.jsonl`

Append-only, one JSON object per line. Rotated at 6 MiB, keep last 6 files.

```json
{"t":"2026-05-11T00:11:55Z","kind":"pressure","level":"warn","rss_mb":1162}
{"t":"2026-05-11T00:11:56Z","kind":"snapshot","reason":"pressure_warn","ms":34}
{"t":"2026-05-11T00:12:08Z","kind":"ws_degraded","since_ok_s":53}
{"t":"2026-05-11T00:12:09Z","kind":"snapshot","reason":"ws_degraded","ms":21}
```

This is the post-incident debug surface. No network egress, ever.

## Test Plan

| Layer | Test | Tool |
|---|---|---|
| D1a | inject memory pressure | `memory_pressure -l critical` (Apple's tool) |
| D1b | simulate WS hang | mock the heartbeat in unit test; do NOT kill real WS |
| D2 | force RSS bloat | unit test: synthesize 2GB scrollback, assert trim fires |
| D3 | crash mid-write | inject `EIO` on tmp write; assert `current.json` still valid prior version |
| D3 recovery | launch with synthetic snapshot | UI test, verify tab tree restored |
| D4 | spawn 200 children/s | bash loop in a test surface; assert SIGSTOP + warning |
| D5 | trigger SIGSEGV | dedicated `BellTitleSelfTest`-style harness, assert bundle written |
| D6 | hang main thread `sleep(120)` | watchdog should kill at 30s, sample captured |

## n=6 Alignment

| Element | Count | Mapping |
|---|---|---|
| Defense layers | 6 | n |
| Failure modes | 6 | n |
| Pressure poll interval (s) | 6 | n |
| Heartbeat interval (s) | 6 | n |
| Snapshot retention | 6 | n |
| Crash bundle retention | 6 | n |
| RSS thresholds | 3 | half-n |
| Telemetry rotation (MiB) | 6 | n |

## Source Layout

```
void/macos/Sources/Defense/
├── PressureMonitor.swift       # D1a + D1b
├── RSSGuard.swift              # D2
├── SessionSnapshot.swift       # D3 (write side)
├── SessionRestore.swift        # D3 (recovery side)
├── SpawnThrottle.swift         # D4
├── CrashCapture.swift          # D5 (signal-safe)
└── DefenseCoordinator.swift    # wiring + config

void/macos/Watchdog/             # D6 — separate target
├── main.swift
└── com.dancinlab.void.watchdog.plist
```

For the future hexa rewrite: same module names under `void/src/defense/*.hexa`, all signal calls go through the existing `extern` FFI from `2026-04-06-void-terminal-design.md`.

## Phase Plan

```
Phase 1 (MVP):     D1a + D3 + D5         — covers the 05-11 incident class
Phase 2:           D2                    — prevent self-bloat contributing to OOM
Phase 3:           D1b + auto-restore    — degraded-mode handling
Phase 4:           D4                    — internal fork-bomb defense
Phase 5:           Telemetry + config UI — observability surface
Phase 6 (opt-in):  D6 external watchdog  — for users running long-lived sessions
```

Each phase is independently shippable. Phase 1 is the minimum that would have prevented the 05-11 user-visible "튕김" experience (Void would have written its state at the warn signal ~30s before WS died, then on re-launch restored everything).

## Open Questions

1. **Restore prompt vs auto-restore default** — auto feels right for an event the user didn't trigger, but risks restoring a known-bad session. Proposal: auto-restore only when last reason ∈ `{ws_degraded, pressure_critical, crash}` AND last save was clean (D3 finished).
2. **Scrollback tail size** — 200 lines is arbitrary. Should it be per-tab byte budget (e.g. 64 KiB) instead?
3. **Plugin host (Layer 5) sandboxing** — out of scope for this spec but related: a runaway hexa-script plugin could trigger D4 falsely.
4. **D6 XPC service** — adds entitlement requirements + signing complexity. Worth it only if hangs become common.

## Cross-References

- VOID base spec: `2026-04-06-void-terminal-design.md`
- Incident postmortem: `bedrock/state/session_logs/2026-05-11_void_crash_postmortem.md`
- macOS source root: `/Users/ghost/core/void/macos/Sources/`
