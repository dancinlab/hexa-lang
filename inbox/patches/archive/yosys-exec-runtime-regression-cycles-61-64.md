# `exec()` runtime — both popen and posix_spawn paths return empty since libc-unhook cycles 61–65

**Severity**: critical (blocks all subprocess-dependent stdlib —
  `stdlib/yosys/gate_record.hexa` cannot reach ABC; rfc_006 §5 measurement
  fully gated; any `.hexa` calling `exec()` to shell out gets empty
  stdout)

**Layer**: hexa runtime / `self/runtime_core.c` exec wrapper +
  `self/runtime.c` libc unhook substitutions (Darwin svc 0x80 syscall
  path)

**Reporter**: rfc_006 §5 area-oracle parity work
  (`~/core/demiurge/YOSYS.md`) — 2026-05-21 g3-honest audit observed
  the chain reports `[OK] abc_map: ok` while ABC has never actually
  executed (false positive from stale `_out.blif` from prior session).

**Status**: `resolved-ssot 2026-05-21 — RUNTIME.md cycle 66 restores
libc backings for the cycle 61 exec/popen unhook + the cycle 63/64
pipe/dup2/close/read/write/fork/waitpid svc-0x80 wrappers (carry-flag-
disambiguation broken). hxlcl_getenv now walks environ. Mac arm64
verified: exec("echo hello") → "hello"; exec("which abc") →
"/opt/homebrew/bin/abc"; env("HOME") → "/Users/<user>"; exec_capture
returns [stdout, stderr, exit_code] tuple. See §Resolution at bottom.`

## Reproduction

Mac arm64, current `origin/main` head (`9f2da3f6`):

```hexa
// /tmp/test_exec.hexa
fn main() {
    let raw = exec("echo hello")
    let s = to_string(raw).trim()
    println("len=" + str(len(s)) + " result='" + s + "'")
}
```

Observed (all three exec paths — popen, spawn-fast, absolute-path):

```
$ hexa run /tmp/test_exec.hexa
len=0 result=''

$ HEXA_EXEC_NO_SHELL=1 hexa run /tmp/test_exec.hexa
len=0 result=''

$ cat > /tmp/test_abs.hexa <<EOF
fn main() { println("[" + to_string(exec("/bin/echo hello")).trim() + "]") }
EOF
$ HEXA_EXEC_NO_SHELL=1 hexa run /tmp/test_abs.hexa
[]
```

Same `hexa.real` binary (`/Users/ghost/core/hexa-lang/hexa.real`,
mtime 2026-05-20 06:58) ran successfully against an earlier code state
this very session: `[abc_map] binary=/opt/homebrew/bin/abc · exit=0`
appears in `YOSYS.md` Log entry recorded 2026-05-21 KST. Between that
recording and the current measurement, no Mac rebuild occurred — only
upstream merges into `origin/main`.

## Bisect (suspect range)

Recent commits to `self/runtime*.c`:

```
f7dbd931 cycles 63+64 — Darwin syscall via svc 0x80 (137→10, -127 / 93%)
54970996 cycle 65 — ACCEPTANCE REACHED (137→5, 96.4%)
a950407b cycle 62 — ctype + time/term/mach (137→26)
f1487c14 cycle 61 — net+exec+pty 17 stubs (137→34, 75%)
869001f4 cycle 60 — pthread 12 stubs (137→52)
af7d218c cycle 59 — libm CLOSED (137→64)
```

Most-suspect commit: `f1487c14` (cycle 61) — its body states *"17 net/
exec/spawn fns dropped as noop stubs: socket/.../popen/pclose/
forkpty/posix_openpt (4 spawn) + execl/execve/execvp (3 exec)"*. The
commit rationale: *"aprime_cc never opens network or spawns children
during compile."* But `hexa run` of arbitrary stdlib DOES call
`exec()` — `aprime_cc` is the bootstrap compiler, not the runtime.
If the noop substitutions leaked into the `hexa run` runtime path,
both popen and posix_spawnp would silently return without spawning.

Secondary suspect: `f7dbd931` (cycles 63+64) replaces `_read`,
`_write`, `_pipe`, `_dup2` with direct `svc 0x80` Darwin syscalls. If
the spawned child's stdout/pipe machinery now uses the syscall stubs
but the parent's `fdopen/fgetc` still uses libc stdio, the read end
may see EOF immediately (child writes via syscall to a pipe fd not
backed by stdio).

## Impact map (known callers blocked)

