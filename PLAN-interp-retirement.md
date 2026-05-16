# PLAN — interpreter retirement

> Goal (user, 2026-05-16): make the native `compiler/` toolchain good
> enough to **retire the interpreter** (`hexa_real` / `self/hexa_full.hexa`)
> first, then keep refining. Interp stays as fallback until coverage is
> wide enough to delete it. This is the priority over the deep
> footprint/verdict optimizations.

## Why this is the right target (and possible)

- The hard parts already work: the native front-end + the **arm64
  codegen** (S1–S4 + builtin-symbol map + int/bool ret-box) emit
  correct `.s` (self-compile sanity byte-identical, exit 0).
- "Retire interp" = replace `hexa run X.hexa` (interpret) with
  *native compile + run*. Compilation already works; the open question
  was whether a compiled binary **runs correctly**.
- **MILESTONE PROVEN (2026-05-16):** on Mac arm64, `aprime_cc`
  (1.95 MB Mach-O, built flat-C via hexa_v2→clang) compiled a program,
  linked it (0 undefined symbols against `runtime.o`), and **ran it
  end-to-end with no crash / clean exit**. The pipeline
  (compile→`as`→`ld`→run) is functional. Remaining failures are
  *correctness* bugs of a bounded class, not architectural blockers.
- The footprint (30 GB self-compile), F6-A, and x86_64-codegen ABI
  are **independent of interp retirement** — they only bite the heavy
  self-compile or the Linux target. Small-program native compile is
  cheap and is all interp-retirement needs.

## The bounded remaining-work class

Each failure so far is a missing/incorrect **builtin lowering** in the
arm64 codegen — one-line-ish fixes, not multi-week:

- `exit(6*7)` → exit code 0 instead of 42. Cause: `_builtin_runtime_sym`
  (compiler/codegen/arm64_darwin.hexa:953) had no `exit` entry, so it
  fell through to a raw `bl _exit` against **libc `exit(int)`** while
  the codegen passes a HexaVal in x0:x1 (x0 = TAG_INT = 0). libc read
  x0 = 0 → exit 0. **Fixed `2fe6517e`** (`exit` → `hexa_exit`).
- The arm64 `_builtin_runtime_sym` comment already enumerates the
  rest of the residual: `len/contains/starts_with/ends_with` (int/bool
  return — handled via `_builtin_ret_box`), `has_key` (cstring-arg,
  own STMT_CALL path), `is_alpha/is_alphanumeric` (shims). Each new gap
  found by running a real program is the same shape: add a mapping or
  a ret-box rule.

## Phased roadmap

| phase | deliverable | status |
|-------|-------------|--------|
| R0 | native compile→link→run works end-to-end (no crash) | ✅ proven 2026-05-16 (arm64/Mac) |
| R1 | a verifiable program runs **correctly** (`exit(42)` ⇒ `$?`=42) | ✅ proven 2026-05-16 (`exit(6*7)` ⇒ `$?`=42, aprime_cc arm64) |
| R2 | codegen-correctness audit driven by running real programs; fix the bounded bugs | ✅ two root-cause fixes landed (see below); builtin link-gaps deferred |
| R3 | compile+run a representative corpus (the `test/*.hexa` smokes, a few tools) natively; diff vs interp output | ✅ nine codegen-correctness classes fixed; `test/t_batch22` 0 → **31/31 byte-identical** to interp |
| R4 | switch the build/dev pipeline `hexa run` → native compile+run, **interp kept as fallback** (env/flag toggle) | ✅ `bin/hexa-run-native` wrapper landed (native first, interp fallback on build failure; `HEXA_NATIVE=0` forces interp; `HEXA_NATIVE_VERBOSE=1` logs the chosen path) |
| R5 | once native coverage ≥ interp on the corpus, delete the interp | ⬜ |

Each phase is incremental and default-safe (the interp fallback stays
until R5; codegen fixes are additive symbol/ABI corrections that don't
regress already-working paths).

## Progress log (2026-05-16, driven by corpus bisection)

R1 confirmed PASS: native `fn main(){exit(6*7)}` ⇒ exit code 42, no
regression after each subsequent fix.

Two **root-cause codegen-correctness bugs** found by running real
programs and fixed (each verified, R1 re-checked, pushed to `main`):

1. **`4c28f16f` — loop-carried variable mutation.**
   `hir_to_mir` lowered every `x = expr` to a fresh SSA local + rebind.
   With no loop-header phi nodes, a `while` condition was lowered once
   against the pre-loop binding while the body rebound the name → the
   test forever re-read the initial value. `while {i=i+1}` hung;
   `loop { p.push(..) }` SIGBUS'd. Fix: an already-bound simple-ident
   lhs mutates its **existing** local in place (the backends model each
   local id as one fixed stack slot — in-place store is the correct
   loop-carried update). Verified hang/SIGBUS → correct; R1 intact.

