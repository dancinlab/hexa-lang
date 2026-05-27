#!/usr/bin/env bash
# RFC 067 PBEAT -- cuBLAS-BEAT envelope sweep: N121 (6-stage) + N107 (swizzle).
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL) per user 2026-05-21.
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
# 3x repeat (r1/r2/r3) to capture small-M cuBLAS launch-bound variance.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ART_DIR_BASENAME="rfc067_pbeat_hexa_sgemm_beat_envelope_2026_05_22"

echo "== STEP 0: regen PTX (idempotent) ==" >&2
python3 gen_sgemm_4warp_6stage_ptx.py
python3 gen_sgemm_4warp_swizzle_ptx.py

echo "== STEP 1: rsync to ubu-2:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh ubu-2 "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_4warp_6stage_ptx.py gen_sgemm_4warp_swizzle_ptx.py *.ptx \
    "ubu-2:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

PTX_6STAGE="sgemm_4warp_6stage_192x192_grid.ptx sgemm_4warp_6stage_256x256_grid.ptx sgemm_4warp_6stage_320x320_grid.ptx sgemm_4warp_6stage_384x384_grid.ptx sgemm_4warp_6stage_448x448_grid.ptx sgemm_4warp_6stage_512x512_grid.ptx"
PTX_SWIZZLE="sgemm_4warp_swizzle_192x192_grid.ptx sgemm_4warp_swizzle_256x256_grid.ptx sgemm_4warp_swizzle_320x320_grid.ptx sgemm_4warp_swizzle_384x384_grid.ptx sgemm_4warp_swizzle_448x448_grid.ptx sgemm_4warp_swizzle_512x512_grid.ptx"

echo "== STEP 3: fire 3x on ubu-2 (r1/r2/r3) ==" >&2
: > fire.log
for TAG in r1 r2 r3; do
    echo "---- RUN ${TAG} ----" | tee -a fire.log
    ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && ./host ${TAG} ${PTX_6STAGE} ${PTX_SWIZZLE} 2>&1" | tee -a fire.log
done

echo "== STEP 4: pull result_*.json + ptxas_info_*.log back ==" >&2
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result_r1.json" . || true
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result_r2.json" . || true
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result_r3.json" . || true
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/ptxas_info_r1.log" . || echo "(no ptxas_info)" >&2

echo "== DONE ==" >&2
