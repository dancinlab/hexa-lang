#!/bin/bash
# run_m5b.sh — HEXA-DDP DDP-M5b on-pod runner.
#
# Run ON a rented 4-GPU node. Captures interconnect topology + the full 12-pair
# P2P probe, builds ddp_train_m5b, and runs:
#   (1) the per-step TRAINING wall-clock at N=1/2/4 GPUs across a model-size
#       sweep (HEXA_DDP_H) -> speedup ratios + efficiency + crossover H, and
#   (2) the N=4 data-parallel TRAINING byte-eq gate (1-GPU W_ref == 4-GPU
#       W_ddp, FP64, max|delta|=0) — the M4 invariant extended to N=4.
# All output -> stdout (the dispatch host tees it into the verdict file).
#
#   scp ddp_train_m5b.cu run_m5b.sh pod:/tmp/ && ssh pod 'bash /tmp/run_m5b.sh'
set -uo pipefail

echo "######## DDP-M5b 4-GPU training speedup :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo
echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT) ===="
nvidia-smi topo -m 2>&1 || true
echo

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ddp_train_m5b.cu"
[ -f "$CU" ] || CU="./ddp_train_m5b.cu"
[ -f "$CU" ] || CU="/tmp/ddp_train_m5b.cu"
[ -f "$CU" ] || { echo "FATAL: ddp_train_m5b.cu not found"; exit 1; }

CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=86
echo "==== building (nvcc -arch=sm_${CC}) ===="
# forward-compat libcuda can shadow the system driver (M3/M5 finding); force the
# system lib path so cudaMemcpyPeer/cudaGetDeviceCount use the real driver.
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
nvcc -O2 -arch=sm_${CC} -o /tmp/ddp_train_m5b "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ddp_train_m5b "$CU" 2>&1; }
echo "build ok"
echo

echo "==== running ddp_train_m5b (HEXA_DDP_H=${HEXA_DDP_H:-64,256,1024,2048}) ===="
HEXA_DDP_H="${HEXA_DDP_H:-64,256,1024,2048}" HEXA_DDP_REPS="${HEXA_DDP_REPS:-30}" /tmp/ddp_train_m5b
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
