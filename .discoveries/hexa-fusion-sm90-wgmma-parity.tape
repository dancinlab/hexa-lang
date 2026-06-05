# discovery: hexa-fusion-sm90-wgmma-parity
# id: F-FUSION-SM90-WGMMA-PARITY
# seed: native sm_90(a) H100 own-GEMM forge parity vs cuBLAS (~340 TFLOP/s).
#       NOT an impossibility verdict — the silicon demonstrably reaches peak via
#       wgmma+TMA (cuBLAS proves it); the residual is a known CUTLASS layout builder.
# verdict-tier-target: 🟢 numerical (bit-correct rel-RMS<=3e-3 → own GFLOP/s + ratio vs cuBLAS)
#
# === STATE (2026-06-06, after 4 honest-negative GPU passes) ===
#   ladder: 30.4x (parent WMMA2 software-TF32)
#         → 29.4x (mma.sync cuBLAS-mainloop, bit-exact #2805)  [mma.sync CEILING — ruled out]
#         → wgmma.mma_async + TMA FEASIBLE on sm_90a (#2808): builds + runs, f16 probe correct,
#           cuTensorMapEncodeTiled + cp.async.bulk.tensor + mbarrier all compile.
#           ⇒ own-source EMIT PATH is NOT the blocker (confirmed).
#         → wgmma bit-correctness BLOCKED (#2812): full-GEMM rel-RMS 1.309. >2300-config sweep
#           (layout × desc LBO/SBO × epilogue) found nothing <1.36 ⇒ plain-layout/offset/epilogue
#           permutation DETERMINISTICALLY RULED OUT. Residual pinned to two defects in the wgmma B
#           no-swizzle core-matrix layout:
#             (1) K-stride collapse — k=1..7 re-reads B's K=0 core-matrix (dominant ~sqrt(2) error)
#             (2) N-octet interleave — output col n reads logical col ~4n within an 8-wide octet
#
# === CLOSED-NEGATIVE (ruled out, do not re-attempt) ===
#   - mma.sync reaching parity (29x ceiling, deterministic)
#   - plain row/col-major + descriptor LBO/SBO offset + epilogue-permutation swizzle (>2300 sweep)
#   - own-GEMM cuBLAS-PARITY on sm_90 is Blackwell-only ONLY via the shortcuts above (NOT the axis)
#
# === OPEN — REGISTERED MILESTONES (the named-residual ladder; fold into HEXA-FUSION.md) ===
#   W1  wgmma GMMA::Layout B-core-matrix builder  ★headline next-cycle claim
#        implement the real CUTLASS-3.x GMMA::Layout core-matrix builder: B's 8 K-values
#        CONTIGUOUS, descriptor LBO = one-core-matrix stride, swizzle mode MATCHED to the TMA
#        tensor-map. Fixes defects (1)+(2). multi-session CUTLASS engineering, NOT impossibility.
#   W2  single-tile identity verify  (k'==KSEL identity probe rel-RMS 0 BEFORE scaling — verify-first gate)
#   W3  full wgmma+TMA GEMM bit-correct  (rel-RMS <= 3e-3 on 2048^3 — the gate to perf measurement)
#   W4  sm_90 parity measure  (own GFLOP/s + ratio vs cuBLAS ~340 → parity verdict)
#        PREDICTION (g5, not measured): first-correct ~150-250 TFLOP/s = ~1.4-2.3x off = near-parity;
#        strict <=1.3x likely needs W5.
#   W5  pipeline tune (if W4 sub-parity)  (stage depth / tile size / warp-specialization → near→strict parity)
#
# === ARTIFACTS ===
#   kit: self/native/wgmma/{wgmma_tf32_decode,_bdecode,_full,_swz}.cu + sweep_fast.sh
#   verdicts: .verdicts/hexa-fusion/F-FUSION-SM90-{CUBLAS-MAINLOOP,WGMMA-TMA,WGMMA-SWIZZLE}.txt
#   PRs: #2805 (mma.sync mainloop) · #2808 (wgmma+TMA feasibility, MERGED) · #2812 (wgmma swizzle)
#   handoffs: 2e4438a7 reply chain (b0e080f6 / c071b080 / 27357108)
#
# next-cycle claim: W1 (GMMA::Layout B-core-matrix builder) — concrete, scoped, GPU sm_90a,
#   verify-first via W2 single-tile identity. Resume gated on a fresh budget (cost-bearing, multi-session).
#   STOP reason = cost/effort (4 passes + vast-reclaim storm), NOT a 불가/impossibility verdict.

