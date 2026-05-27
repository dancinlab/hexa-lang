#!/usr/bin/env bash
# RFC 067 PCOND -- 4-WARP 64x64 + CONDITIONAL CTA-swizzle (identity small-M, Hilbert large-M).
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Single "best everywhere" kernel: at kernel entry, branch on grid CTA count
# (gridDim.x*gridDim.y) -- uniform, no warp divergence -- identity at small M
# (no Hilbert prologue penalty), Hilbert d2xy at large M (L2 cliff recovery).
#
# Usage:  bash measure.sh
# HOST = ubu-2. Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-2}"
ART_DIR_BASENAME="rfc067_pcond_hexa_sgemm_conditional_swizzle_2026_05_22"

echo "== STEP 0: regen PTX (idempotent, Hilbert bijection verified per shape) ==" >&2
python3 gen_sgemm_4warp_conditional_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_4warp_conditional_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ${HOST} ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && PY_HOST=${HOST} ./host \
    sgemm_4warp_cond_256x256_grid.ptx \
    sgemm_4warp_cond_384x384_grid.ptx \
    sgemm_4warp_cond_512x512_grid.ptx \
    sgemm_4warp_cond_1024x1024_grid.ptx \
    sgemm_4warp_cond_2048x2048_grid.ptx \
    sgemm_4warp_cond_4096x4096_grid.ptx \
    sgemm_4warp_cond_6144x6144_grid.ptx \
    sgemm_4warp_cond_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
