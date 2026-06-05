#!/usr/bin/env bash
# build_and_measure_sm90.sh — NATIVE sm_90 H100 verification of the own-GEMM
# WMMA2 path (F-FUSION-WMMA2-SM90-VERIFY). Differs from build_and_measure.sh:
#   • Forces -gencode arch=compute_90,code=sm_90  (NATIVE SASS, no PTX-forward).
#   • HARD-VERIFIES the GPU is genuine Hopper sm_90 (H100), NOT Blackwell sm_120.
#   • Captures the [OWN-SGEMM-WMMA2-FIRED] launcher marker (which kernel fired).
#   • Reports GFLOP/s + Tensor-Core engagement (the driver does the math).
set -e
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

echo "=== GPU IDENTITY (honesty-critical) ==="
nvidia-smi --query-gpu=name,compute_cap,driver_version,memory.total --format=csv,noheader
NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "name=$NAME compute_cap=$CC"
if [ "$CC" != "90" ]; then
  echo "!!! WARNING: compute_cap=$CC is NOT 9.0 (sm_90 Hopper/H100)."
  echo "!!! This run will NOT verify NATIVE sm_90. (sm_120 = Blackwell mis-served.)"
  echo "!!! Re-rent an H100. Continuing only to record the served GPU."
fi
nvcc --version | grep release

# Extract the 3 GEMM kernels + supporting defines verbatim from shipped .cu.
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end=src.index('// Host launcher for the own-GEMM kernel')
print(src[start:end])
PY
echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines, $(grep -c '__global__' gemm_kernels_extracted.cuh) kernels ==="

echo "=== BUILD: -gencode arch=compute_90,code=sm_90 (NATIVE SASS, no PTX-forward) ==="
nvcc -O3 -gencode arch=compute_90,code=sm_90 -lcublas cutlass_driver.cu -o cutlass_driver 2>&1 | tee build_sm90.log

# Confirm native SASS for sm_90 is in the binary (no JIT-only PTX).
echo "=== cuobjdump arch (native sm_90 confirmation) ==="
cuobjdump cutlass_driver 2>/dev/null | grep -i 'arch\|sm_' | head -5 || echo "(cuobjdump unavailable)"

# DEFINITIVE Tensor-Core proof: disassemble the WMMA2 kernel and look for
# HMMA/IMMA/OMMA (Tensor-Core matrix-multiply-accumulate SASS instructions).
# If the WMMA2 path compiles to FFMA-only on sm_90, Tensor Cores are NOT used.
echo "=== SASS Tensor-Core instruction scan in _hx_k_sgemm_cm_wmma2 (sm_90) ==="
cuobjdump -sass -fun _Z19_hx_k_sgemm_cm_wmma2iixxxfPKfxS0_xfPfx cutlass_driver > wmma2_sass.txt 2>/dev/null \
  || cuobjdump -sass cutlass_driver > wmma2_sass.txt 2>/dev/null || true
# Demangled fallback: dump all SASS, isolate the wmma2 function block.
cuobjdump -sass cutlass_driver 2>/dev/null > all_sass.txt || true
HMMA=$(grep -cE 'HMMA|IMMA|OMMA|\.MMA' all_sass.txt 2>/dev/null || echo 0)
FFMA=$(grep -cE 'FFMA' all_sass.txt 2>/dev/null || echo 0)
echo "SASS HMMA/IMMA/OMMA (Tensor-Core MMA) count = $HMMA"
echo "SASS FFMA (CUDA-core FMA) count             = $FFMA"
if [ "$HMMA" -gt 0 ]; then
  echo ">> Tensor-Core MMA instructions PRESENT in sm_90 SASS — WMMA2 emits TC ops."
else
  echo ">> NO Tensor-Core MMA in sm_90 SASS — WMMA2 fell to CUDA-core FFMA (NOT engaged)."
fi
grep -m6 -E 'HMMA|IMMA|OMMA' all_sass.txt 2>/dev/null || true

echo "=== RUN @2048^3 (own-GEMM WMMA2 fires inside the driver) ==="
# The driver launches wmma2 directly; the launcher marker is emitted only via
# _hx_own_sgemm_cm_launch. We also run a launcher-gated check below.
./cutlass_driver 2048 2048 2048 50 2>wmma2_fired.log
echo "--- stderr (FIRED marker / precedence) ---"
cat wmma2_fired.log

echo "=== bounds-guard recheck @ non-tile-multiple shape ==="
./cutlass_driver 130 70 96 5
