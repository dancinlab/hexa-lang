#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  run_m6.sh — build + drive the DDP-M6 socket-ring all-reduce.
#
#  Two modes, selected by $1:
#    loopback           two ranks on ONE node (127.0.0.1) — intermediate proof
#                       of the socket-transport ring (NOT true 2-host).
#    node <RANK> <WORLD> <PEERS>
#                       one rank on THIS node — true multi-host. PEERS is the
#                       comma list host:port (index=rank); rank's own entry is
#                       its listen port (host ignored, binds 0.0.0.0).
#
#  GATE: every rank prints  max|delta|=0  BYTE-EQ PASS  for S=7 and S=1<<20.
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail
cd "$(dirname "$0")"

ARCH="${ARCH:-sm_75}"
echo "[m6] building ring_socket_m6 (arch=$ARCH) ..."
nvcc -O2 -arch="$ARCH" -o ring_socket_m6 ring_socket_m6.cu
echo "[m6] build OK"

MODE="${1:-loopback}"

if [ "$MODE" = "loopback" ]; then
    echo "[m6] LOOPBACK run (2 ranks, ONE node, 127.0.0.1) — intermediate proof"
    PEERS="127.0.0.1:5700,127.0.0.1:5701"
    DDP_WORLD=2 DDP_RANK=0 DDP_PEERS="$PEERS" ./ring_socket_m6 > rank0.log 2>&1 &
    P0=$!
    DDP_WORLD=2 DDP_RANK=1 DDP_PEERS="$PEERS" ./ring_socket_m6 > rank1.log 2>&1 &
    P1=$!
    rc=0
    wait $P0 || rc=$?
    wait $P1 || rc=$?
    echo "===== rank0.log ====="; cat rank0.log
    echo "===== rank1.log ====="; cat rank1.log
    echo "[m6] loopback exit rc=$rc"
    exit $rc
elif [ "$MODE" = "node" ]; then
    RANK="$2"; WORLD="$3"; PEERS="$4"
    echo "[m6] NODE run rank=$RANK world=$WORLD peers=$PEERS"
    DDP_WORLD="$WORLD" DDP_RANK="$RANK" DDP_PEERS="$PEERS" ./ring_socket_m6
    exit $?
else
    echo "usage: $0 {loopback | node <RANK> <WORLD> <host:port,...>}"; exit 64
fi