# ============================================================================
# === UPDATE 2026-06-06 — W2/W3/W4 RESOLVED (bit-exact) + W5/warpspec measured
# ============================================================================
# Branch domain/hexa-fusion-sm90-wgmma-warpspec (#2819 landed bit-exact on main):
#   W1 GMMA::Layout INTER 8x4-core TF32 builder + fence.proxy.async.shared → DONE (rel-RMS 0 @ 2048^3)
#   W2 single-tile identity → DONE   W3 full GEMM bit-correct → DONE (rel_rms 0)   W4 measure → DONE
#   => the W1 "B-core-matrix builder" residual (K-stride collapse + N-octet) is FULLY RESOLVED.
#      own-source wgmma+TMA is BIT-EXACT. NOT impossibility — it was a layout-builder, now built.
#
# W5 PIPELINE TUNE (this pass, verdict F-FUSION-SM90-WGMMA-WARPSPEC.txt, H100 sm_90a):
#   baseline W5 synchronous TN=128 = 38.0 TFLOP/s = 9.35x off cuBLAS-TF32.
#   lever 2 (cp.async async-pipe ring) = 50.7 TFLOP/s BIT-EXACT (rel_rms 0) = +33% = ratio 8.39x.
#       ~11.5% of the 9.35x gap closed. NST 2..5 saturates → ring depth is NOT the wall.
#   lever 1 (warp specialization, producer/consumer mbarrier ring) = first pass FALSIFIED
#       (rel_rms ~0.70; g5 gate emitted no perf). ROOT CAUSE: producer permute read sibling-written
#       Braw without a warpgroup bar.sync (cp.async.wait_group is per-thread). FIXED → rel_rms 0,
#       but 35.0 TFLOP/s = SLOWER than lever 2 at TM=64 (single consumer WG starves the tensor cores).
#
# === NEW NAMED RESIDUAL (next-cycle claim) ===
#   W6  TM=128 dual-consumer-warpgroup warp-spec  ★the real big lever once the tile is wide enough.
#        warp-spec at TM=64 starves compute (1 consumer WG); widen to TM≥128 with ≥2 consumer WGs +
#        register-blocked accumulation so BOTH consumer WGs issue wgmma while 1 WG produces. Predict
#        this is where warp-spec overtakes the async-pipe toward parity. Lever 3+4 (epilogue) follow.
#   STOP reason = honest tile-size residual + pod budget, NOT impossibility. own wgmma+TMA bit-exact;
#   remaining 8.39x is OCCUPANCY/TILE-SIZE bound (cuBLAS proves the silicon reaches peak).
#
# verdict: .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-WARPSPEC.txt (verbatim sweep, pod destroyed leak 0)

# ============================================================================
# === UPDATE 2026-06-06 — W7 dual-consumer-WG warpspec MEASURED (CLOSED-NEGATIVE)
# ============================================================================
# Branch domain/hexa-fusion-sm90-wgmma-warpspec, kernel MODE 3 = gemm_ws2.
# H100 sm_90a (vast 39651872, DESTROYED leak 0), nvcc 12.5.82, verdict
# .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W7.txt (verbatim sweep).
#
# W7 LEVER BUILT: dual-consumer-warpgroup warp-spec. 384 thr = 3 WG. WG0 producer
#   cp.async-loads FULL A 128x8 (two gmma bands As0/As1) + B 8x128 into the NST ring;
#   WG1+WG2 = 2 consumer warpgroups each wgmma over its 64-row band x the SHARED B
#   tile (loaded ONCE). mbarrier full[](prod arrives 128)/empty[](both consumers 256).
#
# RESULT: BIT-EXACT (rel_rms=0, S=2048/4096, NST=2..5) — the dual-consumer mainloop
#   is CORRECT. But SLOWER: 32.0 TFLOP/s @ S=4096 (ratio 13.2x) vs MODE 1 async-pipe
#   50.7 (8.39x) and even vs MODE 2 single-consumer 35.0. W7 hypothesis FALSIFIED.
#
# ROOT CAUSE (on-pod cudaOccupancyMaxActiveBlocksPerMultiprocessor):
#   apipe(128t) = 4 blk/SM = 512 ALL-compute thr/SM.
#   ws2(384t)   = 1 blk/SM (REGISTER-bound: 90 regs * 384 = 34560/CTA; 2 CTAs=69120 > 65536
#     regs/SM), of which 1/3 (the cp.async producer WG) issue ZERO wgmma -> 256 compute
#     thr/SM = HALF the apipe occupancy. NOT shared-mem bound (24KB << 233KB/SM).
#   => a 128-thread cp.async producer WG is the WRONG production engine for sm_90a warp-spec.
#
# === NEW NAMED RESIDUAL (next-cycle claim) ===
#   W8  TMA-DRIVEN production: cp.async.bulk.tensor + a SINGLE elected producer thread
#       (freeing the other 127) so a dual/quad-consumer-WG warp-spec keeps FULL compute
#       occupancy. This is how cuBLAS reaches sm_90a peak — producer is HARDWARE TMA, not
#       a 128-thread cp.async WG. Bring-over the W6 TMA kit (self/native/wgmma/wgmma_tma_gemm.cu).
#   STOP reason = honest occupancy/production-engine wall, NOT impossibility. own wgmma bit-exact;
#   frontier kernel remains MODE 1 async-pipe (50.7, 8.39x) until the TMA producer lands.
