#!/usr/bin/env bash
# build_owngemm_opt.sh — HEXA-0POD OP-1: build + sweep the sm_120 own-GEMM
# optimization variants K0..K4 on aiden (RTX 5070, cc12.0). Gate (bit-exact vs
# K0 baseline) + perf (TFLOP/s vs cuBLAS-TF32) at D={1024,2048}.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_opt.cu" -lcublas -o /tmp/owngemm_opt
echo "=== GATE (bit-exact vs K0) @ D=1024 — all kernels ==="
for KERN in 0 1 2 3 4; do /tmp/owngemm_opt 1024 0 $KERN; done
echo "=== GATE @ D=2048 — all kernels ==="
for KERN in 0 1 2 3 4; do /tmp/owngemm_opt 2048 0 $KERN; done
echo "=== PERF sweep @ D=1024 ==="
for KERN in 0 1 2 3 4; do /tmp/owngemm_opt 1024 1 $KERN; done
echo "=== PERF sweep @ D=2048 ==="
for KERN in 0 1 2 3 4; do /tmp/owngemm_opt 2048 1 $KERN; done
