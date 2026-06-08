#!/usr/bin/env bash
# run_bench6.sh — HEXA-BENCH BENCH-6 driver (run ON aiden, the free pool RTX 5070).
#
# Tests BENCH-3's UNTESTED attribution that flame's residual ~2x TF32 gap vs torch is
# "launch/glue/occupancy of the serial DAG, NOT GEMM." Wraps the per-step kernel
# sequence (cuBLAS-TF32 fwd GEMM -> LN/gelu valley -> transpose -> cuBLAS-TF32 bwd GEMM
# -> AdamW) in a CUDA GRAPH and measures captured step/s vs the un-captured (eager)
# baseline at B=1,2,4,8 — same shape/dtype as BENCH-3.
#
#   graph/eager > ~1.3x  => residual lived in LAUNCH overhead (graph-capture is the lever)
#   graph/eager ~ 1.0x   => cuBLAS GEMM dominates; launch is negligible; residual ~2x is
#                           GEMM-THROUGHPUT, NOT launch (honest closed-neg pinning it).
#
# GATE (g5): max|delta(W')| graph-vs-eager == 0 (bit-exact; capture changes no math) +
# run-to-run determinism == 0. Emits all [CFG]/[GRAPH]/[DETERMINISM]/[GATE]/[RESULT]/
# [SPEEDUP] lines verbatim, plus a fresh torch TF32 read for the residual-2x ratio.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
D="${D:-768}"; T="${T:-256}"; ITERS="${ITERS:-50}"
BSWEEP="${BSWEEP:-1 2 4 8}"
ARCH="${ARCH:-sm_120}"     # RTX 5070 = consumer Blackwell sm_120

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB"

echo "############ HEXA-BENCH BENCH-6 (graph-capture)  D=$D T=$T iters=$ITERS  arch=$ARCH ############"
echo "==== nvidia-smi ===="
nvidia-smi
echo "==== nvcc ===="
nvcc --version | tail -2

echo "==== build flame_bench_step_graph (cuBLAS-TF32 + CUDA-graph capture) ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -o /tmp/flame_graph_tf32 "$HERE/flame_bench_step_graph.cu" -lcublas \
  || { echo "BUILD FAIL graph"; exit 1; }
echo "build OK"

run_flame () { for B in $BSWEEP; do echo "--- flame graph-bench B=$B ---"; /tmp/flame_graph_tf32 "$D" "$T" "$B" "$ITERS"; done; }
run_torch () { local md=$1; for B in $BSWEEP; do echo "--- torch tf32 $md B=$B ---"; python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype tf32 --mode "$md" --iters "$ITERS"; done; }

echo "######## FLAME TF32 — EAGER (BENCH-3 cuBLAS baseline) vs GRAPH-CAPTURE ########"
run_flame

echo "######## TORCH TF32 (for the residual-2x ratio, same run) ########"
echo "==== torch TF32 eager ===="  ; run_torch eager
echo "==== torch TF32 compile ===="; run_torch compile
echo "############ BENCH-6 DONE ############"
