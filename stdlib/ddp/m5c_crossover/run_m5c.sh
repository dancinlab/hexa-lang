#!/bin/bash
# run_m5c.sh — HEXA-DDP DDP-M5c on-pod runner (NVLink crossover).
#
# Run ON a rented 4-GPU NVLink node. Captures interconnect topology + the full
# 12-pair cudaDeviceCanAccessPeer probe (NVLink => 1, staged-host => 0), builds
# ddp_train_m5c, and runs:
#   (1) the per-step TRAINING wall-clock at N=1/2/4 GPUs across a model-size
#       sweep (HEXA_DDP_H) -> speedup ratios + efficiency + crossover H for BOTH
#       2-GPU and 4-GPU (the H where multi-GPU DDP training BEATS 1-GPU), and
#   (2) the N=4 data-parallel TRAINING byte-eq gate (1-GPU W_ref == 4-GPU
#       W_ddp, FP64, max|delta|=0) — the M4 invariant extended to N=4.
# All output -> stdout (the dispatch host tees it into the verdict file).
#
# M5c sweeps a LARGER default H ladder than M5b (up to 8192) so the crossover
# (if reachable on this node) is captured, not just the trend direction.
#
#   scp ddp_train_m5c.cu run_m5c.sh pod:/tmp/ && ssh pod 'bash /tmp/run_m5c.sh'
set -uo pipefail

echo "######## DDP-M5c NVLink crossover :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo
echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT — look for NV# bonds) ===="
nvidia-smi topo -m 2>&1 || true
echo

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ddp_train_m5c.cu"
[ -f "$CU" ] || CU="./ddp_train_m5c.cu"
[ -f "$CU" ] || CU="/tmp/ddp_train_m5c.cu"
[ -f "$CU" ] || { echo "FATAL: ddp_train_m5c.cu not found"; exit 1; }

CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=80
echo "==== building (nvcc -arch=sm_${CC}) ===="
# forward-compat libcuda can shadow the system driver (M3/M5 finding); force the
# system lib path so cudaMemcpyPeer/cudaGetDeviceCount use the real driver.
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
nvcc -O2 -arch=sm_${CC} -o /tmp/ddp_train_m5c "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ddp_train_m5c "$CU" 2>&1; }
echo "build ok"
echo

echo "==== running ddp_train_m5c (HEXA_DDP_H=${HEXA_DDP_H:-256,1024,2048,4096,6144,8192}) ===="
HEXA_DDP_H="${HEXA_DDP_H:-256,1024,2048,4096,6144,8192}" HEXA_DDP_REPS="${HEXA_DDP_REPS:-30}" /tmp/ddp_train_m5c
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
