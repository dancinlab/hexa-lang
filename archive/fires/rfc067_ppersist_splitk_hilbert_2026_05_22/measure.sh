#!/usr/bin/env bash
# RFC 067 PPSH -- Persistent CTA + Split-K + Hilbert visitation (2026-05-22)
#
# Plain `ssh ubu-1` (NO SIDECAR_NO_POOL). Driver-JIT cuModuleLoadDataEx with pure-ASCII PTX.
#
# Goal: follow-on to N149 PHILB (Hilbert-only, M=8192 ratio 0.847) AND N94 PV (persistent-only,
#       failed -0.39% on square shapes). Combine both + split-K (G=4 atomic-add reduce) on
#       LARGE M shapes (4096/6144/8192) where L2 + parallel-K might compound.
#
# Usage:
#   bash measure.sh
#
# HOST = ubu-1 (parallel with ubu-2 on N196). Override with PY_HOST env if needed.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-1}"
ART_DIR_BASENAME="rfc067_ppersist_splitk_hilbert_2026_05_22"

echo "== STEP 0: regen PTX (idempotent, bijection verified per shape; G=4, P=48) ==" >&2
python3 gen_sgemm_ppersist_splitk_hilbert_ptx.py

echo "== STEP 1: rsync to ${HOST}:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh "${HOST}" "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_ppersist_splitk_hilbert_ptx.py *.ptx "${HOST}:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ${HOST} ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda/bin:\$PATH && cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd /tmp/${ART_DIR_BASENAME} && PY_HOST=${HOST} ./host \
    sgemm_ppsh_4096x4096_grid.ptx \
    sgemm_ppsh_6144x6144_grid.ptx \
    sgemm_ppsh_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/result.json" .
scp -q "${HOST}:/tmp/${ART_DIR_BASENAME}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
