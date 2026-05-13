# `stdlib/os/pty.hexa` + `stdlib/os/termios.hexa` — pseudo-terminal pair + raw mode

> **status**: `applied` (2026-05-13 KST PM, wilson session) — C primitives shipped in `self/native/pty.c`; hexa wrappers in `self/stdlib/os/{pty,termios}.hexa`; codegen direct-emit + `_is_builtin_name` registration in `self/codegen_c2.hexa`; hexa_v2 regenerated and hexa.real rebuilt; live smoke test PASS on macOS arm64 (`pty_open` → master/slave/name, `pty_resize`/`pty_get_winsize` round-trip 24×80, `pty_tcgetattr` returns 4 flags + 20 cc entries, `tty_isatty` true on both ends, `pty_spawn /bin/echo`). Wilson `wilson test` 23/23 PASS post-rebuild.

**From:** wilson (downstream) — 2026-05-13. P0 #5 of 5 in the
`u-root/cpu` port. Companion meta: `stdlib-for-cpu-port.md`.
Cross-platform (macOS + Linux). Pairs naturally with a small
`stdlib/os/termios.hexa` (raw/cooked toggle); fine to file as one
delivery.

## Why

Two consumers in hexa-land already need this:

1. **`u-root/cpu` port** — `server/server.go:91` does `pty.Start(cmd)`
   to give the remote child a real PTY so curses programs / job
   control / line editing work. Without this, `cpu ubu-1 vim` is
   useless.
2. **wilson `harness-cli`** — currently uses ad-hoc raw-mode toggles
   (`tcsetattr`-via-exec or a tiny C shim). A proper hexa stdlib
   `pty` + `termios` would let `harness-cli` drop the ad-hoc layer.

Both consumers want the same surface, so this is high-leverage.

## Surface — proposed

```hexa
// stdlib/os/pty.hexa

pub struct PtyPair { master: int, slave: int, slave_name: string }

// POSIX-portable open of a pseudo-terminal pair.
//  Linux: posix_openpt + grantpt + unlockpt + ptsname_r
//  Darwin: posix_openpt + grantpt + unlockpt + ptsname_r
//  FreeBSD: posix_openpt + grantpt + unlockpt + ptsname
pub fn openpty() -> Result<PtyPair, int>

// Convenience: fork + replace stdin/out/err in the child with the
// slave end, return (pid, master_fd) to the parent.
//  Linux: forkpty equivalent (no glibc dep)
//  Darwin: forkpty (libsystem)
pub fn forkpty(prog: string, argv: [string], env: [string]) -> Result<(int, int), int>

// Window-size sync (TIOCSWINSZ on master).
pub struct WinSize { rows: u16, cols: u16, xpix: u16, ypix: u16 }
pub fn set_winsize(fd: int, ws: WinSize) -> int
pub fn get_winsize(fd: int) -> Result<WinSize, int>
```

```hexa
// stdlib/os/termios.hexa

pub struct Termios { iflag: u64, oflag: u64, cflag: u64, lflag: u64, cc: [u8] }

pub fn tcgetattr(fd: int) -> Result<Termios, int>
pub fn tcsetattr(fd: int, when: u32, t: Termios) -> int

// High-level toggle — what 99% of callers actually need.
pub fn make_raw(t: Termios) -> Termios       // returns a copy with raw flags set
pub fn enter_raw_mode(fd: int) -> Result<Termios, int>   // returns old, sets raw
pub fn restore_mode(fd: int, old: Termios) -> int        // tcsetattr(TCSANOW, old)

// when constants
pub const TCSANOW   : u32 = 0
pub const TCSADRAIN : u32 = 1
pub const TCSAFLUSH : u32 = 2

// c_cc indices (most-used)
pub const VEOF     : usize = 0
pub const VEOL     : usize = 1
pub const VINTR    : usize = 8
pub const VQUIT    : usize = 9
pub const VMIN     : usize = 16
pub const VTIME    : usize = 17
// ... (target-specific; behind @platform if values differ)

// flag bits — only the ones make_raw touches. Full set is platform-y.
pub const ICANON : u64 = 0x00000002
pub const ECHO   : u64 = 0x00000008
pub const ISIG   : u64 = 0x00000001
pub const IXON   : u64 = 0x00000400
// ...
```

`enter_raw_mode` / `restore_mode` is the boring pattern every TUI
needs; bake them in so callers don't re-implement.

## Open

- **`fork` vs `posix_spawn`.** `forkpty` semantics (fork + setsid +
  TIOCSCTTY + dup2(slave,0/1/2) + exec) is conventional. A
  `posix_spawn`-based path is cleaner but the spawn flags for
  controlling-tty are not portable. Recommend: implement `forkpty`
  with the explicit dance.
- **Termios flag values are target-specific.** Linux vs Darwin
  differ. Two options: (a) emit per-platform consts behind
  `@platform`; (b) introduce a portable enum and translate. (a) is
  smaller code, (b) is friendlier to portable callers. wilson is
  OK with (a) — POOL.md / harness-cli pick the right consts per
  build target.

## Atlas / diagnostics

- No atlas content (kernel/libc ABI surface).
- No new HX codes.

## Size estimate

~300 LOC total (pty ~150, termios ~150). Each is mostly constants +
thin wrapper. The hard part is the cross-platform PTY allocation
dance; cribbing from creack/pty (Go) clarifies.

## Downstream consumers

- wilson `pool` plugin (POOL.md stage-B) — `forkpty` for cpu server.
- wilson `harness-cli` — replace ad-hoc raw-mode toggle with
  `enter_raw_mode` / `restore_mode`.
- Any future hexa REPL / interactive runner.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Meta note: `stdlib-for-cpu-port.md`.
