#!/usr/bin/env bash
# RFC 067 PH -- cuBLAS SGEMM FP32 23-shape baseline driver (2026-05-21)
#
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).
#
# Pipeline:
#   1. Compile host.c with nvcc -O2 -arch=sm_90 -lcuda -lcublas -lm
#   2. Fire ./host (no args -- shape list is built in).
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
echo "==== fire: ./host (23-shape FP32 SGEMM sweep) ===="
./host 2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
