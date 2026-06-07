#!/bin/bash
# run_m5d.sh — HEXA-DDP DDP-M5d (throughput leg) on-pod runner.
#
# Run ON a rented 4-GPU node (ideally NVLink: confirm cudaDeviceCanAccessPeer=1).
# Captures the interconnect topology + per-pair P2P canAccessPeer probe, builds
# the ddp_train_m5d harness, then runs the THROUGHPUT scaling sweep (per-GPU
# batch FIXED, global batch = B_perGPU*N, samples/sec at N=1/2/4) AND the N=4
# byte-eq gate (1-process ref == 4-GPU DDP, max|delta|=0 FP64). All output goes
# to stdout (the dispatch host tees it into the verdict file).
#
#   scp ddp_train_m5d.cu run_m5d.sh pod:/tmp/ && ssh pod 'bash /tmp/run_m5d.sh'
set -uo pipefail

echo "######## DDP-M5d throughput scaling (per-GPU batch fixed) :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo

echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT) ===="
nvidia-smi topo -m 2>&1 || true
echo

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ddp_train_m5d.cu"
[ -f "$CU" ] || CU="./ddp_train_m5d.cu"
[ -f "$CU" ] || CU="/tmp/ddp_train_m5d.cu"
[ -f "$CU" ] || { echo "FATAL: ddp_train_m5d.cu not found"; exit 1; }

# forward-compat libcuda can shadow the system driver (seen on M3/M5); force the
# system lib path so cudaGetDeviceCount doesn't trip the stale-compat probe.
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=80
echo "==== building (nvcc -arch=sm_${CC}) ===="
nvcc -O2 -arch=sm_${CC} -o /tmp/ddp_train_m5d "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ddp_train_m5d "$CU" 2>&1; }
echo "build ok"
echo

# A100/H100 167KB optin shared cap -> H<=3456 fits 6*H*8B at sm_80. Default
# sweep stays inside that. Per-GPU batch 64 fixed (override HEXA_DDP_BPERGPU).
NG="${DDP_NUM_GPUS:-4}"
H="${HEXA_DDP_H:-256,1024,2048,3072}"
BP="${HEXA_DDP_BPERGPU:-64}"
REPS="${HEXA_DDP_REPS:-30}"
echo "==== running ddp_train_m5d (DDP_NUM_GPUS=$NG, H=$H, B_perGPU=$BP, REPS=$REPS) ===="
DDP_NUM_GPUS="$NG" HEXA_DDP_H="$H" HEXA_DDP_BPERGPU="$BP" HEXA_DDP_REPS="$REPS" /tmp/ddp_train_m5d
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
