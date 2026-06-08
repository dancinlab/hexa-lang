# HEXA-BENCH — log

## 2026-06-08 — domain registered

User asked for a PyTorch-vs-flame benchmark, then pointed out the sidecar pool has GPU hosts ("pool 있다며")
+ g1 (ai-native/canonical-first) → run on the FREE pool GPU (aiden RTX 5070, 12GB, idle/util 0%, mem 2MiB),
NOT a rented vast pod (saves $ + zero leak risk). summer also has a 5070 but its GPU mem is ~11.7GB occupied,
so aiden is the host. Supersedes the single-point #2912 (~1656-2207x @ batch=1 FP64) with a fair matched-dtype
batch sweep. RTX 5070 12GB may OOM FP64 D1536 → shrink config honestly. flame value = reproducibility/no-LLVM,
not step-rate; a large torch win is expected. BENCH-1 (sweep) → BENCH-2 (scorecard). Related: F-FUSION-VS-PYTORCH
#2912, HEXA-FLAME-FAST (closed-neg), reference_megastep_research.

## 2026-06-08 — BENCH-1 + BENCH-2 DONE (aiden RTX 5070, free pool, no vast)

Ran the matched-dtype batch sweep on aiden (RTX 5070, sm_120/cc12.0, 12227 MiB, util 0%, nvidia-smi
verbatim in verdict). Config D=768/T=256 (E-experts folded into the D->D projection GEMM), iters=50,
B=1,2,4,8. flame = tool/bench/flame_bench_step.cu (CUDA-core tiled GEMM, fixed K order, atomic-free,
the fast2 FAST-2 step DAG; FP32/TF32/FP64 one source). torch = tool/bench/torch_bench_step.py
(nn.Linear+LayerNorm+gelu+AdamW, autograd bwd; eager+compile; fp32/tf32/fp64).

KEY FINDING: the #2912 "~1656x" was the full trainer's INTERPRETED per-step glue at batch=1, NOT the
compiled step. Measuring the compiled matched-dtype step the gap collapses to single digits:
  FP64 torch/flame = 0.83-1.10x (flame TIES B=2, WINS B=4/B=8 — torch FP64 has no tensor-core path;
       flame highest FP64 throughput @B=8 826 vs 745 samp/s),
  FP32 2.15-6.60x, TF32 3.03-7.88x (residual = cuBLAS/inductor tuned GEMM vs flame naive tiled).
flame determinism max|delta(W')|=0 at ALL 12 cells (byte-exact). No OOM (FP64 B=8 est 0.09 GiB << 12GB).
Honest: torch wins TF32/FP32 throughput big (29.7k samp/s @ B=8 vs flame 3.8k) — EXPECTED + fine;
flame's value = reproducibility/no-LLVM/device-resident, not step-rate. Free pool GPU, zero vast cost.
Verdict .verdicts/hexa-bench/F-BENCH-1.txt; raw 36-RESULT log tool/bench/bench1_raw.log.

## 2026-06-08 — BENCH-3 DONE — tuned/own-GEMM swap, TF32 gap re-measured (aiden, no vast)

Swapped the bench step's D->D projection GEMM (the naive tiled CUDA-core k_gemm that BENCH-2 fingered as
the cause of the TF32 3-8x gap) for a TUNED GEMM and re-ran the TF32 sweep B=1,2,4,8 on aiden.

OG10 sm_120 ISA CHECK (done FIRST, cheap): the intended own-GEMM = HEXA-FUSION OG10 (W10 TF32-wgmma,
70.7 TFLOP/s, bit-exact, self/native/wgmma/wgmma_tf32_w10.cu) is sm_90a (Hopper). Compiling it for aiden's
sm_120 FAILS at ptxas (CUDA 13.0.88, ON aiden): 'wgmma.fence / wgmma.mma_async / wgmma.commit_group /
wgmma.wait_group not supported on .target sm_120' (~22 sites). HONEST GAP: Hopper warpgroup-async MMA is
NOT in the consumer-Blackwell (sm_120) ISA — OG10-exact can't run on a 5070 without a tcgen05 port. OG10's
summit stands only on Hopper (H100). FELL BACK (plan a) to cuBLAS-TF32 (cublasGemmEx,
CUBLAS_COMPUTE_32F_FAST_TF32) as the tuned-GEMM proxy = optimistic CEILING (OG10 is 6.09x off cuBLAS, would
close LESS). One source tool/bench/flame_bench_step_og.cu, GEMM_BACKEND 0=naive/1=cuBLAS, same DAG as BENCH-1.

GATE (g5): cuBLAS rel-RMS(W' vs naive-ref) ~e-8 all B (<<1e-2 PASS); determinism max|delta(W')|=0 all cells.
RESULT — flame÷best-torch TF32 ratio: NAIVE (re-measured) 3.14/4.08/5.08/9.85x vs cuBLAS-proxy
2.20/2.25/2.07/2.85x. vs PUBLISHED BENCH-1 naive (3.03/4.08/5.54/7.88x) the tuned GEMM SHRINKS the gap by
1.38/1.82/2.67/2.77x. The naive gap GREW with batch (kernel doesn't scale with M); the tuned GEMM flattens
it to a batch-INVARIANT ~2x (biggest win at B=8 where naive was worst). flame GEMM-only speedup cuBLAS÷naive
= 1.43/1.81/2.45/3.46x. NO torch-parity regime in TF32 — residual ~2x is launch/glue/occupancy (serial DAG),
NOT GEMM; FP64 B>=4 remains flame's win regime (BENCH-1). Verdict .verdicts/hexa-bench/F-BENCH-3.txt; raw
log tool/bench/bench3_raw.log.

## 2026-06-08 — BENCH-6 graph-capture: does it cut the residual ~2x? (aiden RTX 5070, no vast)
BENCH-3 ASSERTED (untested) the residual ~2x is "launch/glue/occupancy, NOT GEMM." BENCH-6 TESTED it:
wrapped the cuBLAS-TF32 per-step DAG (fwd GEMM -> LN/gelu valley -> transpose -> bwd GEMM -> AdamW) in a CUDA
graph (BeginCapture/EndCapture -> Instantiate -> Launch; 5-8 nodes -> 1 launch) — flame_bench_step_graph.cu,
eager+graph from one binary, sm_120. GATE bit-exact graph-vs-eager max|delta(W')|=0 + determinism=0 at ALL
B (PASS). RESULT graph/eager step/s: B1 1.014 · B2 1.009 · B4 1.011 · B8 1.003 — ~1.00x, NO speedup; per-op
launch overhead is ~1% of the step wall (noise). warm eager step/s reproduce BENCH-3's cuBLAS baseline
(2281/2160/1929/1626). residual vs best-torch (4358/3595/4192/3844): 1.91/1.66/2.17/2.36x — INVARIANT under
graph capture. CONCLUSION: BENCH-3's launch attribution REFUTED; residual ~2x = GEMM-THROUGHPUT (cuBLAS algo
on sm_120 vs torch inductor; the 2 cuBLAS GEMMs dominate, elementwise+launch tiny). Lever = better GEMM, NOT
megakernel/graph-capture. Verdict .verdicts/hexa-bench/F-BENCH-6.txt.
