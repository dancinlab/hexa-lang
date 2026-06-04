#!/usr/bin/env bash
# build_megafwd.sh — HEXA-FUSION B2 full-fwd MEGAKERNEL build + run.
# On a CUDA-devel H100 pod: extract the own-GEMM WMMA2 kernel body from the
# shipped .cu, build the cooperative-launch FULL-FWD megakernel driver, run the
# full-fwd rel-RMS check + util A/B (where the sub-ms glue lives).
set -uo pipefail
cd "$(dirname "$0")"
CU=self/native/hxqwen14b_cuda.cu

echo "=== env ==="
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader | head -1
nvcc --version | tail -1

# Extract the HXG_* defines + cp.async helpers + the own-GEMM kernels verbatim
# (same range as build_megastep.sh) — provides _hx_k_sgemm_cm_wmma2 + HXG_*
# defines + hxg_cp* helpers that BOTH the eager __global__ launch AND the
# __device__ wrapper (gemm_device_extracted.cuh) depend on.
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXTILE 16')
end=src.index('// Host launcher for the own-GEMM kernel')
sys.stdout.write(src[start:end])
PY
echo "=== extracted $(wc -l < gemm_kernels_extracted.cuh) lines, $(grep -c '__global__' gemm_kernels_extracted.cuh) kernels ==="

# SM_100 STATIC-SMEM FIX for the extracted __global__ own-GEMM (same as the
# device wrapper): the shipped WMMA2 epilogue declares a separate 8 KB `tmp`
# buffer → 57344 B static > 49152 B per-block cap on sm_100 (nvlink rejects it,
# even though the eager path launches it normally). Alias tmp onto As (dead in
# the epilogue) — placement-only, math byte-identical. Applies ONLY to the
# wmma2 epilogue line; other kernels' tmp (if any) are untouched by the anchor.
python3 - <<'PY'
import re
f="gemm_kernels_extracted.cuh"; s=open(f).read()
old="    __shared__ float tmp[HXG_WARPS][16*16];"
new=("    // sm_100 static-smem fit: alias epilogue tmp onto As (dead here).\n"
     "    float (*tmp)[16*16] = reinterpret_cast<float(*)[16*16]>(&As[0][0]);")
n=s.count(old)
s=s.replace(old,new)
open(f,"w").write(s)
print(f"  [smem-fix] aliased {n} tmp epilogue buffer(s) onto As in {f}")
PY

# Arch = the device's real compute capability (sm_90 H100, sm_100 B200, …).
# Requires a toolkit that knows the arch: CUDA 12.8+ for sm_100 (B200). The build
# script picks up nvcc from PATH (CUDA 12.8 installed at /usr/local/cuda-12.8).
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
ARCH=$CC
# nvcc that predates the device arch caps at sm_90 (PTX-JIT). Detect support.
if ! nvcc --list-gpu-arch 2>/dev/null | grep -q "compute_${ARCH}"; then
  echo "note: nvcc does not list compute_${ARCH}; falling back to sm_90 (PTX-JIT on newer HW)"
  ARCH=90
fi
echo "building with -arch=sm_${ARCH}  (device CC=${CC})"

# -rdc=true required for cooperative groups grid.sync() (separable compilation).
# -Xptxas -v emits the per-kernel register/smem budget (the cooperative co-
# residency wall) into the build log.
nvcc -O3 -arch=sm_${ARCH} -rdc=true -Xptxas -v -lcublas -lcudadevrt \
    megafwd_driver.cu -o megafwd_driver 2>&1 | tee build_megafwd.log
if [ ! -x ./megafwd_driver ]; then echo "BUILD FAILED"; exit 1; fi

# Report register/smem budget (the cooperative co-residency wall).
echo "=== ptxas register/smem budget for _hx_k_clm_megafwd ==="
grep -iE "_hx_k_clm_megafwd|registers|smem" build_megafwd.log | head -12 || true

echo
echo "=== RUN: eager-only (no megafwd) sanity ==="
./megafwd_driver

echo
echo "=== RUN: full-fwd megafwd (rel-RMS + util A/B) ==="
HEXA_CLM_MEGASTEP=1 ./megafwd_driver

echo
echo "=== RUN: small odd shape (bounds guard) ==="
HEXA_CLM_MEGASTEP=1 ./megafwd_driver 130 96 80 48 5
echo "=== DONE ==="
