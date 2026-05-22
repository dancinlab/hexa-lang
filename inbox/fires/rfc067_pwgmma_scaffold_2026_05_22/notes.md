# RFC 067 PWGMMA-SCAFFOLD — feasibility fire on RTX 5070 sm_120

**Date**: 2026-05-22
**Host**: ubu-2 (RTX 5070 sm_120, driver 580.159.03 / driver-API 13000)
**Scope**: First hexa-emit wgmma.async fire — feasibility-only

## TL;DR

**Verdict**: FALSIFIED-ARCHITECTURAL. wgmma.async is **sm_90a (Hopper) only**.
RTX 5070 (Blackwell consumer / sm_120a) driver-JIT explicitly rejects every
wgmma instruction. This is not a code bug — it is a silicon-class boundary.

The 16% gap to cuBLAS on sm_120 **cannot** be closed via wgmma. Stay on
mma.sync ceiling. To actually fire wgmma we would need an H100/H200 host.

## What was built

- `gen_wgmma_scaffold_ptx.py` — generator for minimal wgmma kernel
  - tile M=64 N=16 K=16 (smallest viable `wgmma.m64n16k16.f32.f16.f16`)
  - 1 warpgroup (128 threads), single-tile
  - explicit shared-memory load via plain `st.shared.b{64,32}` (no cp.async
    in this fire — feasibility-only)
  - descriptor encoding per PTX ISA 8.0 §9.7.13.5.5:
    - bits 0-13: `start_addr >> 4`
    - bits 16-29: LBO >> 4 (256 B for A leading dim, 16 B for B leading dim)
    - bits 32-45: SBO >> 4 (16 B for A stride dim, 256 B for B stride dim)
    - bits 49-51: base_offset (0)
    - bits 52-53: swizzle (0 = no swizzle)
- `host.c` — driver-API host (cuModuleLoadDataEx + JIT verbose logging)
- `measure.sh` — full pipeline: gen → ptxas verify → nvcc host build → fire

## ptxas standalone (sm_90a target)

```
ptxas info    : Compiling entry function 'wgmma_kernel' for 'sm_90a'
ptxas info    : Function properties for wgmma_kernel
    0 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
ptxas info    : Used 34 registers, 2560 bytes smem
EXIT 0
```

Standalone ptxas (CUDA 12.0.140) **accepts wgmma at sm_90a**. The scaffold
is structurally valid. Would fire on Hopper.

## cuModuleLoadDataEx driver-JIT (target=sm_120a, GPU=RTX 5070)

```
JIT failed: a PTX JIT compilation failed
JIT error log:
ptxas application ptx input, line 90; error : Instruction 'wgmma.fence' cannot be compiled for architecture 'sm_120a'
ptxas application ptx input, line 91; error : Instruction 'wgmma.mma_async with floating point types' cannot be compiled for architecture 'sm_120a'
ptxas application ptx input, line 94; error : Instruction 'wgmma.commit_group' cannot be compiled for architecture 'sm_120a'
ptxas application ptx input, line 95; error : Instruction 'wgmma.wait_group' cannot be compiled for architecture 'sm_120a'
ptxas fatal : Ptx assembly aborted due to errors
```

All four wgmma instruction families rejected by the driver's internal ptxas
when targeting sm_120a. This is not "forward-compat unavailable" — it is an
explicit rejection. wgmma was never part of Blackwell consumer's ISA.

## Silicon class boundaries (recap, for future fires)

| Arch        | SM      | Tensor-core async path     | Status on RTX 5070 |
|-------------|---------|----------------------------|--------------------|
| Ampere      | sm_80   | mma.sync (warp, sync)      | runs (legacy)      |
| Hopper      | sm_90a  | **wgmma.async** (wg, async)| **rejected**       |
| Blackwell B200 | sm_100a | tcgen05.mma (cluster) | rejected (no sm)  |
| Blackwell GB202 | sm_120a | mma.sync only (no async)| native            |

Notes:
- cuBLAS on RTX 5070 picks `cutlass_80_tensorop_s16816gemm_f16` per N104
  SASS-diff — that's an Ampere mma.sync kernel, NOT a wgmma kernel. Even
  cuBLAS itself does not use wgmma on this silicon. Same boat.
- The 16% gap is therefore NOT a "use better tensor core async" gap — it is
  a scheduling/tiling gap within the mma.sync regime.

## Files

- `gen_wgmma_scaffold_ptx.py` — generator (114-line PTX)
- `wgmma_scaffold.ptx` — emitted PTX
- `wgmma_scaffold.cubin` — sm_90a cubin (PROOF OF VALID PTX)
- `host.c` — driver-API host
- `measure.sh` — pipeline
- `ptxas_info.log` — standalone ptxas accept log
- `compile.log` — nvcc host build log
- `fire.log` — JIT rejection log
- `result.json` — structured result
- `notes.md` — this file

## g3 honest summary

- **wgmma ptxas accept on which sm target?** sm_90a only (CUDA 12.0
  standalone ptxas verified). Driver ptxas (CUDA 13) also accepts at
  sm_90a but **explicitly rejects when forced to lower to sm_120a**.
- **cuModuleLoadDataEx on sm_120 status?** REJECTED (CUDA_ERROR_INVALID_PTX).
- **Numeric result?** N/A — kernel never executed.
- **GFLOPS?** N/A.
- **Feasibility verdict on RTX 5070?** IMPOSSIBLE (architectural, not a bug).
- **Feasibility verdict on Hopper?** READY — scaffold passes standalone
  ptxas with 34 reg / 2560 B smem / 0 spills. First fire would need an
  H100/H200 pool host.

## Closure

This cycle delivered the precise architectural finding that wgmma is not
a path to closing the 0.84 → 1.0 cuBLAS gap on RTX 5070. That information
was previously suspected (the GPU is Blackwell, wgmma is Hopper) but not
*measured* — now it is, with the exact ptxas error string captured.

Future cycles on this gap should focus on mma.sync scheduling /
tiling / occupancy rather than instruction-class promotion.
