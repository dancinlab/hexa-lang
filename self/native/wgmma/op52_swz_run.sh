#!/usr/bin/env bash
# op52_swz_run.sh — OP-52 on-pod driver: test the OP-45-GPU T4 lever (CTA-swizzle + better
# single-pass tile) on the route-(a) own-GEMM MODE 8 (b14) to try to CLOSE the @D=4096 TF32
# sub-parity gap (~1.52x slower than cuBLAS-TF32), STAYING BIT-EXACT (rel_rms 0 mandatory).
#
# THE LEVER (OP-45-GPU T4): cuBLAS's +24.6% large-D win = cta_swizzle=1 + single-pass (split_k=1),
# NOT split-K. MODE 7 already swizzles BUT also converts to a persistent kernel (T3: regressed
# @4096). MODE 9 (gemm_og17_b14_swz) ISOLATES the swizzle: b14 MODE 8 math VERBATIM + 1-CTA/tile
# grid (NOT occ*SM) + ONLY the CTA->tile assignment swizzled. SWZ=0 == MODE 8 EXACTLY.
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 8 baseline reproduced @D=2048 (parity anchor ~320) & D=4096 (cap ~284) — rel_rms 0.
#   2) MODE 9 SWZ=0 MUST reproduce MODE 8 EXACTLY (apples self-check) — rel_rms 0, same TFLOP/s.
#   3) MODE 9 SWZ sweep — rel_rms 0 GATE FIRST (a swizzle that changes output = tile-index bug),
#      THEN perf. cuBLAS-TF32 = ROOFLINE. PARITY = ratio <= 1.3x. All output INLINE (g5 verbatim).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD b14 (+MODE 9 swizzle) ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/b14 wgmma_tf32_b14.cu 2>&1; then
  echo "B14-BUILD: OK"
else
  echo "B14-BUILD: FAIL"; exit 1
fi
echo
echo "----- ptxas -v on the swizzle kernel (occupancy must match MODE 8 = 90 regs / 2 CTA/SM) -----"
$NVCC -O3 -arch=sm_90a -Xptxas -v -lcublas -lcuda -c wgmma_tf32_b14.cu -o /tmp/b14.o 2>&1 | grep -A1 "gemm_og17_b14_swz\|gemm_og17_b14'" || true
echo

echo "================= STEP 1 — MODE 8 baseline (apples, NEVER regress) ================="
for S in 2048 4096; do
  echo "--- MODE 8 S=$S NST=3 (PDEP best: 2048->2, 4096->1) ---"
  for PDEP in 1 2; do for r in 1 2 3; do /tmp/b14 $S 8 3 $PDEP 2>&1 | grep -E "OCCUPANCY|B14 S=$S MODE=8"; done; done
done
echo

echo "================= STEP 2 — MODE 9 SWZ=0 apples self-check (MUST == MODE 8) ================="
for S in 2048 4096; do
  echo "--- MODE 9 S=$S SWZ=0 NST=3 PDEP=2 ---"
  for r in 1 2 3; do /tmp/b14 $S 9 3 2 0 2>&1 | grep -E "OCCUPANCY|B14 S=$S MODE=9"; done
done
echo

echo "================= STEP 3 — MODE 9 CTA-SWIZZLE sweep (the @D=4096 gap-close attempt) ================="
echo "  (gate rel_rms 0 FIRST; median of 3 reps per cfg; sweep SWZ group-width)"
for S in 4096 2048; do
  for NST in 3; do
    for PDEP in 1 2; do
      for SWZ in 2 4 6 8 12 16; do
        echo "--- MODE 9 S=$S NST=$NST PDEP=$PDEP SWZ=$SWZ ---"
        for r in 1 2 3; do /tmp/b14 $S 9 $NST $PDEP $SWZ 2>&1 | grep -E "OCCUPANCY|B14 S=$S MODE=9"; done
      done
    done
  done
done
echo

echo "================= OP-52 DONE ================="
