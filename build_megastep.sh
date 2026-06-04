#!/usr/bin/env bash
# build_megastep.sh — HEXA-FUSION H1b/B1 megakernel SKELETON build + run.
# On a CUDA-devel H100 pod: extract the own-GEMM WMMA2 kernel body from the
# shipped .cu, build the cooperative-launch megakernel driver, run the sub-chain
# byte-eq/rel-RMS check + util A/B.
set -uo pipefail
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

echo "=== env ==="
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader | head -1
nvcc --version | tail -1

# Extract the HXG_* defines + cp.async helpers + the 3 own-GEMM kernels verbatim
# (same range as build_and_measure.sh — provides _hx_k_sgemm_cm_wmma2 + HXG_*
# defines + hxg_cp* helpers that BOTH the eager __global__ launch AND the
# __device__ wrapper (gemm_device_extracted.cuh) depend on).
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end=src.index('// Host launcher for the own-GEMM kernel')
sys.stdout.write(src[start:end])
PY
echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines, $(grep -c '__global__' gemm_kernels_extracted.cuh) kernels ==="

# Detect arch (nvcc 12.x caps at sm_90; Hopper/Blackwell run sm_90 via PTX-JIT).
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
ARCH=90; [ "$CC" -lt 90 ] && ARCH=$CC
echo "building with -arch=sm_${ARCH}"

# -rdc=true required for cooperative groups grid.sync() (separable compilation).
nvcc -O3 -arch=sm_${ARCH} -rdc=true -lcublas -lcudadevrt \
    megakernel_driver.cu -o megakernel_driver 2>&1 | tee build.log
if [ ! -x ./megakernel_driver ]; then echo "BUILD FAILED"; exit 1; fi

echo
echo "=== RUN: eager-only (no megakernel) sanity ==="
./megakernel_driver

echo
echo "=== RUN: megakernel sub-chain (byte-eq/rel-RMS + util A/B) ==="
HEXA_CLM_MEGASTEP=1 ./megakernel_driver

echo
echo "=== RUN: small odd shape (bounds guard) ==="
HEXA_CLM_MEGASTEP=1 ./megakernel_driver 130 96 80 5
echo "=== DONE ==="
