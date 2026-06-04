#!/usr/bin/env bash
# build_and_measure_bf16.sh — HEXA-FUSION C1: on the GPU pod, extract the GEMM
# kernels (incl. the new _hx_k_sgemm_cm_bf16) from the shipped .cu, build the
# BF16 A/B driver, run cuBLAS-BF16 vs BF16-own vs FP32-WMMA2 vs FP64-cuBLAS.
set -e
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

# Extract HXG_*/HXGB_* defines + cp.async helpers + ALL own-GEMM kernels verbatim
# (from "#define HXTILE 16" down to the host launcher) — same range as the FP32
# driver's build_and_measure.sh; the BF16 kernel sits in this range.
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end=src.index('// Host launcher for the own-GEMM kernel')
print(src[start:end])
PY

echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines ==="
grep -c '__global__' gemm_kernels_extracted.cuh | sed 's/^/kernels: /'
grep -q '_hx_k_sgemm_cm_bf16' gemm_kernels_extracted.cuh && echo "bf16 kernel: PRESENT" || { echo "bf16 kernel: MISSING"; exit 1; }

CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "compute_cap=$CC"
ARCH=90
if [ "$CC" -lt 90 ]; then ARCH=$CC; fi
echo "building with -arch=sm_${ARCH}"

nvcc -O3 -arch=sm_${ARCH} -lcublas bf16_driver.cu -o bf16_driver 2>&1 | tee build_bf16.log

echo "=== RUN @2048^3 ==="
./bf16_driver 2048 2048 2048 50
echo "=== correctness recheck @ small odd shape (bounds guard) ==="
./bf16_driver 130 70 96 5
