#!/usr/bin/env bash
# run_m6_loopback.sh — DDP-M6 INTERMEDIATE proof: socket-transport ring over
# TCP loopback (one host, 2 processes). Labels itself 'loopback, NOT true
# multi-host'. The bytes still cross a real TCP socket (the transport under
# test), but both ranks are on 127.0.0.1 — so this validates the ring's
# socket transport, NOT inter-node routing. The 2-host driver run_m6_2host.sh
# proves the actual node boundary.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/ring_tcp_m6"
cc -O2 -o "$BIN" "$HERE/ring_tcp_m6.c" || { echo "BUILD FAIL"; exit 2; }

P0=5700; P1=5701
run_case () {
  local S="$1"
  echo "=== loopback case np=2 S=$S (S%2=$((S % 2))) ==="
  "$BIN" --rank 1 --np 2 --listen 127.0.0.1:$P1 --succ 127.0.0.1:$P0 --S "$S" &
  local pid1=$!
  "$BIN" --rank 0 --np 2 --listen 127.0.0.1:$P0 --succ 127.0.0.1:$P1 --S "$S"
  local rc0=$?
  wait $pid1; local rc1=$?
  echo "  rank0 rc=$rc0  rank1 rc=$rc1"
  [ $rc0 -eq 0 ] && [ $rc1 -eq 0 ] || return 1
}

rc=0
run_case 7         || rc=1     # boundary S%2=1
run_case $((1<<20)) || rc=1    # large
echo
echo "=== DDP-M6 loopback verdict: $([ $rc -eq 0 ] && echo 'BYTE-EQ PASS (loopback, NOT true multi-host)' || echo 'FAIL') ==="
exit $rc
