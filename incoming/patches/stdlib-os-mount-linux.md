# `stdlib/os/mount.hexa` — Linux `mount(2)` / `umount(2)` syscall wrapper

**From:** wilson (downstream) — 2026-05-13. P0 #3 of 5 in the
`u-root/cpu` port. Companion meta: `stdlib-for-cpu-port.md`. Smallest
and dependency-free — recommended first landing.

## Why

The `cpu`-pattern (Plan 9 cpu(1)) requires the server side to mount a
9P share + bind mounts + tmpfs into the child namespace. Five sites
in `~/core/resource/vendor/u-root-cpu/`:

```
session/session_linux.go:120  unix.Mount("localhost", target, "9p", flags, opts)
session/session_linux.go:132  unix.Mount("/", tmpMnt+"/local", "", MS_BIND, "")
session/session_linux.go:141  unix.Mount("cpu", tmpMnt, "tmpfs", 0, "")
cmds/cpud/serve.go:77         unix.Mount("cpu", "/tmp", "tmpfs", 0, "")
mount/mount_linux.go:68       mount(unix.Mount, fstab)
```

hexa currently has no `mount(2)` binding. Downstream forks `mount` /
`mount(8)` via `exec()` — fork-storm, SPEC §16 anti-pattern.

## Surface — proposed

```hexa
// @platform(linux)
pub fn mount(source: string, target: string, fstype: string,
             flags: u64, data: string) -> int
//  rc == 0 on success; -errno on failure (same shape as exec rc).

// @platform(linux)
pub fn umount(target: string, flags: u32) -> int

// @platform(linux)
pub fn umount2(target: string, flags: u32) -> int
//  alias for umount(target, flags) with explicit MNT_* flags.

// Flag constants (Linux, asm-generic/mount.h).
pub const MS_RDONLY      : u64 = 1
pub const MS_NOSUID      : u64 = 2
pub const MS_NODEV       : u64 = 4
pub const MS_NOEXEC      : u64 = 8
pub const MS_SYNCHRONOUS : u64 = 16
pub const MS_REMOUNT     : u64 = 32
pub const MS_MANDLOCK    : u64 = 64
pub const MS_DIRSYNC     : u64 = 128
pub const MS_NOATIME     : u64 = 1024
pub const MS_NODIRATIME  : u64 = 2048
pub const MS_BIND        : u64 = 4096
pub const MS_MOVE        : u64 = 8192
pub const MS_REC         : u64 = 16384
pub const MS_SILENT      : u64 = 32768
pub const MS_POSIXACL    : u64 = 1 << 16
pub const MS_UNBINDABLE  : u64 = 1 << 17
pub const MS_PRIVATE     : u64 = 1 << 18
pub const MS_SLAVE       : u64 = 1 << 19
pub const MS_SHARED      : u64 = 1 << 20
pub const MS_RELATIME    : u64 = 1 << 21
pub const MS_STRICTATIME : u64 = 1 << 24
pub const MS_LAZYTIME    : u64 = 1 << 25

// umount2 flags
pub const MNT_FORCE    : u32 = 1
pub const MNT_DETACH   : u32 = 2
pub const MNT_EXPIRE   : u32 = 4
pub const UMOUNT_NOFOLLOW : u32 = 8
```

macOS stub: same signature, returns `-ENOSYS` and emits HX-warning
(or compile-time `@platform(linux)` rejection — preferred). Tied to
the @platform annotation question below.

## Open

- **`@platform(...)` annotation.** hexa-lang spec may already have a
  conditional-compilation/target-gate mechanism (looked but didn't
  find one in passing). If not, this note doubles as a request:
  introduce `@platform(linux | darwin | freebsd | …)` at item level
  so a fn / module is omitted (or stub'd to `unimplemented()`) on
  unmatched targets. Without this, callers need ifdef-style runtime
  guards everywhere.
- **Error reporting.** Returning `-errno` matches the kernel ABI but
  hexa's idiomatic style might prefer a `Result<unit, OsError>`-like
  shape. Take whichever fits existing `stdlib/os/*` conventions.

## Atlas / diagnostics

- No new atlas L nodes — `mount` is a kernel ABI, not a derivable law.
- No new HX codes needed; `mount(2)` failures use the existing
  `host_log` / errno path.

## Size estimate

~150 hexa LOC (thin wrapper + constants). One day of work for
someone fluent in hexa-lang's existing syscall binding pattern.

## Downstream consumers

- wilson `pool` plugin (POOL.md stage-B). 9P / tmpfs / bind mounts
  to set up the cpu-pattern's child namespace.
- Any future hexa-native container runtime.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Meta note: `stdlib-for-cpu-port.md`.
