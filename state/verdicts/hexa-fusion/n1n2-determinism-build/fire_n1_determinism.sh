#!/usr/bin/env bash
# fire_n1_determinism.sh — HEXA-FUSION N1 per-glue-kernel determinism probe.
# Run ON POD in ~/work (same tree fire_p1b_aprime2.sh builds in: self/ +
# runtime_cuda.c present). Builds the harness against the SAME runtime_cuda.o
# the real clm_prod_gpu uses, then fires the per-kernel run-to-run Δ table.
#
# N2 follow-up: re-run with HEXA_DEVGLUE_DETERMINIZE=0/1 and HEXA_OWN_GEMM=1
# to attribute the ~1e-1 to a specific kernel+buffer+mechanism.
set -uo pipefail
cd ~/work
CUDA_LIB=$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")
echo "=== GPU ==="; nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader -i 0

echo "=== nvcc compile runtime_cuda.c (if not already present) ==="
if [ ! -f runtime_cuda.o ]; then
  nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 -O2 -w \
       -I self/cuda -I self -I . -c runtime_cuda.c -o runtime_cuda.o 2>/tmp/nvcc.err \
    && echo "  runtime_cuda.o: $(stat -c%s runtime_cuda.o) bytes" \
    || { echo "NVCC FAIL"; tail -30 /tmp/nvcc.err; exit 1; }
fi
if [ ! -f runtime_cuda_dlink.o ]; then
  nvcc -dlink -arch=sm_90 runtime_cuda.o -o runtime_cuda_dlink.o 2>/tmp/dlink.err \
    && echo "  dlink ok" || { echo "DLINK FAIL"; tail -20 /tmp/dlink.err; exit 1; }
fi

echo "=== gcc link devglue_determinism harness ==="
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self/cuda -I self -I . \
    devglue_determinism.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
    -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread \
    -o devglue_determinism 2>/tmp/harness.err \
  && echo "  devglue_determinism: $(stat -c%s devglue_determinism) bytes" \
  || { echo "HARNESS LINK FAIL"; grep -iE 'error|undefined' /tmp/harness.err | head -30; exit 1; }

echo
echo "############################################################"
echo "### N1-A — baseline probe (per-op glue, cuBLAS matmul)    ###"
echo "############################################################"
env CUDA_VISIBLE_DEVICES=0 N=3 ./devglue_determinism

echo
echo "############################################################"
echo "### N1-B — OWN-GEMM probe (HEXA_OWN_GEMM=1, deterministic) ###"
echo "############################################################"
env CUDA_VISIBLE_DEVICES=0 N=3 HEXA_OWN_GEMM=1 ./devglue_determinism

echo
echo "############################################################"
echo "### N1-C — racefix OFF (legacy uninit tail)              ###"
echo "############################################################"
env CUDA_VISIBLE_DEVICES=0 N=3 HEXA_OWN_GEMM=1 HEXA_DEVGLUE_DETERMINIZE=0 ./devglue_determinism

echo
echo "############################################################"
echo "### N1-D — racefix ON (zero-on-alloc)                    ###"
echo "############################################################"
env CUDA_VISIBLE_DEVICES=0 N=3 HEXA_OWN_GEMM=1 HEXA_DEVGLUE_DETERMINIZE=1 ./devglue_determinism

echo "=== DONE ==="
