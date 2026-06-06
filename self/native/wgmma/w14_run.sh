#!/usr/bin/env bash
# w14_run.sh — W14 on-pod driver: the PRECISION axis (FP16/BF16 wgmma own-GEMM on sm_90a).
# Ports the W10 composed-swizzle-decode own-GEMM to 16-bit operands (f32 accumulate). The
# 16KB gmma band (half of TF32's 32KB) re-opens the W13 deep-async overlap at 2 CTA/SM.
#
# GATE CHANGE (g5 HONESTY — STATED): NOT bit-exact-vs-FP64. The W14 gate is a PRECISION-
# APPROPRIATE TOLERANCE (rel_rms <= 1e-2) vs a SAME-DTYPE reference (f16/bf16 operands +
# f32 accumulate; CPU f64-accum oracle for single-tile, cuBLAS-FP16/BF16 for full GEMM).
# cuBLAS comparison is SAME-DTYPE (cuBLAS-FP16, NOT cuBLAS-TF32). NO superiority claim.
#
# GATE DISCIPLINE (mandatory order):
#   0) MODE 2/3 RAW DUMPS — re-measure the f16 SWIZZLE_128B landed layout (don't trust theory).
#   1) MODE 0 composed-decode single-tile probe -> rel_rms ~0 (f16 round-trip exact). gate.
#   2) MODE 1 composed-wgmma single-tile probe  -> rel_rms <= 1e-2 vs same-dtype oracle. gate.
#   3) ONLY after gates: full GEMM (MODE 4 single band), same-dtype gate + perf, occupancy.
#   4) MODE 6 deep-async ring (the W13 overlap reopened) — occupancy + gate + perf.
#   5) MODE 7/8 BF16 mode if budget remains.
# All output INLINE (vast-reclaim storm). cuBLAS-FP16 = roofline.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD w14 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w14 wgmma_f16_w14.cu 2>&1; then
  echo "W14-BUILD: OK"
else
  echo "W14-BUILD: FAIL"; exit 1
fi
echo

echo "================= MODE 2 — f16 A-DUMP (re-measure SWIZZLE_128B landed layout) ================="
/tmp/w14 2048 2; echo "exit=$?"
echo
echo "================= MODE 3 — f16 B-DUMP ================="
/tmp/w14 2048 3; echo "exit=$?"
echo
echo "================= GATE 1 — MODE 0 f16 composed-decode (rel_rms ~0) ================="
/tmp/w14 2048 0; G0=$?; echo "exit=$G0"
echo
echo "================= GATE 2 — MODE 1 f16 composed-wgmma (rel_rms <= 1e-2 same-dtype) ================="
/tmp/w14 2048 1; G1=$?; echo "exit=$G1"
echo

if [ "$G0" -ne 0 ] || [ "$G1" -ne 0 ]; then
  echo "W14 SINGLE-TILE GATE FAILED (g0=$G0 g1=$G1) — f16 composed law / layout re-derivation off."
  echo "STOP per g5: no full GEMM, no perf. Report exact-wall (f16 layout). TF32 W10 70.7 KEPT."
  exit 2
fi
echo "W14 SINGLE-TILE GATES PASSED — proceeding to full GEMM."
echo

echo "================= MODE 4 — f16 FULL GEMM (single band) gate + perf + occupancy ================="
for S in 2048 4096 8192; do
  for NST in 2 3; do
    echo "--- S=$S NST=$NST ---"; /tmp/w14 $S 4 $NST; echo "exit=$?"
  done
done
echo
echo "================= MODE 6 — f16 DEEP-ASYNC RING (W13 overlap reopened @2 CTA/SM) ================="
for S in 4096 8192; do
  for NSTG in 2 3; do
    echo "--- S=$S NST=3 NSTG=$NSTG ---"; /tmp/w14 $S 6 3 $NSTG; echo "exit=$?"
  done
done
echo
echo "================= MODE 7 — BF16 single-tile wgmma gate ================="
/tmp/w14 2048 7; echo "exit=$?"
echo
echo "================= MODE 8 — BF16 FULL GEMM gate + perf ================="
for S in 4096 8192; do
  echo "--- S=$S NST=3 ---"; /tmp/w14 $S 8 3; echo "exit=$?"
done
echo "================= DONE ================="
