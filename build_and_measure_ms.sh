#!/usr/bin/env bash
# build_and_measure_ms.sh — on the GPU pod: extract the GEMM kernels (incl. the
# new A3 _hx_k_sgemm_cm_wmma2_ms) from the shipped .cu, build the standalone MS
# driver, run the 3-way A/B (cuBLAS vs WMMA2 vs WMMA2-MS).
set -e
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

# Extract the HXG_* defines + cp.async helpers + ALL kernels in range, i.e. from
# "#define HXTILE 16" down to the host-launcher marker — this now includes the
# A3 multi-stage kernel + skewed-shared helpers (authored just above the marker).
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end=src.index('// Host launcher for the own-GEMM kernel')
print(src[start:end])
PY

echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines ==="
grep -c '__global__' gemm_kernels_extracted.cuh | sed 's/^/kernels: /'
grep -q '_hx_k_sgemm_cm_wmma2_ms' gemm_kernels_extracted.cuh && echo "MS kernel: present" || { echo "MS kernel: MISSING"; exit 1; }

CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "compute_cap=$CC"
ARCH=90
if [ "$CC" -lt 90 ]; then ARCH=$CC; fi
echo "building with -arch=sm_${ARCH}"

nvcc -O3 -arch=sm_${ARCH} -lcublas cutlass_ms_driver.cu -o cutlass_ms_driver 2>&1 | tee build_ms.log

echo "=== RUN @2048^3 (R16 fwd+bwd square-GEMM proxy) ==="
./cutlass_ms_driver 2048 2048 2048 50
echo "=== square sweep ==="
for S in 1024 4096; do
  echo "--- ${S}^3 ---"
  ./cutlass_ms_driver $S $S $S 50
done
echo "=== correctness recheck @ small odd shape (bounds guard) ==="
./cutlass_ms_driver 130 70 96 5
