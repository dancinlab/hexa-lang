#!/usr/bin/env bash
# warpspec_run.sh — W9 on-pod driver for F-FUSION-SM90-WGMMA-W9 (swizzled-TMA own-GEMM).
# W8 frontier = MODE 4 gemm_ws_tma (66.5 TFLOP/s, 6.44x, 2 CTA/SM, rel_rms=0). W9 adds
# MODE 5/6/7 = SWIZZLED-TMA (128B/64B/32B) so the bulk copy LANDS the tile wgmma-ready,
# DROPPING the per-K-step cooperative permute + its 2 __syncthreads. Bit-exact GATE FIRST
# (rel_rms<=3e-3; gate BEFORE any perf number, g5). cuBLAS-TF32 = ROOFLINE. NO superiority.
# All output captured INLINE (vast-reclaim storm — no nohup). wgmma REQUIRES -arch=sm_90a.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD warpspec (W9) ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/ws wgmma_tf32_warpspec.cu 2>&1; then
  echo "WS-BUILD: OK"
else
  echo "WS-BUILD: FAIL"; exit 1
fi
echo

# ---- W8 MODE 4 baseline (apples-to-apples carry, must reproduce ~66.5 @ S=4096) ----
echo "================= MODE 4 — W8 TMA-producer baseline (no swizzle, permute present) ================="
for S in 2048 4096; do for NST in 2 3 4; do /tmp/ws $S 4 $NST; echo "exit=$?"; done; done
echo

# ---- W9 LEVER-1: 128B swizzle (TKSW=32) — permute REMOVED ----
# The swizzle<->8x4-INTER descriptor interaction is the named risk: SWEEP (lbo,sbo,kstep)
# at small S=2048 NST=2 FIRST to FIND the bit-exact descriptor (rel_rms<=3e-3), THEN scale.
echo "================= MODE 5 — W9 SWIZZLED-TMA 128B descriptor SWEEP (find bit-exact) ================="
# canonical 128B-swizzle candidates: lbo in {16,32,1024}, sbo in {1024,16,128}, kstep {0,1}.
for KSTEP in 0 1; do
  for LBO in 16 1024 32 128; do
    for SBO in 1024 16 128 32; do
      /tmp/ws 2048 5 2 $LBO $SBO $KSTEP; echo "exit=$?"
    done
  done
done
echo "----------------- MODE 5 — SCALE the bit-exact descriptor (edit LBO/SBO/KSTEP below to the winner) -----------------"
# Default scale run uses the kernel-default descriptor; the harvester will re-run the
# WINNING (lbo,sbo,kstep) from the sweep above at full scale. Provided here for the
# common-case canonical winner (lbo=16 sbo=1024 kstep=0):
for S in 2048 4096 6144 8192; do for NST in 2 3 4; do /tmp/ws $S 5 $NST 16 1024 0; echo "exit=$?"; done; done
echo

# ---- W9 LEVER-2 fallbacks: 64B / 32B swizzle (if 128B mismatches the TF32 8x4 core) ----
echo "================= MODE 6 — W9 SWIZZLED-TMA 64B (fallback) ================="
for S in 2048 4096; do for NST in 2 3; do /tmp/ws $S 6 $NST; echo "exit=$?"; done; done
echo
echo "================= MODE 7 — W9 SWIZZLED-TMA 32B (fallback) ================="
for S in 2048 4096; do for NST in 2 3; do /tmp/ws $S 7 $NST; echo "exit=$?"; done; done
echo

# ---- SASS evidence: confirm the permute + its __syncthreads are GONE in MODE 5 ----
echo "================= SASS — permute-removal evidence (MODE 5 vs MODE 4) ================="
$NVCC -O3 -arch=sm_90a -cubin -o /tmp/ws.cubin wgmma_tf32_warpspec.cu 2>/dev/null && \
  cuobjdump -sass /tmp/ws.cubin > /tmp/ws.sass 2>/dev/null && {
    echo "gemm_ws_tma (MODE4) BAR.SYNC count:    $(awk '/gemm_ws_tma\(/{f=1} /gemm_ws_tma_sw/{f=0} f&&/BAR.SYNC/{c++} END{print c+0}' /tmp/ws.sass)"
    echo "gemm_ws_tma_sw (MODE5) BAR.SYNC count: $(awk '/gemm_ws_tma_sw/{f=1} /\.text\.[^g]/{f=0} f&&/BAR.SYNC/{c++} END{print c+0}' /tmp/ws.sass)"
    echo "(MODE5 BAR.SYNC should drop vs MODE4 — the per-K-step permute syncs are gone.)"
  } || echo "cuobjdump unavailable — skip SASS evidence"
echo "================= DONE ================="
