#!/usr/bin/env bash
# RFC 067 PC -- HGEMM scale-up matrix re-fire driver (2026-05-21)
#
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).
#
# Pipeline:
#   1. Compile host.c with nvcc -O2 -arch=sm_90 -lcuda -lcublas -lm
#   2. Fire ./host /home/summer/r067_perf/wmma_256x256_grid.ptx
#      (the existing PR #214 composite kernel staged on ubu-2)
#   3. Capture stdout/stderr to fire.log, result.json from host.
#
# All actions wrapped via `SIDECAR_NO_POOL=1` from the caller side to
# avoid wilson-pool routing the SSH command back to itself.
#
# Usage: bash measure.sh

set -euo pipefail

WORKDIR="/home/summer/r067_pC_scaleup"
PTX_PATH="/home/summer/r067_perf/wmma_256x256_grid.ptx"

cd "$WORKDIR"

# --- compile ---
echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

# --- fire ---
echo "==== fire: ./host $PTX_PATH ===="
./host "$PTX_PATH" 2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
