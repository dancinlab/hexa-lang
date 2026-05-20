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

**Status**: not_started (filed 2026-05-21 KST)

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
- `~/core/hexa-lang/inbox/notes/2026-05-21-hexa-exec-broken-pipe.md`
  (if exists) — earlier-noted popen brokenness, may be the same root
- `~/core/hexa-lang/RUNTIME.md` — cycle 61 / 63 / 65 entries
- `~/core/hexa-lang/inbox/patches/stdlib-print-float-emits-type-tag-not-value.md`
  — sibling runtime regression filed 2026-05-21 (anima trainer)

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
