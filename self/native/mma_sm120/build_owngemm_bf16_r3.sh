#!/usr/bin/env bash
# build_owngemm_bf16_r3.sh — build + run the WingEdge sm_120 BF16 parity recipe on aiden.
# fleet-lab bf16-r3. mma m16n8k16.f32.bf16.bf16.f32, fp32 accum, 128x128x32 tile,
# ldmatrix.x4 frag loads, 128B XOR swizzle, 2-stage pipeline.
set -eu
# use the REAL nvcc (cudafe++ PATH fix from memory: /usr/local/bin/nvcc cannot find cudafe++)
export PATH=/usr/local/cuda-13.0/bin:/usr/local/cuda/bin:$PATH
NVCC="$(command -v /usr/local/cuda-13.0/bin/nvcc || command -v /usr/local/cuda/bin/nvcc || command -v nvcc)"
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"

echo "=== build r3 (128x128x32, ldmatrix.x4, XOR-swizzle, 2-stage) ==="
"$NVCC" -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_bf16_r3.cu" -lcublas -o /tmp/owngemm_sm120_bf16_r3

echo "=== gate @ D=768 (rel-RMS vs FP64) ==="
/tmp/owngemm_sm120_bf16_r3 768 0
echo "=== determinism @ D=1024 (run-to-run max|delta| must be 0) ==="
/tmp/owngemm_sm120_bf16_r3 1024 2

echo "=== perf: r3 vs cuBLAS-BF16 @ 512/1024/2048/4096 ==="
for S in 512 1024 2048 4096; do /tmp/owngemm_sm120_bf16_r3 $S 1; done
