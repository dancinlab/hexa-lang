# N200 TMA SMOKE — partial PASS (mbarrier parity bug found)

## What worked
- ptxas (CUDA 12.9) accepts `.target sm_120a + .version 8.7` SGEMM kernel with TMA.
- 2 TMA descriptors (A 64x16, B 16x64) encoded via `cuTensorMapEncodeTiled`.
- `cuModuleLoadDataEx` accepts on RTX 5070 sm_120 driver-JIT.
- `cuLaunchKernel` runs to completion, no driver error.
- First TMA load reaches shared memory with correct values.

## Bug found
**Mbarrier parity does NOT flip per K-iter.** Result.json:
```
got = 2.000000  (= a[0, 32], 3rd iter's k_off)
exp = 3.000000  (= a[0, 48], expected last iter's k_off=48)
```
This means iters 0,1,2 ran (k_off=0,16,32) but iter 3 (k_off=48) either
didn't run or wrote stale data. Diagnosis: `mbarrier.try_wait.parity.shared::cta.b64 %p, [bar], 0`
always waits for parity=0, but mbarrier parity flips each `arrive` cycle.
Second iter's arrive flips parity to 1, but the wait still uses 0 → spins forever
OR hits sticky-completion of phase 0 and proceeds without waiting for new data.

## Fix
- Track parity bit: alternate try_wait parity (0, 1, 0, 1, ...) per K-iter.
- OR reset mbarrier each K-iter via `mbarrier.init` — wasteful.
- OR use one mbarrier per K-stage (multi-stage like cuBLAS) — N201 territory.

## Significance
**This is the first hexa TMA+mma.sync GEMM-shaped kernel to load + execute on sm_120.**
Single-iter TMA works perfectly. Multi-iter needs parity-tracking (next cycle).

Falsifier F-RFC067-TMA-SMOKE: PARTIAL_PASS (loads work, multi-iter mbarrier bug).
