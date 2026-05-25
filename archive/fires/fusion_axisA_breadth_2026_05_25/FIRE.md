# F-FUSION-AXISA-BREADTH — whole-program-fusion moat across the NN elementwise/norm surface

GPU.md §5f/§5a, broadening the §10 moat box (already `[x]` via F-FUSION-LAUNCH-AMORT-WALL,
PR #1028) from ONE workload to FOUR real NN operators. Each: a fused 1-kernel vs an eager
multi-launch baseline on a transformer-shaped tensor, on ubu-2 RTX 5070 ($0, local).

Pre-registered falsifier (one per workload): a single fused kernel (1 launch) beats the
eager per-op stack by >=30% wall. FALSIFIED if any workload fails to reach >=30%.

## Workloads + verdicts (all PASS)

| workload  | eager ops (launches)                  | launch ratio | HBM ratio | large %  | small %  |
|-----------|---------------------------------------|--------------|-----------|----------|----------|
| LayerNorm | reduce-mean,reduce-var,normalize,affine (4) | 4.0x   | 2.00x     | 66.2%    | 72.7%    |
| RMSNorm   | reduce-sq,normalize,scale (3)         | 3.0x         | 1.67x     | 59.5%    | 58.6%    |
| Softmax   | row-max,exp,row-sum,div (4)           | 4.0x         | 1.50x     | 65.9%    | 56.3%    |
| SwiGLU    | sigmoid,mul-gate,mul-up (3)           | 3.0x         | 2.67x     | 63.0%    | 47.8%    |

4/4 PASS in both launch-bound (small) and bandwidth-bound (large) regimes; 8/8 numeric PASS.

## Artifacts

| file | role |
|---|---|
| `<wl>_fused.ptx`   | fused single-launch kernel (smem reduction for norms; regs for swiglu) |
| `<wl>_eager.ptx`   | eager per-op kernels (HBM round-trip per op) |
| `host_<wl>.c`      | CUDA driver host — fused vs eager, 20 warmup + 200 median, f64 numeric ref |
| `result.json`      | combined per-workload per-size measured |
| `result_<wl>.json` | per-workload measured |
| `fire.log`         | verbatim timed + ptxas-clean summary |

## Method

cuLaunchKernel + cuEvent; 20 warmup + 200 timed median + std; numeric vs f64 CPU ref using the
HONEST per-row-scaled RMS rel metric (NOT naive |err|/(|want|+eps), which explodes near zero —
that was the round-3 attention false-FAIL); tol 1e-2. SERIAL timing only (nvidia-smi 0% verified
before each run). `hexa verify` (g5) is BROKEN on both ubu hosts; correctness settled via the
compiled f64-ref harness, stdout persisted verbatim in `.verdicts/fusion-axisA-<wl>/`.

## Finding

The whole-program-fusion moat is now a robust GENERAL result across N+1 = 5 workloads
(LayerNorm 66% · RMSNorm 59% · Softmax 66% · SwiGLU 63% large-regime, + launch-amort 73-76%),
not a single data point. cuBLAS/cuDNN supply tuned GEMMs but the elementwise/norm/activation
glue is exactly what fusion owns; the eager per-op stack pays a launch + HBM round-trip per op.

## Provenance / governance

- PTX hand-emitted following the `archive/fires/gpu_fusion_launch_amort_2026_05_25/fused_chain.ptx`
  elementwise + smem-reduction pattern; pure ASCII (driver-JIT ptxas rejects non-ASCII comments).
- All modules ptxas -arch=sm_90 -v clean, 0 spill. Host follows `host_fusion_launch.c`.
- No LLVM (@F f1). No C-transpile change (@F f2). CPU codegen untouched (hand-emit PTX).
