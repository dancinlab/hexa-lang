#!/usr/bin/env bash
# RFC 067 PV V1 -- N77 persistent CTA variant.
#
# Plain `ssh ubu-2`.
# Driver-JIT cuModuleLoadDataEx with PTX text -- pure ASCII.
#
# Usage:
#   bash measure.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ART_DIR_BASENAME="rfc067_pV_hexa_sgemm_persistent_2026_05_21"

echo "== STEP 0: regen PTX (idempotent) ==" >&2
python3 gen_sgemm_persistent_ptx.py

echo "== STEP 1: rsync to ubu-2:/tmp/${ART_DIR_BASENAME}/ ==" >&2
ssh ubu-2 "mkdir -p /tmp/${ART_DIR_BASENAME}"
scp -q host.c gen_sgemm_persistent_ptx.py *.ptx "ubu-2:/tmp/${ART_DIR_BASENAME}/"

echo "== STEP 2: build host on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 2b: capture ptxas info per shape ==" >&2
> ptxas_info.log
for s in 256 384 512 768 1024 1536; do
    echo "=== shape ${s} ===" | tee -a ptxas_info.log
    ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && /usr/local/cuda/bin/ptxas -arch=sm_90 -v --warn-on-spills sgemm_persistent_${s}x${s}_grid.ptx -o /tmp/dummy.cubin 2>&1 || true" | tee -a ptxas_info.log
done

echo "== STEP 3: fire on ubu-2 ==" >&2
ssh ubu-2 "cd /tmp/${ART_DIR_BASENAME} && ./host \
    sgemm_persistent_256x256_grid.ptx \
    sgemm_persistent_384x384_grid.ptx \
    sgemm_persistent_512x512_grid.ptx \
    sgemm_persistent_768x768_grid.ptx \
    sgemm_persistent_1024x1024_grid.ptx \
    sgemm_persistent_1536x1536_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json back ==" >&2
scp -q "ubu-2:/tmp/${ART_DIR_BASENAME}/result.json" .

echo "== DONE ==" >&2
echo "result.json:" >&2
cat result.json >&2
