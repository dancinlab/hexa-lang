commit c546172502a0dd8f86f89bea46f57ca2d04a1bed
Author: nbcorr-agent <nbcorr@local>
Date:   Sat Jun 6 05:09:57 2026 +0900

    domain(HEXA-FUSION sm90): wgmma TF32 BIT-CORRECT via real GMMA::Layout — swizzle SOLVED 🟢
    
    Verdict + discovery tape (W1-W5 flipped) + README sm_90 caveat for
    F-FUSION-SM90-WGMMA-GMMA-LAYOUT.
    
    W1 built · W2 single-tile rel-RMS 0 (SWIZZLE SOLVED) · W3 full 2048^3 rel-RMS 0
    (bit-correct, fence.proxy.async fix) · W4 own 20.2 TFLOP/s 17.67x PARITY=NO ·
    W5 best TN=128 38.0 TFLOP/s 9.35x bit-exact. Residual = warp-specialized TMA
    multi-stage pipeline (perf only; layout + correctness solved). pod destroyed, leak 0.
    
    Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>

diff --git a/.discoveries/hexa-fusion-sm90-wgmma-parity.tape b/.discoveries/hexa-fusion-sm90-wgmma-parity.tape
new file mode 100644
index 000000000..c8b3df254
--- /dev/null
+++ b/.discoveries/hexa-fusion-sm90-wgmma-parity.tape
@@ -0,0 +1,50 @@
+# discovery: hexa-fusion-sm90-wgmma-parity
+# id: F-FUSION-SM90-WGMMA-PARITY
+# seed: native sm_90(a) H100 own-GEMM forge parity vs cuBLAS (~340 TFLOP/s).
+#       NOT an impossibility verdict — the silicon demonstrably reaches peak via
+#       wgmma+TMA (cuBLAS proves it); the residual is a known CUTLASS layout builder.
+# verdict-tier-target: 🟢 numerical (bit-correct rel-RMS<=3e-3 → own GFLOP/s + ratio vs cuBLAS)
+#
+# === STATE (2026-06-06, after the GMMA::Layout pass — SWIZZLE SOLVED, BIT-CORRECT) ===
+#   ladder: 30.4x (parent WMMA2 software-TF32)
+#         → 29.4x (mma.sync cuBLAS-mainloop, bit-exact #2805)  [mma.sync CEILING — ruled out]
+#         → wgmma.mma_async + TMA FEASIBLE on sm_90a (#2808): builds + runs, f16 probe correct.
+#         → wgmma bit-correctness BLOCKED (#2812): rel-RMS 1.309, >2300-config sweep nothing<1.36.
+#         → **SOLVED (2026-06-06, F-FUSION-SM90-WGMMA-GMMA-LAYOUT):** the real CUTLASS GMMA
+#           INTER core-matrix layout makes wgmma TF32 BIT-EXACT.
+#           ROOT CAUSE: a wgmma core matrix is 8 ROWS x 16 BYTES = for TF32 (4B) 8x4 ELEMENTS,
+#           NOT the 8x8 K-strip the prior sweep assumed. That 8-vs-4 IS defects (1)+(2).
+#           W2 single-tile rel-RMS = 0.000e+00 · W3 full 2048^3 rel-RMS = 0.000e+00 (after the
+#           fence.proxy.async.shared::cta ordering fix — wgmma reads shared via async proxy).
+#
+# === CLOSED-NEGATIVE (ruled out, do not re-attempt) ===
+#   - mma.sync reaching parity (29x ceiling, deterministic)
+#   - plain row/col-major + descriptor LBO/SBO offset + epilogue-permutation swizzle (>2300 sweep)
+#   - the 8x8 K-core assumption (the actual TF32 core is 8x4 — this WAS the layout bug)
+#
+# === MILESTONES (W-ladder, this pass) ===
+#   W1  GMMA::Layout B-core-matrix builder       DONE — built, 8x4 TF32 INTER core layout.
+#   W2  single-tile identity verify (GATE)       DONE — rel-RMS 0.000e+00 (SWIZZLE SOLVED ★).
+#   W3  full wgmma GEMM bit-correct (GATE)        DONE — rel-RMS 0.000e+00 @2048^3 (proxy-fence fix).
+#   W4  sm_90 parity measure                     DONE (honest) — own 20.2 TFLOP/s 2048^3,
+#                                                  cuBLAS-TF32 357.5, ratio 17.67x, PARITY=NO.
+#   W5  pipeline tune                            NARROWED — wide-N TN=128 → 38.0 TFLOP/s (9.35x),
+#                                                  bit-exact. TN=256 slower (reg/occupancy).
+#
+# === OPEN — the one named residual ===
+#   PARITY (strict <=1.3x): needs the full warp-specialized TMA multi-stage CUTLASS mainloop
+#     (cp.async.bulk.tensor producer + wgmma consumer, deep software pipeline). Multi-session
+#     build. It is a LATENCY-HIDING residual — NOT the layout (W2 solved) and NOT correctness
+#     (W3 bit-exact 2048^3). The own-GEMM is now provably CORRECT on sm_90a; the gap is pure perf.
+#
+# === ARTIFACTS ===
+#   kit (new): self/native/wgmma/wgmma_tf32_gmma.cu (W1/W2), wgmma_tf32_gemm2048.cu (W3/W4),
+#              wgmma_tf32_gemm_w5.cu (W5 TN=128), wgmma_tf32_gemm_w5b.cu (W5 TN=256), gmma_run.sh
+#   kit (prior): self/native/wgmma/{wgmma_tf32_decode,_bdecode,_full,_swz}.cu + sweep_fast.sh
+#   verdict: .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt
+#   PRs: #2805 · #2808 (MERGED) · #2812 · #2815 (consolidation) · <this PR> (GMMA layout)
+#   handoffs: 2e4438a7 reply chain
+#
+# next-cycle claim: W5+ warp-specialized TMA multi-stage mainloop toward strict parity.
+#   The layout + correctness are SOLVED; the remaining work is a pure pipeline-engineering
+#   perf climb (9.35x → <=1.3x), gated on a fresh multi-session GPU budget.
diff --git a/.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt b/.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt
new file mode 100644
index 000000000..aed055493
--- /dev/null
+++ b/.verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt
@@ -0,0 +1,52 @@
+F-FUSION-SM90-WGMMA-GMMA-LAYOUT — wgmma TF32 GMMA::Layout core-matrix builder
+sm_90a H100 SXM (compute_cap 9.0), CUDA 12.6, -arch=sm_90a. vast 39639304 (destroyed, leak 0).
+date 2026-06-06. branch domain/hexa-fusion-sm90-wgmma-gmma-layout.
+
+=== W1 — wgmma GMMA::Layout B-core-matrix builder: BUILT = YES ===
+Implemented the real CUTLASS-3.x GMMA INTER (no-swizzle) shared-memory core-matrix
+layout for TF32 wgmma.mma_async.m64n64k8.
+ROOT CAUSE of the prior >2300-config dead end: a wgmma core matrix is 8 ROWS x 16 BYTES
+= for TF32 (4B/elem) 8 rows x 4 ELEMENTS, NOT the 8x8 K-strip the prior kit assumed.
+That 8-vs-4 mismatch IS pinned defects (1) K-stride collapse + (2) N-octet interleave.
+Layout: gmma_phys(s,k) = (strip*2 + kcore)*32 + sr*4 + kc  (8x4 cores laid contiguous).
+Descriptor (cute/arch/mma_sm90_desc.hpp): start[0,14) LBO[16,30) SBO[32,46)
+layout_type[62,64)=INTERLEAVE(0); LBO=128B SBO=256B inter-core strides.
+artifact: self/native/wgmma/wgmma_tf32_gmma.cu
+
+=== W2 — single-tile identity verify (GATE): PASS, rel_rms = 0.000e+00 ===
+mode=1 ALO=0 BLO=0 lA=128 sA=256 lB=128 sB=256 : exact=4096/4096 rel_rms=0.000e+00 PASS
+full random single-tile (mode=0) same config: exact=4096/4096 rel_rms=0.000e+00.
+=> THE SWIZZLE IS SOLVED. The single 64x64x8 wgmma tile is bit-exact.
+
+=== W3 — full wgmma+TMA GEMM bit-correct (GATE): PASS at 2048^3, rel_rms = 0.000e+00 ===
+Tiled 64x64 GEMM, K-loop wgmma accumulation, double-buffered shared.
+Initial cliff: bit-exact <=K1536 but non-deterministic 3e-2..1e-1 at K>=1792.
+ROOT CAUSE: wgmma reads shared through the ASYNC PROXY; ordinary __syncthreads does
+NOT order generic shared stores vs the async-proxy read. FIX: fence.proxy.async.shared::cta
+after staging. Then 2048^3 own vs cuBLAS-TF32 = 0.000e+00, own vs CPU-f64 = 0.000e+00,
+DETERMINISTIC across runs. (no TMA in this kernel; cp.async/TMA reserved for W5 pipeline.)
+artifact: self/native/wgmma/wgmma_tf32_gemm2048.cu
+
+=== W4 — sm_90 parity measure (HONEST, bit-correct kernel, g5) ===
+naive single-wgmma-per-block (64x64 tile, wait_group 0 every step):
+  2048^3: own=20.2 TFLOP/s  cuBLAS-TF32=357.5  ratio(cuBLAS/own)=17.67x  rel_rms=0.000e+00  PARITY=NO
+  4096^3: own=25.9 TFLOP/s  cuBLAS-TF32=440.4  ratio=16.99x              rel_rms=0.000e+00  PARITY=NO
+cuBLAS-TF32 = roofline; NO superiority claim. Sub-parity (expected: zero latency hiding).
+
+=== W5 — pipeline tune (W4 sub-parity) ===
+wide-N TN=128 (2 wgmma/K-step, reuse A):  own=38.0 TFLOP/s 2048^3  ratio 9.35x  rel_rms=0.000e+00
+  -> ~1.9x over W4 single-wgmma; bit-exact preserved.
+wide-N TN=256 (4 wgmma/K-step):           own=26.7 TFLOP/s         ratio 13.26x (SLOWER —
+  128 accum regs + larger shared cut occupancy). TN=128 is the sweet spot here.
+HONEST STOP: best real sm_90 own-wgmma number = 38.0 TFLOP/s bit-exact, 9.35x off cuBLAS.
+NAMED RESIDUAL: strict <=1.3x parity needs the full warp-specialized TMA multi-stage
+CUTLASS mainloop (cp.async.bulk.tensor producer + wgmma consumer, deep pipeline) — a
+multi-session build. NOT the layout (W2 SOLVED) and NOT correctness (W3 bit-exact 2048^3).
+artifacts: self/native/wgmma/wgmma_tf32_gemm_w5.cu (TN=128), wgmma_tf32_gemm_w5b.cu (TN=256)
+
+=== TIER ===
+W1 BUILT · W2 PASS (rel_rms 0 — SWIZZLE SOLVED) · W3 PASS (rel_rms 0 @2048^3 — bit-correct)
+· W4 measured (20.2 TFLOP/s, 17.7x, PARITY=NO) · W5 best 38.0 TFLOP/s (9.35x, PARITY=NO).
+🟢 numerical: own-GEMM on sm_90a is now BIT-CORRECT via the real GMMA layout. Parity gap
+narrowed from "wrong result" to a named latency-hiding pipeline residual (9.35x, honest).
+pod destroyed YES (leak 0).
diff --git a/README.md b/README.md
index a5a6f4fee..c503372fe 100644
--- a/README.md
+++ b/README.md
@@ -166,6 +166,8 @@ The full-step gap closed in two landed steps: skinny-shape dispatch (16×16 tile
 > **↳ wgmma + TMA rewrite — FEASIBILITY PASS, layout residual (`F-FUSION-SM90-WGMMA-TMA`).** The named wgmma/TMA lever is now **build- and run-feasible on native sm_90 H100**: with `-arch=sm_90a` (nvcc 12.6), **`wgmma.mma_async` executes correctly** (f16 probe: nonzero 2048/2048, sum 1962.49 vs ref 1956.87) and the **entire Hopper async PTX surface compiles** — `cuTensorMapEncodeTiled` (TMA) + `cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes` + `mbarrier.*`. This **converts** the prior `F-FUSION-ATTN-WGMMA-WALL` hardware-blocked closed-negative (same kernel silently NOP'd on Blackwell sm_120) into testable-on-Hopper. **The own-source emit path is NOT the blocker.** The standalone TF32 warpgroup mainloop builds + launches but is **not yet bit-correct** (rel-RMS **1.309e+00** vs 3e-3); an isolated descriptor sweep + a structured-input diagnostic proved the binding residual is the wgmma **no-swizzle 8×16B core-matrix shared-memory layout** of the operands (NOT the instruction, descriptor offsets, or the verified-correct epilogue register→C mapping). **No own GFLOP/s is reported** — g5 forbids perf on a wrong-result kernel; **parity NOT measured**. Kit: `self/native/wgmma/`. Honest scope: parity-seeking, cuBLAS = roofline, no superiority claim.
 >
 > **↳ swizzle wedge — residual PINNED to the B-operand K-core stride, NOT a permutation (`F-FUSION-SM90-WGMMA-SWIZZLE`, closed-negative this pass).** An on-hardware reverse-engineering (distinct-ramp operand + one-hot selector; native H200 sm_90a, nvcc 12.6, pod DESTROYED leak 0) isolated the rel-RMS 1.309 residual to **two superimposed defects in the wgmma B no-swizzle core-matrix layout**: (1) a **K-stride collapse** — for contraction index k=1..7 wgmma re-reads B's K=0 core-matrix (the decoded k′ is pinned to 0 for every K-selector), the dominant ≈√2 error; (2) an **N-octet interleave** (output col n reads logical col ≈4n within an 8-wide octet). A **>2300-config exhaustive sweep** — A/B shared layout ∈ {plain row-major, two 8-row-strip core tilings, col-major-B} × descriptor (LBO,SBO) ∈ {16…512} for both operands × 3 epilogue register-maps, fault-isolated per-process — found **no config below rel-RMS 1.36**, **deterministically ruling out** the hypothesis that the residual is a plain-layout/offset/epilogue permutation. The fix **requires the genuine CUTLASS `GMMA::Layout` core-matrix builder** (B's 8 K-values forming a contiguous 8-row core-matrix, descriptor LBO = one-core-matrix stride, swizzle field matched to the TMA `cuTensorMapEncodeTiled` swizzle mode), verified FIRST on the single-tile decode probe to k′==KSEL identity before any 2048³ run. Kit: `self/native/wgmma/{wgmma_tf32_decode,wgmma_tf32_bdecode,wgmma_tf32_full}.cu`. Still **parity-seeking, no perf number on a non-bit-correct kernel (g5)**.
+>
+> **↳ GMMA::Layout core-matrix builder — wgmma TF32 is now BIT-CORRECT on native sm_90a (`F-FUSION-SM90-WGMMA-GMMA-LAYOUT`, 🟢 numerical).** The swizzle is **SOLVED**. The root cause of the >2300-config dead end was a single wrong constant: a wgmma core matrix is **8 rows × 16 bytes = for TF32 (4 B/elem) 8 rows × 4 ELEMENTS**, not the **8×8 K-strip** the prior kit assumed — that 8-vs-4 mismatch **is** both pinned defects (K-stride collapse + N-octet interleave). Implementing the real CUTLASS-3.x **GMMA INTER (no-swizzle) 8×4 core-matrix layout** (`gmma_phys = (strip*2+kcore)*32 + sr*4 + kc`, descriptor `start[0,14) LBO[16,30) SBO[32,46) layout_type[62,64)=INTERLEAVE`, LBO=128 B / SBO=256 B inter-core strides) made the **single 64×64×8 wgmma tile bit-exact** (**W2 rel-RMS 0.000e+00**, native H100 SXM cc 9.0, `-arch=sm_90a`, nvcc 12.6, pod DESTROYED leak 0). Scaling to the full **2048³** GEMM revealed a second, *separate* defect — a K-loop **async-proxy ordering** bug (`wgmma` reads shared through the async proxy, which ordinary `__syncthreads` does **not** order against generic stores; non-deterministic 3e-2…1e-1 past K≈1536). Adding **`fence.proxy.async.shared::cta`** after staging makes the K-loop **bit-exact at 2048³** (**W3 own-vs-cuBLAS-TF32 & own-vs-CPU-f64 both rel-RMS 0.000e+00, deterministic**). **Parity is now MEASURABLE** (g5 satisfied): the naive single-wgmma-per-block kernel runs **20.2 TFLOP/s @ 2048³** (cuBLAS-TF32 357.5, **17.67× off**, PARITY=NO); a first pipeline tune (wide-N **TN=128**, 2 wgmma/K-step reusing A) nearly doubles it to **38.0 TFLOP/s (9.35× off)**, still bit-exact (TN=256 is slower — register/occupancy bound). **The own-GEMM is now provably CORRECT on sm_90a; the remaining gap is a pure latency-hiding residual** — a full **warp-specialized TMA multi-stage** CUTLASS mainloop (`cp.async.bulk.tensor` producer + `wgmma` consumer, deep pipeline), a multi-session build — **NOT the layout (solved) and NOT correctness (bit-exact 2048³)**. cuBLAS = roofline, no superiority claim. Kit: `self/native/wgmma/{wgmma_tf32_gmma,wgmma_tf32_gemm2048,wgmma_tf32_gemm_w5,wgmma_tf32_gemm_w5b}.cu`.
 
 **Util is a workload-size property, not a defect** (`F-FUSION-D2-RIGHTSIZED`): the *byte-identical* D1536 own-GEMM step that under-fills an idle **H100 to ~13 % MEAN** (median 2 %) **saturates a right-sized RTX 5070 to 98.00 % MEAN** (every sample 98 %, SM 98 %, compute-bound) — the 2048³ large shape gives 99 % on the same 5070. Low util on the H100 is the H100 being too big for a D1536 model, not a codegen flaw; given a GPU sized for the workload, util is at the saturation ceiling.
 
