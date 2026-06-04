#!/usr/bin/env bash
# build_and_measure.sh — on the GPU pod: extract the 3 GEMM kernels from the
# shipped .cu, build the standalone driver, run the 3-way A/B.
set -e
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

# Extract the HXG_* defines + cp.async helpers + the 3 kernels verbatim.
# Range = from the "#define HXTILE 16" (just above the naive WMMA's tiled sibling)
# down to the end of _hx_k_sgemm_cm_wmma2 (the line before the host launcher).
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys,re
src=open(sys.argv[1]).read()
# grab the three kernels + supporting defines.
# tiled (#define HXTILE) ... up to end of _hx_k_sgemm_cm_wmma2.
start=src.index('#define HXTILE 16')
end_marker='// Host launcher for the own-GEMM kernel'
end=src.index(end_marker)
frag=src[start:end]
print(frag)
PY

echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines ==="
grep -c '__global__' gemm_kernels_extracted.cuh | sed 's/^/kernels: /'

# Detect arch
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "compute_cap=$CC"
# nvcc 12.4 caps at sm_90; use sm_90 for Hopper/Blackwell (PTX-JIT on Blackwell).
ARCH=90
if [ "$CC" -lt 90 ]; then ARCH=$CC; fi
echo "building with -arch=sm_${ARCH}"

nvcc -O3 -arch=sm_${ARCH} -lcublas cutlass_driver.cu -o cutlass_driver 2>&1 | tee build.log

echo "=== RUN @2048^3 ==="
./cutlass_driver 2048 2048 2048 50
echo "=== correctness recheck @ small odd shape (bounds guard) ==="
./cutlass_driver 130 70 96 5