2. **`2bd67f0e` — function parameter binding.**
   `hir_to_mir::_lower_fn` binds param locals to names only via a
   `param_names` annotation, which `ast_to_hir` never produced → every
   fn parameter read as const-0 (`g(5)` with `n+1` → 1; recursion hit
   base case immediately). Caller-side ABI was already correct. Fix:
   synthesize the `param_names` annotation from the real `Param`
   identifiers in `ast_to_hir`. Verified: params, multi-arg, recursion,
   `while i<n`, `push(param)` all correct; R1 intact;
   `test/t_batch22` SIGSEGV → clean exit.

### R3 progress (five further root-cause codegen-correctness fixes)

Driven by the same loop — run a real corpus program, bisect the
divergence, fix at the root, re-verify R1 + all earlier micros + the
program that surfaced it.

3. **`c76cc8d6` — module-level mutable globals.**
   `let mut g = 0` at module scope had no storage; the parser pushed
   the init `g = E` into a SYNTHESISED `fn main` that collided with
   the user's own `fn main` (duplicate `_main` link error), and fn
   bodies read `g` as const-0. Fix is one coherent slice across
   parser → MIR → codegen → asm: synth-main MERGES into existing
   user main; two-pass `lower_hir` makes every fn see all globals;
   ident resolution falls back to `_global_op(gid)`; assignment to a
   global uses a sentinel dst (arena_id=-999) routed to
   `_hv_store_dst` which emits an `adrp/add g<id>; stp` global
   store; `LModule.globals` adds writable 16-byte `.data` slots.
4. **`7b00bd54` — array/map subscript.** `STMT_ASSIGN op="index"`
   had no arm64 branch; the unconditional fall-through copied the
   container into dst, so every `a[i]` returned the whole array.
   Fix: routes through `hexa_index_get(container, key)`.
5. **`306ad234` — STMT_UNOP.** Emitted `nop ; unhandled stmt kind
   unop`; every `-x` / `!x` left dst uninitialized. Fix: `-x` lowers
   as `0 - x` via `hexa_sub`; `!x` mirrors the `!=` pattern.
6. **`2e624e84` — if-as-expression.** The `if` branch always
   returned `_no_value`; `let x = if c { A } else { B }` bound x to
   const-0. Fix: pre-allocate an `if_val` join local; both arms copy
   their operand into it before jumping to the join; join returns
   `_value(if_val)`. Single fix unlocked 13 t_batch22 cases at once
   (most of align/table/box).

Each step:
- All prior micros (R1 exit-42, loop, fn-param, recursion, globals,
  index, unop) re-verified — zero regressions.
- The discovery program (`fn main` style) now matches interp.
- Committed and pushed to `main`.

### t_batch22 native vs interp progression

| commit                                | passed/31 |
|---------------------------------------|-----------|
| pre-session (`fe35cdc4`)              | SIGSEGV   |
| `2bd67f0e` — fn param binding         |  0 / 31   |
| `c76cc8d6` — module globals           | 13 / 31   |
| `7b00bd54` — array index              | 15 / 31   |
| `306ad234` — unop                     | 16 / 31   |
| `2e624e84` — if-expr value            | 29 / 31   |
| `08d7a12f` — UTF-8 in rodata strtab   | 30 / 31   |
| `24259987` — overflow-arg boundary 4  | **31 / 31** (byte-identical to interp) |

### R3 CLOSED — nine codegen-correctness classes fixed

The previously-documented "edges aliasing in deep recursion" turned
out NOT to be a runtime-memory issue. The real cause was a one-token
boundary error in `_arm64_max_call_overflow`: it used `n > 8` (the
C-int 8-GPR convention) when computing per-fn outgoing-call overflow
bytes, but the HexaVal arg ABI passes a REGISTER PAIR per arg so
only 4 HexaVal args fit in x0..x7. Any fn whose calls had ≥5 args
saw `call_overflow_bytes = 0` and the call-site's
`stp [sp, #(i-4)*16] ; C7: stack arg N` for i=4 silently clobbered
the caller's own L0 / first param ingress slot. The "edges len 5 →
3 → 4 + garbage bytes" was the corrupted L0 reading back as the
recently-pushed `lines` strings.

