#!/usr/bin/env bash
# build_owngemm.sh — build + run the sm_120 TF32 own-GEMM gate+perf on aiden.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120.cu" -lcublas -o /tmp/owngemm_sm120
echo "=== gate @ D=768 ==="
/tmp/owngemm_sm120 768 0
echo "=== perf sweep ==="
for S in 768 1024 2048 4096; do /tmp/owngemm_sm120 $S 1; done
