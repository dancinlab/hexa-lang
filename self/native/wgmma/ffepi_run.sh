#!/bin/bash
# FF-EPILOGUE on-pod build + byte-eq + fused-vs-separate wall. H100 (sm_90a).
set -e
cd "$(dirname "$0")"
echo "=== nvcc build (sm_90a) ==="
nvcc -O3 -arch=sm_90a -o ffepi wgmma_tf32_ffepi.cu -lcuda -lcublas -lcudart
echo "=== GPU ==="; nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
for S in 1024 2048 4096; do
  echo "=== S=$S ==="
  ./ffepi $S
done
