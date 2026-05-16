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
| R1 | a verifiable program runs **correctly** (`exit(42)` ⇒ `$?`=42) | 🔄 `2fe6517e` exit-map landed; re-verify in flight |
| R2 | builtin-lowering audit — sweep `_builtin_runtime_sym` / ret-box / cstring-arg vs every runtime builtin a typical program uses; fix the gaps | ⬜ |
| R3 | compile+run a representative corpus (the `test/*.hexa` smokes, a few tools) natively; diff vs interp output | ⬜ |
| R4 | switch the build/dev pipeline `hexa run` → native compile+run, **interp kept as fallback** (env/flag toggle) | ⬜ |
| R5 | once native coverage ≥ interp on the corpus, delete the interp | ⬜ |

Each phase is incremental and default-safe (the interp fallback stays
until R5; codegen fixes are additive symbol/ABI corrections that don't
regress already-working paths).

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
