#!/usr/bin/env bash
# RFC 067 PK -- hexa-emit SGEMM + 2-stage cp.async pipeline vs cuBLAS SGEMM.
# Executes on ubu-2 (RTX 5070 sm_120) or RunPod Blackwell sm_120 substitute.

set -euo pipefail

WORKDIR="${WORKDIR:-$(pwd)}"
cd "$WORKDIR"

echo "==== generate PTX ===="
python3 gen_sgemm_multistage_ptx.py

echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

echo "==== fire: ./host (6-shape sweep, hexa-multistage vs cuBLAS) ===="
./host \
  sgemm_multistage_256x256_grid.ptx \
  sgemm_multistage_384x384_grid.ptx \
  sgemm_multistage_512x512_grid.ptx \
  sgemm_multistage_768x768_grid.ptx \
  sgemm_multistage_1024x1024_grid.ptx \
  sgemm_multistage_1536x1536_grid.ptx \
  2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