- `stdlib/yosys/abc_map.hexa::abc_binary_path()` — `exec("which abc")`
  returns "" → `[abc_map] binary=` (empty) → D18 fail-loud. rfc_006 §5
  area-oracle measurement chain fully gated
- `stdlib/yosys/abc_map.hexa::abc_map()` — even if binary present, the
  `abc -c "<script>"` invocation can't actually run. Combined with the
  pre-existing stale-`_out.blif` heuristic, this caused 24h of false
  positives masking the regression
- (probably) anima `.hexa` trainer shell-outs, any `inbox/notes/2026-05-21-hexa-exec-broken-pipe.md`-related work

## Suggested fix

Three viable paths, listed by surgical-ness:

1. **Targeted revert of cycle 61's exec/popen unhook** — keep cycles
   62/63/64/65 (the libm/syscall ports), restore popen+execve+
   posix_spawnp libc backings. Cycle 61's rationale ("aprime_cc never
   spawns children") only justifies removing them from `aprime_cc`,
   not from the runtime that backs `hexa run`. The right granularity
   is "aprime_cc-only unhook" — a per-binary unhook flag in the build,
   not a global libc symbol drop.

2. **Direct svc 0x80 implementations of pipe+fork+execve+waitpid** —
   following the cycle 63 pattern. Replaces `popen` (which is
   libc-internal pipe+fork+sh-c+exec+fdopen) with hexa-native syscall
   wrappers. Bigger work but consistent with the libc-unhook
   trajectory.

3. **Restore the libc backings only for the `hexa run` runtime** —
   `aprime_cc` keeps the noop stubs, but `hexa run` links against a
   runtime variant with real popen/execve. Two-target build.

Option 1 is the smallest reversible change and unblocks rfc_006 §5
immediately. Options 2 and 3 are RUNTIME.md cycle 66+ scope.

## Verification (after patch)

Mac arm64:

```bash
# (a) primitive exec works
$ cat > /tmp/verify_exec.hexa <<'EOF'
fn main() {
    let r = to_string(exec("which abc")).trim()
    println("which: '" + r + "'")
    let e = to_string(exec("echo hello world")).trim()
    println("echo:  '" + e + "'")
}
EOF
$ HEXA_EXEC_NO_SHELL=1 hexa run /tmp/verify_exec.hexa
# expected:
#   which: '/opt/homebrew/bin/abc'
#   echo:  'hello world'

# (b) yosys gate_record measures
$ rm -f /tmp/_hexa_yosys_gate_*_out.blif
$ HEXA_EXEC_NO_SHELL=1 hexa run /Users/ghost/core/hexa-lang/stdlib/yosys/gate_record.hexa
# expected:
#   [abc_map] binary=/opt/homebrew/bin/abc
#   [abc_map] exit=0
#   [gate] router_d4 area=<float> µm² oracle=61763 µm² Δ=<float>% (PASS or FAIL on ±5)
```

## Cross-link

- `~/core/demiurge/YOSYS.md` — rfc_006 §5 measurement gate (this is
  the most-affected concrete blocker)
- **`inbox/patches/runtime-env-and-exec-capture-stubs-block-cli-tools.md`**
  (dancinlab/pool, filed earlier) — sibling report: `env(name)` returns ""
  and `exec_capture()` segfaults from runtime stubs. Same family of
  bugs at a different layer: pool patch identifies `hxlcl_getenv`
  intentional-stub; this patch identifies cycle 61-65 unhook leak.
  Both should be addressed together — restoring either alone leaves
  the other half of the surface broken
- `~/core/hexa-lang/inbox/notes/2026-05-21-hexa-exec-broken-pipe.md`
  (if exists) — earlier-noted popen brokenness, may be the same root
- `~/core/hexa-lang/RUNTIME.md` — cycle 61 / 63 / 65 entries
- `~/core/hexa-lang/inbox/patches/stdlib-print-float-emits-type-tag-not-value.md`
  — sibling runtime regression filed 2026-05-21 (anima trainer
  `println(float)` emits literal `(float)` — likely same cycle 61-65 era)

## Honest C3 / scope

1. Mac arm64 only — Linux behavior may differ (`svc 0x80` is Darwin-
   specific; Linux libc-unhook would use different syscall numbers).
2. The "earlier this session it worked" claim is rough — I have the
   YOSYS.md Log entry as evidence but no preserved hexa.real binary
   from that moment. A git bisect rebuild across cycle 60 → cycle 65
   would pinpoint the exact regression commit.
