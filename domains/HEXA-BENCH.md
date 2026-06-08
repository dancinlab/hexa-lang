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

- [ ] **BENCH-3 — swap the bench step naive tiled GEMM for the OG10 own-GEMM (TF32 wgmma) + re-measure** —
  BENCH-1 found the TF32 3-8x torch gap is cuBLAS-tuned-GEMM vs flame naive tiled CUDA-core kernel (not
  interpreter). hexa already HAS the OG10 own-GEMM (TF32 wgmma, ~70.7 TFLOP/s, bit-exact, 6.09x off cuBLAS).
  Wire OG10 into the bench step D->D projection (replacing the naive kernel), re-run the TF32 batch sweep on
  aiden RTX 5070 (free pool GPU, NOT vast). Gate (g5): bit-exact vs naive result + new flame/torch TF32 ratio.
  HONEST: OG10 is 6.09x off cuBLAS so it narrows but won't beat torch; measure how much 3-8x shrinks. aiden is
  consumer Blackwell sm_120 - OG10 is sm_90a wgmma; if it won't compile on sm_120 report the ISA gap + scope.

## honest framing (g5)

flame is NOT a speed-competition tool — torch will almost certainly win throughput by a large margin (#2912
~1656x @ batch=1 FP64). The bench's value is (a) a FAIR, matched-dtype, batch-swept number replacing the
single worst-case point, and (b) measuring whether TF32+batch shrinks the gap at all. flame's actual value
(byte-exact · device-resident · no-LLVM · deterministic) is orthogonal to step-rate. Free pool GPU (aiden),
no vast cost. RTX 5070 12GB may OOM FP64 D1536 — shrink config + report it.
