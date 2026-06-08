#!/usr/bin/env bash
# build_fast1.sh — HEXA-FLAME-FAST FAST-1 occupancy probe build + run.
# On a cooperative-launch-capable CUDA-devel pod (H100): compile the fused-step
# occupancy probe with -Xptxas -v (per-kernel reg/smem budget into the log) and
# run it at the flame step shapes. Pure cudaOccupancy query — no inputs, no A/B.
set -uo pipefail
cd "$(dirname "$0")"

echo "=== env ==="
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader | head -1
nvcc --version | tail -1

# arch = device cc; nvcc predating the arch caps at sm_90 (PTX-JIT on newer HW).
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
ARCH=$CC
if ! nvcc --list-gpu-arch 2>/dev/null | grep -q "compute_${ARCH}"; then
  echo "note: nvcc does not list compute_${ARCH}; falling back to sm_90 (PTX-JIT)"
  ARCH=90
fi
echo "building with -arch=sm_${ARCH}  (device CC=${CC})"

# -rdc=true required for cooperative_groups grid.sync(); -Xptxas -v -> reg/smem.
nvcc -O3 -arch=sm_${ARCH} -rdc=true -Xptxas -v -lcudadevrt \
    fast1_occupancy.cu -o fast1_occupancy 2>&1 | tee build_fast1.log
if [ ! -x ./fast1_occupancy ]; then echo "BUILD FAILED"; exit 1; fi

echo
echo "=== ptxas per-kernel register/smem budget (the co-residency wall) ==="
grep -iE "megastep_(fp64|tf32|bf16)|registers|smem|bytes stack" build_fast1.log || true

echo
echo "=== RUN: FAST-1 occupancy probe @ flame shapes (D1536 T512) ==="
./fast1_occupancy

echo
echo "=== RUN: sanity @ tiny shape ==="
./fast1_occupancy 256 128
echo "=== DONE ==="
