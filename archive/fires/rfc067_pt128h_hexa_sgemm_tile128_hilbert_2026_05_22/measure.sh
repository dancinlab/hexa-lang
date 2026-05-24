#!/usr/bin/env bash
# RFC 067 PT128H -- 128x128 output tile (N89 PS) + Hilbert CTA-swizzle (N149 PHILB) cliff sweep.
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Goal: combine N89's 128x128 output tile with N149's Hilbert CTA-swizzle. Headline:
# does 128x128 + Hilbert beat 64x64 + Hilbert (N149) at M=8192 (ratio 0.847)?
#
# Usage:
#   bash measure.sh
#
# HOST = ubu-2 (RTX 5070 sm_120). Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-2}"
ART_DIR_BASENAME="rfc067_pt128h_hexa_sgemm_tile128_hilbert_2026_05_22"

echo "== STEP 0: regen PTX (idempotent, bijection verified per shape) ==" >&2
python3 gen_sgemm_tile128_hilbert_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_tile128_hilbert_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ${HOST} ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && PY_HOST=${HOST} ./host \
    sgemm_tile128_hilbert_4096x4096_grid.ptx \
    sgemm_tile128_hilbert_5120x5120_grid.ptx \
    sgemm_tile128_hilbert_6144x6144_grid.ptx \
    sgemm_tile128_hilbert_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
