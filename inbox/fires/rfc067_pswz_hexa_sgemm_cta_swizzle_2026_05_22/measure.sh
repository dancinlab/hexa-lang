#!/usr/bin/env bash
# RFC 067 PSWZ -- 4-WARP 64x64 + CTA-swizzle (2D super-block) cliff sweep.
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Goal: test whether 4x4 super-block CTA-swizzle recovers the M=6144 / M=8192
# ratio cliff seen in N130 (16.55 TFLOPS / 0.234 @ M=6144, 13.91 / 0.304 @ M=8192).
# Hypothesis: row-major CTA visitation thrashes L2 past M=4096; swizzle reuse fix.
#
# Usage:
#   bash measure.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ART_DIR_BASENAME="rfc067_pswz_hexa_sgemm_cta_swizzle_2026_05_22"

echo "== STEP 0: regen PTX (idempotent) ==" >&2
python3 gen_sgemm_4warp_swizzle_ptx.py

echo "== STEP 1: rsync to ubu-2:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh ubu-2 "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_4warp_swizzle_ptx.py *.ptx "ubu-2:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && ./host \
    sgemm_4warp_swizzle_4096x4096_grid.ptx \
    sgemm_4warp_swizzle_5120x5120_grid.ptx \
    sgemm_4warp_swizzle_6144x6144_grid.ptx \
    sgemm_4warp_swizzle_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
