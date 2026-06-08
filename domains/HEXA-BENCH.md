# HEXA-BENCH

@title: 🏁 HEXA-BENCH — flame vs PyTorch 정직 벤치마크

@goal: Honest head-to-head: flame CLMConvMoE train step vs PyTorch (eager + compile) across a batch
sweep at matched dtype, on the FREE pool GPU (aiden RTX 5070) — NOT a rented vast pod (g1 canonical-first).
Supersedes the single-point #2912 (batch=1 FP64, ~1656-2207x slower) with a fair curve: same shape, matched
dtype (TF32 — flame now has the FAST-2 TF32 path), throughput (samples/s) not just step/s. The point is an
HONEST scorecard of where flame stands + whether TF32/batch narrows the gap — flame's value is byte-exact/
no-LLVM/reproducible, NOT step-rate, so a large gap is EXPECTED and fine.

## milestones

- [x] **BENCH-1 — matched-config batch sweep on aiden RTX 5070 (free pool GPU)** — DONE 2026-06-08
  (.verdicts/hexa-bench/F-BENCH-1.txt). Config D=768/T=256, B=1,2,4,8, flame FP32/TF32/FP64 vs torch
  eager+compile, same dtype. No OOM (FP64 B=8 est 0.09 GiB << 12GB). flame determinism max|delta|=0 ALL
  cells. Raw 36 [RESULT] lines + nvidia-smi (RTX 5070) verbatim in the verdict. Free pool GPU, zero vast.
- [x] **BENCH-2 — honest scorecard + gap analysis** — DONE (same run). The #2912 ~1656x was the full
  trainer's INTERPRETED per-step glue at batch=1, NOT the compiled step. Measuring the compiled matched-dtype
  step, the gap collapses to SINGLE DIGITS: FP64 0.83-1.10x (flame TIES B=2, WINS B>=4 — torch has no FP64
  tensor-core path), FP32 2.15-6.60x, TF32 3.03-7.88x (torch's cuBLAS GEMM vs flame's naive tiled kernel).
  Least-far-behind regime = FP64 B>=2 where flame is AHEAD. flame's edge = reproducibility/no-LLVM; torch's
  = raw TF32 throughput (29.7k samp/s @ B=8 vs flame 3.8k). Honest: a large torch TF32 win is EXPECTED + fine.
- [x] **BENCH-3 — tuned/own-GEMM swap, re-measure the TF32 gap** — DONE 2026-06-08
  (.verdicts/hexa-bench/F-BENCH-3.txt). Swapped the bench step's D->D projection GEMM (naive tiled CUDA-core
  k_gemm) for a TUNED GEMM and re-ran the TF32 sweep on aiden. ISA FINDING: the intended OG10 (HEXA-FUSION
  W10 TF32-wgmma own-GEMM) is sm_90a (Hopper wgmma.mma_async/fence/commit/wait) — ptxas REJECTS it for
  aiden's sm_120 consumer-Blackwell ISA (Hopper warpgroup-async MMA not in the sm_120 ISA; OG10-exact can't
  run without a port). FELL BACK to cuBLAS-TF32 (COMPUTE_32F_FAST_TF32) as the tuned-GEMM proxy (= optimistic
  ceiling; OG10 is 6.09x off cuBLAS so would close LESS). GATE rel-RMS vs naive ~e-8 (<<1e-2), determinism
  max|delta|=0 all cells. RESULT: the tuned GEMM shrinks the BENCH-1 naive gap from a batch-GROWING 3.03x@B1
  -> 7.88x@B8 down to a near batch-INVARIANT ~2.0-2.9x (2.20/2.25/2.07/2.85x; up to 2.77x shrink @B8). NO
  torch-parity regime in TF32 (residual ~2x = launch/glue/occupancy, not GEMM); FP64 B>=4 stays flame's win.
