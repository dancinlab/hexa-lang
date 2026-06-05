#!/usr/bin/env bash
# build_on_pod.sh — P1B-a''' (ASYNC-OFF capstone) on-pod build, run in ~/work.
# Inputs expected already scp'd into ~/work:
#   fusion_build_sources.tgz   (kit: self/ tree + corpus.txt + base clm_prod.c/runtime_cuda.c)
#   clm_prod.c                 (P1B-a' device-eager build, OVERRIDES the kit's)
#   runtime_cuda.c             (P1B-a' FP64-megafwd + EAGER-DEVGLUE marker, OVERRIDES the kit's)
#   fire_p1b_aprime3.sh        (the ASYNC-OFF A/B + reproducibility ladder)
# Recipe = kit README + P1B-a' (#2779): nvcc -rdc=true -DHEXA_CUDA -gencode compute_90 → .o → -dlink.
set -uo pipefail
cd ~/work
echo "=== GPU (HONEST — note actual card) ==="
nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader -i 0
nvcc --version | tail -2; gcc --version | head -1; ldd --version | head -1

echo "=== unpack kit sources (self/ + corpus), then OVERRIDE clm_prod.c + runtime_cuda.c ==="
tar xzf fusion_build_sources.tgz   # -> ./self ./corpus.txt ./clm_prod.c(base) ./runtime_cuda.c(base)
# restore the P1B-a' device-eager overrides (scp'd alongside, kept under names below)
cp -f clm_prod.aprime3.c   clm_prod.c
cp -f runtime_cuda.aprime3.c runtime_cuda.c
echo "  clm_prod.c        $(stat -c%s clm_prod.c) B   ($(grep -c EAGER-DEVGLUE clm_prod.c) EAGER markers in driver)"
echo "  runtime_cuda.c    $(stat -c%s runtime_cuda.c) B   ($(grep -c 'EAGER-DEVGLUE-FIRED' runtime_cuda.c) EAGER markers, $(grep -c megafwd_fp64 runtime_cuda.c) megafwd_fp64 refs)"

echo "=== nvcc compile runtime_cuda.o (rdc for grid.sync, -DHEXA_CUDA for all 58 launchers) ==="
nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=compute_90 -O2 -w \
     -I self -I . -c runtime_cuda.c -o runtime_cuda.o 2>/tmp/nvcc.err \
  && echo "  runtime_cuda.o: $(stat -c%s runtime_cuda.o) B" \
  || { echo "NVCC FAIL"; tail -30 /tmp/nvcc.err; exit 1; }
# confirm the FP64 megafwd device sym + launcher are present
nm runtime_cuda.o 2>/dev/null | grep -ci megafwd_fp64 | xargs echo "  megafwd_fp64 syms:"

echo "=== nvcc -dlink (grid.sync cooperative launch needs device-link) ==="
nvcc -dlink -gencode arch=compute_90,code=compute_90 runtime_cuda.o \
     -o runtime_cuda_dlink.o -lcudadevrt 2>/tmp/dlink.err \
  && echo "  runtime_cuda_dlink.o: $(stat -c%s runtime_cuda_dlink.o) B" \
  || { echo "DLINK FAIL"; tail -30 /tmp/dlink.err; exit 1; }

echo "=== link clm_prod_gpu ==="
CUDA_LIB=$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self -I . \
    clm_prod.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
    -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread -o clm_prod_gpu 2>/tmp/link.err \
  && echo "  clm_prod_gpu: $(stat -c%s clm_prod_gpu) B" \
  || { echo "LINK FAIL"; tail -30 /tmp/link.err; exit 1; }
echo "=== BUILD OK — now run: bash fire_p1b_aprime3.sh ==="
