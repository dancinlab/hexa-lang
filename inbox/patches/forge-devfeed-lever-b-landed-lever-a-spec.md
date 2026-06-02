# forge device-feed levers — lever (b) LANDED, lever (a) spec (2026-06-02)

Context: the Lane-G CLM util-RED unblock. Two fires proved forge runs on the GPU
(cuBLAS+cudart+libcuda linked, 196 W, 66 GB dev-mem) and descent is GREEN, but
util is RED (PEAK 4-6%, MEAN 0.24%) and SCALE-INVARIANT — the host-side backward
feed (im2col/col2im + adam + the interpreted per-step loop) pegs one CPU core
while the cuBLAS GEMMs finish in microseconds. The documented unblock is to move
the backward feed on-device (lever a) and/or fuse the per-step GEMMs (lever b).

## Lever (b) — fuse the per-step conv GEMMs — LANDED (this branch)

The CLMConvMoE trainer launches the two ConvExperts (e0/e1: d→d, K=3, identical
shape) as 2 separate forge GEMMs every step (fwd) and 2 each for dW/dX (bwd) —
microsecond-latency-bound micro-launches. Batched them into ONE
`cublasDgemmStridedBatched` (batch=2) per fused GEMM.

- New 7-arg builtin `forge_dispatch_matmul_batched(a_all,M,K,b_all,N,batch,c_all)`:
  `self/codegen.hexa` lowering · `self/runtime.h` proto + bare seam ·
  `self/runtime.c` wrapper (CUDA → `_hx_cuda_farr_matmul_batched_gpu` =
  `cublasDgemmStridedBatched`; no-CUDA → byte-eq host loop oracle) ·
  `self/cuda/runtime_cuda_emit.hexa` emits the kernel (row-major→col-major swap,
  strides M·K / K·N / M·N over the batch dim). `runtime_cuda.c` seed regenerated.
- `stdlib/flame/clm_conv_batched.hexa` — `forge_matmul_batched` oracle +
  `conv2_fwd/bwd_via_forge_batched` (share im2col across the 2 experts).
- `stdlib/flame/clm_prod.hexa` — e0/e1 fwd+bwd wired through the batched path
  (env `CLM_PROD_BATCHED` gates the GPU builtin; oracle otherwise).

CPU-local byte-eq (local no-CUDA self-host stage build → `./build/hexa_devfeed`):
- `F-FORGE-BATCHED-EQ = 1` — per-problem max|Δ| batched-vs-serial = 0.0 (EXACT).
- `F-CLM-CONV2-BATCHED-FWD/BWD-EQ = 1` — fwd y0/y1 = 0.0; bwd dW/dX/db = 0.0.
- full-trainer: un-batched 4.69813→1.66631 == batched 4.69813→1.66631 (IDENTICAL).

The `cublasDgemmStridedBatched` call itself is exercised only on the GPU pod
(nvcc compile); its C is structurally identical to the proven single-Dgemm path
(`_hx_cuda_farr_matmul_gpu`).

Honest caveat: lever (b) reduces the expert-conv LAUNCH count but does NOT touch
the dominant host peg (im2col/col2im/adam scalar loop). Per the mid-d1536
finding, (a)+(b) TOGETHER are the unblock — firing GPU on (b) alone is unlikely
to clear util≥20%. No GPU fired this rung.

## Lever (a) — device-side im2col/col2im + adam — SPEC (remaining gap)

The real host-core peg. To remove it the backward feed must stay device-resident:

1. **Device im2col / col2im kernels.** Port `_conv1d_im2col` (gather) and the
   col2im scatter-add to `__global__` kernels (one thread per (t, ci·K+k) output
   cell; col2im needs atomicAdd on the scatter, OR the transpose-gather form to
   avoid atomics). The im2col output `x_col` must be written to a DEVICE-RESIDENT
   farr (FARR_DEVICE) and consumed by `forge_dispatch_matmul[_batched]` WITHOUT an
   intervening D2H/H2D — i.e. the GEMM reads the device buffer in place. This is
   the piece that actually removes the host roundtrip; an im2col kernel that still
   copies x_col back to host between the gather and the GEMM does NOT help.
   Touches the FARR_DEVICE residency + dirty_host/dirty_dev bookkeeping so the
   GEMM's `_h2d` sees the buffer already current on device.
2. **Device AdamW for all weights.** `_hx_cuda_farr_adamw_step_gpu` already exists
   (decoupled-wd, byte-eq to the host oracle). Wire every `_adam(...)` call in the
   trainer's per-step loop through it so the optimizer step + its m/v state stay
   on-device, eliminating the per-weight host update between micro-GEMMs.

Both must be GRAD-EXACT / byte-eq to the current host path (match the conv→forge
byte-eq bar #2352/#2383). Only after (a) is locally green should the single small
util fire run (mid scale d~1536/T~512); success = util clears 20% AND descent
GREEN.
