# RFC 075 P5 — flame Metal integration step 2/5 fire

**Date**: 2026-05-21
**Branch**: worktree-agent-a95d01003c9f74aec
**Falsifier**: F-RFC075-METAL-SHIM-NUMERIC-EQ — **PASS**

## What

The `_hx_metal_farr_matmul_gpu` shim body lives in
`self/metal/runtime_metal.m` and closes the N15 (commit 6315b59f) link
gap: runtime.c's HEXA_METAL dim-gate can now dispatch large-shape
`farr_matmul` calls through Apple `MPSMatrixMultiplication` (FP32 SGEMM
via MetalPerformanceShaders).

## Numeric oracle

| Metric    | Value      |
|-----------|------------|
| Shape     | 64 × 64 × 64 |
| max_abs   | 3.076e-06  |
| max_rel   | 3.862e-04  |
| Tolerance | 1e-03 (FP32-honest) |
| Verdict   | **PASS**   |

The 3.86e-4 max relative error is consistent with the FP64 → FP32 →
FP64 round-trip the shim performs (Apple GPU has no FP64 compute path).
FP64 bit-exact users (ag_tape byte-eq oracles, tiny smokes) must NOT
set HEXA_METAL=1 — they stay on the CPU ikj path at runtime.c:6220.

## Build commands (Mac local)

```bash
# 1. shim object (standalone compile check)
xcrun --sdk macosx clang -c -fobjc-arc \
    -framework Metal -framework MetalPerformanceShaders \
    self/metal/runtime_metal.m -o /tmp/runtime_metal.o

# 2. runtime.c with HEXA_METAL active
xcrun --sdk macosx clang -c -DHEXA_METAL \
    self/runtime.c -o /tmp/runtime.o

# 3. link smoke harness
xcrun --sdk macosx clang -O2 -DHEXA_METAL -fobjc-arc \
    -framework Metal -framework MetalPerformanceShaders -framework Foundation \
    inbox/fires/rfc075_metal_runtime_shim_2026_05_21/host_check.c \
    self/metal/runtime_metal.m \
    -o /tmp/host_check

# 4. run
/tmp/host_check
```

## Object sizes (no-regression check)

| Build              | Size (B) | Delta  |
|--------------------|----------|--------|
| runtime.o (no flag) | 484 752  | (base) |
| runtime.o -DHEXA_METAL | 485 504 | +752 B |
| runtime_metal.o    | 8 016    | new    |

Default Mac build (no -DHEXA_METAL) is byte-equivalent in behaviour to
pre-N15 — the new block is `#if defined(__APPLE__) && defined(HEXA_METAL)`
gated.

## Out of scope (gap #1 elephant)

- FP64 path. Apple GPU is FP32-only; pre-req #1 (HX_FARR32 FP32 farr
  table) lands in a separate cycle and eliminates the per-call cast cost.
- d=768 / d=4096 production measurement. Numeric correctness is closed
  on a 64×64 smoke; perf measurement at flame's d768/12L hot-path is the
  next follow-on cycle.
- Hexa-native Metal codegen. MPS is a closed-library blackbox — no
  whole-program fusion. The hexa-emit Metal target lives in
  compiler/codegen/metal_target.hexa (separate N5 lane).
