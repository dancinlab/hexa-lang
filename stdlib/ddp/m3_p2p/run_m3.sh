#!/bin/bash
# run_m3.sh — HEXA-DDP DDP-M3 on-pod runner.
#
# Run ON a rented 2-GPU node. Captures the interconnect topology, the P2P
# canAccessPeer probe, builds the ring_p2p harness, and runs the byte-eq gate.
# All output goes to stdout (the dispatch host tees it into the verdict file).
#
#   ssh pod 'bash -s' < run_m3.sh                 # if ring_p2p.cu already on pod
# or scp ring_p2p.cu + this script, then ssh pod 'bash run_m3.sh'
set -uo pipefail

echo "######## DDP-M3 real 2-GPU P2P ring all-reduce :: $(date -u +%Y-%m-%dT%H:%M:%SZ) ########"
echo

echo "==== nvidia-smi -L ===="
nvidia-smi -L 2>&1 || true
echo
echo "==== nvidia-smi topo -m (VERBATIM SSOT) ===="
nvidia-smi topo -m 2>&1 || true
echo

# locate the .cu (same dir as this script, or cwd)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CU="$HERE/ring_p2p.cu"
[ -f "$CU" ] || CU="./ring_p2p.cu"
[ -f "$CU" ] || { echo "FATAL: ring_p2p.cu not found"; exit 1; }

# detect arch from the first GPU (default sm_86 = RTX 3090/A10).
CC="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')"
[ -n "$CC" ] || CC=86
echo "==== building (nvcc -arch=sm_${CC}) ===="
nvcc -O2 -arch=sm_${CC} -o /tmp/ring_p2p "$CU" 2>&1 || {
    echo "nvcc sm_${CC} failed, retrying generic"; nvcc -O2 -o /tmp/ring_p2p "$CU" 2>&1; }
echo "build ok"
echo

echo "==== running ring_p2p ===="
/tmp/ring_p2p
RC=$?
echo
echo "==== exit code: $RC ===="
exit $RC
