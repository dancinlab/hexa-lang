# discovery: hexa-fusion-sm90-wgmma-parity
# id: F-FUSION-SM90-WGMMA-PARITY
# seed: native sm_90(a) H100 own-GEMM forge parity vs cuBLAS (~340 TFLOP/s).
#       NOT an impossibility verdict — the silicon demonstrably reaches peak via
#       wgmma+TMA (cuBLAS proves it); the residual is a known CUTLASS layout builder.
# verdict-tier-target: 🟢 numerical (bit-correct rel-RMS<=3e-3 → own GFLOP/s + ratio vs cuBLAS)
#
# === STATE (2026-06-06, after the GMMA::Layout pass — SWIZZLE SOLVED, BIT-CORRECT) ===
#   ladder: 30.4x (parent WMMA2 software-TF32)
#         → 29.4x (mma.sync cuBLAS-mainloop, bit-exact #2805)  [mma.sync CEILING — ruled out]
#         → wgmma.mma_async + TMA FEASIBLE on sm_90a (#2808): builds + runs, f16 probe correct.
#         → wgmma bit-correctness BLOCKED (#2812): rel-RMS 1.309, >2300-config sweep nothing<1.36.
#         → **SOLVED (2026-06-06, F-FUSION-SM90-WGMMA-GMMA-LAYOUT):** the real CUTLASS GMMA
#           INTER core-matrix layout makes wgmma TF32 BIT-EXACT.
#           ROOT CAUSE: a wgmma core matrix is 8 ROWS x 16 BYTES = for TF32 (4B) 8x4 ELEMENTS,
#           NOT the 8x8 K-strip the prior sweep assumed. That 8-vs-4 IS defects (1)+(2).
#           W2 single-tile rel-RMS = 0.000e+00 · W3 full 2048^3 rel-RMS = 0.000e+00 (after the
#           fence.proxy.async.shared::cta ordering fix — wgmma reads shared via async proxy).
#
# === CLOSED-NEGATIVE (ruled out, do not re-attempt) ===
#   - mma.sync reaching parity (29x ceiling, deterministic)
#   - plain row/col-major + descriptor LBO/SBO offset + epilogue-permutation swizzle (>2300 sweep)
#   - the 8x8 K-core assumption (the actual TF32 core is 8x4 — this WAS the layout bug)
#
# === MILESTONES (W-ladder, this pass) ===
#   W1  GMMA::Layout B-core-matrix builder       DONE — built, 8x4 TF32 INTER core layout.
#   W2  single-tile identity verify (GATE)       DONE — rel-RMS 0.000e+00 (SWIZZLE SOLVED ★).
#   W3  full wgmma GEMM bit-correct (GATE)        DONE — rel-RMS 0.000e+00 @2048^3 (proxy-fence fix).
#   W4  sm_90 parity measure                     DONE (honest) — own 20.2 TFLOP/s 2048^3,
#                                                  cuBLAS-TF32 357.5, ratio 17.67x, PARITY=NO.
#   W5  pipeline tune                            NARROWED — wide-N TN=128 → 38.0 TFLOP/s (9.35x),
#                                                  bit-exact. TN=256 slower (reg/occupancy).
#
# === OPEN — the one named residual ===
#   PARITY (strict <=1.3x): needs the full warp-specialized TMA multi-stage CUTLASS mainloop
#     (cp.async.bulk.tensor producer + wgmma consumer, deep software pipeline). Multi-session
#     build. It is a LATENCY-HIDING residual — NOT the layout (W2 solved) and NOT correctness
#     (W3 bit-exact 2048^3). The own-GEMM is now provably CORRECT on sm_90a; the gap is pure perf.
#
# === ARTIFACTS ===
#   kit (new): self/native/wgmma/wgmma_tf32_gmma.cu (W1/W2), wgmma_tf32_gemm2048.cu (W3/W4),
#              wgmma_tf32_gemm_w5.cu (W5 TN=128), wgmma_tf32_gemm_w5b.cu (W5 TN=256), gmma_run.sh
#   kit (prior): self/native/wgmma/{wgmma_tf32_decode,_bdecode,_full,_swz}.cu + sweep_fast.sh
#   verdict: .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt
#   PRs: #2805 · #2808 (MERGED) · #2812 · #2815 (consolidation) · <this PR> (GMMA layout)
#   handoffs: 2e4438a7 reply chain
#
# next-cycle claim: W5+ warp-specialized TMA multi-stage mainloop toward strict parity.
#   The layout + correctness are SOLVED; the remaining work is a pure pipeline-engineering
#   perf climb (9.35x → <=1.3x), gated on a fresh multi-session GPU budget.

# ============================================================================
# === UPDATE 2026-06-06 — W6 async-pipe (50.7) + W7 dual-consumer-WG CLOSED-NEG
# ============================================================================
# W6 (#2833): cp.async async-pipe ring = 50.7 TFLOP/s bit-exact (rel_rms 0) = 8.39x off
#   cuBLAS-TF32 (+33% over 38.0; ~11.5% of gap closed). NST 2..5 saturates → ring depth
#   not the wall. single-consumer-WG warp-spec = 35.0 (starves TC at TM=64).
#
# W7 dual-consumer-WG warp-spec (MODE 3 gemm_ws2, TM=128: 1 cp.async producer WG + 2
#   consumer WGs each wgmma over its 64-row band x SHARED B tile). H100 sm_90a, vast
#   39651872 DESTROYED leak 0, nvcc 12.5.82. verdict F-FUSION-SM90-WGMMA-W7.txt.
#   RESULT: BIT-EXACT (rel_rms 0, S=2048/4096, NST=2..5) but SLOWER = 32.0 (13.2x).
#   W7 hypothesis FALSIFIED. ROOT CAUSE (on-pod occupancy calc): 128-thread cp.async
#   producer WG @ TM=128 is REGISTER-bound to 1 blk/SM (90 regs * 384 = 34560/CTA;
#   2 CTAs=69120 > 65536 regs/SM) -> 256 compute-thr/SM vs apipe 4*128=512. NOT smem
#   bound (24KB << 233KB/SM). More consumer WGs cannot win w/ a full-WG cp.async producer.
#
# === NAMED RESIDUAL (W8, next-cycle) ===
#   TMA-driven production: cp.async.bulk.tensor + 1 elected producer thread (freeing 127)
#   so warp-spec keeps FULL occupancy — how cuBLAS reaches sm_90a peak. Bring-over the W6
#   TMA kit self/native/wgmma/wgmma_tma_gemm.cu. Frontier kernel = W6 async-pipe (50.7, 8.39x).
#   STOP = honest occupancy/production-engine wall, NOT impossibility. cuBLAS=roofline.
