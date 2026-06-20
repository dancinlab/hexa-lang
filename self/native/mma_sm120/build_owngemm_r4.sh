#!/usr/bin/env bash
# build_owngemm_r4.sh — build + sweep the tf32-parity-research r4 variants on aiden.
# Lever A = Split-K (owngemm_sm120_splitk.cu), Lever B = TMA (owngemm_sm120_tma.cu).
# These are OPT-IN experimental TF32 fastmode variants; the shipped owngemm_sm120.cu
# (FP64 default path) is untouched and byteeq-NEUTRAL.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"

echo "=== build baseline (reference) ==="
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120.cu" -lcublas -o /tmp/owngemm
echo "=== build Lever A: Split-K ==="
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_splitk.cu" -lcublas -o /tmp/splitk
echo "=== build Lever B: TMA ==="
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_tma.cu" -lcublas -lcuda -o /tmp/tma

echo "=== baseline sweep ==="
for S in 256 512 768 1024 1536 2048 3072 4096; do /tmp/owngemm $S 1 | grep PERF; done

# argv: S MODE SPLITS ATOMIC   (ATOMIC=1 = atomicAdd path, no workspace)
echo "=== Lever A best-per-size (Split-K) ==="
echo "256 workspace splits=4:"; /tmp/splitk 256 1 4 0 | grep PERF
echo "1024 atomic splits=2:";   /tmp/splitk 1024 1 2 1 | grep PERF
echo "4096 workspace splits=2:";/tmp/splitk 4096 1 2 0 | grep PERF

echo "=== Lever B sweep (TMA — measured slower, kept for the record) ==="
for S in 256 1024 4096; do /tmp/tma $S 1 | grep PERF; done
