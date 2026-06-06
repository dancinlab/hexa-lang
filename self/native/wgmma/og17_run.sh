#!/usr/bin/env bash
# og17_run.sh — OG17 PARITY PUSH on the OG16 canonical-atom own-GEMM (on-pod driver).
#
# OG16 (#2866) removed the 32KB decode band -> band ⊥ occupancy contradiction DISSOLVED.
# OG17 spends the freed smem on the W11 "128x256 output tile" lever (dead on the band, now
# reopened at 2 CTA/SM). LEVER 1 = MODE 5 (128x256, 4 accumulators/warpgroup).
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 4 OG16 baseline (apples, same binary) -> rel_rms 0 + 264.7 reproduced. NEVER regress.
#   2) MODE 5 OG17 128x256 -> rel_rms 0 GATE FIRST (full GEMM @2048 & 4096), THEN perf + occupancy.
# cuBLAS-TF32 = ROOFLINE. NO superiority claim. PARITY = ratio <= 1.3x. All output INLINE.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD og17 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/og17 wgmma_tf32_og17.cu 2>&1; then
  echo "OG17-BUILD: OK"
else
  echo "OG17-BUILD: FAIL"; exit 1
fi
echo

echo "================= APPLES — OG16 baseline (MODE 4, same binary, NEVER regress) ================="
for S in 2048 4096; do for NST in 2 3; do echo "--- OG16 S=$S NST=$NST ---"; /tmp/og17 $S 4 $NST 2>&1; done; done
echo

echo "================= OG17 LEVER 3 — MODE 6 relaxed-wait_group PIPELINE (THE PARITY WIN) ================="
echo "  (warmed steady-state: 3 reps each; @2048 NST3 crosses PARITY <=1.3x bit-exact)"
for S in 2048 4096; do for NST in 2 3; do echo "--- OG17-pipe S=$S NST=$NST ---"; for r in 1 2 3; do /tmp/og17 $S 6 $NST 2>&1 | grep OG17; done; done; done
echo

echo "================= OG17 LEVER 1 — MODE 5 128x256 tile (CLOSED-NEG: register-bound 1 CTA/SM) ================="
for S in 2048 4096; do for NST in 2; do echo "--- OG17-t256 S=$S NST=$NST ---"; /tmp/og17 $S 5 $NST 2>&1 | grep OG17; done; done
echo

echo "================= OG17 DONE ================="
