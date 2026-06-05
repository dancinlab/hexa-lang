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
