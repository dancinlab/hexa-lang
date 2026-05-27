#!/usr/bin/env bash
# RFC 067 PZ-spec -- WARP SPECIALIZATION (2P+2C) on N107 4-warp 64x64 baseline.
#
# Plain `ssh ubu-2` per user 2026-05-21 (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Usage:
#   bash measure.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ART_DIR_BASENAME="rfc067_pZspec_hexa_sgemm_warp_spec_2026_05_22"

echo "== STEP 0: regen PTX (idempotent) ==" >&2
python3 gen_sgemm_warp_spec_ptx.py

echo "== STEP 1: rsync to ubu-2:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh ubu-2 "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_warp_spec_ptx.py *.ptx "ubu-2:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && ./host \
    sgemm_warp_spec_256x256_grid.ptx \
    sgemm_warp_spec_384x384_grid.ptx \
    sgemm_warp_spec_512x512_grid.ptx \
    sgemm_warp_spec_768x768_grid.ptx \
    sgemm_warp_spec_1024x1024_grid.ptx \
    sgemm_warp_spec_1536x1536_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