<!-- BENCH-6-ANCHOR (do not remove; BENCH-6 appends here to avoid colliding with parallel BENCH-4/5) -->
- [x] **BENCH-6 — CUDA-graph capture on the bench step: does it cut the residual ~2x?** — DONE 2026-06-08
  (.verdicts/hexa-bench/F-BENCH-6.txt). CLOSED-NEGATIVE (honest, productive). Wrapped the BENCH-3 cuBLAS-TF32
  per-step DAG (fwd GEMM -> LN/gelu valley -> transpose -> bwd GEMM -> AdamW) in a CUDA graph
  (cudaStreamBeginCapture/EndCapture -> cudaGraphInstantiate -> cudaGraphLaunch; 5-8 nodes replay as ONE
  launch) and measured captured vs un-captured (eager) step/s at B=1,2,4,8 on aiden (free pool RTX 5070, no
  vast). RESULT: graph/eager = 0.98-1.01x at EVERY B (NO speedup; per-op launch overhead is ~1% of the step
  wall, in the noise). GATE bit-exact graph-vs-eager max|delta(W')|=0 + determinism=0 all cells. So the
  residual ~2.0-2.4x vs torch is UNCHANGED by graph capture => it is NOT launch/glue/occupancy. This REFUTES
  BENCH-3's asserted launch attribution and PINS the residual to GEMM-THROUGHPUT (cuBLAS-TF32 algo-selection
  on sm_120 vs torch's inductor-tuned GEMM; the two cuBLAS GEMMs dominate the step, elementwise+launch are
  tiny). Lever to close it = a better-tuned own/cuBLAS GEMM for this shape, NOT megakernel/graph-capture.

- [x] **BENCH-5 — port the OG10 own-GEMM from sm_90a (Hopper wgmma) to sm_120 (consumer Blackwell) so flame's
  own-GEMM RUNS on the free consumer card** — DONE 2026-06-08 (.verdicts/hexa-bench/F-BENCH-5.txt). ISA PROBE
  on aiden CUDA13.0.88: mma.sync.m16n8k8.tf32 = ACCEPTED (portable warp MMA, the path that works), tcgen05 =
  mnemonic KNOWN to ptxas but needs the full Blackwell tmem protocol (deferred), wgmma (Hopper) = REJECTED
  (re-confirms BENCH-3 ISA gap). Built a TF32 own-GEMM for sm_120 (self/native/mma_sm120/owngemm_sm120.cu,
  OG10 tile-spirit on mma.sync) — GATE rel-RMS 1.3e-5..7e-5 vs cuBLAS-TF32 (<<1e-2) ALL shapes, ~4.9-8.1
  TFLOP/s standalone (3.2-6.9x off cuBLAS, like OG10's 6.09x on Hopper). Wired as flame_bench_step_og.cu
  -DGEMM_BACKEND=3 (OWN120-mma.sync), re-ran TF32 sweep vs naive/cuBLAS/torch on aiden. RESULT: own-GEMM-on-
  consumer-card NARROWS the naive gap 3.06-9.67x -> 2.81-4.73x (up to 2.04x shrink @B8, kills the naive batch-
  scaling blowup) and sits BETWEEN naive and the cuBLAS-proxy ceiling (2.15-2.79x) — does NOT reach cuBLAS,
  no torch-parity in TF32. WIN = flame's own-GEMM now RUNS+correct on sm_120 (BENCH-3 ISA-gap weakness REMOVED),
  not beating torch. Determinism max|delta|=0 all cells. Free pool GPU (aiden), zero vast, no leak.

<!-- ANCHOR:BENCH-4 (unique — parallel BENCH-5/6 append at their own anchors) -->
- [ ] **BENCH-4 — measure the REAL OG10 own-GEMM on a true H100 (replace BENCH-3's cuBLAS proxy)** —
  WIP. BENCH-3 had to PROXY OG10 with cuBLAS-TF32 because aiden's sm_120 rejects the Hopper wgmma ISA. BENCH-4
  rents ONE real H100 (vast, sm_90a — paid, justified: OG10 is Hopper-only) and runs the SAME bench step with
  the ACTUAL OG10 own-GEMM (W10 TF32-wgmma, self/native/wgmma/wgmma_tf32_w10_lib.h) wired as the D->D GEMM.
  3-way: NAIVE (BENCH-1) vs real OG10 (this) vs cuBLAS proxy (BENCH-3) vs torch. Gate (g5): bit-exact /
  rel-RMS<=1e-2 vs naive ref. HONEST: OG10 is 6.09x off cuBLAS so it should land BETWEEN naive and proxy
  (close the 3-8x naive gap but LESS than the proxy's ~2x). Also re-confirm the FP64 flame-win regime on H100.
<!-- /ANCHOR:BENCH-4 -->

## honest framing (g5)

flame is NOT a speed-competition tool — torch will almost certainly win throughput by a large margin (#2912
~1656x @ batch=1 FP64). The bench's value is (a) a FAIR, matched-dtype, batch-swept number replacing the
single worst-case point, and (b) measuring whether TF32+batch shrinks the gap at all. flame's actual value
(byte-exact · device-resident · no-LLVM · deterministic) is orthogonal to step-rate. Free pool GPU (aiden),
no vast cost. RTX 5070 12GB may OOM FP64 D1536 — shrink config + report it.
