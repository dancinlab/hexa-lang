# `stdlib/os/namespace.hexa` — Linux `unshare(2)` / `setns(2)` / `pivot_root(2)`

> **status**: `applied` (2026-05-13 KST PM, bundled with mount) — `hexa_unshare` / `hexa_setns` / `hexa_pivot_root` in `self/native/namespace.c`; `namespace_clone_const(name)` returns CLONE_NEW* values at module-load time so the hexa-side `pub let CLONE_NEW*` constants stay in sync with `<linux/sched.h>`. macOS returns `-ENOSYS` for the syscalls but still surfaces the canonical Linux constants for portable code. Convenience: `unshare_mount_ns_private()` does the "fresh mount ns + mount / private rec" combo the cpu pattern's first move needs. Live verified on Mac (`CLONE_NEWNS=131072`, `CLONE_NEWUSER=268435456`, unshare returns -78). Wilson 23/23 smoke PASS.

**From:** wilson (downstream) — 2026-05-13. P0 #4 of 5 in the
`u-root/cpu` port. Companion meta: `stdlib-for-cpu-port.md`.
Dependency-free; can land alongside `stdlib-os-mount-linux.md`.

## Why

`cpu`-pattern isolates the server-side execution in a fresh mount
(and often user/PID) namespace before mounting the caller's 9P share.
Without namespace isolation, mounting `localhost:9p` would affect the
host's global namespace. Upstream Go uses:

```
cmds/cpuns/main_linux.go   syscall.SysProcAttr{Cloneflags: CLONE_NEWNS|NEWUSER|...}
session/session_linux.go   uses CLONE_NEWNS implicitly via the cpuns helper
```

hexa today has no namespace primitives. Calling `unshare(1)` via
`exec()` is possible but loses the "child runs in the namespace its
parent set up" semantics (the helper would have to fork-exec the real
work, two layers).

## Surface — proposed

```hexa
// @platform(linux)
pub fn unshare(flags: u32) -> int
//  rc == 0 on success; -errno on failure.

// @platform(linux)
pub fn setns(fd: int, nstype: u32) -> int

// @platform(linux)
pub fn pivot_root(new_root: string, put_old: string) -> int

// CLONE_* flags (sched.h)
pub const CLONE_NEWNS     : u32 = 0x00020000   // mount namespace
pub const CLONE_NEWUTS    : u32 = 0x04000000   // hostname / NIS
pub const CLONE_NEWIPC    : u32 = 0x08000000   // SysV IPC
pub const CLONE_NEWUSER   : u32 = 0x10000000   // user IDs
pub const CLONE_NEWPID    : u32 = 0x20000000   // process IDs
pub const CLONE_NEWNET    : u32 = 0x40000000   // network
pub const CLONE_NEWCGROUP : u32 = 0x02000000   // cgroup
pub const CLONE_NEWTIME   : u32 = 0x00000080   // time namespace (Linux 5.6+)

// nstype values for setns
pub const SETNS_NEWNS   : u32 = CLONE_NEWNS
pub const SETNS_NEWUSER : u32 = CLONE_NEWUSER
// ... etc (one per CLONE_NEW*)
```

### `exec`-with-namespace — preferred shape

`u-root/cpu` actually wants "fork a child with these namespaces
preset," which on Linux is `clone()` with the CLONE_NEW* flags or
`fork()` + child `unshare()`. The cleanest hexa surface is **an
extension to whatever `exec()` already returns** (e.g. `Spawn` config):

```hexa
// extension of stdlib/os/exec.hexa
pub struct SpawnOpts {
    cwd:          string,
    env:          [string],
    namespaces:   u32,        // OR of CLONE_NEW*; 0 = inherit
    uid_map:      string,     // optional /proc/<pid>/uid_map content
    gid_map:      string,     // ditto
    // ... existing fields
}
pub fn spawn(prog: string, argv: [string], opts: SpawnOpts) -> int
```

If `stdlib/os/exec.hexa` already has a `SpawnOpts`-ish struct,
extending it with `namespaces` + `uid_map`/`gid_map` is preferable
to a bare `unshare()` wrapper because the kernel side wants the
clone() flag at process creation, not after.

## Open

- **`@platform(linux)`** — same gate question as `stdlib-os-mount-linux.md`.
- **`pidfd_open` / `pidfd_send_signal`** (Linux 5.3+) for namespace-aware
  signal delivery. Not strictly required for cpu but useful for a
  hexa-native process supervisor. Defer to P1.
- **rootless** — `CLONE_NEWUSER` needs uid_map / gid_map handling
  (`/proc/self/uid_map`, `setgroups deny`). cpud/cpuns does this; the
  P0 surface should at least expose the file-writes, even if a
  high-level helper comes later.

## Atlas / diagnostics

- No atlas content.
- No new HX codes — namespace failures use existing host_log / errno.

## Size estimate

~200 hexa LOC if implemented as bare syscalls + flag constants.
Closer to ~400 if including `spawn(opts)` with uid_map plumbing.

## Downstream consumers

- wilson `pool` plugin (POOL.md stage-B).
- Future hexa-native container/sandbox primitives.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Meta note: `stdlib-for-cpu-port.md`. Pairs with `stdlib-os-mount-linux.md`.
