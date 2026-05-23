# `exec_with_status` → 3-tuple `[stdout, stderr, exit_code]` migration

> **Status**: DOCS-ONLY this cycle (PROBE r8). Runtime impl is the
> ~115 LoC popen→fork rewrite mirroring `hexa_exec_capture` (runtime.c:9991);
> caller migration is the >500-site / 150-file blast radius that gates this
> from being a single PR. Decl + docs land NOW; impl + caller sweep land
> as a stacked PR series.

**Severity**: medium (correctness — silent stderr loss across all build /
test / dispatch shellouts; not a crash, but agents can't surface the
*reason* a `clang foo.c` failed because stderr is dropped on the floor
unless callers manually append `2>&1`).

**Affected**: every hexa caller of `exec_with_status(cmd)`. Greppable
surface:

```
$ grep -rln 'exec_with_status' --include='*.hexa' --include='*.sh' . \
    | grep -vE '(archive|inbox|CHANGELOG|build/)' | wc -l
150   # files
$ grep -rE 'let [a-zA-Z_][a-zA-Z_0-9]* = exec_with_status' --include='*.hexa' --include='*.sh' . \
    | grep -vE '(archive|inbox|CHANGELOG|build/)' | wc -l
532   # let-bound result bindings
```

**Reporter**: anima (PROBE r8 canonical-deviation audit, 2026-05-23)

## Problem (PROBE r8 evidence)

```hexa
let r = exec_with_status("clang foo.c -o bar")
// r = [stdout, exit_code]   ← 2-tuple, stderr LOST
// callers see r[1] == 0 / 1 (exit code)
// to actually read the error message the caller must mutate the command:
let r = exec_with_status("clang foo.c -o bar 2>&1")
// now r[0] contains BOTH stdout and stderr interleaved (channel info gone)
```

Canonical references — every comparable runtime exposes stderr as its
own field:

| Language | API                                | Shape                                                 |
|----------|------------------------------------|-------------------------------------------------------|
| Rust     | `std::process::Command.output()`   | `Output { stdout: Vec<u8>, stderr: Vec<u8>, status }` |
| Go       | `os/exec.Cmd.Output()` / `.Run()`  | separate `cmd.Stderr` field; `CombinedOutput()` opt-in |
| Python   | `subprocess.run(..., capture_output=True)` | `CompletedProcess { stdout, stderr, returncode }` |

The 2-tuple `[stdout, exit_code]` shape is the canonical deviation.

## Why this isn't a single PR

The same repo *already has* the canonical 3-tuple impl — `hexa_exec_capture(cmd)`
(`self/runtime.c:9991`, returns `[stdout, stderr, exit_code]` via
pipe/fork/select; merged 2026-05-23 in PR #423 with the multiplexed drain
fix). So the runtime change is trivially "rename / alias / extend." What
isn't trivial is the caller migration:

1. **532 `let r = exec_with_status(...)` bindings** across 150 files.
   Each binding's downstream `r[1]` access has to be re-categorized:
   - was-`r[1]`-is-exit_code  → must become `r[2]`
   - new-`r[1]`-is-stderr     → opt-in for callers that want it
2. **Silent semantic regression**: `if r[1] == 0` becomes
   "if stderr-string == int 0" → always false → exit-status checks
   silently invert. Not a crash, *worse* than a crash.
3. **Bootstrap caller hot files** include `self/compile_call.hexa`
   (250 `[1]` uses on a same-named local), `self/compile_while.hexa`
   (213), `self/main.hexa` (204 false-positive on a different `pair[1]`),
   `self/test_runner.hexa` (58), `self/main.hexa` real binding (3).
   Auto-sed would need precise per-file scope analysis to avoid
   corrupting unrelated `[1]` indexers.

## Migration plan (stacked PRs)

### PR A (this PR) — decl + docs only

