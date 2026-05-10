---
doc: hexa-lang.doc.daemon_v0
kind: spec
audience: [human, agent]
date: 2026-05-09
status: v0
parent: proposals/rfc_021_daemon_mode.md §13
---

# hexa daemon v0 — first cut

RFC-021 §13's suggested first deliverable: a minimal `hexa daemon serve`
that listens on a Unix socket and answers two ops, `atlas.lookup` and
`shutdown`. Everything else from §4 (build, lint, check, etc.) is
deferred to v0.2 / v1.

## Quick start

Start the daemon (foreground; backgrounding is the user's responsibility
in v0):

```sh
hexa run compiler/main.hexa daemon serve --socket=/tmp/hexa.sock
```

Default socket path:

- linux: `${XDG_RUNTIME_DIR:-/tmp}/hexa.sock`
- macOS: `${TMPDIR:-/tmp}/hexa.sock`

Default idle timeout: `1800` seconds (30 minutes) per RFC-021 §3.3.

Send a request from another shell:

```sh
echo '{"op":"atlas.lookup","kind":"P","id":"alpha"}' | nc -U /tmp/hexa.sock
# → {"status":"ok","result":{"kind":"P","id":"alpha","raw":"@P alpha = ..."}}
```

Stop the daemon:

```sh
echo '{"op":"shutdown"}' | nc -U /tmp/hexa.sock
# → {"status":"ok"}
```

## Op list (v0)

| op             | request fields           | response (success)                                         |
|----------------|--------------------------|------------------------------------------------------------|
| `atlas.lookup` | `kind` (P/C/L/E), `id`   | `{"status":"ok","result":{"kind":"...","id":"...","raw":"..."}}` |
| `shutdown`     | (none)                   | `{"status":"ok"}` and the daemon exits                     |

Errors:

| condition                  | response                                          |
|----------------------------|---------------------------------------------------|
| unrecognised `op`          | `{"status":"error","error":"unknown_op"}`         |
| empty / unparseable line   | `{"status":"error","error":"malformed_request"}`  |

`atlas.lookup` for an unknown id returns success with `kind=""` and
`raw=""` — the daemon distinguishes "miss" from "error". This matches
the underlying `compiler/atlas/merger.hexa::lookup` sentinel-node
contract.

## v0 socket layer (documented limitation)

The v0 server shells out to `socat UNIX-LISTEN:<sock>,fork EXEC:<self>`
because stage0 hexa has no libc FFI for `socket(2)` / `bind(2)` /
`listen(2)`. Each accepted connection forks a fresh handler process
that runs `hexa run compiler/main.hexa daemon handle-line`, reads one
JSON line from stdin, writes one JSON line to stdout, and exits.

Consequence: in v0 the atlas index is reloaded per request via
`static_atlas()`. That call is O(1) const-array materialization — no
file I/O, no parsing — so the cost is small, but it does mean the
"resident process amortises startup" benefit RFC-021 §1.2 motivates is
not yet realised. v1 fixes this by replacing the socat shellout with
a libc-FFI accept loop inside the same hexa process, at which point
`static_atlas()` becomes a one-time startup cost.

This is a deliberate v0 tradeoff: prove the wire protocol end-to-end
without blocking on intrinsic work the RFC explicitly defers.

## Roadmap

| version | scope                                                                          | gating                              |
|---------|--------------------------------------------------------------------------------|-------------------------------------|
| **v0**  | this doc — atlas.lookup + shutdown via socat shellout                          | shipped 2026-05-09                  |
| v0.2    | + `lint`, `build` ops (still socat shellout, still per-request handler fork)   | v0 in use ≥1 week                   |
| v1      | thread pool + libc-FFI accept loop + atlas hot-reload (RFC-021 §6)             | stage 1 native compiler stable      |
| v2      | full async + per-project context + LSP backend ops                             | v1 in production                    |

Out of scope (per RFC-021 §1.4): network IPC, multi-user share,
distributed build, hot-swap of the compiler binary itself.

## Known limitations (v0)

1. **No resident atlas** — atlas is loaded per request. Cheap
   (`static_atlas()` is O(1) materialization) but defeats the §1.2
   motivation until v1 lands the FFI accept loop.
2. **No atlas hot-reload** — RFC-021 §6's kqueue/inotify watcher is
   v1; v0 reads whatever `static_atlas()` was compiled with at daemon
   start time. Restart the daemon to pick up atlas changes.
3. **Single-threaded request semantics** — v0 contract per RFC-021 §5;
   socat's `fork` mode does spawn parallel handlers, but atlas.lookup
   is read-only and idempotent so this is benign for v0's two ops.
4. **No request id / correlation** — RFC-021 §4.3's optional `id`
   echo field is not honoured in v0.
5. **No graceful drain on shutdown** — in-flight handler children
   complete normally because they own their own process; the parent
   daemon exits as soon as the marker file is observed.
6. **`socat` is required** — install via `brew install socat` (macOS)
   or `apt install socat` (linux). The daemon refuses to start if
   socat is not on PATH.
7. **No auth** — Unix socket file permissions are the security
   boundary, same as v1 will be (RFC-021 §7). v0 does NOT yet enforce
   the `0600` / `0700` directory mode RFC-021 §2.2 specifies; that
   lands with the FFI bind in v1.

## Files

| path                                  | role                                                |
|---------------------------------------|-----------------------------------------------------|
| `compiler/daemon/server.hexa`         | accept loop driver, idle timer, shutdown marker     |
| `compiler/daemon/proto.hexa`          | hand-rolled JSON encode/decode for v0 message types |
| `compiler/daemon/server_test.hexa`    | end-to-end smoke test                               |
| `compiler/main.hexa`                  | `daemon serve` / `daemon handle-line` dispatch      |

See also: `proposals/rfc_021_daemon_mode.md` (full spec).
