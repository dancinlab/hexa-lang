#!/usr/bin/env bash
# RFC 067 PD -- HGEMM follow-on fire driver (2026-05-21).
#
# Executes on ubu-2 (RTX 5070 sm_120, driver 580.126.09, CUDA 12.0).
#
# Pipeline:
#   1. Compile host.c with nvcc -O2 -arch=sm_90 -lcuda -lcublas -lm
#   2. Fire ./host on 3 PTX shape variants:
#        wmma_256x256_grid.ptx (existing /home/summer/r067_perf/ baseline)
#        wmma_512x512_grid.ptx (pD shape-port 512)
#        wmma_1024x1024_grid.ptx (pD shape-port 1024)
#   3. Capture stdout/stderr to fire.log, result.json from host.
#
# All actions wrapped via `SIDECAR_NO_POOL=1` from the caller side to
# avoid wilson-pool routing the SSH command back to itself.
#
# Usage: bash measure.sh

set -euo pipefail

WORKDIR="/home/summer/r067_pD_followon"
PTX_256="/home/summer/r067_perf/wmma_256x256_grid.ptx"
PTX_384="${WORKDIR}/wmma_384x384_grid.ptx"
PTX_512="${WORKDIR}/wmma_512x512_grid.ptx"
PTX_768="${WORKDIR}/wmma_768x768_grid.ptx"
PTX_1024="${WORKDIR}/wmma_1024x1024_grid.ptx"

cd "$WORKDIR"

echo "==== compile: nvcc host.c ===="
nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

echo "==== fire: ./host \\"
echo "             ${PTX_256} \\"
echo "             ${PTX_384} \\"
echo "             ${PTX_512} \\"
echo "             ${PTX_768} \\"
echo "             ${PTX_1024}"
./host "${PTX_256}" "${PTX_384}" "${PTX_512}" "${PTX_768}" "${PTX_1024}" 2>&1 | tee fire.log

echo "==== done ===="
ls -la result.json fire.log
