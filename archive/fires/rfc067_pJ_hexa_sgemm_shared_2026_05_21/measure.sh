#!/usr/bin/env bash
# RFC 067 PJ -- hexa-emit SGEMM + shared-mem prefetch vs cuBLAS SGEMM.
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).

set -euo pipefail

WORKDIR="${WORKDIR:-$(pwd)}"
cd "$WORKDIR"

echo "==== generate PTX ===="
python3 gen_sgemm_shared_ptx.py

echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

echo "==== fire: ./host (6-shape sweep, hexa-shared vs cuBLAS) ===="
./host \
  sgemm_shared_256x256_grid.ptx \
  sgemm_shared_384x384_grid.ptx \
  sgemm_shared_512x512_grid.ptx \
  sgemm_shared_768x768_grid.ptx \
  sgemm_shared_1024x1024_grid.ptx \
  sgemm_shared_1536x1536_grid.ptx \
  2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
