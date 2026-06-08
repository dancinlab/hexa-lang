#!/usr/bin/env bash
# run_bench1.sh — HEXA-BENCH BENCH-1 driver (run ON aiden, the free pool RTX 5070).
# Builds the flame .cu (FP32/TF32/FP64), runs flame + torch across a batch sweep,
# emits all [RESULT] lines verbatim for the verdict table.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
D="${D:-768}"; T="${T:-256}"; ITERS="${ITERS:-50}"
BSWEEP="${BSWEEP:-1 2 4 8}"
ARCH="${ARCH:-sm_120}"     # RTX 5070 = consumer Blackwell sm_120

echo "############ HEXA-BENCH BENCH-1  D=$D T=$T iters=$ITERS  arch=$ARCH ############"
echo "==== nvidia-smi ===="
nvidia-smi
echo "==== nvcc ===="
nvcc --version | tail -2

# ---- build flame variants ----
echo "==== build flame_bench_step (FP32 / TF32 / FP64) ===="
nvcc -arch=$ARCH -O3 -DBENCH_PREC=1            -o /tmp/flame_fp32 "$HERE/flame_bench_step.cu" || { echo "BUILD FAIL fp32"; exit 1; }
nvcc -arch=$ARCH -O3 -DBENCH_PREC=1 -DUSE_TF32 -o /tmp/flame_tf32 "$HERE/flame_bench_step.cu" || { echo "BUILD FAIL tf32"; exit 1; }
nvcc -arch=$ARCH -O3 -DBENCH_PREC=2            -o /tmp/flame_fp64 "$HERE/flame_bench_step.cu" || { echo "BUILD FAIL fp64"; exit 1; }
echo "build OK"

run_flame () { local bin=$1; for B in $BSWEEP; do echo "--- flame $bin B=$B ---"; "/tmp/$bin" "$D" "$T" "$B" "$ITERS"; done; }
run_torch () { local dt=$1 md=$2; for B in $BSWEEP; do echo "--- torch $dt $md B=$B ---"; python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype "$dt" --mode "$md" --iters "$ITERS"; done; }

echo "######## FLAME ########"
echo "==== flame FP32 ===="; run_flame flame_fp32
echo "==== flame TF32 ===="; run_flame flame_tf32
echo "==== flame FP64 ===="; run_flame flame_fp64

echo "######## TORCH ########"
echo "==== torch FP32 eager ===="   ; run_torch fp32 eager
echo "==== torch FP32 compile ===="  ; run_torch fp32 compile
echo "==== torch TF32 eager ===="   ; run_torch tf32 eager
echo "==== torch TF32 compile ===="  ; run_torch tf32 compile
echo "==== torch FP64 eager ===="   ; run_torch fp64 eager
echo "==== torch FP64 compile ===="  ; run_torch fp64 compile
echo "############ BENCH-1 DONE ############"
