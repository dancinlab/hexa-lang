#!/usr/bin/env bash
# build_probe.sh — BENCH-5 ISA probe driver. Compiles probe_mma_sm120.cu once per
# candidate MMA family for -arch=sm_120 and reports which ptxas ACCEPTS.
# Run ON aiden (RTX 5070 / CUDA 13.0.88). Needs the cuda PATH + include set.
set -u
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
SRC="$(dirname "$0")/probe_mma_sm120.cu"
ARCH=sm_120
echo "=== BENCH-5 ISA PROBE  arch=$ARCH  $(nvcc --version | grep release) ==="
for MAC in TRY_MMA_SYNC TRY_TCGEN05 TRY_WGMMA; do
  out=$(nvcc -arch=$ARCH $INC -D$MAC "$SRC" -o /tmp/probe_$MAC 2>&1)
  if [ $? -eq 0 ]; then
    echo "[$MAC] ACCEPTED  (ptxas emitted SASS for $ARCH)"
  else
    echo "[$MAC] REJECTED"
    echo "$out" | grep -iE 'not supported|error|ptxas|unrecognized|invalid' | head -4 | sed 's/^/    /'
  fi
done
