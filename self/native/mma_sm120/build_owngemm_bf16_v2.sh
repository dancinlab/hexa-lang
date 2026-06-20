#!/usr/bin/env bash
# build_owngemm_bf16_v2.sh — build + run the sm_120 BF16 own-GEMM-v2 (r4) on aiden.
# r3-cublas-independence BF16 r4: packed-bf16 smem staging (L4-a) + BK=32 (L4-b).
# GATE (rel-RMS vs FP64) + determinism (max|d|=0) + perf-sweep vs cuBLAS-BF16.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_bf16_v2.cu" -lcublas -o /tmp/owngemm_sm120_bf16_v2

echo "=== gate @ D=768 (rel-RMS vs FP64) ==="
/tmp/owngemm_sm120_bf16_v2 768 0
echo "=== determinism @ 512/1024/2048 (max|d|=0) ==="
for S in 512 1024 2048; do /tmp/owngemm_sm120_bf16_v2 $S 2; done
echo "=== perf: v2 (r4) vs cuBLAS-BF16 ==="
for S in 512 1024 2048; do /tmp/owngemm_sm120_bf16_v2 $S 1; done
