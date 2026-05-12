# stdlib/channel — bidirectional IPC + spawn-with-channels

**Status**: preview (since 2026-05-08) · **v0.2.0** (2026-05-13)
**Module**: `stdlib/channel.hexa`
**Selftest**: `stdlib/test/test_channel.hexa` — 21/21 PASS (interp, macOS arm64)
**Driver**: anima chat autonomous-speech roadmap 2026-05-08, decision 4c
(L2 multi-agent dialogue + L5 long-running daemon prereq); **v0.2.0** driver =
`stdlib/jsonl_pool` (wilson swarm — `incoming/patches/wilson-pi-port-6-gap-prereq.md` G6).

**v0.2.0 (2026-05-13, additive — the original 6-symbol surface is unchanged):**
- `channel_send_sync(fd, msg) -> bool` — synchronous send (no `()&` backgrounding).
  Surfaces **back-pressure** (a full kernel pipe buffer blocks the caller in `write(2)`)
  and gives **ordering** (call N completes before N+1 starts → N sends on the same fd
  arrive in call order; `channel_send` races). FIFO inode gone → `false` = the explicit
  EPIPE-equivalent `channel_send` lacks. (See "Synchronous send" + "No back-pressure
  surfacing" below — the latter is now *surfaced*.)
- `channel_recv_lines(fd, timeout_ms) -> [string]` — drain **all** currently-buffered
  lines in one shot via a single unbuffered `sysread`. `channel_recv` alone reads one
  line via perl's buffered `<$fh>` and `close()`s, discarding lines 2..N when several
  are buffered — invisible in strict ping-pong, **wrong for a request-stream / demux
  pool**. See "Embedded newlines / multi-line buffering" below.

## TL;DR

Hexa stdlib's existing process surface (`stdlib/proc.hexa`) gives you fire-and-forget supervised spawn (`proc_spawn_supervised`) and one-shot stdin/JSON request-response (`proc_run_with_stdin`, `proc_run_json_bridge`). It does NOT give you a long-lived bidirectional conversation between two processes — exactly what L2 (CLM A ↔ CLM B autonomous dialogue) and L5 (Engine A/G persistent daemon) need.

`stdlib/channel` adds that. Six new symbols, no changes to existing surface:

```hexa
import "stdlib/channel" as ch

let pair = ch.channel_pair_open()           // [read_fd, write_fd]
let pid  = ch.proc_spawn_with_channels(
    "python3 my_helper.py",
    pair[1],                                 // child's stdin = parent's write side
    pair[0]                                  // child's stdout = parent's read side
)
ch.channel_send(pair[1], "hello")
let line = ch.channel_recv(pair[0], 5000)    // ms timeout; "" = no data / EOF
ch.channel_close(pair[0])
ch.channel_close(pair[1])
```

## Implementation strategy: (a) named FIFO + perl IO::Select probe

Three approaches were considered:

| # | Approach | Verdict |
|---|---|---|
| (a) | `mkfifo` filesystem FIFO + `perl -MIO::Select` for timeout | **chosen** |
| (b) | `socketpair(AF_UNIX, SOCK_STREAM)` via long-lived perl/python | rejected (real fds don't survive across hexa's stateless `exec()` invocations) |
| (c) | `c_ffi` to libc `socketpair` / `pipe2` | viable but heavier (requires session-scoped FFI handle table not in current runtime) |

Why (a) is right:
- mkfifo creates a kernel-resident FIFO inode that PERSISTS as a filesystem object across separate `exec()` calls. Hexa's `exec()` is stateless (each invocation is a fresh popen of `/bin/sh -c`), so the channel "fd" must be filesystem-resolvable. ✓
- `open(2)` on a FIFO with `O_RDWR` (`+<` in perl) does NOT block waiting for a peer — kernel always permits it. This sidesteps the classic FIFO-open deadlock.
- `IO::Select::can_read($timeout_secs)` provides accurate ms-resolution timeout via `select(2)`. Same idiom as the recently-landed `stdlib/sys.hexa::sys_stdin_read_line_timeout` (S-NEW-SYS follow-on).
- Cross-platform: POSIX mkfifo + perl-base ship on macOS + every major Linux distro.

The "fd" returned is a small `int` channel-id that encodes a (nonce, side) pair. The path is reconstructed deterministically via `channel_path_for(fd)`. No global mutable state, no registry file, hexa-stateless-friendly.

## ABI primitives used

| Op | Primitive | Notes |
|---|---|---|
| Create channel | `mkfifo(2)` via `mkfifo -m 0600` shell | Mode 0600 owner-only |
| Open for read (parent) | perl `open($fh, "+<", $path)` → `O_RDWR` | Non-blocking open semantics |
| Open for write (parent) | shell `exec 3<>'$path'` → `O_RDWR` | Same — kernel-level RW |
| Open for read (child stdin) | shell `cmd <&3` after parent pre-opens `3<>fifo` | Inherits RW fd, child sees normal stdin |
| Open for write (child stdout) | shell `cmd >&4` after parent pre-opens `4<>fifo` | Same — child sees normal stdout |
| Wait with timeout | `IO::Select::can_read($ms/1000.0)` | `select(2)` under the hood |
| Read one line | perl `<$fh>` then `s/\\r?\\n\\z//` | CR/LF tolerant |
| Send line | shell `printf '%s\\n' '<msg>' >&3` | One-shot script per call |
| Close | `unlink(2)` via `rm -f` | Inode removed; existing peer fds get EOF on next read, EPIPE on write |

## Blocking vs non-blocking semantics

`channel_recv(fd, timeout_ms)` honours three regimes:

| `timeout_ms` | Behavior |
|---|---|
| `< 0` | Block indefinitely (perl `can_read()` with no arg) |
| `== 0` | Single `select(2)` poll; return immediately if no data |
| `> 0` | Wait up to `timeout_ms` ms; return on first data OR timeout |

Return value of `""` is overloaded: it means "no data" (timeout fired, or peer closed the write end and FIFO is drained). The roadmap entry treats this as the same condition by intent — both signal "peer is unresponsive". Callers needing to distinguish should pair recv with `proc_alive(pid)` from `stdlib/proc`.

`channel_send(fd, msg)` is fire-and-forget non-blocking: the message is written to a kernel pipe buffer and the call returns. EPIPE on a closed peer is NOT surfaced as a return value (the `&` background subshell catches it on stderr but doesn't propagate). Callers needing reliable delivery should bracket sends with response acks via `channel_recv` — or use `channel_send_sync`.

### Synchronous send (`channel_send_sync`, v0.2.0)

`channel_send_sync(fd, msg) -> bool` runs the write **without** the `()&` backgrounding `channel_send` uses. Two consequences:

- **Back-pressure is surfaced.** The writer opens the FIFO RW (`exec 3<>` — a non-blocking open, dodging the classic FIFO-open deadlock) and `write(2)`s the line itself. When the kernel pipe buffer is full (slow / stalled peer reader), `write(2)` blocks and so does this call — the caller feels the peer's pace instead of piling unbounded data into background shells.
- **Ordering is guaranteed.** Each call fully completes (its `sh` process exits) before the next one starts, so N `channel_send_sync` calls on the same fd arrive at the peer in call order. `channel_send` backgrounds each write under `()&`, so N rapid `channel_send` calls race and can arrive out of order — fine for one-shot fire-and-forget, wrong for a request stream (this is why `stdlib/jsonl_pool` uses `channel_send_sync`).

Return: `false` if the FIFO inode is gone (peer called `channel_close`, or the channel was never opened) — the explicit EPIPE-equivalent `channel_send` doesn't give. Caveat: if the inode still exists but the peer process died without `channel_close`, a small line (≤ pipe-buf) still goes into the kernel buffer and the call returns `true`; true EPIPE would need a write-only open that blocks until a reader attaches, trading away the non-blocking-open property — the pool layer detects a dead cell via `pool_pids`+`pool_alive`, not via the send.

## Cross-platform (macOS / Linux)

| Concern | macOS | Linux | Notes |
|---|---|---|---|
| `mkfifo -m 0600` | ✓ | ✓ | POSIX |
| FIFO O_RDWR open | ✓ | ✓ | POSIX |
| Pipe buffer size | 65536 default | 65536 default | Enlargeable on Linux via F_SETPIPE_SZ; not done here |
| Last-writer-close drains buffer | **drops** when no reader attached | **drops** when no reader attached | Both POSIX-conformant; matters for "send-before-spawn" patterns |
| `perl -MIO::Select` | ships in perl-base | ships in perl-base | Required dep, same as stdlib/sys S-SYS-STDIN-TIMEOUT |
| `nohup` | ✓ | ✓ | POSIX |

Behaviorally identical on both. Selftest passes on macOS arm64 (aka Darwin); CI run on Linux x86_64 expected to also pass (no platform-specific `if uname` branches in module).

## Performance characteristics

Measured on macOS arm64 (M-class CPU, warm cache):

| Operation | Cost | Dominated by |
|---|---|---|
| `channel_pair_open` | ~10 ms | 2× mkfifo shell-out + status check |
| `channel_send` (small line) | ~5 ms | sh exec + small file create + printf |
| `channel_send_sync` (small line, drained peer) | ~5 ms | sh exec + small file create + printf (blocks if peer buffer full = back-pressure) |
| `channel_recv` (data ready) | ~10 ms | perl fork+exec + select syscall |
| `channel_recv` (timeout fires) | timeout + ~10 ms overhead | perl select |
| `channel_recv_lines` (data ready) | ~10 ms | perl fork+exec + select + one sysread (drains *all* buffered lines in this one call) |
| `channel_close` | ~3 ms | rm -f shell-out |
| `proc_spawn_with_channels` | ~20 ms | nohup + 2 fifo opens + sh -c |

Per-op fork+exec overhead is the dominant cost (~5-10 ms). For LLM dialogue loops where a single token of inference is 100-1000 ms, the IPC overhead is invisible. For tight ping-pong synthetic benchmarks the overhead dominates — a future c_ffi-backed `channel_recv_native` (using libc `select` + `read` directly via the c_ffi surface) can supplant without changing the public API.

The 5-cycle ping-pong selftest completes in ~150 ms total wall-clock — comfortably below the 3000 ms recv timeout used per cycle.

## Known limits (raw#91 — be honest)

- **Line size**: a single line is whatever fits in the kernel pipe buffer (PIPE_BUF=512 atomic on macOS, 4096 on Linux; total buffer 65536 default). Lines larger than the buffer split across multiple `read(2)`s — perl's `<$fh>` handles this, but extremely large lines (> 1 MB) will starve the writer until the reader drains. Practical recommendation: keep individual messages under 64 KB. Not enforced.

- **Embedded newlines / multi-line buffering**: `channel_send` appends a single trailing `\n`. If `msg` itself contains `\n`, it passes through verbatim. More importantly: when *several* messages are buffered before you read, `channel_recv` returns only the FIRST line and **discards the rest** — its perl `<$fh>` is buffered, so the underlying `read(2)` slurps the whole pipe buffer into perl's I/O buffer, then `print $line; close($fh)` throws lines 2..N away. Invisible in strict ping-pong (only ever one line buffered); a silent data-loss bug for a request-stream / demux pool. **Fix (v0.2.0): `channel_recv_lines(fd, timeout_ms)`** — `can_read(timeout)` then one unbuffered `sysread` of the whole available buffer → `split(/\n/)` → returns *all* lines. Line framing holds because `channel_send`/`channel_send_sync` write lines ≤ PIPE_BUF (atomic). Callers wanting strict 1-message-per-line should still pre-validate / replace embedded `\n` with a marker; callers reading a multi-message burst should use `channel_recv_lines`, not a loop of `channel_recv`.

- **close-on-exec**: FIFO fds are NOT marked `FD_CLOEXEC`. A grandchild spawned via `system()`/`fork()`/`exec()` from inside the child will inherit the FIFO descriptors. For cooperative children this is harmless; for security-sensitive cases, the child should explicitly close fds 3 and 4 before exec'ing.

- **EPIPE on closed peer**: `channel_send` does NOT propagate EPIPE / SIGPIPE to the caller — it returns `true` even if the peer has closed the read end. **`channel_send_sync` (v0.2.0)** returns `false` when the FIFO inode is gone (the closest the FIFO model gives to EPIPE — see "Synchronous send" for the inode-present-but-peer-dead caveat). Idiom for `channel_send`: bracket sends with response acks via `channel_recv` / `channel_recv_lines`, which return `""` / `[]` on a peer-closed channel.

- **Send-before-spawn loses messages on macOS**: BSD/Darwin FIFO semantics drop unconsumed buffered bytes when the LAST writer closes WITHOUT a reader currently attached. Sequence `pair = channel_pair_open(); pid = proc_spawn_with_channels(...); channel_send(...)` (spawn before send) — same advice as POSIX `pipe(7)` recommends.

- **Back-pressure** — `channel_send` does NOT surface it: if the reader is slow and the kernel buffer fills, the `write(2)` blocks in the background subshell, invisible to the parent (visible only as growing process count via `pgrep -f hexa_chan_send`). **Use `channel_send_sync` (v0.2.0)** for pipelines where back-pressure matters — it runs the write in the foreground so a full buffer blocks the caller. (A c_ffi-based `channel_send_native` using libc `write` with `O_NONBLOCK` + `EAGAIN` could later give finer control without an API change.)

- **Nonce collision**: nonces use `epoch_seconds * 1e6 + (pid % 1000) * 1e3 + counter`. Two hexa scripts started in the same wall-clock second from processes with PIDs differing by a multiple of 1000, both calling `channel_pair_open()` exactly N times, would collide. `_ch_alloc_counter` is per-script so within one script collisions are impossible; cross-script the probability is astronomically small but not zero.

- **Cleanup on parent crash**: if the parent hexa script crashes between `channel_pair_open` and `channel_close`, the FIFO inodes remain in `/tmp` until manual cleanup or `tmpwatch`. `tool/resource_reaper.hexa` does NOT currently scan for orphaned channel FIFOs (out of scope — could be added with a `kind=channel` resource entry, future work).

## Recipe: supervised channel for L5 daemons

Combine with `proc_spawn_supervised` to get lease-TTL reaping over a channel-bound child:

```hexa
import "stdlib/proc"
import "stdlib/channel" as ch

let pair = ch.channel_pair_open()

// Wrap the child cmd in a setsid+register prologue so the resource_reaper
// will SIGTERM the whole pgrp on lease expiry.
let pid = ch.proc_spawn_with_channels(
    "exec setsid python3 daemon.py",  // exec replaces sh, child is pgrp leader
    pair[1], pair[0]
)
proc_register_external(pid, "engine-a-daemon", 600, "L5 chat daemon")

// ... long-running dialogue ...
defer {
    ch.channel_close(pair[0])
    ch.channel_close(pair[1])
    proc_reap(pid)
}
```

(`proc_register_external` is a future helper — for now, the channel + manual `proc_kill` on tear-down is the working idiom.)

## Recipe: sibling-to-sibling (no parent middleman)

L2 multi-agent: CLM A and CLM B talk directly, parent supervises but doesn't relay.

```hexa
let ab = ch.channel_pair_open()    // A → B (B reads, A writes)
let ba = ch.channel_pair_open()    // B → A

// A: stdin = ba (recv from B), stdout = ab (send to B)
let pid_a = ch.proc_spawn_with_channels("clm_role_a.hexa", ba[1], ab[0])
// B: stdin = ab (recv from A), stdout = ba (send to A)
let pid_b = ch.proc_spawn_with_channels("clm_role_b.hexa", ab[1], ba[0])

// parent doesn't even need to touch the channel after spawn — A and B
// converse directly. Parent monitors via proc_alive(pid_a/pid_b) and
// reaps on completion / lease expiry.
```

## Out-of-scope (intentional gaps)

- **Multi-line messages with framing**: no length-prefix protocol; lines only. JSON-line idiom (`json_stringify` per message + newline-free encoding) recommended.
- **Binary transport**: line-oriented assumes ASCII / UTF-8 text. Embedded NUL bytes will be dropped by `printf '%s'`. For binary data, use `proc_run_with_stdin` (one-shot) or roll a separate binary-channel module on top of `pipe(2)` via c_ffi.
- **Windows**: mkfifo doesn't exist. A Windows port would use Named Pipes (`\\.\pipe\name`) — separate module entirely. Hexa-lang does not target Windows yet.
- **Reconnect / handle re-validation**: a closed channel cannot be re-opened on the same fd. Callers re-running `channel_pair_open` get a fresh nonce.

## Cross-link

- `stdlib/proc.hexa` — sister supervised-spawn (untouched by this PR)
- `stdlib/sys.hexa::sys_stdin_read_line_timeout` — sister perl IO::Select pattern (S-NEW-SYS)
- `stdlib/c_ffi.hexa` — substrate for a future `channel_recv_native` replacement
- `.roadmap.stdlib` S-NEW-CHANNEL — this entry's roadmap row
- anima chat autonomous-speech roadmap (`/Users/ghost/core/anima/docs/anima_chat_autonomous_speech_roadmap_2026_05_08.md`) decision 4c — driving requirement
