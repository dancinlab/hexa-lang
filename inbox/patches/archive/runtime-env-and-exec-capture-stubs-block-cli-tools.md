# Runtime stubs block CLI tools: `env(name)` returns "" and `exec_capture()` segfaults

**Source**: dancinlab/pool
**Kind**: patches
**Status**: `resolved-ssot 2026-05-21 — RUNTIME.md cycle 66 fixes both
env(name) and exec_capture(). hxlcl_getenv now walks the environ
global directly (was noop stub returning NULL). hxlcl_execve / execvp
/ execl / pipe / close / dup2 / read / write / fork / waitpid all
restored to libc backings (cycle 63/64 svc 0x80 wrappers lost the
Darwin BSD carry-flag-disambiguates-success-vs-errno convention).
hxlcl_popen rewritten as manual pipe+fork+execve+fdopen-shim so it
returns a fake FILE* compatible with hxlcl_fread. Mac arm64 verified:
env("HOME") → "/Users/<user>" (was ""); exec_capture("printf hello")
→ ["hello", "", 0] tuple (was SIGSEGV). See §Resolution at bottom.`

## What's broken

Two primitives that single-file hexa CLI tools rely on are non-functional in both compiled and interpreter modes:

| primitive | observed | expected | impact |
|---|---|---|---|
| `env(name)` | returns empty string | OS env (e.g. `env("HOME")` → `/Users/<user>`) | can't resolve user paths (`~/.pool/pool.json` etc.) |
| `exec_capture(cmd)` | SIGSEGV at runtime | `[stdout, stderr, exit]` per `stdlib/cloud/cloud.hexa` contract | can't shell out (ssh / `test -e` / mkdir) |

## Reproduction

```hexa
// /tmp/env-probe.hexa
fn main() {
    let h = env("HOME")
    println("type: " + type_of(h))
    println("len: " + to_string(len(h)))
}
```

```bash
$ HEXA_MAC_BUILD_OK=1 hexa build /tmp/env-probe.hexa -o /tmp/env-probe
$ /tmp/env-probe
type: string
len: 0
$ hexa run /tmp/env-probe.hexa     # interpreter — same result
type: string
len: 0
```

```hexa
// /tmp/exec-probe.hexa
fn main() {
    let r = exec_capture("printf hello")
    println("stdout: " + r[0])
}
```

```bash
$ /tmp/exec-probe
[1]    47763 segmentation fault  /tmp/exec-probe
$ hexa run /tmp/exec-probe.hexa
sh: line 1: 47763 Segmentation fault: 11  '/Users/ghost/.hexa-cache/hexa_run.443857338216000' 2>&1
```

## Root cause (suspected)

In `self/runtime.c`:

```c
static char *__attribute__((noinline)) hxlcl_getenv(const char *name) {
    (void)name; return (char *)0;     // intentional stub
}
```

The comment notes `hxlcl_getenv` is stubbed because earlier-cycle initialization order needed it removed from init-time helpers. The user-facing `env()` runtime function (`hexa_env_var` at line 8098) calls this stub at line 8197 (`const char* v = hxlcl_getenv(HX_STR(name))`), so every non-`__HEXA_*` lookup returns `""`.

`exec_capture` SIGSEGV in compiled binaries — root cause not yet bisected; likely a similar init-time / TAG_FN unbound slot pattern. Reproduces in both `hexa build` output and `hexa run` interpreter cache binaries.

## Ask

Restore process-level access for user-mode CLI tools:

1. **`env(name)`** — call real `getenv(3)` (or expose a separate `getenv()` primitive that does so) without breaking the `__HEXA_ARENA_*` / `__HEXA_PHASE_LOG__` side-channel interception block that already lives in `hexa_env_var`.
2. **`exec_capture(cmd)`** — make compiled-mode subprocess work, matching the contract in `stdlib/cloud/cloud.hexa` (`[stdout, stderr, exit]`). At minimum, never segfault — fail-loud with a clear error string is acceptable as a first step.

## Why this matters

The upstream JSON CLI pattern (`stdlib/alloc/json_cli_pattern_test.hexa`, 7 falsifiers PASS) demonstrates the full read-mutate-write JSON loop in pure hexa. But every "real" CLI also needs (a) an absolute state path resolved from `$HOME` and (b) at least one subprocess (ssh / git / a sibling binary). Without these, hexa-native CLI tools can't escape `/tmp` and can't talk to the world.

Confirmed callers blocked:
- `dancinlab/pool` Phase 1 port (see https://github.com/dancinlab/pool/blob/main/TODO.md). `bin/pool.hexa` draft compiles cleanly but cannot resolve `~/.pool/pool.json` and cannot run `ssh` for `on` / `status` verbs.

The earlier patch `port-pool-cli-to-hexa.md` (closed 2026-05-21 with the JSON surface canonical example) is necessary but not sufficient — the runtime primitive layer is the remaining blocker.

## Acceptance

A hexa-native CLI tool of the form

```hexa
fn main() {
    let path = env("HOME") + "/.foo/bar.json"
    let r = exec_capture("test -e " + path)
    if r[2] == 0 { println("exists") } else { println("absent") }
}
```

compiles and runs without segfault, prints the correct branch.

## Out of scope

- Threading / async (needed for `pool list --live` in phase 4) — separate inquiry.
- File-existence built-in (`file_exists`) — `exec_capture("test -e ...")` is sufficient if `exec_capture` works.

## Related

- https://github.com/dancinlab/pool — Phase 1 port draft (`bin/pool.hexa`, ~210 LoC) carried in repo but not wired until this patch lands.
- `inbox/patches/port-pool-cli-to-hexa.md` (RESOLVED 2026-05-21) — closes the JSON surface side; this patch closes the runtime side.

---

## Resolution 2026-05-21 — RUNTIME.md cycle 66

Closed by the same commit that resolves
inbox/patches/yosys-exec-runtime-regression-cycles-61-64.md —
both patches reported the same family of bugs (env stub +
exec/popen stubs + carry-flag-broken syscall wrappers).

### Verification — Mac arm64 (this patch's reproducers)

```
$ cat > /tmp/env-probe.hexa <<EOF
fn main() {
    let h = env("HOME")
    println("type: " + type_of(h))
    println("len: " + to_string(len(h)))
}
EOF
$ /tmp/env-probe
type: string
len: 16           ← was 0 before cycle 66
```

```
$ cat > /tmp/exec-probe.hexa <<EOF
fn main() {
    let r = exec_capture("printf hello")
    println("stdout: " + r[0])
}
EOF
$ /tmp/exec-probe
stdout: hello     ← was SIGSEGV before cycle 66
```

Full primitives map + cycle 66 fix detail: see
yosys-exec-runtime-regression-cycles-61-64.md §Resolution.
