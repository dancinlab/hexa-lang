#!/usr/bin/env bash
# RFC 067 PG -- HGEMM 23-shape extension driver (2026-05-21)
#
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).
#
# Pipeline:
#   1. Compile host.c with nvcc -O2 -arch=sm_90 -lcuda -lcublas -lm
#   2. Fire ./host with all 23 PTX paths in increasing-shape order.
#   3. Capture stdout/stderr to fire.log, result.json from host.
#
# Usage: bash measure.sh

set -euo pipefail

WORKDIR="${WORKDIR:-$(pwd)}"
cd "$WORKDIR"

SHAPES=(192 256 320 384 448 512 576 640 704 768 832 896 960 1024 1088 1152 1280 1408 1536 1664 1792 1920 2048)

# --- compile ---
echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

# --- fire ---
echo "==== fire: ./host wmma_192x192_grid.ptx ... wmma_2048x2048_grid.ptx ===="
ARGS=()
for S in "${SHAPES[@]}"; do
  ARGS+=("wmma_${S}x${S}_grid.ptx")
done
./host "${ARGS[@]}" 2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
