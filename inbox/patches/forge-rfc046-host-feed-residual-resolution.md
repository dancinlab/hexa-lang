# F-RFC046 host per-step orchestration — residual resolution (host-feed finding)

ref: fe2e43a35 (lever-a/b landed); forge-devfeed-lever-b-landed-lever-a-spec.md;
     #2504 (lever-b strided GEMM fuse) · #2505 (lever-a device im2col/col2im+AdamW)
status: SOURCE redesign landed (byte-eq PRESERVED) · util≥20% PENDING gated GPU fire

## the finding (today's clean Lane-G fire)

All 5 build/link/compile/emit bugs fixed + merged; GPU provably live (87W,
GB-scale device memory). Measured util **RED — mean 0.811%, peak 6%, n=987** at
mid d~1536 / T~512 — **DESPITE both device-feed levers active** (lever-a #2505,
lever-b #2504). CE descent GREEN (F-CLM-PROD-DESCENT=1). The trainer pegs ONE CPU
core at 100% while the GPU SM-starves. Root cause is NOT link/kernel/emit/scale
(all closed today) — it is the **interpreted host-side per-step orchestration loop**
in the flame/clm_prod driver.

## profile (PROFILE-FIRST, verbatim — d=1536 / T=512 / K=3 / E=2 / V=256)

Method: per-step interpreted-op count model + measured hexa-interpreter
t_set/t_get throughput.

    measured interpreter throughput (warm, compile-cached, mac CPU):
      empty (alloc+exit)        : 0.03 s
      14,155,776-op host loop   : 0.22 s   →  ~13.4 ns / interpreted scalar op

    per-step HOST scalar-op count (runs host-interpreted EVEN with DEVFEED+BATCHED):
      FWD TOTAL  41,422,848
      BWD TOTAL  62,656,512
      TOTAL     104,079,360 host scalar ops / step   (+22 separate _adam dispatches)

    category breakdown:
      expert batched-path host repack/im2col/col2im : 67,633,152  (65.0%)  ← DOMINANT
      conv Wt-transpose + bias + db (4 convs ea way): 32,514,048  (31.2%)
      residual/copy/sum glue                        :  3,932,160  ( 3.8%)

    wall-time: 104.08M × 13.4 ns ≈ 1.39 s host CPU/step (one core 100%); H100
    conv GEMM (M=512,K=4608,N=1536) ≈ sub-ms → util ≈ <1ms/1400ms ≈ 0.07–0.8%
    ⇒ MATCHES the fire (mean 0.811%, peak 6%).

KEY: the device levers offload the MATH, but the surrounding per-step host repack
stays interpreted. Critically, the **batched-expert path bypassed lever-(a)**:
`conv2_fwd_via_forge_batched` / `conv2_bwd_via_forge_batched` carried INLINE host
`t_set` im2col / im2col_t loops instead of calling `_clmp_im2col` /
`_clmp_im2col_t`, so the experts' gather never went device-resident.

## redesign landed (this branch, byte-eq PRESERVED)

Route the batched-expert im2col / im2col_t through the lever-(a) device helpers
(`_clmp_im2col` / `_clmp_im2col_t`) — device-resident under CLM_PROD_DEVFEED so
the gather leaves the host hot path and feeds the batched GEMM in place with no
H2D roundtrip. Device math (levers a+b) intact.

byte-eq (g5, CPU oracle `stdlib/flame/clm_prod_hostfeed_eq.hexa`, $0 mac):

    F-RFC046-HOSTFEED-FWD-EQ = 1   (max|Δ| y0=0.0 y1=0.0, dil∈{1,2})
    F-RFC046-HOSTFEED-BWD-EQ = 1   (max|Δ| xcolT=0.0,      dil∈{1,2})

Existing oracles unchanged & re-green: F-CLM-DEVFEED-{IM2COL,FWD,BWD,ADAM}-EQ,
F-CLM-CONV2-BATCHED-{FWD,BWD}-EQ all max|Δ|=0.0 (dX residual 2.7e-17 FP64-ULP).

## HONEST residual — what is NOT done here (pod-rebuild, separate)

The im2col routing removes the expert GATHER from the host hot path, but the
DOMINANT remaining host cost is the **GEMM-feed REPACK** intrinsic to the matmul
calling convention: weight transpose (`Wt`), `a_all`/`b_all`/`c_all` pack/unpack,
`dW` unpack (the 14.16M-op loops). Eliminating those needs a device repack /
transpose-aware GEMM builtin (`forge_dispatch_matmul` has no transpose variant) —
a signature change in self/runtime.c + the cuda kernels, requiring the self-host
pod rebuild and NOT byte-eq-testable on the prebuilt mac binary. That is a
distinct, larger effort (a follow-on lever), out of scope for this byte-eq source PR.

## next step (HELD — gated for user go)

util≥20% verify fire: clean single-driver H100 sm_90 (no collision), CLM_PROD_DEVFEED
+ CLM_PROD_BATCHED both set, HEXA_CUDA_ARCH=90, -lcuda. SUCCESS = util ≥20% AND
descent GREEN; paste nvidia-smi PEAK/MEAN verbatim. NOT fired this pass (source +
byte-eq only, per cost discipline). The source redesign CANNOT confirm util≥20%
without that fire.
