#!/usr/bin/env bash
# RFC 067 PR -- STACK N77 ldmatrix HGEMM + cp.async.cg vec16 + K-UNROLL 2x.
#
# Plain `ssh ubu-2` per user 2026-05-21 (NO SIDECAR_NO_POOL).
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Usage:
#   bash measure.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ART_DIR_BASENAME="rfc067_pR_hexa_sgemm_kunroll_2026_05_21"

echo "== STEP 0: regen PTX (idempotent) ==" >&2
python3 gen_sgemm_kunroll_ptx.py

echo "== STEP 1: rsync to ubu-2:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh ubu-2 "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_kunroll_ptx.py *.ptx "ubu-2:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 2b: capture ptxas info (sm_90 standalone) ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && rm -f ptxas_info.log && for p in sgemm_kunroll_*_grid.ptx; do \
    echo \"==== \$p ====\"; \
    ptxas -arch=sm_90 -v -o /dev/null \$p 2>&1 || echo \"(ptxas standalone failed for \$p)\"; \
done > ptxas_info.log 2>&1; cat ptxas_info.log"

echo "== STEP 3: fire on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && ./host \
    sgemm_kunroll_256x256_grid.ptx \
    sgemm_kunroll_384x384_grid.ptx \
    sgemm_kunroll_512x512_grid.ptx \
    sgemm_kunroll_768x768_grid.ptx \
    sgemm_kunroll_1024x1024_grid.ptx \
    sgemm_kunroll_1536x1536_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . 2>/dev/null || true

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
