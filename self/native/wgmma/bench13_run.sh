#!/usr/bin/env bash
# bench13_run.sh — BENCH-13: SWIZZLED-RASTERIZATION + PERSISTENT-KERNEL own-GEMM (on-pod driver).
#
# BENCH-12 brought the descriptor-direct bit-exact own-GEMM to 1.23x@2048 (parity) / 1.62x@4096
# off cuBLAS via decode-elimination. BENCH-12 isolated the residual ~1.3-1.6x as cuBLAS's
# PERSISTENT MULTI-CTA SCHEDULER: (1) swizzled CTA->tile rasterization (L2 operand reuse) +
# (2) a persistent grid (gridDim=#SMs, tile-queue loop) that amortizes launch + smooths the tail
# wave. BENCH-13 adds both to gemm_og17_persist (MODE 7) and re-measures vs cuBLAS.
#
# GATE (g5, MANDATORY): rasterization changes only tile ORDER -> rel_rms MUST stay 0 (a non-zero
# value = a tile-index bug). cuBLAS-TF32 = ROOFLINE. PARITY = ratio <= 1.3x. All output INLINE.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD og17 (BENCH-13) ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/og17 wgmma_tf32_og17.cu 2>&1; then
  echo "OG17-BUILD: OK"
else
  echo "OG17-BUILD: FAIL"; exit 1
fi
echo

echo "================= APPLES — OG16 descriptor-direct baseline (MODE 4, NEVER regress) ================="
for S in 2048 4096; do for NST in 2 3; do echo "--- OG16 S=$S NST=$NST ---"; /tmp/og17 $S 4 $NST 2>&1 | grep -E "OCCUPANCY|OG16"; done; done
echo

echo "================= BENCH-13 — MODE 7 SWIZZLED-RASTER + PERSISTENT (the cell) ================="
echo "  args: S 7 NST SWZ GRIDMUL  | SWZ=0 row-major  | GRIDMUL=0 non-persistent (gridDim=tiles)"
echo "  ---- SWIZZLE-WIDTH SWEEP (SWZ in {0,2,4,8,16}) @ persistent GRIDMUL=2, NST=3 ----"
for S in 2048 4096; do
  for SWZ in 0 2 4 8 16; do
    echo "--- persist S=$S SWZ=$SWZ GRIDMUL=2 NST=3 (rep x3) ---"
    /tmp/og17 $S 7 3 $SWZ 2 2>&1 | grep -E "OCCUPANCY"
    for r in 1 2 3; do /tmp/og17 $S 7 3 $SWZ 2 2>&1 | grep "OG17"; done
  done
done
echo

echo "  ---- PERSISTENT-DEPTH SWEEP (GRIDMUL in {0,1,2,4}) @ best SWZ=8, NST=3 ----"
for S in 2048 4096; do
  for GM in 0 1 2 4; do
    echo "--- persist S=$S SWZ=8 GRIDMUL=$GM NST=3 (rep x3) ---"
    /tmp/og17 $S 7 3 8 $GM 2>&1 | grep -E "OCCUPANCY"
    for r in 1 2 3; do /tmp/og17 $S 7 3 8 $GM 2>&1 | grep "OG17"; done
  done
done
echo

echo "  ---- NST=2 cross-check (64KB/CTA, the BENCH-12 best-occupancy point) @ SWZ=8 GRIDMUL=2 ----"
for S in 2048 4096; do
  echo "--- persist S=$S SWZ=8 GRIDMUL=2 NST=2 (rep x3) ---"
  for r in 1 2 3; do /tmp/og17 $S 7 2 8 2 2>&1 | grep "OG17"; done
done
echo

echo "================= BENCH-13 DONE ================="
