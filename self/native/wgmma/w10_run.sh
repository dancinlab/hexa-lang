#!/usr/bin/env bash
# w10_run.sh — W10 on-pod driver for F-FUSION-SM90-WGMMA-W10 (composed swizzle decode).
# Composes the W9-MEASURED 128B-swizzle law (g XOR ((r+1)&7)) with the GMMA INTER 8x4
# core packing (gmma_phys) to land a PERMUTE-FREE bit-exact swizzled-TMA own-GEMM.
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 0 single-tile COMPOSED-DECODE probe -> rel_rms 0 GATE (cheap). If FAIL, STOP —
#      the composed law does not recover the swizzled tile; report exact-wall, KEEP W8 66.5.
#   2) MODE 1 single-tile COMPOSED wgmma probe  -> rel_rms 0 GATE. If FAIL, STOP likewise.
#   3) ONLY after BOTH gates pass: build the full GEMM, full bit-exact gate, then perf.
# cuBLAS-TF32 = ROOFLINE. NO superiority claim. All output INLINE (vast-reclaim storm).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD w10 probe ================="
if $NVCC -O3 -arch=sm_90a -lcuda -o /tmp/w10 wgmma_tf32_w10.cu 2>&1; then
  echo "W10-BUILD: OK"
else
  echo "W10-BUILD: FAIL"; exit 1
fi
echo

echo "================= GATE 1 — MODE 0 composed-decode single-tile probe (rel_rms 0) ================="
/tmp/w10 2048 0; G0=$?; echo "exit=$G0"
echo
echo "================= GATE 2 — MODE 1 composed-wgmma single-tile probe (rel_rms 0) ================="
/tmp/w10 2048 1; G1=$?; echo "exit=$G1"
echo

if [ "$G0" -ne 0 ] || [ "$G1" -ne 0 ]; then
  echo "W10 SINGLE-TILE GATE FAILED (g0=$G0 g1=$G1) — composed law does NOT decode bit-exact."
  echo "STOP per g5: no full GEMM, no perf number. W8 66.5 frontier KEPT (no regression)."
  exit 2
fi
echo "W10 SINGLE-TILE GATES PASSED — proceeding to full-GEMM build + bit-exact gate + perf."
echo "(full-GEMM path lands in MODE 5-composed of wgmma_tf32_warpspec.cu — see w10 full block.)"
