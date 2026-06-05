#!/usr/bin/env bash
# HEXA-FUSION SM90 WARP-TILE RETUNE — on-pod build + measure driver.
# Run on a NATIVE sm_90 (H100, compute_cap 9.0) pod from the repo root.
# Captures: register usage (parent WMMA2 vs RR) via cuobjdump -res-usage,
# blocks/SM (from regs + smem), own square 2048^3 GFLOP/s + ratio vs cuBLAS
# + rel-RMS, for BOTH the parent WMMA2 kernel and the RR variant.
set -e
ARCH=sm_90
KCU=self/native/hxqwen14b_cuda.cu
BCU=self/native/bench/wmma2_rr_bench.cu
N=${1:-2048}

echo "=== device ==="
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader || true
echo

echo "=== compile kernel TU (sm_90, -DHEXA_CUDA) ==="
nvcc -O3 -DHEXA_CUDA -arch=$ARCH -lineinfo -c $KCU -o /tmp/hxq.o
echo "ok"
echo

echo "=== register / resource usage (cuobjdump -res-usage) ==="
echo "--- parent _hx_k_sgemm_cm_wmma2 ---"
cuobjdump -res-usage /tmp/hxq.o 2>/dev/null | grep -A6 -i '_hx_k_sgemm_cm_wmma2[^_]' | head -12 || true
echo "--- RR _hx_k_sgemm_cm_wmma2_rr ---"
cuobjdump -res-usage /tmp/hxq.o 2>/dev/null | grep -A6 -i '_hx_k_sgemm_cm_wmma2_rr' | head -12 || true
echo
echo "(full table for the two wmma2 syms:)"
cuobjdump -res-usage /tmp/hxq.o 2>/dev/null | grep -iE 'wmma2' || true
echo

echo "=== build bench ==="
nvcc -O3 -arch=$ARCH $BCU /tmp/hxq.o -lcublas -lcuda -o /tmp/wmma2_rr_bench
echo "ok"
echo

echo "=== MEASURE: parent WMMA2 (HEXA_OWN_GEMM_WMMA2=1) ==="
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SYNC=1 /tmp/wmma2_rr_bench $N
echo
echo "=== MEASURE: RR variant (HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_WMMA2_RR=1) ==="
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_WMMA2_RR=1 HEXA_OWN_GEMM_SYNC=1 /tmp/wmma2_rr_bench $N
echo
echo "=== occupancy note: H100 = 65536 regs/SM, 256 thr/blk ==="
echo "blocks/SM (reg-limited) = floor(65536 / (regs_per_thread * 256))"
echo "done."
