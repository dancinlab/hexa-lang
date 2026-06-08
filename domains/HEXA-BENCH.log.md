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
