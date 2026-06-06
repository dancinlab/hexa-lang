#!/bin/bash
# run_m5.sh — HEXA-DDP DDP-M5 (collective leg) on-pod runner.
#
# Run ON a rented 4-GPU node. Captures the interconnect topology (so the
# scaling note knows NVLink vs PCIe), the per-pair P2P canAccessPeer probe,
# builds the ring_p2p_m5 harness, runs the N=4 byte-eq gate AND the N=2 vs
# N=4 scaling sweep. All output goes to stdout (the dispatch host tees it
# into the verdict file).
#
#   scp ring_p2p_m5.cu run_m5.sh pod:/tmp/ && ssh pod 'bash /tmp/run_m5.sh'
set -uo pipefail

echo "######## DDP-M5 real 4-GPU ring all-reduce :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo

echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT) ===="
nvidia-smi topo -m 2>&1 || true
echo

# locate the .cu (same dir as this script, or cwd, or /tmp)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ring_p2p_m5.cu"
[ -f "$CU" ] || CU="./ring_p2p_m5.cu"
[ -f "$CU" ] || CU="/tmp/ring_p2p_m5.cu"
[ -f "$CU" ] || { echo "FATAL: ring_p2p_m5.cu not found"; exit 1; }

# detect arch from the first GPU (sm_80 = A100, sm_86 = 3090/A10).
CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=80
echo "==== building (nvcc -arch=sm_${CC}) ===="
# forward-compat libcuda can shadow the system driver (seen on M3); force the
# system lib path so cudaGetDeviceCount doesn't trip the stale-compat probe.
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
nvcc -O2 -arch=sm_${CC} -o /tmp/ring_p2p_m5 "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ring_p2p_m5 "$CU" 2>&1; }
echo "build ok"
echo

NG="${DDP_NUM_GPUS:-4}"
echo "==== running ring_p2p_m5 (DDP_NUM_GPUS=$NG) ===="
DDP_NUM_GPUS="$NG" /tmp/ring_p2p_m5
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
