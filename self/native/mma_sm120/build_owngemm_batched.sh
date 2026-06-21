#!/usr/bin/env bash
# build_owngemm_batched.sh — build + run the sm_120 batched-strided overtake
# bench on aiden (RTX 5070). PREREQ measures stock cublasSgemmStridedBatched;
# OWN measures the batched mma.sync.m16n8k8 TF32 kernel; COMPARE = off-ratio.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
nvcc -arch=sm_120 $INC -O3 "$D/owngemm_batched_sm120.cu" -lcublas -o /tmp/owngemm_batched
echo "=== gate (rel-RMS + run-to-run byte-eq) @ S=1024 batch=8 ==="
/tmp/owngemm_batched 1024 8 0
