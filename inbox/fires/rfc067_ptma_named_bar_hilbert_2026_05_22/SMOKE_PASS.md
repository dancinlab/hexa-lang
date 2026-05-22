# N200 TMA SMOKE PASS — parity fix landed (2026-05-22)

## Pipeline
1. Bug from initial fire: `mbarrier.try_wait.parity 0` wedged on multi-iter K-loop (parity flips per arrive, must track).
2. Fix: `and.b32 %parity, %k_iter, 1` + `mbarrier.try_wait.parity %pdone, [bar], %parity`. Alternates 0,1,0,1 across K-iters.
3. Plus em-dash → `--` ASCII fix (driver-JIT ptxas rejects non-ASCII PTX, separate from standalone ptxas).
4. Re-fire: **mismatch=0/256, verdict=TMA_SMOKE_PASS**.

## What this proves
First hexa TMA+SGEMM-shaped kernel runs **bit-exact** on RTX 5070 sm_120:
- 2 TMA descriptors (A 64x16 fp16 + B 16x64 fp16)
- 4-iteration K-loop with parity-tracked mbarrier (mbarrier.arrive.expect_tx.release + mbarrier.try_wait.parity)
- `.target sm_120a + .version 8.7` (per N196 forward-compat blocker)
- ASCII-only PTX (driver-JIT requirement)

## Verified
- ptxas 12.9 accepts kernel
- driver-JIT (cuModuleLoadDataEx) accepts on sm_120
- cuLaunchKernel runs to completion
- C output cells 0..255 match A's last K-tile (k_off=48..63) byte-exact
- No driver error, no driver-side warning

## Next
N200 now ready for real MMA layer (the SMOKE proved TMA integrates correctly).
Step: replace "write smem_a to C" with full mma.sync.m16n8k16 accumulation chain
(8 mma/warp × 4 K-iters = 32 mma per warp), then store accumulators to C.
Then scale shapes: M=512, M=4096, M=8192.
Then add Hilbert d2xy CTA-swizzle for L2 locality at large M.

Falsifier F-RFC067-TMA-SMOKE: PASS (mismatch=0/256).
