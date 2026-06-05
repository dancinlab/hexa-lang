#!/usr/bin/env bash
# warpspec_run.sh — on-pod driver for F-FUSION-SM90-WGMMA-WARPSPEC.
# Builds the warp-specialized / async-pipelined wgmma TF32 GEMM and measures each
# MODE. Bit-exact GATE FIRST (rel_rms<=3e-3) then own/cuBLAS TFLOP/s (g5: NO perf on
# a wrong-result kernel). All output captured inline (vast-reclaim storm — no nohup).
# Requires native sm_90a H100/H200, nvcc 12.x. wgmma REQUIRES -arch=sm_90a.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD warpspec ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/ws wgmma_tf32_warpspec.cu 2>&1; then
  echo "WS-BUILD: OK"
else
  echo "WS-BUILD: FAIL"; exit 1
fi
echo

# MODE 0 = W5 rebase (sanity, must ~38 TFLOP/s) ; MODE 1 = async-pipe (NST sweep)
echo "================= MODE 0 — W5 rebase (baseline sanity) ================="
for S in 2048 4096; do /tmp/ws $S 0; echo "exit=$?"; done
echo
echo "================= MODE 1 — ASYNC-PIPE (cp.async ring) NST sweep ================="
for S in 2048 4096; do
  for NST in 2 3 4 5; do /tmp/ws $S 1 $NST; echo "exit=$?"; done
done
echo
echo "================= MODE 2 — WARPSPEC single-consumer-WG (producer/consumer) ================="
for S in 2048 4096; do
  for NST in 2 3 4; do /tmp/ws $S 2 $NST; echo "exit=$?"; done
done
echo
echo "================= MODE 3 — DUAL-CONSUMER-WG WARPSPEC (W7 big lever, TM=128) ================="
for S in 2048 4096; do
  for NST in 2 3 4 5; do /tmp/ws $S 3 $NST; echo "exit=$?"; done
done
echo "================= DONE ================="
