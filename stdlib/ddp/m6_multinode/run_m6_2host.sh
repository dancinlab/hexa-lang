#!/usr/bin/env bash
# run_m6_2host.sh — DDP-M6 REAL cross-node proof. Run ONE instance per HOST.
# The ring socket crosses the node boundary over TCP (or IB if the fabric
# routes it transparently — to the socket API it is the same send/recv).
#
#   On host A (rank 0):
#     ./run_m6_2host.sh 0 <hostB_ip> 5700 5701 7
#   On host B (rank 1):
#     ./run_m6_2host.sh 1 <hostA_ip> 5700 5701 7
#
# args: RANK PEER_IP PORT0 PORT1 S
#   rank r listens on 0.0.0.0:PORT{r} and connects to PEER_IP:PORT{(r+1)%2}.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/ring_tcp_m6"
cc -O2 -o "$BIN" "$HERE/ring_tcp_m6.c" || { echo "BUILD FAIL"; exit 2; }

RANK="${1:?rank}"; PEER="${2:?peer_ip}"; P0="${3:-5700}"; P1="${4:-5701}"; S="${5:-7}"
if [ "$RANK" = "0" ]; then LP=$P0; SP=$P1; else LP=$P1; SP=$P0; fi
echo "=== 2host rank=$RANK listen=0.0.0.0:$LP succ=$PEER:$SP S=$S ==="
"$BIN" --rank "$RANK" --np 2 --listen "0.0.0.0:$LP" --succ "$PEER:$SP" --S "$S"
