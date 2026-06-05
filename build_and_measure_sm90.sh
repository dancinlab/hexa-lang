#!/usr/bin/env bash
# build_and_measure_sm90.sh — HEXA-FUSION sm_90 (Hopper H100) own-GEMM WMMA2
# DYNAMIC-SHARED FIX harness (verdict F-FUSION-SM90-DYNSHARED-FIX, PR #2796 follow-up).
#
# HARD-ASSERTS the GPU is a NATIVE sm_90 H100 (compute_cap 9.0, NOT Blackwell
# sm_120) so the measurement is genuine native-Hopper SASS — the verdict
# F-FUSION-WMMA2-SM90-VERIFY's 1.13x was on Blackwell; this proves the fix on
# the GPU that previously FAILED with cudaErrorInvalidValue.
#
# Builds with EXPLICIT -gencode arch=compute_90,code=sm_90 (real sm_90 SASS,
# no PTX-JIT) and runs the 3-way cuBLAS / naive-WMMA / tiled-WMMA2 A/B. The
# WMMA2 kernel now uses extern (dynamic) shared + cudaFuncSetAttribute opt-in.
set -e
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

echo "=== GPU identity ==="
nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
echo "GPU_NAME=$GPU_NAME  COMPUTE_CAP=$CAP"
if [ "$CAP" != "9.0" ]; then
  echo "FATAL: expected NATIVE sm_90 (compute_cap 9.0, H100); got $CAP — wrong GPU, ABORT." >&2
  exit 3
fi
echo "compute_cap 9.0 CONFIRMED (native Hopper H100)"

# Extract the GEMM kernels verbatim from the SHIPPED .cu (no copy drift).
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end_marker='// Host launcher for the own-GEMM kernel'
end=src.index(end_marker)
print(src[start:end])
PY
echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines ==="
grep -c '__global__' gemm_kernels_extracted.cuh | sed 's/^/kernels: /'
# Sanity: the fix MUST be present in the extracted (measured) kernel.
grep -q 'extern __shared__ float hxg_smem' gemm_kernels_extracted.cuh \
  && echo "FIX PRESENT: WMMA2 uses extern __shared__ (dynamic)" \
  || { echo "FATAL: extracted kernel is NOT the dynamic-shared fix" >&2; exit 4; }

echo "=== build: nvcc -gencode arch=compute_90,code=sm_90 (NATIVE sm_90 SASS) ==="
nvcc -O3 -gencode arch=compute_90,code=sm_90 -lcublas cutlass_driver.cu -o cutlass_driver 2>&1 | tee build.log

# Confirm REAL sm_90 SASS (HMMA present) — not a PTX-JIT fallback.
echo "=== HMMA count in sm_90 SASS for the WMMA2 kernel ==="
cuobjdump -sass cutlass_driver 2>/dev/null | grep -c HMMA | sed 's/^/HMMA_total: /' || true

echo "=== RUN @2048^3 (native sm_90 H100) ==="
./cutlass_driver 2048 2048 2048 50
echo "=== correctness recheck @ small odd shape (bounds guard) ==="
./cutlass_driver 130 70 96 5