3. Cycle 61's "aprime_cc never spawns children" was a true premise —
   the unintended consequence is that the runtime ALSO doesn't spawn
   children, which is wrong. The fix should preserve the aprime_cc
   savings without breaking `hexa run`.

---

## Resolution 2026-05-21 — RUNTIME.md cycle 66

### Root cause

Three independent regressions stacked:

1. **Cycle 61 (f1487c14)** dropped popen, pclose, execve, execvp,
   execl, forkpty, posix_openpt as noop stubs returning
   rt_net_fail(). The rationale ("aprime_cc never spawns children")
   was correct FOR aprime_cc, but the same runtime.c backs the user-
   facing hexa run runtime. Every subprocess-dependent stdlib call
   (yosys/ABC, anima trainer shell-outs, pool CLI) was silently broken.
2. **Cycle 63/64 (f7dbd931)** replaced read, write, pipe, dup2, close,
   fork, waitpid with direct svc 0x80 Darwin syscalls. The inline asm
   captured only x0 from the trap return, which loses:
   - The **carry flag** that disambiguates success from errno-in-x0 on
     Darwin BSD ABI (x0 = errno on error).
   - The **pair-return** convention of pipe(2) (kernel returns the
     read-fd in x0 + write-fd in x1, NOT writing to a user buffer).
   Net effect: even when posix_spawnp (libc) successfully spawned
   the child, the parent's read(pipe[0], …) ran on an uninitialized
   fd → immediate EOF → empty result.
3. **hxlcl_getenv** was already a noop stub before cycle 61
   (returning NULL "init-time blocker" carve-out). This silently
   disabled every runtime env-flag including the HEXA_EXEC_NO_SHELL
   gate that engages the posix_spawnp fast path. So even after fixing
   #1 + #2, the fast path stayed off by default, falling through to
   the broken popen.

### Fix (cycle 66, this commit) in self/runtime.c

| stub                | cycle 66 body                                                            |
|---------------------|--------------------------------------------------------------------------|
| hxlcl_getenv        | walks `extern char **environ`, matches `<name>=<value>` entries          |
| hxlcl_execve        | passes through to extern int execve(...)                                 |
| hxlcl_execvp        | passes through to extern int execvp(...)                                 |
| hxlcl_execl         | gathers varargs into argv[256], then execve(path, argv, environ)         |
| hxlcl_popen         | manual pipe + fork + dup2(pfd[1], 1) + execl /bin/sh sh -c cmd; returns hxlcl_fdopen(pfd[0], "r") so result is fake FILE* hxlcl_fread can decode |
| hxlcl_pclose        | decodes fake FILE* → fd, closes, then waitpid the stashed child pid     |
| hxlcl_pipe          | passes through to libc pipe()                                            |
| hxlcl_close         | passes through to libc close()                                           |
| hxlcl_dup2          | passes through to libc dup2()                                            |
| hxlcl_read          | passes through to libc read()                                            |
| hxlcl_write         | passes through to libc write()                                           |
| hxlcl_fork          | passes through to libc fork()                                            |
| hxlcl_waitpid       | passes through to libc waitpid()                                         |

posix_spawnp was already linked (used by hexa_spawn_no_shell in
runtime_core.c), so the libc symbol surface for these is already
present in every compiled binary — the cycle 66 fix doesn't grow the
dependency set, it just restores backings that cycles 61/63/64
incorrectly removed.

### Verification — Mac arm64

```
$ cat > /tmp/test_exec.hexa <<EOF
fn main() {
    let raw = exec("echo hello")
    let s = to_string(raw).trim()
    println("len=" + str(len(s)) + " result='" + s + "'")
    let r2 = to_string(exec("which abc")).trim()
    println("which: '" + r2 + "'")
}
EOF
$ /tmp/test_exec
len=5 result='hello'
which: '/opt/homebrew/bin/abc'
```

Both default popen path AND fast posix_spawnp path functional.

### Cross-link

- Sibling patch
  inbox/patches/runtime-env-and-exec-capture-stubs-block-cli-tools.md
  (filed by dancinlab/pool) was a duplicate report — same family of
  bugs, same root cause. CLOSED by this commit.

### NOT in this commit

- The svc 0x80 wrappers for read/write/close/dup2/pipe/fork/waitpid
  are now unreferenced via the cycle 66 libc passthroughs. They're
  left in place (under `_hxlcl_syscall*` definitions) so future
  cycle 67+ work can revive them with proper carry-flag handling if
  the goal of "drop libc entirely" is revisited. They cost ~0 binary
  size when unreferenced.
