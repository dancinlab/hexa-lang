#!/usr/bin/env bash
# bench11_run.sh — BENCH-11 on-pod driver: warp-specialized TMA-producer + ring-staged-
# decode TF32 wgmma own-GEMM (gemm_b11), vs the W10 baseline (gemm_w10 MODE4) and cuBLAS.
#
# GATE DISCIPLINE (g5, MANDATORY): bit-exact rel_rms vs cuBLAS-TF32 ref FIRST (<=3e-3),
# perf (TFLOP/s + cuBLAS-multiple) only after the gate. cuBLAS = ROOFLINE, no superiority
# fabrication. All output INLINE (vast-reclaim storm). HONEST closed-neg is a valid result.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD W10 baseline (gemm_w10 MODE4) ================="
if $NVCC -O3 -arch=sm_90a -lcuda -lcublas -o /tmp/w10 wgmma_tf32_w10.cu 2>&1; then
  echo "W10-BUILD: OK"
else
  echo "W10-BUILD: FAIL"; exit 1
fi

echo "================= BUILD BENCH-11 (gemm_b11 MODE6) ================="
if $NVCC -O3 -arch=sm_90a -lcuda -lcublas -o /tmp/b11 wgmma_tf32_bench11.cu 2>&1; then
  echo "B11-BUILD: OK"
else
  echo "B11-BUILD: FAIL"; exit 1
fi
echo

echo "================= W10 BASELINE @2048/4096 (gate+perf) ================="
/tmp/w10 2048 4 3; echo "exit=$?"
/tmp/w10 4096 4 3; echo "exit=$?"
echo

echo "================= BENCH-11 warp-spec TMA @2048/4096 (gate+perf, NST sweep) ================="
for S in 2048 4096; do
  for NSW in 3 4 5; do for NGM in 2 3 4; do
    /tmp/b11 $S 6 $NSW $NGM; echo "exit=$? (S=$S NSW=$NSW NGM=$NGM)"
  done; done
done
echo
echo "================= DONE — see W10 own=... vs B11 own=... ratio(cuBLAS/own) ================="
