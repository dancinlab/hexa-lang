#!/usr/bin/env bash
# run_bench5.sh — HEXA-BENCH BENCH-5: TF32 batch sweep with the sm_120 own-GEMM
# (mma.sync m16n8k8) wired into the flame bench step, vs naive, vs cuBLAS-proxy,
# vs torch. Run ON aiden (RTX 5070 / sm_120 / CUDA 13.0.88). FREE pool, no vast.
#
# Files expected alongside (copied to ~/bench5/):
#   flame_bench_step_og.cu   owngemm_sm120.cu   torch_bench_step.py
set -u
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D=~/bench5
ARCH=sm_120
echo "=== BENCH-5  arch=$ARCH  $(nvcc --version|grep release) ==="
nvidia-smi --query-gpu=name,compute_cap,utilization.gpu,memory.used --format=csv,noheader

# Build the three flame backends (TF32 lane): 0 naive, 1 cuBLAS-proxy, 3 OWN120.
nvcc -arch=$ARCH $INC -O3 -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=0 \
     $D/flame_bench_step_og.cu -lcublas -o /tmp/bench5_naive  2>&1 | sed 's/^/[naive ] /'
nvcc -arch=$ARCH $INC -O3 -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=1 \
     $D/flame_bench_step_og.cu -lcublas -o /tmp/bench5_cublas 2>&1 | sed 's/^/[cublas] /'
# OWN120 links owngemm_sm120.cu (its main is guarded by OWNGEMM_MAIN, not set here).
nvcc -arch=$ARCH $INC -O3 -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=3 \
     $D/flame_bench_step_og.cu $D/owngemm_sm120.cu -lcublas -o /tmp/bench5_own 2>&1 | sed 's/^/[own120] /'

echo "=== flame TF32 sweep (D=768 T=256, B=1,2,4,8) ==="
for B in 1 2 4 8; do
  /tmp/bench5_naive  768 256 $B 50
  /tmp/bench5_cublas 768 256 $B 50
  /tmp/bench5_own    768 256 $B 50
done

echo "=== torch TF32 sweep ==="
PY=$(command -v python3)
for B in 1 2 4 8; do
  for M in eager compile; do
    $PY $D/torch_bench_step.py --D 768 --T 256 --B $B --dtype tf32 --mode $M --iters 50 2>/dev/null | grep RESULT
  done
done
