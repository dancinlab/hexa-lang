#!/usr/bin/env bash
# ── DDP-M6b WAN throughput runner. Build + run one rank of the perf sweep. ──
# On each of the two rented vast pods:
#   rank0 (host A): run_m6b.sh 0 0.0.0.0:5700 <B_ip>:<B_ext_port>
#   rank1 (host B): run_m6b.sh 1 0.0.0.0:5701 <A_ip>:<A_ext_port>
# Container ports must be exposed via vast's Docker port map; pass the
# EXTERNAL host:port of the successor as $3.
set -euo pipefail
RANK="${1:?rank}"; LISTEN="${2:?listen H:P}"; SUCC="${3:?succ H:P}"
REPS="${4:-11}"; PINGS="${5:-50}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cc -O2 -o "$DIR/ring_perf_m6b" "$DIR/ring_perf_m6b.c" -lm
exec "$DIR/ring_perf_m6b" --rank "$RANK" --np 2 \
    --listen "$LISTEN" --succ "$SUCC" --reps "$REPS" --ping "$PINGS"
