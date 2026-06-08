#!/usr/bin/env bash
# build_owngemm_bf16.sh — build + run the sm_120 BF16 own-GEMM gate/perf/det on aiden.
# HEXA-0POD OP-3. mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32, fp32 accum.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_bf16.cu" -lcublas -o /tmp/owngemm_sm120_bf16
echo "=== gate @ D=768 (rel-RMS vs FP64) ==="
/tmp/owngemm_sm120_bf16 768 0
echo "=== determinism @ D=1024 ==="
/tmp/owngemm_sm120_bf16 1024 2
echo "=== perf vs cuBLAS-BF16 ==="
for S in 1024 2048; do /tmp/owngemm_sm120_bf16 $S 1; done
