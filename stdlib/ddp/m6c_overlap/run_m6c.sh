#!/usr/bin/env bash
# run_m6c.sh — build + run the DDP-M6c overlapped WAN ring on a 2-node WAN path.
# Reuses the M6/M6b transport; changes ONLY the send/recv blocking discipline.
#
# On each pod:  cc -O2 -pthread -o ring_perf_m6c ring_perf_m6c.c -lm
# rank1 (host B):  ./ring_perf_m6c --rank 1 --np 2 --listen 0.0.0.0:5701 \
#                    --succ <A_pub>:<A_port> --mode pipeline --pchunks 8 --check
# rank0 (host A):  ./ring_perf_m6c --rank 0 --np 2 --listen 0.0.0.0:5700 \
#                    --succ <B_pub>:<B_port> --mode pipeline --pchunks 8 --check
#
# Sweep all three modes (serial baseline re-measure, duplex, pipeline) so the
# speedup is measured on the SAME path (removes pod-to-pod variance vs M6b):
#   --mode serial    (== M6b blocking baseline)
#   --mode duplex    (full-duplex send||recv, P=1)
#   --mode pipeline  (full-duplex + --pchunks P sub-chunks in flight)
set -euo pipefail
cc -O2 -pthread -o ring_perf_m6c "$(dirname "$0")/ring_perf_m6c.c" -lm
echo "built ring_perf_m6c"