- `self/runtime.h:299` — fix misleading `{rc, stdout, stderr}` comment
  (impl is `[stdout, exit_code]` 2-tuple); add deprecation note pointing
  at `hexa_exec_capture` as the canonical 3-tuple path.
- `self/runtime_core.c:5173` — extend the docstring above
  `hexa_exec_with_status` with the PROBE r8 finding + the canonical
  Rust/Go/Py reference + the explicit pointer at `exec_capture` for new
  code.
- This patch — full migration plan (PR B + PR C below).

### PR B — runtime impl extension (~115 LoC C)

Option B1 — **new function** `hexa_exec_with_status3(cmd)` returning the
3-tuple, with body = `hexa_exec_capture(cmd)` (5-LoC alias) OR a fresh
pipe/fork/select impl if call-site naming wants to stay close to
`exec_with_status`. Surface both names through the codegen
(`self/codegen.hexa` adds `exec_with_status3` → `hexa_exec_with_status3`)
and `ai_native_pass.hexa` (3 mention sites for purity classification).
Zero caller change required. NEW callers use `exec_with_status3` / NEW
callers use `exec_capture`. OLD callers untouched.

Option B2 — **extend in-place**: rewrite `hexa_exec_with_status` to use
the pipe/fork/select drain (mirror `hexa_exec_capture` lines 9991-10106)
and return the 3-tuple. This is the BREAKING change variant — fast to
write (~115 LoC) but requires PR C to ship atomically.

Recommend B1 for the impl PR (non-breaking, additive) + PR C as an
optional later "deprecation tail" that flips old-name → new-name aliases.

### PR C — caller migration sweep (only if B2)

Per-file scope-analyzed sed pass:

1. For each file containing `exec_with_status`:
   - For each `let <var> = exec_with_status(...)` line:
     - Within that variable's lexical scope, every `<var>[1]` becomes
       `<var>[2]`
     - Optionally insert `let <var>_err = <var>[1]` if downstream code
       could benefit from the stderr channel
2. Inline `exec_with_status(...)[1]` accesses (8 known sites):
   `test/regression/roadmap_with_unlock.hexa:65,69,75,79`,
   `tool/exec_eq_int_lint.hexa:39,266,317` (docstring),
   `self/linter.hexa:161` (warning text).
3. Bootstrap caller fix-up: `self/main.hexa:1929` `_r[1] == 0`,
   `self/main.hexa:2110` `__pair[1]`, `self/main.hexa:3900` `pair[1]`,
   `self/test_vm_to_arm64.hexa:499` `r[1]`, `self/test_syscall_emit.hexa:359,360,366`,
   `self/test_runner.hexa:180,250`.
4. Self-host parse smoke (`hexa parse self/main.hexa`) + bootstrap
   compile (`hexa run install.hexa --rebuild`) + integration test sweep
   (`./tests/integration/run.sh`) must all be green before merging.

Risk mitigation: a linter rule (extends `self/linter.hexa` /
`tool/exec_eq_int_lint.hexa`) flags any remaining 2-tuple-shaped
`<var>[1] == <int>` comparison post-migration — fail-loud at parse time.

## Verification (compile-free, this PR)

```
$ clang -fsyntax-only -Wno-everything self/runtime.c
# clean (runtime_core.c is #include'd into runtime.c)

$ hexa parse self/main.hexa
# clean (no source change)
```

## References

- PROBE r8 evidence: `dancinlab/anima` PROBE.md / PROBE.log.md
- Canonical 3-tuple impl already in repo: `self/runtime.c:9991`
  (`hexa_exec_capture`), merged PR #423 (select-multiplexed drain)
- g34 (surgical) + g21 (proper fix) + g33 (simplicity): the proper
  fix IS the 3-tuple, but only when the caller migration can be made
  atomic-or-staged-safely. Single-PR atomic land = too-much for the
  caller blast radius; stacked PRs A/B/C = stay surgical per layer.
- Backward-compat-first variant (B1): adds a new name, breaks zero
  callers; recommended.
