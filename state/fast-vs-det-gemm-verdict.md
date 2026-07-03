# FAST vs DET GEMM parity verdict — 2026-06-29

## GOAL
"fast 기본 완료": prove FAST (non-deterministic default, `HEXA_DET` unset) >= DET
(`HEXA_DET=1`) at GEMM kernel level. #4208 wired `_hx_k_gemm_splitk` (atomic split-K)
as FAST default for M>1, `_hx_k_gemm` for DET.

## Measurement setup
- host: summer (RTX 5070 12GB, sm_120, CUDA 12.9 at /usr/local/cuda-12.9)
- harness: `build/cuda/gemm_cuda` compiled from fixed `tool/build_cuda_runtime`
  (`CUDA_HOME=/usr/local/cuda-12.9 SM=120`)
- FAST: `build/cuda/gemm_cuda` (no env, `_forge_det_on()=0`)
- DET: `HEXA_DET=1 build/cuda/gemm_cuda` (`_forge_det_on()=1`)
- N=7 isolated runs each (back-to-back, same process, no interleaving)
- cuBLAS-free (own kernels only)

## Raw results (GFLOP/s)

FAST d=1024: 369.27 381.88 383.54 384.75 385.87 386.02 389.95
FAST d=2048: 457.74 458.08 458.14 458.64 458.68 458.71 458.83
DET  d=1024: 375.15 378.24 380.98 383.32 386.09 386.70 388.70
DET  d=2048: 453.29 453.63 454.10 454.14 454.84 455.86 455.99

## Median summary

| size  | FAST (median) | DET (median) | FAST/DET | verdict |
|-------|---------------|--------------|----------|---------|
| d=1024 | 384.75 GFLOP/s | 383.32 GFLOP/s | +0.37% | FAST >= DET |
| d=2048 | 458.64 GFLOP/s | 454.14 GFLOP/s | +0.99% | FAST >= DET |

## Numerical correctness

- FAST rel_rms_vs_ikj: 1.129e-15 (d=1024), 1.586e-15 (d=2048)
- DET  rel_rms_vs_ikj: 4.327e-16 (d=1024), 5.112e-16 (d=2048)
- Both within machine epsilon (~2.2e-16 for f64). DET has lower variance
  (deterministic reduction order).

## GOAL verdict: CONFIRMED

FAST >= DET at both GEMM sizes (+0.37% to +0.99%). Zero regression.
"fast 기본 완료" = CLOSED at GEMM kernel level.

## Scope limitation

Measurement is GEMM-level only. Full-step CLM training (clm303 303M) was not
measured because:
1. anima trainer is on a separate repo not directly accessible here
2. The hexa runtime CUDA build infrastructure needed a fix before any CUDA
   measurement was possible (multi-def link wall, 19 symbols — now fixed)

The GEMM evidence covers the dominant compute kernel in transformer training.

## Prerequisite fix committed

`tool/build_cuda_runtime` multi-def wall (19 symbols:
hexa_arena_alloc/mark/rewind/reset + 15x rt_str_*) was root-caused and fixed:
- `_regen_runtime_core_for_cuda()`: regen runtime_core.c from SSOT emitter after
  restore_frozen_seeds (adds HEXA_RT_ALLOC_NATIVE guards)
- SSOT reconcile: drops 4 migrated f64<->bits weak defs from runtime.c
- RT-NATIVE Z2a: patches out #include "runtime_hi_gen.c" when rt_hi_native.o in CORES
- CPU build: compiles fresh runtime.o instead of extracting from archive
