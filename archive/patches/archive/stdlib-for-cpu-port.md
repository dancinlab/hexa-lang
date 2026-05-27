# `stdlib` surface needed to port `u-root/cpu` to hexa — meta note

> **Status:** ✅ FIXED — all 5 sub-patches landed: stdlib-os-mount-linux (applied 2026-05-13), stdlib-os-namespace-linux (applied 2026-05-13), stdlib-os-pty (applied 2026-05-13), stdlib-9p-codec MVP (applied 2026-05-14), stdlib-ssh-client full-stack (landed 2026-05-14). This umbrella meta-note tracked them as an index; with every component shipped, the cpu-port surface is complete and downstream wilson `pool` plugin Stage-B/C is unblocked.


**From:** wilson (downstream) — 2026-05-13. Filed alongside 5 atomic
companion notes (linked below). Together they're the hexa-lang
surface that lets a downstream `pool` plugin run `cpu`-pattern (Plan 9
`cpu(1)` style: remote exec with the caller's namespace mounted via
9P) **without an external Go binary**.

## Why this exists

wilson is building a `pool` plugin (design SSOT:
`~/core/resource/POOL.md`) that routes deterministic tool calls onto a
host pool of LAN + mesh peers. Day-1 transport is the **u-root/cpu**
Go binary — wilson `exec("cpu", host, cmd)`. That's stage-A — works
today, zero hexa-lang change. Stage-B / C of the plugin's roadmap want
the same behavior **hexa-native** — both to honor the `hexa-first`
governance principle (`update || PR` via `hexa atlas register|promote|pr`)
and to absorb the SSH/9P fork-storm cleanly (SPEC §16).

## The five atomic asks (P0)

| order (deps) | file | what |
|---|---|---|
| 1 | `inbox/patches/stdlib-os-mount-linux.md` | `mount(2)` / `umount(2)` + `MS_*` flag constants. macOS stub. |
| 2 | `inbox/patches/stdlib-os-namespace-linux.md` | `unshare(2)` / `setns(2)` / `pivot_root(2)` + `CLONE_NEW*` flags. macOS stub. |
| 3 | `inbox/patches/stdlib-os-pty.md` | `openpty` / `forkpty` + termios raw/cooked toggle. macOS + Linux. |
| 4 | `inbox/patches/stdlib-9p-codec.md` | Plan 9 9P2000.L T/R message codec + `Attacher` interface. |
| 5 | `inbox/patches/stdlib-ssh-client.md` | SSH client (dial / exec / port-fwd / key auth). Largest; can also be deferred behind `exec("ssh")` fallback. |

Stages 1-3 are independent and parallel-implementable (small, ~150–300
LOC each). #4 (9P) needs the socket layer (already in hexa stdlib).
#5 (SSH) is by far the largest and is OK to land last — wilson can keep
shelling out to system `ssh` until then.

## Total scope

~3000–5000 hexa LOC across the five files. Not a single PR — five
independent landings. Each note is self-contained so they can be
scheduled atomically.

## Mapping to `u-root/cpu` sites

The 5 syscall + protocol sites in the upstream Go that this surface
needs to replace (verified by grep on `~/core/resource/vendor/u-root-cpu/`):

```
session/session_linux.go:120  unix.Mount("localhost", target, "9p", flags, opts)   → P0 #3 + #4
session/session_linux.go:132  unix.Mount("/", tmpMnt+"/local", "", MS_BIND, "")    → P0 #3
session/session_linux.go:141  unix.Mount("cpu", tmpMnt, "tmpfs", 0, "")            → P0 #3
cmds/cpud/serve.go:77         unix.Mount("cpu", "/tmp", "tmpfs", 0, "")            → P0 #3
server/server.go:91           pty.Start(cmd)                                       → P0 #5
client/client.go              ssh.NewClientConn / ssh.NewClient / sess.Start       → P0 #1
client/srv.go                 p9.Server (Attacher)                                 → P0 #4
cmds/cpuns/main_linux.go      SysProcAttr{Cloneflags: CLONE_NEWNS|NEWUSER|...}     → P0 #4 (namespace)
```

## SPEC / atlas

- **SPEC §16 fork-storm absorption** — all five are direct §16 cases.
  Today's wilson `bin/hexa-r` / `bin/py-r` / many `exec("ssh ...")`
  sites in `~/core/resource/bin/*` are exactly the fork-storm the
  hexa-first principle (governance #2) wants absorbed. Landing these
  is the canonical `update` arm of `update || PR` for the resource
  layer.
- **Atlas** — cpu carries little numeric content. The 9P message-size
  invariant (`size` field on the wire equals the on-wire byte length)
  is a candidate L node; tracked inside `stdlib-9p-codec.md`. Not a
  driver of atlas growth — small.
- **Diagnostics** — 9P codec violations justify a new HX85xx subseries
  (`HX8501 "9p: malformed Tread, size N less than header"` etc.). Spec'd
  in the 9P note, not here.

## P1 (nice to have, doesn't block stage-B)

- `stdlib/net/socket.hexa` UNIX domain + `SCM_RIGHTS` fd passing — pty master fd hand-off
- `stdlib/os/signal.hexa` extended — SIGCHLD reaping, forwarding
- `stdlib/parse/ssh_config.hexa` — `~/.ssh/config` parser
- `stdlib/proc/mountinfo.hexa` — `/proc/self/mountinfo` parser

## P2 (cpu optional features)

- `stdlib/net/mdns.hexa` (DNS-SD)
- `stdlib/net/nfs.hexa` (NFS alt-transport)
- `stdlib/net/vsock.hexa` (decpu VM↔host)

## Downstream — where `pool` consumes this

`~/core/resource/POOL.md` (the wilson `pool` plugin spec):

- **Stage A (now)**: `pool_on` shells out to `cpu` Go binary.
- **Stage B (v1.0)**: P0 #2-5 landed → `pool` ships its own hexa cpud
  + 9P server, only SSH transport stays `exec("ssh")`.
- **Stage C (v1.x)**: P0 #1 landed → SSH absorbed too; `exec("ssh")`
  disappears.

No wilson-side change. Filed per AGENTS.md hexa-lang handoff protocol.
Companion notes filed in the same batch.
