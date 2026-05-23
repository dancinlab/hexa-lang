# `stdlib/proc.proc_spawn_supervised` (+ stderr autoflush) — daemon silent-exit under nohup

**Reporter**: anima (`dancinlab/anima` downstream consumer · PR #121 akida_bridge .hexa port)
**Severity**: medium (downstream live deploy blocked; python equivalent works as fallback)
**Affected**: `stdlib/proc.hexa::proc_spawn_supervised` + (possibly) `stdlib/websocket.hexa::ws_available` + hexa runtime stderr autoflush

## Symptom

A hexa daemon that follows the canonical pattern

```
fn run_daemon() {
    eprintln("[name] daemon start")
    eprintln("  config = ...")
    let avail = ws_available()
    if !avail["websocat"] { eprintln("FATAL: ..."); return }
    let state = state_init()
    while true {
        let nc_h = nc_spawn(host, port, "nc")          // proc_spawn_supervised
        let ws_h = ws_connect(broker_ws)               // websocat via stdlib
        run_once(state, nc_h, ws_h)
        eprintln("reconnect in 5s")
        let _s = exec("sleep 5")
    }
}
fn main() { run_daemon() }
```

works in foreground (`hexa run x.hexa selftest` prints all 9 selftest lines), but
launched under nohup (`nohup hexa run x.hexa daemon > out 2> err < /dev/null &`):

1. The daemon process **exits within a few seconds** (`pgrep -fl x.hexa` empty).
2. **Both stdout/stderr log files are 0 bytes** — NOT a single `eprintln` line lands,
   not even the very first `[name] daemon start` line.
3. The mkfifo'd FIFOs (`/tmp/hexa_akida_nc_*.fifo`, `/tmp/hexa_ws_*.fifo`) exist on
   disk after the exit, but no `nc` / `websocat` subprocess is in the process table.

Symptoms reproduce on macOS arm64 (M2 mini, hexa 0.x at
`/Users/mini/.hx/bin/hexa`). The host has no `setsid`, so
`proc_spawn_supervised`'s nohup-fallback path is the one executed.

## Probable cause(s) — two stacked gaps

### (1) `proc_spawn_supervised` does not survive parent exit on macOS nohup-fallback

Implementation summary (current `stdlib/proc.hexa`):
```
launch = "nohup sh -c '" + cmd + "' </dev/null >/dev/null 2>&1 & echo $!"
pid    = to_int(exec(launch).trim())
```

Theory: the spawned `sh -c '<cmd>' &` becomes a child of the `exec()` shell that
hexa uses to run `launch`. When `exec()` returns and that shell exits, the
detached `sh -c` should keep running due to `nohup` + `&`. But under macOS,
without `setsid` to start a new session, the child may inherit the controlling
terminal — and when the hexa daemon process exits, SIGHUP propagates and the
child dies. The end result: `proc_spawn_supervised` returns a PID, but by the
time the daemon's next iteration reaches the FIFO read, the child is already
gone — `nc_read_line` blocks forever (or the daemon itself races a SIGHUP).

Suggested fix at source:
- Make `proc_spawn_supervised` truly detach on macOS too — e.g., shell out to
  `nohup sh -c '... &' < /dev/null &> /dev/null & echo $!` AND `disown` the
  intermediate shell. Or invoke via a tiny C helper that does the
  double-fork-detach idiom. The selftest contract should exercise
  "spawn, parent-exit, child-survives".
- File `selftest_proc_spawn_supervised_macos_survives_parent.hexa` against
  this would have caught it.

### (2) Redirected `eprintln` is block-buffered — no diagnostic ever flushes

When the daemon's stderr is a regular file (not a TTY), `eprintln` output is
block-buffered. Daemons that die quickly never flush the buffer, so the
0-byte log files hide whatever the daemon would have printed.

Suggested fix at source: hexa runtime should `setvbuf(stderr, NULL, _IOLBF, 0)`
at startup (or use `fputs/fflush` per `eprintln`), matching the de-facto Unix
contract that **stderr is unbuffered / line-buffered**. The current behavior
(stderr block-buffered when redirected) violates that convention and makes
daemons unreasonably hard to debug.

### (Possibly 3) `ws_available()["websocat"]` may return false even when websocat is on PATH

If `ws_available()` checks by invoking `websocat --version`, behavior may
depend on websocat exit code, PATH propagation under `env -i`, or a subprocess
issue. The daemon's FATAL return path would explain immediate exit (but the
"FATAL websocat not available" eprintln would also fail to flush per (2),
hiding it). Recommend `ws_available()` use a stat-like check (`command -v
websocat`) rather than executing websocat to probe.

## Why it bit anima

`HEXAD/CHAT/server/akida_bridge.hexa` (PR #121, the
`akida_ws_publisher.py` + `akida_bridge_pipeline.sh` replacement) parses + runs
selftest (`F-AKIDA-BRIDGE-1..4` = 9/9 PASS) on Mac AND mini, but under
`nohup hexa run akida_bridge.hexa daemon` it dies silently. The .py pipeline
runs cleanly under the same `nohup ... &` invocation, so the gap is hexa-side.

**Anima-side fallback (current live state):** restored
`nohup nc 192.168.50.155 9512 | python3 akida_ws_publisher.py` via plist-free
nohup (per project's plist-abolition directive). The .hexa stays as a code asset
pending these stdlib fixes.

## Suggested investigation order (cheapest first)

1. **stderr autoflush fix in runtime** (one-liner) — unblocks ALL future hexa
   daemon debugging. Even if (1) is unrelated, fixing (2) makes (1) visible.
2. **add macOS-survives-parent-exit selftest** for `proc_spawn_supervised`.
   If it fails, fix the spawn pattern.
3. **harden `ws_available()`** to stat-only probe.

## Cross-link (anima side)

- `dancinlab/anima` PR #121 — `kosmos_emitter.hexa`-style hexa-native daemon,
  blocked from live deploy by this gap.
- `dancinlab/anima` memory `feedback-plist-forbidden-akida-endpoint` — directive
  context (no plist → daemons must run cleanly under nohup).
- Sibling inbox patch: `websocket-streaming-client-websocat-dependency.md` —
  the WS-client websocat dependency, separately filed.

## honest C3

- The 3 theories above are diagnostic — only (2) is confidently reproducible
  (0-byte log files are direct evidence of buffering or never-reached code).
  (1) and (possibly 3) are inferred from "daemon exits with 0 log output";
  fixing (2) first would let the daemon's own eprintlns disambiguate.
- The python fallback is functionally complete; this gap is about removing the
  blocker for hexa-native daemons (not about uptime).
- All evidence collected against hexa runtime on mini (M2 macOS arm64) — Linux
  behavior may differ.
