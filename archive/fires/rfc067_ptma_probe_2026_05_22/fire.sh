#!/usr/bin/env bash
# RFC 067 PTMA probe fire on ubu-1 (RTX 5070 sm_120)
#
# This runs on the remote host (ubu-1). The local Mac side just scp's the
# artifacts over, then ssh's to run this script, then scp's logs back.
#
# Steps:
#   1) ptxas --gpu-name=sm_90a (offline accept check on the bulk instruction)
#   2) ptxas --gpu-name=sm_120a (does the consumer Blackwell arch accept it?)
#   3) Compile host driver with nvcc/gcc + -lcuda
#   4) Run; produce result.json + fire.log
set -uo pipefail   # do NOT use -e: we want negative results to land cleanly

CUDA=/usr/local/cuda-12.9
PTXAS="${CUDA}/bin/ptxas"
NVCC="${CUDA}/bin/nvcc"

cd "$(dirname "$0")"
exec > fire.log 2>&1

echo "=== rfc067 ptma probe fire (ubu-1) ==="
date -u
echo

echo "--- GPU ---"
nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv
echo

echo "--- ptxas version ---"
"${PTXAS}" --version
echo

echo "--- Step 1: offline ptxas accept check at sm_90a (the documented target) ---"
"${PTXAS}" --gpu-name=sm_90a -o /tmp/tma_probe_sm90a.cubin tma_probe.ptx
echo "ptxas sm_90a exit=$?"
echo

echo "--- Step 2: offline ptxas accept check at sm_120a (the device's own arch) ---"
"${PTXAS}" --gpu-name=sm_120a -o /tmp/tma_probe_sm120a.cubin tma_probe.ptx
echo "ptxas sm_120a exit=$?"
echo

echo "--- Step 3: build host driver ---"
"${NVCC}" -O2 -arch=sm_90 \
    -I"${CUDA}/include" \
    -L"${CUDA}/lib64" -L"${CUDA}/lib64/stubs" \
    -o host host.c -lcuda
hb_exit=$?
echo "host build exit=$hb_exit"
echo

if [ "$hb_exit" -ne 0 ]; then
    echo "host build failed; aborting"
    exit 1
fi

echo "--- Step 4: fire ---"
./host tma_probe.ptx
fire_exit=$?
echo
echo "fire exit=$fire_exit"

echo
echo "--- result.json ---"
cat result.json 2>/dev/null || echo "(no result.json)"

exit 0
