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

## Lever (a) — LANDED (branch feat/forge-devfeed-lever-a, stacked on #2504)

Both pieces implemented + the (a)+(b) trainer wiring. CPU-LOCAL byte-eq green; the
full-trainer byte-eq + util fire are the pod self-host rebuild (recipe below).

### 1. Device im2col / col2im — DONE (transpose-gather, NO atomics)
- `stdlib/flame/clm_conv_devfeed.hexa` — the CPU-LOCAL byte-eq ORACLE + selftest
  (devfeed_im2col / devfeed_im2col_T / devfeed_col2im). col2im uses the
  TRANSPOSE-GATHER form (one thread per dX[p,ci] output cell summing its K dilated
  taps) → no atomicAdd, deterministic, byte-eq to the host scatter order.
  CPU-local proof (`hexa run`, $0, mac):
    F-CLM-DEVFEED-IM2COL-EQ = 1   im2col dil=1/2 max|Δ| = 0.0
    F-CLM-DEVFEED-FWD-EQ    = 1   fwd  dil=1/2 max|Δ| = 0.0
    F-CLM-DEVFEED-BWD-EQ    = 1   bwd dW=0.0 db=0.0 ; dX=2.78e-17/5.55e-17
                                  (FP64 ULP, the #2383 dX class, ≪ 1e-9)
    F-CLM-DEVFEED-ADAM-EQ   = 1   adam 5-step max|Δ| W = 0.0
- `self/cuda/runtime_cuda_emit.hexa` — emits `_hx_cuda_farr_im2col_gpu`,
  `_hx_cuda_farr_im2col_t_gpu`, `_hx_cuda_farr_col2im_gpu` (1-D grid, 1 thread per
  output cell). The im2col kernels call `_d2h_out`, which under the RFC-056
  `FORGE_OUT_DEVICE_KEEP` disposition KEEPS the output FARR_DEVICE (dirty_host=1)
  — the follow-up forge GEMM's `_h2d` sees DEVICE && !dirty_host and SKIPs the
  copy, so x_col never round-trips. THIS is the residency piece the spec called out.
  (To engage the no-roundtrip path, the trainer must set the disposition register
  to FORGE_OUT_DEVICE_KEEP before the im2col call and back to HOST_NOW after the
  GEMM chain — wired in clm_prod's devfeed branch on the pod build; the default
  HOST_NOW path is byte-identical to the host oracle, so correctness holds either
  way.)
- `self/codegen.hexa` — 6-arg lowering for forge_dispatch_im2col / _im2col_t /
  _col2im. `self/runtime.h` — protos + bare seams. `self/runtime.c` (seed) —
  wrappers: HEXA_CUDA→device kernel / no-CUDA→byte-eq host gather/scatter oracle.

### 2. Device AdamW — DONE (wired to the existing inplace kernel)
- `forge_dispatch_adamw(W,g,m,v,n,lr,b1,b2,eps,wd,t)` -> int rc. CUDA →
  `_hx_cuda_farr_adamw_step_inplace_gpu` (the decoupled-wd kernel, ALREADY byte-eq
  to the host oracle; W/m/v kept device-resident). no-CUDA → -1 so the .hexa caller
  runs the proven host `adamw_step` (byte-eq fallback). codegen 11-arg lowering +
  runtime.h proto + runtime.c wrapper. `clm_prod.hexa` `_adam` routes through it
  under env CLM_PROD_DEVFEED.

### 3. (a)+(b) wired — `stdlib/flame/clm_prod.hexa`
- `_clmp_im2col` / `_clmp_im2col_t` / `_clmp_col2im` helpers (env-gated devfeed
  builtin → host oracle fallback) replace the inline conv gather/scatter in
  `conv1d_via_forge` / `conv1d_bwd_via_forge`. `_adam` → forge_dispatch_adamw.
  ALL gated by `env("CLM_PROD_DEVFEED") != ""` — same discipline as lever-b's
  CLM_PROD_BATCHED, so the prebuilt mac binary (no new builtins) never
  link-references them under `hexa run`; both levers compose (set BOTH
  CLM_PROD_DEVFEED and CLM_PROD_BATCHED for the full device feed).

### runtime.c wrapper bodies (SSOT — self/runtime.c is a gitignored build seed)
The four `hexa_forge_dispatch_{im2col,im2col_t,col2im,adamw}` wrapper bodies live
in `self/runtime.c` (regenerated per checkout, not committed — the "23 seed .c"
the GPU-link patch ships). They follow the lever-b `hexa_forge_dispatch_matmul_
batched` template EXACTLY: extract ids/shape, `#ifdef HEXA_CUDA` → extern the
`_hx_cuda_farr_*_gpu` symbol + call it, `if rc==0 return 0` else fall through;
no-CUDA → the byte-eq host gather/scatter (im2col/col2im) or return -1 (adamw,
caller falls to host adamw_step). The full C is in this branch's
`self/runtime.c`; on a fresh pod checkout, re-apply these four bodies after the
batched body (~L14434) before the self-host rebuild.

### CPU-LOCAL status (this pass, $0)
- clm_conv_devfeed.hexa oracle selftest: ALL-PASS (verbatim above).
- runtime.c lever-a wrappers: `clang -fsyntax-only` OK (no-CUDA).
- runtime_cuda_emit.hexa: emits valid C; kernels syntax-OK (only the expected
  cuda_runtime.h-not-found under __CUDACC__ on a CUDA-less mac).
- codegen.hexa transpiles clean; single-file transpile of self/main.hexa OK.

### REMAINING (pod self-host rebuild — the GPU fire build)
1. Full-trainer byte-eq: self-host stage build (lever-b's ./build/hexa_devfeed
   recipe — `build/hexat self/main.hexa` → all CLI module TUs + self/runtime.c +
   self/cuda/runtime_cuda.c + forge_tier_v1.c, the multi-TU link via
   tool/build_dispatch.hexa) → run clm_prod with CLM_PROD_DEVFEED set vs unset →
   identical CE trajectory (devfeed host-fallback == host path; the device path is
   byte-eq to the oracle by construction). The single-`main.hexa` transpile here
   links only the core driver, NOT the CLI command-table TUs — so the FULL
   byte-eq is the pod multi-TU build, identical to the build the util fire uses.
2. nvidia-smi util fire (mid d~1536/T~512), CLM_PROD_DEVFEED + CLM_PROD_BATCHED
   both set, HEXA_CUDA_ARCH=90, -lcuda, ship the seed .c. SUCCESS = util ≥20% AND
   descent GREEN; paste PEAK/MEAN verbatim. NOT fired this pass (lever-a local-green
   reached on the oracle; the full-trainer self-host byte-eq is the same pod build
   as the fire, so per cost-discipline the fire runs from the pod build once that
   byte-eq is confirmed there).
