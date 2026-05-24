#!/usr/bin/env bash
# RFC 067 PHILB -- 4-WARP 64x64 + Hilbert-curve CTA-swizzle (Pattern B) cliff sweep.
#
# Plain `ssh ubu-1` (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Goal: follow-on to N134 (Pattern A 2D super-block 4x4). Replace the super-block
# CTA-swizzle with a Hilbert space-filling curve d2xy mapping. Headline: does Hilbert
# beat super-block at the M=6144 / M=8192 cliff (N134: 0.655 / 0.624)?
#
# Usage:
#   bash measure.sh
#
# HOST = ubu-1 (parallel with ubu-2). Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-1}"
ART_DIR_BASENAME="rfc067_philb_hexa_sgemm_hilbert_swizzle_2026_05_22"

echo "== STEP 0: regen PTX (idempotent, bijection verified per shape) ==" >&2
python3 gen_sgemm_4warp_hilbert_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_4warp_hilbert_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ${HOST} ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && PY_HOST=${HOST} ./host \
    sgemm_4warp_hilbert_4096x4096_grid.ptx \
    sgemm_4warp_hilbert_5120x5120_grid.ptx \
    sgemm_4warp_hilbert_6144x6144_grid.ptx \
    sgemm_4warp_hilbert_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