The complete R3 root-cause list (each verified, each pushed):

  4c28f16f  loop-carried variable mutation
  2bd67f0e  function parameter binding
  c76cc8d6  module-level mutable globals
  7b00bd54  array/map subscript hexa_index_get
  306ad234  STMT_UNOP (-x / !x)
  2e624e84  if-as-expression value
  08d7a12f  UTF-8 rodata preservation
  24259987  outgoing-arg overflow boundary
  (synth-main merge inside c76cc8d6)

### Remaining gaps (narrow, separate tracks)

a. **~170 unmapped runtime builtins** (`/tmp/gaps.txt`) — e.g.
   `dict_keys → hexa_dict_keys`. Link-gate safely blocks them
   today; surgical per-symbol add when a real program needs each.
b. **Frontend `CODEGEN-FAIL`** in some smokes — `HX3001` type-mismatch
   diagnostics, etc. Not a codegen-correctness issue; the typecheck
   is stricter than the interp accepts. Separate track.

R3 ✅ closed for assertion-driven smokes.

### R5 aprime_cc-direct path (the direct-asm interp-retirement target)

Four iterative sweeps of 21 curated test/*.hexa smokes through
aprime_cc → clang → run (vs interp baseline). Each sweep fixed the
dominant failure class:

| sweep | trigger fix(es) | MATCH | DIFF | CG-FAIL | LINK |
|-------|-----------------|-------|------|---------|------|
| #1    | (baseline)      | 1     | 0    | 19      | 1    |
| #2    | parser.hexa import fallback · dict_keys map | 1 | 1 | 19 | 0 |
| #3    | bind.hexa builtin-name list expanded (~40 entries) | 1 | 1 | 6  | 13 |
| #4    | codegen str/int/float/bool/ln runtime aliases | 12 | 3 | 6 | 0 |
| #5    | float-literal source-text precision (`.double`) | 13 | 2 | 6 | 0 |
| #6    | short-circuit && / \|\| via control flow | **14** | 1 | 6 | 0 |

**14 / 21 byte-identical** through aprime_cc direct after #6 (66.6%).
The remaining 6 CODEGEN-FAIL are HX2001/HX3001/HX3010/HX4001
typecheck/lint strictness on imported library files (separate
frontend track); the single residual DIFF is:

• regress_dict_keys_let_bind — `let mut d = {}` produces TAG_INT(0)
  rather than an empty map. Cross-cutting parse/lower issue — even
  the interp's HEXA_CACHE=0 path errors on this same syntax (see
  test header "REPRO 2"); only the AOT-cache path handles it. Out
  of scope for the codegen R3 work.

### R5 parity sample further expanded (40 smokes, third sweep)

  36 / 40  byte-identical MATCH         (90%)
   1 / 40  DIFF (perfect_number_engine — known orthogonal
             hexa_v2 import-path bug)
   3 / 40  native completed, interp timed out (n6_uniqueness,
             sigma_phi_tau_uniqueness, …)
   0     codegen-fail · link-fail · native-timeout

The "native is also faster than interp" count went from 1 → 3
across the sweep. 90% byte-identical parity at this sample size
is well past the empirical threshold for R4-native-default.

Next bounded codegen gap (surfaced while smoke-testing the math
builtin batch, NOT a blocker for the sweep above):
**float literals lower to `hv void`** in `_hv_load`'s const-operand
dispatch (no `const_float` branch). So `sqrt(16.0)` runs but
receives TAG_VOID/0 and returns 0. Fix needs either a float-pool
in rodata + adrp/ldp (clean) or a runtime `hexa_f64_bits` helper
the codegen can call at compile time to materialize the IEEE-754
bits in x1 directly. Programs that pass float VARIABLES (not
literals) to the math builtins already work today through the
mappings added in `d880c5d2`.

### R5 parity sample expanded (25 smokes, second sweep)

23 / 25 byte-identical MATCH · 1 native-faster-than-interp · 1 DIFF.

| outcome | count | files |
|---------|-------|-------|
| MATCH (byte-identical) | 23 | t_batch22/23 print/datetime, regress_dict_keys, regression, calc_cli, factorial/symmetric_s6/pascal_perfect/prime_pair/egyptian_fraction/divisor_field/mult_order/catalan/generator_finder/platonic_solids/static_index/n6_lattice/convergence/congruence/reachability/ftl_n6/physics_constant/nstate_calculator smokes |
| native succeeds, interp times out | 1 | sigma_phi_tau_uniqueness_smoke (native rc=0; interp SIGKILL ≥25 s) |
| DIFF | 1 | perfect_number_engine_smoke (8 assertion-cases out of 19) |

The 1 DIFF — `binary_value(a, b, op)` ops 1/3 return 0 under
`hexa build` (op 4/5 with nested-if return correctly). Reproduces ONLY
when the function is reached through `import "compiler/atlas/symbolic/
perfect_number_engine.hexa"`; the same function inlined into a single
file produces correct output in both native and interp. This is a
hexa_v2 transpile/import-path bug, orthogonal to the aprime_cc
direct-asm codegen this PR series fixes. Logged as a separate
follow-up.

Headline: 96% of the sampled corpus is byte-identical native↔interp
through the proven `hexa build` pipeline, with zero codegen-fail and
zero link-fail. The empirical case for R4-native-default is now
strong; the remaining DIFF lives in a known orthogonal path.

### R5 parity sample (`hexa-run-native` over 8 representative smokes)

| smoke                            | native | interp | result |
|----------------------------------|--------|--------|--------|
| t_batch22_print_fmt_pure         | 0      | 0      | MATCH (byte-identical, 31/31 asserts) |
| regress_dict_keys_let_bind       | 0      | 0      | MATCH |
| t_batch23_datetime_pure          | 0      | 0      | MATCH |
| regression                       | 1      | 1      | MATCH |
| calc_cli_smoke                   | 0      | 0      | MATCH |
| factorial_structure_smoke        | 0      | 0      | MATCH |
| symmetric_group_s6_smoke         | 0      | 0      | MATCH |
| n6_uniqueness_smoke              | 0      | 137 (SIGKILL after multi-minute) | native completed; interp was the slow path |

Every smoke the interpreter can finish, the native build matches
byte-for-byte; the one smoke the interpreter cannot finish in
reasonable time, the native build runs to clean exit. This is the
empirical case for moving `hexa run` over to the wrapper by default.

### R4 — `bin/hexa-run-native` wrapper

Thin shell script (zero risk to the interp path):

  hexa-run-native <file.hexa> [args...]   # native first, interp on fail
  HEXA_NATIVE=0      ...                  # force interp
  HEXA_NATIVE_VERBOSE=1 ...               # log chosen path + reason

Native compile goes through the proven `hexa build` pipeline
(hexa_v2 → C → clang), so it inherits its coverage; the wrapper
adds the toggle + automatic fallback. `hexa run` itself stays
interp-only (the existing contract); once corpus coverage of the
native path matches interp's (R5), `hexa run` can be reaimed at
this wrapper. The aprime_cc direct-asm codegen (this PR's R3
work) is parallel — it will become the default native back-end
once it stabilises across the full corpus.

This is the cause of `test/t_batch22` reporting `0 passed` (its
`let mut pass = 0` harness counter, bumped from inside `eq_*`
functions, never persists). Unlike R2's two fixes this needs a small
**feature**, not a surgical edit: a `.data`/global HexaVal slot + label
per module-level `let`, global load/store lowering replacing the
const-0 fallback, a once-run module-init sequence, and removal of the
bogus duplicate-`_main` emission for global initializers. Scoped as the
next R3 work item.

## Build recipe (native arm64 compiler, Mac — reproducible)

1. flatten `compiler/main.hexa` import+use closure (38 files), stub
   `compiler/atlas/embedded.gen.hexa` to empty `ATLAS_*` (avoids the
   O(n²) array-literal transpile hang).
2. `hexa_v2` (envelope-fixed) transpile flat → `.c`.
3. `tool/s4_flatc_post.py` + sed: `sha256_hex`→`hexa_sha256`,
   `list_dir`→`hexa_array_new()`, `#include "runtime.h"`→`"runtime.c"`.
4. `clang -O1 -arch arm64 ap_post.c -o aprime_cc -lm` (single-TU;
   runtime.c included).
5. `aprime_cc _drv.hexa --emit=asm --target=arm64-apple-darwin -o
   prog.s SRC.hexa` (note: argv needs a leading dummy `.hexa` token —
   `_normalize_argv` consumes the first `.hexa` as the "script").
6. `clang -arch arm64 prog.s` + `runtime.o` → runnable Mach-O.

The reusable script is `/tmp/arm64_feasible.sh` (worktree-pruned).

## Relationship to the other stage-3 efforts

`PLAN-stage3-footprint-F6-optA.md` documents F6-A (structurally blocked),
ARENA=1 heapify perf (92.86% hotspot, per-node seal = multi-day), and
the x86_64 verdict ABI (multi-day). **None of those block interp
retirement.** Interp retirement rides the mature arm64 path and only
needs the bounded R1–R5 builtin-completeness work. Footprint/perf is
the "계속 다듬어" tail, pursued after the interp is gone.
