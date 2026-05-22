#!/usr/bin/env bash
# RFC 067 N201 -- TMA SWIZZLE_128B SGEMM sweep on ubu-1 (RTX 5070 sm_120).
#
# Plain `ssh ubu-1` (NO SIDECAR_NO_POOL).
# Uses /usr/local/cuda-12.9.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-1}"
ART_DIR_BASENAME="rfc067_ptma_swizzle128_2026_05_22"
REMOTE_DIR="/tmp/${ART_DIR_BASENAME}"

echo "== STEP 0: regen PTX (bijection verified per shape) ==" >&2
python3 gen_sgemm_tma_swizzle128_ptx.py

echo "== STEP 0a: ASCII-only check ==" >&2
for f in *.ptx; do
    if LC_ALL=C grep -P '[^\x00-\x7f]' "$f" > /dev/null; then
        echo "ERROR: non-ASCII in $f" >&2
        exit 1
    fi
done
echo "  all PTX files ASCII-only" >&2

echo "== STEP 1: rsync to ${HOST}:${REMOTE_DIR}/ ==" >&2
ssh "${HOST}" "mkdir -p ${REMOTE_DIR}"
scp -q host.c gen_sgemm_tma_swizzle128_ptx.py *.ptx "${HOST}:${REMOTE_DIR}/"

echo "== STEP 2: build host on ${HOST} (CUDA 12.9, sm_120a) ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda-12.9/bin:\$PATH && cd ${REMOTE_DIR} && /usr/local/cuda-12.9/bin/nvcc -O2 -arch=sm_120a -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd ${REMOTE_DIR} && PY_HOST=${HOST} ./host \
    sgemm_tma_sw128_512x512_grid.ptx \
    sgemm_tma_sw128_1024x1024_grid.ptx \
    sgemm_tma_sw128_2048x2048_grid.ptx \
    sgemm_tma_sw128_4096x4096_grid.ptx \
    sgemm_tma_sw128_6144x6144_grid.ptx \
    sgemm_tma_sw128_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:${REMOTE_DIR}/result.json" . || echo "(no result.json)" >&2
scp -q "${HOST}:${REMOTE_DIR}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
[ -f result.json ] && {
    echo "result.json summary:" >&2
    python3 -c "
import json
d=json.load(open('result.json'))
for s in d['shapes']:
    hx = s['hexa_n201_tflops']
    rt = s['ratio_vs_cublas']
    mr = s['hexa_vs_cublas_maxrel']
    n200 = s['n200_swiznone_tflops']
    dr = s['ratio_delta_vs_n200']
    if hx is None:
        print(f\"  M={s['M']:5d} cuBLAS={s['cublas_hgemm_tflops']:7.3f} hexa=N/A  note={s.get('note','')}\")
    else:
        print(f\"  M={s['M']:5d} cuBLAS={s['cublas_hgemm_tflops']:7.3f} hexa_N201={hx:7.3f} ratio={rt:.4f} maxrel={mr:.6f} vs_N200_tflops={hx-n200:+.3f} dratio={dr:+.4f}\")
"
}
