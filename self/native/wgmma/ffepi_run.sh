#!/bin/bash
# FF-EPILOGUE on-pod build + byte-eq + fused-vs-separate wall. H100 (sm_90a).
set -e
cd "$(dirname "$0")"
echo "=== nvcc build (sm_90a, -fmad=false for cross-callsite byte-eq) ==="
# -fmad=false: the fused & separate paths must NOT diverge on FMA-contraction of the
# GELU 0.5*x*(1+erf) expression (otherwise ~1 ULP residual). With it OFF both call
# sites compute the identical fp32 op sequence -> max|Δ|=0.
nvcc -O3 -arch=sm_90a -fmad=false -o ffepi wgmma_tf32_ffepi.cu -lcuda -lcublas -lcudart
echo "=== GPU ==="; nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
for S in 1024 2048 4096; do
  echo "=== S=$S ==="
  ./ffepi $S
done
