#!/usr/bin/env bash
# RFC 067 N203 -- 3-stage TMA pool + mma.sync + Hilbert SGEMM sweep on ubu-2 (RTX 5070 sm_120).
#
# Plain `ssh ubu-2` (NO SIDECAR_NO_POOL).
# Uses /usr/local/cuda-12.9 (default /usr/local/cuda may be older).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HOST="${PY_HOST:-ubu-2}"
ART_DIR_BASENAME="rfc067_ptma_multistage_mma_2026_05_22"
REMOTE_DIR="/tmp/${ART_DIR_BASENAME}"

echo "== STEP 0: regen PTX (idempotent, bijection verified per shape) ==" >&2
python3 gen_sgemm_tma_multistage_mma_ptx.py

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
scp -q host.c gen_sgemm_tma_multistage_mma_ptx.py *.ptx "${HOST}:${REMOTE_DIR}/"

echo "== STEP 2: build host on ${HOST} (CUDA 12.9, sm_120a) ==" >&2
ssh "${HOST}" "export PATH=/usr/local/cuda-12.9/bin:\$PATH && cd ${REMOTE_DIR} && /usr/local/cuda-12.9/bin/nvcc -O2 -arch=sm_120a -o host host.c -lcuda -lcublas -lm 2>&1" | tee compile.log

echo "== STEP 3: fire on ${HOST} ==" >&2
ssh "${HOST}" "cd ${REMOTE_DIR} && PY_HOST=${HOST} ./host \
    sgemm_tma_multistage_mma_512x512_grid.ptx \
    sgemm_tma_multistage_mma_1024x1024_grid.ptx \
    sgemm_tma_multistage_mma_2048x2048_grid.ptx \
    sgemm_tma_multistage_mma_4096x4096_grid.ptx \
    sgemm_tma_multistage_mma_6144x6144_grid.ptx \
    sgemm_tma_multistage_mma_8192x8192_grid.ptx 2>&1" | tee fire.log

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
    M = s['M']
    cub = s['cublas_hgemm_tflops']
    hx  = s.get('hexa_n203_tflops')
    rat = s.get('ratio_vs_cublas')
    n200 = s.get('n200_full_ratio')
    dn200 = s.get('ratio_delta_vs_n200_full')
    broke = s.get('broke_085_here')
    if hx is None:
        print(f'  M={M:5d} cuBLAS={cub:.3f}TF hexa=NULL note={s[\"note\"]}')
    else:
        print(f'  M={M:5d} cuBLAS={cub:.3f}TF hexa={hx:.3f}TF ratio={rat:.4f} N200ratio={n200:.4f} delta={dn200:+.4f} broke085={broke}')
print(f'HEADLINE broke_085_at_any_shape = {d[\"headline_broke_085_at_any_shape\"]}')
" 2>&1 || cat result.json
}
