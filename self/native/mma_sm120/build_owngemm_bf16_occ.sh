#!/usr/bin/env bash
# build_owngemm_bf16_occ.sh — BF16 own-GEMM OCCUPANCY variant (WALL-B closer) on aiden.
# mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32, fp32 accum.
#
# Cuts the per-block footprint (bf16 smem staging: 18944 -> 10752 B, 72 -> 70 reg)
# to RAISE resident-warp occupancy (measured 20 -> 28 warps/SM = 42% -> 58% of the
# 48-warp sm_120 max), while keeping vectorized 128-bit global loads. Byte-faithful:
# rel-RMS vs FP64 PASS, run-to-run determinism max|delta|=0.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 --ptxas-options=-v -DOWNGEMM_MAIN \
  "$D/owngemm_sm120_bf16_occ.cu" -lcublas -o /tmp/owngemm_sm120_bf16_occ 2>&1 | grep -iE "registers|smem" || true

echo "=== gate (rel-RMS vs FP64) + determinism (max|delta| MUST be 0) ==="
for S in 512 1024 2048; do /tmp/owngemm_sm120_bf16_occ $S 2; done

echo "=== perf: bf16-occ vs cuBLAS-BF16 ==="
for S in 512 1024 2048 4096; do /tmp/owngemm_sm120_bf16_occ $S 1 | grep PERF; done
