#!/usr/bin/env bash
# build_and_measure.sh — on-pod driver for F-FUSION-SM90-WGMMA-TMA.
# Stages, in order. Each stage is independently valuable; a later-stage failure
# does NOT erase an earlier PASS. Output is captured verbatim for the verdict.
#
# Requires: native sm_90 H100 (compute_cap 9.0), nvcc 12.x. wgmma REQUIRES
# -arch=sm_90a (NOT sm_90 — Hopper architecture-specific feature).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
NVCC=${NVCC:-nvcc}

echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

# ---- Stage 0: confirm sm_90a is a valid target in this toolchain ----
echo "================= STAGE 0: sm_90a target check ================="
if $NVCC --list-gpu-arch 2>/dev/null | grep -q "compute_90a"; then
  echo "STAGE0: sm_90a SUPPORTED by nvcc"
else
  echo "STAGE0: sm_90a NOT in --list-gpu-arch (will still attempt build)"
fi
echo

# ---- Stage 1a: f16 wgmma probe (known-good kernel, sm_90a build+run) ----
echo "================= STAGE 1a: f16 wgmma probe ================="
if $NVCC -O3 -arch=sm_90a -o /tmp/wgmma_f16_probe wgmma_f16_probe.cu 2>&1; then
  echo "STAGE1a-BUILD: OK"
  /tmp/wgmma_f16_probe; echo "STAGE1a-EXIT=$?"
else
  echo "STAGE1a-BUILD: FAIL (sm_90a/wgmma cannot build here — see error above)"
fi
echo

# ---- Stage 1b: TF32 wgmma single-warpgroup probe (correctness gate) ----
echo "================= STAGE 1b: TF32 wgmma probe ================="
if $NVCC -O3 -arch=sm_90a -o /tmp/wgmma_tf32_probe wgmma_tf32_probe.cu 2>&1; then
  echo "STAGE1b-BUILD: OK"
  /tmp/wgmma_tf32_probe; echo "STAGE1b-EXIT=$?"
else
  echo "STAGE1b-BUILD: FAIL"
fi
echo

# ---- Stage 2-4: TMA + warpgroup mainloop GEMM + cuBLAS measure ----
echo "================= STAGE 2-4: wgmma+TMA GEMM vs cuBLAS ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/wgmma_tma_gemm wgmma_tma_gemm.cu 2>&1; then
  echo "STAGE234-BUILD: OK"
  for Nsq in 1024 2048 4096; do
    echo "--- N=$Nsq ---"
    /tmp/wgmma_tma_gemm $Nsq; echo "EXIT=$?"
  done
else
  echo "STAGE234-BUILD: FAIL"
fi
echo "================= DONE ================="
