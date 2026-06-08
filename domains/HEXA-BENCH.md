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
- [ ] **BENCH-6 — CUDA-graph capture on the bench step: does it cut the residual ~2x?** — WIP
  (.verdicts/hexa-bench/F-BENCH-6.txt). BENCH-3 ATTRIBUTED (untested) the residual ~2x TF32 gap to
  "launch/glue/occupancy of the serial DAG, NOT GEMM." BENCH-6 TESTS it: wraps the per-step kernel
  sequence (cuBLAS-TF32 fwd GEMM -> LN/gelu valley -> transpose -> cuBLAS-TF32 bwd GEMM -> AdamW) in a
  CUDA graph (cudaStreamBeginCapture/EndCapture -> cudaGraphInstantiate -> cudaGraphLaunch), replays the
  whole step as ONE launch, measures captured step/s vs the un-captured (eager) baseline at B=1,2,4,8 on
  aiden (free pool RTX 5070, no vast). GATE (g5): max|delta(W')| graph-vs-eager == 0 (capture changes no
  math) + run-to-run determinism == 0. Resolves WHERE the residual ~2x lives: graph/eager >~1.3x => launch
  overhead is the lever; graph/eager ~1.0x => cuBLAS GEMM dominates, residual is GEMM-THROUGHPUT not launch.

## honest framing (g5)

flame is NOT a speed-competition tool — torch will almost certainly win throughput by a large margin (#2912
~1656x @ batch=1 FP64). The bench's value is (a) a FAIR, matched-dtype, batch-swept number replacing the
single worst-case point, and (b) measuring whether TF32+batch shrinks the gap at all. flame's actual value
(byte-exact · device-resident · no-LLVM · deterministic) is orthogonal to step-rate. Free pool GPU (aiden),
no vast cost. RTX 5070 12GB may OOM FP64 D1536 — shrink config + report it.
