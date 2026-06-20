#!/usr/bin/env bash
# build_owngemm_multi.sh — tf32-parity-research r2 lever sweep on aiden (RTX 5070, sm_120).
# Incrementally measures LEVER1 (multi-tile+dispatch), LEVER2 (deeper cp.async on
# the 128x128 tile), LEVER3 (XOR smem swizzle). Gate (rel-RMS vs cuBLAS) + PERF
# (TFLOP/s + cuBLAS ratio) across the full r1 size sweep.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
SRC="$D/owngemm_sm120_multi.cu"
SIZES="256 512 768 1024 1536 2048 3072 4096"

# config grid: "BIG DEEP SWZ  label"  (r2b: swizzle+deeppipe falsified-closed in r2a;
# now compare big-tile shape 128x128 vs 128x64 at 2-stage + the dispatch threshold)
CFGS=(
  "128 2 0  BIG128x128,2stage"
  "64  2 0  BIG128x64,2stage"
)

echo "########## tf32-parity-research r2b big-tile shape sweep — aiden RTX 5070 sm_120 ##########"
for cfg in "${CFGS[@]}"; do
  set -- $cfg
  BIG=$1; DEEP=$2; SWZ=$3; LABEL=$4
  BIN=/tmp/owngemm_multi_${BIG}_${DEEP}_${SWZ}
  if ! nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN -DBIG=$BIG -DDEEP=$DEEP -DSWZ=$SWZ \
       "$SRC" -lcublas -o "$BIN" 2>/tmp/nvcc_multi_${BIG}_${DEEP}_${SWZ}.log; then
    echo "===== $LABEL : BUILD FAIL ====="; cat /tmp/nvcc_multi_${BIG}_${DEEP}_${SWZ}.log; continue
  fi
  echo "===== $LABEL ====="
  for S in $SIZES; do "$BIN" $S 1; done
done
echo "########## sweep done ##########"
