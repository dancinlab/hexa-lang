# N143-re-restore — RFC 071 P11 natural-loop matmul source-to-silicon CLOSURE

**Date:** 2026-05-22
**Verdict:** PASS — natural-loop matmul source-to-silicon CLOSED end-to-end.
**Falsifier:** F-RFC071-NVPTX-MATMUL-NATURAL-LOOP-SOURCE-TO-SILICON — CLOSED.

## TL;DR

The N143 auto-synth matcher (`_hir_is_nested_matmul_body` + 8 `_hir_*`
helpers + `_synthesize_matmul_skeleton` + `_lower_fn` call-site) was
wiped from origin/main by `e8c2dc1c` (the second wipe; first re-restore
attempt is what N153/N164 found missing). This cycle:

1. Re-applied the exact N143 diff from `4c93b550` (clean apply,
   reverse-check byte-identical) — commit `c440d002`.
2. Found the matcher, even when present, NEVER matched real
   parse->lower output — it had only ever been validated against the
   hand-built `mir_test` case (g) HIR. Two desugar artifacts were
   rejected (commit `9e937ad9`):
   - The loop index let is mutable -> HExpr text `mut:__for_idx_N`
     (not the bare `__for_idx_N` the helpers checked from char 0).
   - `var sum = 0.0` desugars into a stray `ident "var"` + a separate
     `assign sum = 0.0` -> 6-child middle for-body, not 5.
3. With both fixed, the natural triple-loop fixture emits the full
   WMMA set and fires numerically correct on RTX 5070.

## Decisive measurement (the two-PTX contrast, now flipped)

| source | wmma | verdict |
|---|---|---|
| **natural triple-loop** (`matmul_naive`, P11 fixture) | **4** | full WMMA — auto-synth FIRES |
| **`gpu_matmul()` builtin** (`matmul_kernel`, P10 fixture) | **4** | full WMMA — N128 path |

The natural-loop WMMA instruction set is byte-identical to the builtin
control: `wmma.load.a` + `wmma.load.b` + `wmma.mma.sync` +
`wmma.store.d`. Emit is deterministic (3 re-emits MD5-identical:
`ff11068f4b87cfb89ebb34763c7f9479`).

## Silicon fire (ubu-1 RTX 5070, driver 580.159.04, CUDA 12.9)

PTX emitted sm_80, driver-JIT forward-compiled to sm_120 via
`cuModuleLoadDataEx`. M=N=K=64, FP16 inputs (LCG-fill), FP32 accumulate,
CPU FP32 reference. Result (reproducible, rc=0):

```
max_abs        = 2.622604e-06     (tol 1e-2 -> PASS)
max_rel        = 5.385030e-04
byte_mismatch  = 3324 / 4096      (expected: FP16-in/FP32-acc WMMA != CPU FP32-ref in low ULP)
c_nonzero      = 4096 / 4096
ref_first_8    == got_first_8     (FP32 to 3 decimals)
```

`max_abs = 2.6e-6` is the ≤4 ULP FP32 numeric-equivalence closure.

## Build path (ubu-1, /tmp fresh clone, no Mac OOM)

- Compiled module loader flatten (NOT interp — interp flatten thrashed
  30 GB RAM + 39 GB swap, the documented full-compiler OOM). Compiled
  `hexa_module_loader self/main.hexa` -> 24-file flatten in seconds.
- Standalone `emit_ptx_harness.hexa` (same `use` chain as
  self/main.hexa::_build_nvptx_emit_driver, EMPTY AtlasIndex to bypass
  `static_atlas()`'s `load_atlas_hxc -> hexa_exec` crash in the
  standalone harness — the matmul matcher never consults the atlas).
- hexa_v2 transpile + clang (4 `extern HexaVal fs_*;` decls injected;
  those runtime-builtin globals live in the separate runtime.c TU).

## Artifacts

- `matmul_naive.sm_80.WMMA.ptx` — emitted natural-loop PTX (4 wmma, NEW closure evidence).
- `matmul_naive.sm_80.NATURAL_NO_WMMA.ptx` — pre-fix scalar PTX (kept as historical failing evidence).
- `matmul_kernel.sm_80.BUILTIN_CONTROL_WMMA.ptx` — builtin control (N128).
- `host_matmul.c` — ubu-1 fire harness (FIRED this cycle).
- `result.json` — fire numeric result.

## Commits (branch worktree-agent-ac5d83401a37b1290)

- `c440d002` re-restore N143 (382+482 line re-apply of `4c93b550`).
- `9e937ad9` matcher robustness: `mut:` prefix + var-sum 6-child shape.
