#!/usr/bin/env bash
# RFC 067 PI -- hexa SGEMM vs cuBLAS SGEMM driver (2026-05-21).
#
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).
#
# Pipeline:
#   1. Compile host.c with nvcc -O2 -arch=sm_90 -lcuda -lcublas -lm
#   2. Fire ./host <6 PTX paths>
#   3. Capture stdout/stderr to fire.log, result.json from host.
#
# Usage: bash measure.sh

set -euo pipefail

WORKDIR="${WORKDIR:-$(pwd)}"
cd "$WORKDIR"

# --- compile ---
echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

# --- fire ---
echo "==== fire: ./host (6-shape TF32 SGEMM sweep, hexa-emit vs cuBLAS) ===="
./host \
  sgemm_256x256_grid.ptx \
  sgemm_384x384_grid.ptx \
  sgemm_512x512_grid.ptx \
  sgemm_768x768_grid.ptx \
  sgemm_1024x1024_grid.ptx \
  sgemm_1536x1536_grid.ptx \
  2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
