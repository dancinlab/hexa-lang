#!/usr/bin/env bash
# build_on_pod.sh — P1B-a''' (ASYNC-OFF capstone) on-pod build, run in ~/work.
# CORRECTED recipe (matches the PROVEN aprime2 link path, l3d self/runtime.c base):
#   l3d runtime.c already defines 4 of the 5 fused dispatchers (gelu2/groupnorm_gelu/
#   groupnorm_gelu_residual/moe_block2) + every per-op dispatcher clm_prod.c needs;
#   the ONLY missing symbol is forge_dispatch_clm_megafwd -> supplied by
#   clm_megafwd_dispatch.c (its proto inserted into self/runtime.h).
# Inputs expected already scp'd into ~/work (assembled by stage_p1b_aprime3.sh):
#   stage.tgz  — self/ tree (l3d runtime.c override) + corpus.txt + clm_prod.c +
#                runtime_cuda.c + clm_megafwd_dispatch.c + insert_clm_megafwd_proto.py
#   fire_p1b_aprime3.sh  (the ASYNC-OFF A/B + reproducibility ladder)
set -uo pipefail
cd ~/work
echo "=== GPU (HONEST — note actual card) ==="
nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader -i 0
nvcc --version | tail -2; gcc --version | head -1; ldd --version | head -1

echo "=== unpack stage.tgz (self/ tree w/ l3d runtime.c, corpus, clm_prod.c, runtime_cuda.c, clm_megafwd_dispatch.c) ==="
tar xzf stage.tgz
echo "  clm_prod.c        $(stat -c%s clm_prod.c) B   ($(grep -c 'forge_dispatch_clm_megafwd' clm_prod.c) clm_megafwd calls)"
echo "  runtime_cuda.c    $(stat -c%s runtime_cuda.c) B   ($(grep -c 'EAGER-DEVGLUE-FIRED' runtime_cuda.c) EAGER markers, $(grep -c 'MEGAFWD-FIRED' runtime_cuda.c) MEGAFWD markers)"
echo "  self/runtime.c    $(stat -c%s self/runtime.c) B  ($(grep -c 'forge_dispatch_clm_megafwd' self/runtime.c) clm_megafwd defs in base — expect 0)"
echo "  clm_megafwd_dispatch.c $(stat -c%s clm_megafwd_dispatch.c) B"

echo "=== insert 5 fused dispatcher protos into self/runtime.h (idempotent) ==="
# clm_prod.c calls bare forge_dispatch_{gelu2,groupnorm_gelu,groupnorm_gelu_residual,
# moe_block2,clm_megafwd} but l3d runtime.h lacks ALL 5 protos -> implicit-int ->
# "invalid initializer". 4 of the 5 BODIES are in l3d self/runtime.c already; only
# clm_megafwd's body comes from clm_megafwd_dispatch.c. We insert all 5 PROTOS.
python3 insert_fusion_protos.py self/runtime.h \
  && echo "  fusion protos in runtime.h: $(grep -cE '^HexaVal forge_dispatch_(gelu2|groupnorm_gelu|groupnorm_gelu_residual|moe_block2|clm_megafwd)\(' self/runtime.h)" \
  || { echo "PROTO INSERT FAIL (anchor missing)"; exit 1; }

echo "=== nvcc compile runtime_cuda.o (rdc for grid.sync, -DHEXA_CUDA for all launchers) ==="
nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 -O2 -w \
     -I self/cuda -I self -I . -c runtime_cuda.c -o runtime_cuda.o 2>/tmp/nvcc.err \
  && echo "  runtime_cuda.o: $(stat -c%s runtime_cuda.o) B" \
  || { echo "NVCC FAIL"; tail -30 /tmp/nvcc.err; exit 1; }
nm runtime_cuda.o 2>/dev/null | grep -ci 'megafwd' | xargs echo "  megafwd syms in .o:"

echo "=== nvcc -dlink (grid.sync cooperative launch needs device-link) ==="
nvcc -dlink -arch=sm_90 runtime_cuda.o -o runtime_cuda_dlink.o -lcudadevrt 2>/tmp/dlink.err \
  && echo "  runtime_cuda_dlink.o: $(stat -c%s runtime_cuda_dlink.o) B" \
  || { echo "DLINK FAIL"; tail -30 /tmp/dlink.err; exit 1; }

echo "=== link clm_prod_gpu (clm_prod.c + clm_megafwd_dispatch.c + l3d self/runtime.c) ==="
CUDA_LIB=$(dirname "$(find /usr/local/cuda* -name libcudart.so 2>/dev/null | head -1)")
gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self/cuda -I self -I . \
    clm_prod.c clm_megafwd_dispatch.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
    -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread -o clm_prod_gpu 2>/tmp/link.err \
  && echo "  clm_prod_gpu: $(stat -c%s clm_prod_gpu) B" \
  || { echo "LINK FAIL"; grep -iE 'error|undefined|multiple' /tmp/link.err | head -30; exit 1; }
echo "=== BUILD OK — now run: bash fire_p1b_aprime3.sh ==="
