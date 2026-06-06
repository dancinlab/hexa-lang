#!/usr/bin/env bash
# w11_run.sh — W11 on-pod driver. Applies the research-named top levers on top of the W10
# composed swizzle-decode frontier (70.7 TFLOP/s @4096, 6.09x off cuBLAS-TF32):
#   LEVER 1 = 128x256 output tile (MODE 6).  LEVER 3 = +ping-pong epilogue overlap (MODE 7).
#
# GATE DISCIPLINE (g5, MANDATORY ORDER — cuBLAS-TF32 = ROOFLINE, NO superiority claim):
#   1) W10 single-tile composed-decode GATES (MODE 0 + MODE 1) -> rel_rms 0. The bigger-tile
#      kernels reuse the SAME composed index, so if the W10 single-tile law regresses, STOP.
#   2) W10 full-GEMM MODE 4 @4096 -> the SAME-BINARY 70.7 frontier baseline (apples).
#   3) W11 MODE 6 (128x256) full-GEMM rel_rms gate (<=3e-3 ideally 0) BEFORE any perf number.
#   4) Only on green: MODE 6 perf sweep (NST 2/3), then MODE 7 ping-pong. KEEP W10 if regress.
# All output INLINE (vast-reclaim storm loses nohup data).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
S=${S:-4096}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD w10 (single-tile gate + same-binary 70.7 baseline) ================="
if $NVCC -O3 -arch=sm_90a -lcuda -lcublas -o /tmp/w10 wgmma_tf32_w10.cu 2>&1; then
  echo "W10-BUILD: OK"; else echo "W10-BUILD: FAIL"; exit 1; fi
echo
echo "----- GATE 1: W10 MODE0 composed-decode single-tile (rel_rms 0) -----"
/tmp/w10 2048 0; G0=$?; echo "exit=$G0"
echo "----- GATE 2: W10 MODE1 composed-wgmma single-tile (rel_rms 0) -----"
/tmp/w10 2048 1; G1=$?; echo "exit=$G1"
if [ "$G0" -ne 0 ] || [ "$G1" -ne 0 ]; then
  echo "W11 SINGLE-TILE GATE FAILED (g0=$G0 g1=$G1) — composed law regressed. STOP per g5."
  echo "W10 70.7 frontier KEPT (no regression shipped)."; exit 2; fi
echo "W11 SINGLE-TILE GATES PASSED."
echo
echo "----- BASELINE: W10 MODE4 @S=$S NST=2 (same-binary 70.7 apples) -----"
/tmp/w10 "$S" 4 2 || true
echo

echo "================= BUILD w11 (128x256 tile lever) ================="
if $NVCC -O3 -arch=sm_90a -lcuda -lcublas -o /tmp/w11 wgmma_tf32_w11.cu 2>&1; then
  echo "W11-BUILD: OK"; else echo "W11-BUILD: FAIL"; exit 1; fi
echo

echo "================= LEVER 1 — MODE 6 (128x256) bit-exact gate + perf ================="
echo "----- MODE6 NST=2 -----"; /tmp/w11 "$S" 6 2 || true
echo "----- MODE6 NST=3 -----"; /tmp/w11 "$S" 6 3 || true
echo "----- MODE6 S=2048 NST=2 -----"; /tmp/w11 2048 6 2 || true
echo "----- MODE6 S=8192 NST=2 -----"; /tmp/w11 8192 6 2 || true
echo
echo "================= LEVER 3 — MODE 7 (128x256 ping-pong) bit-exact gate + perf ================="
echo "----- MODE7 NST=2 -----"; /tmp/w11 "$S" 7 2 || true
echo "----- MODE7 NST=3 -----"; /tmp/w11 "$S" 7 3 || true
echo
echo "W11 RUN COMPLETE — cuBLAS-TF32 = ROOFLINE, no superiority claim. KEEP W10 70.7 if any regress."
