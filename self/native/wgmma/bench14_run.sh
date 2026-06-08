#!/usr/bin/env bash
# bench14_run.sh — BENCH-14 on-pod driver: per-CTA wgmma INNER-LOOP microarch tuning of the
# descriptor-direct own-GEMM (MODE 8 gemm_og17_b14) to close the D=2048 single-wave ~1.36x
# residual off cuBLAS, STAYING BIT-EXACT. Levers: deeper wgmma-group pipeline (dual-issue PDEP)
# + overlapped vectorized (.v2.f32) epilogue.
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 4 OG16 baseline (apples, same binary) -> rel_rms 0 reproduced. NEVER regress.
#   2) MODE 6 OG17 pipe baseline (depth-1) reproduced -> rel_rms 0.
#   3) MODE 8 b14 PDEP sweep -> rel_rms 0 GATE FIRST (full GEMM @2048 & 4096), THEN perf.
#      PDEP=1 MUST reproduce MODE 6 EXACTLY (apples self-check). PDEP>=2 = the net-new lever.
# cuBLAS-TF32 = ROOFLINE. NO superiority claim. PARITY = ratio <= 1.3x. All output INLINE.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD b14 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/b14 wgmma_tf32_b14.cu 2>&1; then
  echo "B14-BUILD: OK"
else
  echo "B14-BUILD: FAIL"; exit 1
fi
echo

echo "================= APPLES — OG16 baseline (MODE 4, same binary, NEVER regress) ================="
for S in 2048 4096; do for NST in 2 3; do echo "--- OG16 S=$S NST=$NST ---"; /tmp/b14 $S 4 $NST 2>&1 | grep -E "OCCUPANCY|OG16"; done; done
echo

echo "================= APPLES — OG17 pipe baseline (MODE 6 depth-1, NEVER regress) ================="
for S in 2048 4096; do for NST in 3; do echo "--- OG17-pipe S=$S NST=$NST ---"; for r in 1 2 3; do /tmp/b14 $S 6 $NST 2>&1 | grep OG17; done; done; done
echo

echo "================= BENCH-14 — MODE 8 PDEP sweep (deeper pipeline + vec epilogue) ================="
echo "  (gate rel_rms 0 FIRST; PDEP=1 == MODE6 self-check; median of 3 reps per cfg)"
# NST=3 -> PDEP in {0,1,2}; NST=4 -> PDEP in {1,2,3}; NST=5 -> PDEP in {2,3,4}
for S in 2048 4096; do
  for NST in 3 4 5; do
    PMAX=$((NST-1))
    for PDEP in $(seq 0 $PMAX); do
      echo "--- B14 S=$S NST=$NST PDEP=$PDEP ---"
      for r in 1 2 3; do /tmp/b14 $S 8 $NST $PDEP 2>&1 | grep -E "OCCUPANCY|B14"; done
    done
  done
done
echo

echo "================= BENCH-14 DONE ================="
