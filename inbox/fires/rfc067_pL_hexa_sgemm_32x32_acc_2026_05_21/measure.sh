#!/bin/bash
# RFC 067 PL -- hand-emit hexa SGEMM with 32x32 per-warp accumulator on RTX 5070 ubu-2.
#
# Direct comparison to N66 PK 2-stage (16x16 per-warp, peak 13.35 TFLOPS @ M=1536, ratio 0.406)
# on same substrate.
set -euxo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# Regenerate PTX (idempotent) and compile host.
python3 gen_sgemm_32x32_ptx.py

nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1 | tee compile.log

./host \
    sgemm_32x32_256x256_grid.ptx \
    sgemm_32x32_384x384_grid.ptx \
    sgemm_32x32_512x512_grid.ptx \
    sgemm_32x32_768x768_grid.ptx \
    sgemm_32x32_1024x1024_grid.ptx \
    sgemm_32x32_1536x1536_grid.ptx \
    2>&1 | tee fire.log

echo "=== result.json ==="
cat result.json
