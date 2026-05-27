# RFC-021 — `hexa daemon` IPC mode (system-wide zero-fork)

- **Status**: **Draft** (2026-05-09) — design proposal, no implementation
- **Author date**: 2026-05-09
- **Mode**: brainstorming → spec (deferred until stage 1 native compiler settles)
- **Decision (2026-05-09)**: pursue v0 daemon ASAP after stage 1 native compiler is stable; until then, the spec stands as the L3 rung in the fork-storm prevention ladder. Do **not** ship daemon while interpreter is still load-bearing.
- **Position in ladder**: L0 (single-binary), L1 (per-call cache), L2 (subprocess pool), **L3 (this RFC: long-lived daemon)**, L4 (in-process embedding via library).
- **Style template**: RFC-017 (atlas embedding) and RFC-018 (native codegen spec).
- **Companion**: SPEC.yaml `fork_storm_prevention:` (issue #56, separate task).
- **Affected areas**: `compiler/main.hexa` (driver entry, gains `--serve` flag), new `compiler/daemon/` tree (server.hexa, proto.hexa, watcher.hexa), `gate/` (claude-bind hook entry rewrite), `launchd/` (macOS plist), packaging (systemd unit on linux).

---

## 1. Status / motivation

### 1.1 Observed pathology (2026-05-09)

- User audit found **36 copies** of `hexa_interp.real.real` on macOS, totaling **~2.4 GB** of disk pressure.
- Of those 36 copies, **~94% are claude-bind hooks/probes** that never exercise native codegen. They parse a tiny request, look something up, and exit. Each invocation pays full process-startup cost (~80–200 ms cold) plus binary-resolution cost.
- Per-build the driver still spawns **5–10 system tools** (lexer probe, atlas verifier, lint, formatter, link, strip, codesign, …). A single `hexa build` is a small fork-storm.
- Aggregate: developer workflows currently produce hundreds to low thousands of `hexa_interp.real.real` invocations per day per machine.

### 1.2 Why daemon (L3) not just better caching (L1/L2)

- L1 (per-call disk cache) only kills repeat work for **identical inputs**. Different lookups still pay startup.
- L2 (subprocess pool) reduces fork count but each pool worker is still a separate process tree; macOS Mach-O gate (see `doc/macos_machO_gate.md`) re-validates per process.
- L3 (this RFC) eliminates **both** problems in one shot: one resident process amortises startup over its lifetime, and routes every system tool through internal code paths. Net result: zero fork for the 94% claude-bind path, and 1 fork (the daemon spawn) for the remaining 6% codegen path.
- L4 (in-process library embedding) is strictly better for clients that can link against `libhexa`, but requires every consumer (claude-bind, LSP, editor plugins) to switch language/ABI. L3 ships first, L4 later.

### 1.3 Goals

1. **System-wide zero fork** for read-only operations (`atlas.lookup`, `lint`, `check`).
2. **One fork per build** (the daemon itself) for write operations, regardless of how many tools the build needs internally.
3. **Wire-compatible** with the existing claude-bind hook contract — drop-in replacement, no behaviour change visible to hooks.
4. **Bounded RAM** — daemon self-exits on idle; user can force-stop without state loss.

### 1.4 Non-goals (v0)

- Multi-host / network IPC. Unix-socket only, ever.
- Cross-user sharing. One daemon per user.
- Hot-swap of compiler binary itself (restart on upgrade is fine).
- Distributed build / remote execution.

---

## 2. Architecture

### 2.1 Process topology — one daemon per *user*

| Scope | Pros | Cons | Verdict |
|---|---|---|---|
| Per-host (system service) | Min RAM, max share | Cross-user perms minefield, multi-tenant security | ❌ |
| **Per-user** | One process per logged-in user, simple perms (0600 socket) | Multiple users on one box pay N× RAM | ✅ **v0** |
| Per-project | Per-cwd context isolation, no cache poisoning across projects | N projects = N daemons; defeats fork-storm goal | ❌ for v0, revisit v2 |

Decision: **per-user** for v0. Per-project context is handled inside the single daemon by a project-id field in each request (the daemon keeps a small map `project_root → ProjectContext`).

### 2.2 Socket location

- Linux: `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hexa/hexa.sock`
- macOS: `${TMPDIR}/hexa-${UID}/hexa.sock` (macOS lacks `XDG_RUNTIME_DIR`; `TMPDIR` is per-user under `/var/folders/...`)
- Permissions: socket file `0600`, parent dir `0700`, owner = invoking UID.
- Lock file alongside socket (`hexa.pid`) holds the daemon PID for client liveness check.

### 2.3 Component layout

```
compiler/daemon/
  server.hexa     — accept loop, request dispatch, idle timer
  proto.hexa      — JSON request/response codec, schema versioning
  watcher.hexa    — atlas.n6 mtime watcher, in-memory index reload
  context.hexa    — per-project state (atlas hash, hexa.toml, lint cache)
  client.hexa     — thin client used by `hexa daemon ipc <op>` subcommand
```

Driver (`compiler/main.hexa`) gains:

- `hexa daemon start | stop | status | restart`
- `hexa daemon ipc <op> [args]` — one-shot client (used by hooks)
- `hexa --serve` — internal flag, becomes the daemon entry once stage 1 lands

---

## 3. Lifecycle

### 3.1 States

```
  not-running ──hexa daemon start──▶ running ──idle 30 min──▶ self-exit ──▶ not-running
                                       │
                                       ├─ hexa daemon stop ──▶ graceful drain ──▶ exit
                                       ├─ atlas.n6 mtime change ──▶ reload (stay up)
                                       └─ SIGTERM / SIGINT ──▶ graceful drain ──▶ exit
```

### 3.2 Auto-start

- **Linux**: systemd user unit `~/.config/systemd/user/hexa-daemon.service`, type=notify, `WantedBy=default.target`. Socket-activation via `hexa-daemon.socket` so the daemon spins up on first client connect.
- **macOS**: launchd plist `~/Library/LaunchAgents/dev.hexa.daemon.plist` with `RunAtLoad=false`, `KeepAlive=false`, and `Sockets` dictionary so launchd lazily activates on socket access.
- Both flavours support **lazy activation**: the very first `hexa daemon ipc` call wakes the daemon; subsequent calls hit a warm process.

### 3.3 Idle timeout

- Default **30 min** of no requests → daemon self-exits.
- Configurable via `[daemon] idle_timeout_sec = ...` in `hexa.toml`.
- `0` disables timeout (developer mode).
- On idle exit, lock/pid file is removed so next call re-activates cleanly.

### 3.4 Reload

- Daemon watches `atlas.n6` (and `atlas.append.*.n6`) mtimes via kqueue (macOS) / inotify (linux).
- On change, daemon re-parses atlas in-memory and bumps an internal `atlas_generation` counter.
- This is **distinct from RFC-017 §4.5 static embed**: the static-embed path is compile-time and bakes atlas into the compiler binary. The daemon's atlas index is **runtime** state and can refresh without rebuilding. See §6.

---

## 4. Protocol v0

Line-delimited JSON, one request per line, one response per line. No framing layer beyond newline.

### 4.1 Requests

```json
{"op": "build",        "src": "x.hexa", "out": "a.out", "target": "darwin-arm64", "project": "/path"}
{"op": "atlas.lookup", "kind": "P",     "id":  "einstein-mass-energy",            "project": "/path"}
{"op": "lint",         "root": ".",     "project": "/path"}
{"op": "shutdown"}
```

### 4.2 Responses

```json
{"status": 0, "diags": [], "artifacts": ["a.out"]}
{"status": 0, "node": {"kind": "P", "id": "einstein-mass-energy", "atlas_hash": "a3f9..."}}
{"status": 1, "diags": [{"file": "x.hexa", "line": 42, "col": 11, "code": "S1", "msg": "..."}]}
{"status": 0, "msg": "shutting down"}
```

### 4.3 Wire rules (v0)

- **Human-readable JSON only**. No msgpack, no protobuf, no flatbuffer in v0. Easier to `nc` or `socat` for debugging.
- Every request carries an optional `id` field for client-side correlation; daemon echoes it.
- Every request carries `proto: "hexa.v0"`; mismatched proto → status 99 + `unsupported protocol` message.
- Unknown `op` → status 98 + `unknown op`.
- Diag list is the same shape as RFC-019 (error diagnostics spec) so clients can reuse formatters.

### 4.4 Future ops (deferred)

- `check` (lint + type without codegen, LSP path)
- `format`
- `discover` (n6 atlas search)
- `lsp.*` family (textDocument/definition, hover, completion) — see §10 v1.

---

## 5. Concurrency

| Version | Model | Rationale |
|---|---|---|
| **v0** | **single-threaded request queue** | Trivial correctness; matches today's serial driver behaviour; sufficient for the 94% claude-bind read path. |
| v1 | thread pool (N = number of cores) | Parallelise lint and atlas.lookup (read-only ops). Build still serialised per project. |
| v2 | full async (fiber / await) + per-project DAG-aware build cache | Multi-project monorepos, watch mode. |

v0 contract: requests are processed strictly in arrival order; clients that need parallelism open multiple connections (the accept loop is async even in v0, only the work loop is serial).

---

## 6. Atlas hot-reload

- Daemon's `watcher.hexa` registers kqueue/inotify watches on `${atlas_root}/atlas.n6` and the `atlas.append.*.n6` glob.
- On any mtime bump, the daemon re-runs the in-memory atlas merge (≈30–80 ms per RFC-017 §4.2) and atomically swaps the active index.
- In-flight requests finish against the old index; new requests see the new index.
- The daemon **does not** rebuild the compiler binary itself. RFC-017 §4.5 static-embed is a compile-time-only optimisation; the daemon keeps a parallel runtime index for hot-reload.
- Daemon exposes the atlas hash in every response for clients that want to detect drift.

This split is intentional:

- **Static embed (RFC-017)** = ship a frozen atlas inside the compiler binary for offline / single-binary deployment.
- **Daemon runtime index (this RFC)** = developer machine, atlas is edited daily, no rebuild required.

---

## 7. Security

- Unix domain socket only. **No TCP, no UDP, no abstract namespace, no network exposure ever.**
- Socket file mode `0600`, parent dir `0700`, owner = invoking UID. Verified at bind time, fatal if perms drift.
- No auth tokens. Filesystem permissions are the security boundary, same as ssh-agent and gpg-agent.
- Daemon refuses to start if the socket path resolves outside `XDG_RUNTIME_DIR` / `TMPDIR` (defence against symlink attacks).
- All paths in requests are normalised to absolute and rejected if they escape the project root declared in the request (`../`, symlink-up, etc).
- Daemon never executes arbitrary user shell. Build steps go through the same internal driver paths as `hexa build`.

---

## 8. Wire compatibility with claude-bind hooks

Today, claude-bind hooks invoke directly:

```
$HOME/.hx/packages/hexa/build/hexa_interp.real.real <args...>
```

Migration path (zero behaviour change):

1. Replace the hook entry shim with a small wrapper that calls `hexa daemon ipc <op> <args>`.
2. The wrapper is a 30-line shell script (POSIX sh) that:
   - tries the daemon socket first,
   - on `ECONNREFUSED` / missing socket, falls back to direct binary spawn (preserves today's behaviour during rollout),
   - emits a one-line stderr warning when falling back so we can measure adoption.
3. Once metrics show ≥99% daemon hit rate, the fallback is removed.

The hook layer does **not** belong to RFC-021. This RFC only commits to keeping the wire format stable enough that a thin shim is sufficient.

---

## 9. Bootstrap

- **Phase 0 (today, interpreter era)**: daemon binary is `hexa_interp` running `compiler/daemon/server.hexa`. `hexa daemon start` → spawns interpreter with that script. RAM cost ~30 MB resident.
- **Phase 1 (post stage 1 native compiler)**: daemon is the compiler binary itself, invoked as `hexa --serve`. The daemon and the one-shot driver share 100% of the code; `--serve` just flips main.hexa into the accept-loop branch instead of the build-once branch.
- **Phase 2 (stage 2)**: optional `libhexa` extraction so editors / LSP can embed in-process (L4 of the ladder), with the daemon as the fallback for non-linkable clients.

The Phase 0 daemon is acceptable as a stop-gap **only because** stage 1 is on the near-term roadmap. We do not invest heavily in interpreter-based daemon performance.

---

## 10. Roadmap

| Version | Scope | Gating |
|---|---|---|
| **v0** | Unix socket + line-delimited JSON RPC + 4 ops (build / atlas.lookup / lint / shutdown) + lifecycle (start/stop/status) + idle timeout | Stage 1 native compiler stable |
| **v1** | thread pool (read-only ops parallel) + atlas hot-reload (§6) + LSP backend ops (`check`, `lsp.hover`, `lsp.definition`) | v0 in production ≥1 month, hook fallback removed |
| **v2** | full async + multi-project context map + DAG-aware build cache + watch mode (`hexa daemon watch`) | v1 in production, real LSP client integrated |

Out of roadmap (explicitly): network IPC, multi-user share, distributed build.

---

## 11. Open questions

1. **One daemon per host vs per user vs per project?** — v0 picks per-user (§2.1). Per-project may be needed if atlas-override per project becomes common; revisit at v2. **Biggest open question.**
2. **cgroup / RAM limits** — should the systemd unit set `MemoryMax=` to bound runaway compile loops? launchd has no direct equivalent on macOS; rely on `setrlimit(RLIMIT_AS)` inside daemon? Defer to v1.
3. **Crash recovery / supervision** — systemd `Restart=on-failure` is straightforward; launchd `KeepAlive` with `SuccessfulExit=false` is the macOS equivalent. Need a pid-file lockout to prevent thrash.
4. **LSP integration timing** — this is roadmap D2 in RFC-017. Should LSP land as v1 (separate ops) or v2 (full async)? Probably v1 with a serial fallback.
5. **append-N6 watch granularity** — watching 409 append files individually is wasteful; watch the directory and filter by glob, or watch a manifest file? Decide before v1.
6. **Multi-tenant CI** — on shared CI runners, `XDG_RUNTIME_DIR` may be missing or shared. Need a `--socket-path` override and CI-mode docs.
7. **Hook fallback removal criterion** — we say ≥99% hit rate, but how is that measured? Add daemon counter + `hexa daemon status --json`.

---

## 12. Decision log

- **2026-05-09** — Pursue v0 ASAP after stage 1 native compiler settles. Defer all daemon implementation until then. This RFC is the L3 rung in the SPEC.yaml `fork_storm_prevention:` ladder (companion task #56).
- **2026-05-09** — Per-user scope chosen over per-host and per-project for v0 (§2.1).
- **2026-05-09** — Wire format = line-delimited JSON in v0; binary formats explicitly out of scope (§4.3).
- **2026-05-09** — Daemon runtime atlas index is **separate** from RFC-017 static embed; both coexist (§6).
- **2026-05-09** — claude-bind hook migration is a thin shell shim, not part of this RFC's deliverables (§8).

---

## 13. One-line conclusion

Route every hexa call through one resident per-user daemon over a 0600 Unix socket speaking line-delimited JSON; eliminate ~94% of `hexa_interp.real.real` forks (the claude-bind read path) immediately, and reduce the remaining build path to one fork (the daemon itself) regardless of how many internal tools a build needs.
