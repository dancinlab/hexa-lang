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
| R3 | compile+run a representative corpus (the `test/*.hexa` smokes, a few tools) natively; diff vs interp output | 🔄 in progress — next blocker = module-level mutable globals (see below) |
| R4 | switch the build/dev pipeline `hexa run` → native compile+run, **interp kept as fallback** (env/flag toggle) | ⬜ |
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

### Next R3 blocker (documented, NOT yet fixed — not a bounded one-liner)

**Module-level mutable globals (`let mut g = 0` at module scope) are
unimplemented in native codegen.** Evidence (asm of
`let mut g=0; fn inc(){ g=g+1 } fn main(){ inc();inc();inc(); print(g) }`):

- the global initializer is mis-emitted as a **second `_main`**
  (duplicate symbol → link failure);
- inside `_inc`, `g` reads as `movz #0` (const-0) and the write lands
  in a discarded local — globals have no storage/addressing;
- `to_string(g)` in `main` likewise reads const-0.

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
