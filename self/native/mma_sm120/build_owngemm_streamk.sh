#!/usr/bin/env bash
# build_owngemm_streamk.sh — TF32 own-GEMM HYBRID Stream-K (WALL-A closer) on aiden.
# mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32, fp32 accum.
#
# Three byte-eq-safe Stream-K formulations are in the kernel:
#   MODE 1 = hybrid Stream-K (data-parallel bulk + K-split remainder + det fixup)
#   MODE 2 = determinism (run-to-run max|delta|, MUST be 0)
#   MODE 3 = persistent grid-stride data-parallel (path P, no fixup, bit-id baseline)
# All use a PINNED-order workspace reduction (NO atomics) => byte-eq.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_streamk.cu" -lcublas -o /tmp/owngemm_sm120_streamk

echo "=== determinism (byte-eq: run-to-run max|delta| MUST be 0) ==="
for S in 512 1024 2048 3072; do /tmp/owngemm_sm120_streamk $S 2 | grep -E "GATE|DET"; done

echo "=== perf: hybrid Stream-K vs cuBLAS-TF32 ==="
for S in 512 1024 2048 3072; do /tmp/owngemm_sm120_streamk $S 1 | grep PERF; done

echo "=== perf: persistent grid-stride (path P) vs cuBLAS-TF32 ==="
for S in 512 1024 2048 3072; do /tmp/owngemm_sm120_streamk $S 3 | grep PERSIST; done
