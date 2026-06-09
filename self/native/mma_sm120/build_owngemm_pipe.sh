#!/usr/bin/env bash
# build_owngemm_pipe.sh — HEXA-0POD OP-1b sweep on aiden (RTX 5070, sm_120).
# Compiles the pipe harness across the BK / STAGES / VEC lever grid and runs
# GATE (vs cuBLAS + vs FP64) + PERF (TFLOP/s + cuBLAS ratio) at D={1024,2048}.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
SRC="$D/owngemm_sm120_pipe.cu"

# config grid: "BK STAGES VEC  label"
CFGS=(
  "16 2 0  baseline(OP-1: BK16,2stg,scalar)"
  "32 2 0  L1:BK32"
  "16 3 0  L2:3stage"
  "16 2 1  L3:vec-epi"
  "32 3 0  L1+L2:BK32+3stage"
  "32 2 1  L1+L3:BK32+vec"
  "16 3 1  L2+L3:3stage+vec"
  "32 3 1  ALL:BK32+3stage+vec"
)

echo "########## OP-1b sm_120 TF32 pipeline sweep — aiden RTX 5070 ##########"
for cfg in "${CFGS[@]}"; do
  set -- $cfg
  BK=$1; ST=$2; VEC=$3; LABEL=$4
  BIN=/tmp/owngemm_pipe_${BK}_${ST}_${VEC}
  nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN -DLBK=$BK -DLSTAGES=$ST -DLVEC=$VEC \
       "$SRC" -lcublas -o "$BIN" 2>/tmp/nvcc_err_${BK}_${ST}_${VEC}.log \
    || { echo "=== $LABEL : BUILD FAIL ==="; cat /tmp/nvcc_err_${BK}_${ST}_${VEC}.log; continue; }
  echo "===== $LABEL ====="
  # gate @ 768 (bit-exact ground truth), then perf @ 1024 & 2048
  "$BIN" 768 0
  for S in 1024 2048; do "$BIN" $S 1; done
done
echo "########## sweep done ##########"
