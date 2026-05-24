#!/usr/bin/env bash
# RFC 067 N203 -- TMA + warp-spec (2P+2C) + Hilbert SGEMM sweep on ubu-2 (RTX 5070 sm_120).
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Uses /usr/local/cuda-12.9.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-2}"
ART_DIR_BASENAME="rfc067_ptma_warp_spec_2026_05_22"
REMOTE_DIR="/tmp/${ART_DIR_BASENAME}"

echo "== STEP 0: regen PTX (bijection verified per shape) ==" >&2
python3 gen_sgemm_tma_warp_spec_ptx.py

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
scp -q host.c gen_sgemm_tma_warp_spec_ptx.py *.ptx "${HOST}:${REMOTE_DIR}/"

echo "== STEP 2: build host on ${HOST} (CUDA 12.9, sm_120a) ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda-12.9/bin:\$PATH && cd ${REMOTE_DIR} && /usr/local/cuda-12.9/bin/nvcc -O2 -arch=sm_120a -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd ${REMOTE_DIR} && PY_HOST=${HOST} ./host \
    sgemm_tma_warp_spec_512x512_grid.ptx \
    sgemm_tma_warp_spec_1024x1024_grid.ptx \
    sgemm_tma_warp_spec_2048x2048_grid.ptx \
    sgemm_tma_warp_spec_4096x4096_grid.ptx \
    sgemm_tma_warp_spec_6144x6144_grid.ptx \
    sgemm_tma_warp_spec_8192x8192_grid.ptx 2>&1" | tee fire.log

echo "== STEP 4: pull result.json + ptxas_info.log back ==" >&2
scp -q "${HOST}:${REMOTE_DIR}/result.json" . || echo "(no result.json)" >&2
scp -q "${HOST}:${REMOTE_DIR}/ptxas_info.log" . || echo "(no ptxas_info.log)" >&2

echo "== DONE ==" >&2
[ -f result.json ] && {
    echo "result.json summary:" >&2
    python3 -c "
import json
d = json.load(open('result.json'))
for s in d['shapes']:
    hexa = s['hexa_n203_tflops']
    hexa_str = f'{hexa:.3f}' if hexa is not None else 'NULL'
    ratio = s['ratio_vs_cublas']
    ratio_str = f'{ratio:.4f}' if ratio is not None else 'NULL'
    ma = s['hexa_vs_cublas_maxabs']
    ma_str = f'{ma:.4f}' if ma is not None else 'NULL'
    pn200 = s.get('pct_over_n200_full')
    pn200_str = f'{pn200:+.2f}%' if pn200 is not None else 'NULL'
    pn197 = s.get('pct_over_n197')
    pn197_str = f'{pn197:+.2f}%' if pn197 is not None else 'NULL'
    print(f\"  M={s['M']:5d} cuBLAS={s['cublas_hgemm_tflops']:.3f} hexa={hexa_str} ratio={ratio_str} maxabs={ma_str} vs_N200={pn200_str} vs_N197={pn197_str}\")
" 2>&1 || cat result.json
}
