#!/usr/bin/env bash
# w12_run.sh — W12 on-pod driver. The COUPLED LEVER on the W10 70.7 frontier:
#   (a) warp-spec register realloc (producer 40 / consumer 232, setmaxnreg) + 2 consumer WGs
#   (b) per-K8-sub decode -> smem 147KB -> ~110KB/CTA -> restore 2 CTA/SM. (MODE 9.)
#
# GATE DISCIPLINE (g5, MANDATORY ORDER — cuBLAS-TF32 = ROOFLINE, NO superiority claim):
#   1) W10 single-tile composed-decode GATES (MODE 0 + MODE 1) -> rel_rms 0. W12 reuses the
#      SAME composed index; if the W10 single-tile law regresses, STOP.
#   2) W10 full-GEMM MODE 4 @4096 -> the SAME-BINARY 70.7 frontier baseline (apples).
#   3) W12 MODE 9 occupancy print (verify 2 CTA/SM RESTORED) + full-GEMM rel_rms gate
#      (<=3e-3 ideally 0) BEFORE any perf number.
#   4) Only on green: MODE 9 perf sweep (NST 2/3, S 2048/4096/8192). KEEP W10 if regress.
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
  echo "W12 SINGLE-TILE GATE FAILED (g0=$G0 g1=$G1) — composed law regressed. STOP per g5."
  echo "W10 70.7 frontier KEPT (no regression shipped)."; exit 2; fi
echo "W12 SINGLE-TILE GATES PASSED."
echo
echo "----- BASELINE: W10 MODE4 @S=$S NST=2 (same-binary 70.7 apples) -----"
/tmp/w10 "$S" 4 2 || true
echo

echo "================= BUILD w12 (warp-spec + sub-decode 128x256) ================="
if $NVCC -O3 -arch=sm_90a -lcuda -lcublas -o /tmp/w12 wgmma_tf32_w12.cu 2>&1; then
  echo "W12-BUILD: OK"; else echo "W12-BUILD: FAIL"; exit 1; fi
echo

# timeout guard: a deadlocked warp-spec handshake must NOT hang the pod (storm-safe).
TO="timeout -k 5 90"
echo "================= MODE 10 — (b) sub-decode ONLY (PRIMARY: isolate occupancy lever) ========"
echo "----- MODE10 NST=2 (occupancy must be 2 CTA/SM, rel_rms 0) -----"; $TO /tmp/w12 "$S" 10 2; echo "[exit=$?]"
echo "----- MODE10 NST=3 -----"; $TO /tmp/w12 "$S" 10 3; echo "[exit=$?]"
echo "----- MODE10 S=2048 NST=2 -----"; $TO /tmp/w12 2048 10 2; echo "[exit=$?]"
echo "----- MODE10 S=8192 NST=2 -----"; $TO /tmp/w12 8192 10 2; echo "[exit=$?]"
echo
echo "================= MODE 9 — (a)+(b) warp-spec + sub-decode (coupled) ================="
echo "----- MODE9 NST=2 (90s timeout guard; deadlock -> skip, KEEP MODE10/W10) -----"; $TO /tmp/w12 "$S" 9 2; echo "[exit=$?]"
echo "----- MODE9 NST=3 -----"; $TO /tmp/w12 "$S" 9 3; echo "[exit=$?]"
echo
echo "W12 RUN COMPLETE — cuBLAS-TF32 = ROOFLINE, no superiority claim. KEEP W10 70.7 if any regress."
