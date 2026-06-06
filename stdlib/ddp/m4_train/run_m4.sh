#!/bin/bash
# run_m4.sh — HEXA-DDP DDP-M4 on-pod runner.
#
# Run ON a rented 2-GPU node. Captures the interconnect topology + P2P probe,
# builds the ddp_train harness, and runs the DATA-PARALLEL TRAINING byte-eq
# gate: 1-GPU reference step vs 2-GPU DDP step (grad ring all-reduce) must
# produce byte-identical weights + loss (FP64, max|Δ|=0).
#
#   scp ddp_train.cu run_m4.sh pod:/root/ ; ssh pod 'bash /root/run_m4.sh'
set -uo pipefail

echo "######## DDP-M4 data-parallel training byte-eq :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo
echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT) ===="
nvidia-smi topo -m 2>&1 || true
echo

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ddp_train.cu"
[ -f "$CU" ] || CU="./ddp_train.cu"
[ -f "$CU" ] || { echo "FATAL: ddp_train.cu not found"; exit 1; }

CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=86
echo "==== building (nvcc -arch=sm_${CC}) ===="
nvcc -O2 -arch=sm_${CC} -o /tmp/ddp_train "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ddp_train "$CU" 2>&1; }
echo "build ok"
echo

echo "==== running ddp_train ===="
# the M3 transport note: forward-compat libcuda can shadow the system driver;
# force the system lib path so cudaMemcpyPeer uses the real driver.
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-} /tmp/ddp_train
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
