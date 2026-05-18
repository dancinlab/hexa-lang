#!/usr/bin/env bash
# run_orfs_d4.sh — launch ORFS router_d4 baseline P&R on ubu-2,
# ssh-drop-resilient (nohup detach). Task #13. Run AFTER #12 (d6) finishes
# (no parallel make on the same box; ubu-2 will be busy with d6).
#
# Usage (from a ubu-2 ssh session, or via `wilson pool on ubu-2 ...`):
#   bash run_orfs_d4.sh
#
# Pattern mirrors bkml0mjdh (d6 run) — same fresh-clone + detached docker
# + output to $HOME/comb_pnr_out2_d4/orfs_d4.log so ssh drop doesn't lose
# the run.

set -uo pipefail

REPO_DIR=/tmp/hexa_comb_v2_d4
OUT_DIR=$HOME/comb_pnr_out2_d4

# Fresh clone (avoids stale local pack); --depth=1 keeps it lean.
rm -rf "$REPO_DIR"
git clone --depth=1 --branch rfc043-hexa-torch \
    https://github.com/dancinlab/hexa-lang.git "$REPO_DIR" 2>&1 | tail -3

echo "=== d4 SDC verify (must show ns-correct 5.0 / 0.25) ==="
cat "$REPO_DIR/comb/rtl/orfs/sky130hd/router_d4/constraint.sdc"

mkdir -p "$OUT_DIR"
nohup bash -c "
docker run --rm --user root \
  -v $REPO_DIR/comb/rtl/orfs/sky130hd:/din:ro \
  -v $OUT_DIR:/out \
  openroad/orfs:latest \
  bash -lc 'set -e
    D=/OpenROAD-flow-scripts/flow/designs/sky130hd/router_d4
    mkdir -p \$D
    cp /din/router_d4/* \$D/
    cd /OpenROAD-flow-scripts/flow
    make DESIGN_CONFIG=./designs/sky130hd/router_d4/config.mk 2>&1 | tail -100
    echo ===GDS===
    find results/sky130hd/router_d4 -name \"*.gds*\"
    echo ===FILES===
    find results reports -path \"*router_d4*\" -type f 2>/dev/null | head -40
    cp -r results/sky130hd/router_d4 /out/results_d4 2>/dev/null || true
    cp -r reports/sky130hd/router_d4 /out/reports_d4 2>/dev/null || true
    cp -r logs/sky130hd/router_d4 /out/logs_d4 2>/dev/null || true
    echo ===DONE===
  '
" > "$OUT_DIR/orfs_d4.log" 2>&1 &

PID=$!
echo "ORFS d4 detached, pid=$PID"
sleep 3
ps -p $PID >/dev/null && echo "launcher alive — d4 P&R running independent of ssh" || echo "launcher exited (check log)"
echo "Log: $OUT_DIR/orfs_d4.log"
