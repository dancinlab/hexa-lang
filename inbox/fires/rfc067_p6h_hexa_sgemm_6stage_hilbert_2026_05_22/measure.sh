#!/usr/bin/env bash
# RFC 067 P6H -- 4-WARP 64x64 + 6-STAGE cp.async PIPELINE + HILBERT CTA-SWIZZLE.
#
# COMBINE N121 6-stage pipeline (small-shape win) + N149 Hilbert swizzle (large-shape win).
# Sweep BOTH regimes: M=256/384/512 (small) + M=4096/6144/8192 (large).
#
# Plain `ssh ubu-1` (NO SIDECAR_NO_POOL). Driver-JIT cuModuleLoadDataEx, pure-ASCII PTX.
#
# Usage:  bash measure.sh
# HOST = ubu-1 (parallel with ubu-2 N151/N167). Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-1}"
ART_DIR_BASENAME="rfc067_p6h_hexa_sgemm_6stage_hilbert_2026_05_22"

echo "== STEP 0: regen PTX (idempotent, bijection verified per shape) ==" >&2
python3 gen_sgemm_4warp_6stage_hilbert_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_4warp_6stage_hilbert_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ${HOST} ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && PY_HOST=${HOST} ./host \
    sgemm_4warp_6stage_hilbert_256x256_grid.ptx \
    sgemm_4warp_6stage_hilbert_384x384_grid.ptx \
    sgemm_4warp_6stage_hilbert_512x512_grid.ptx \
    sgemm_4warp_6stage_hilbert_4096x4096_grid.ptx \
    sgemm_4warp_6stage_hilbert_6144x6144_grid.ptx \
    sgemm_4warp_6stage_hilbert_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
