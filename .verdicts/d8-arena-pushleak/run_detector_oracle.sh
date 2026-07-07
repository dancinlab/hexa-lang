#!/usr/bin/env bash
# run_detector_oracle.sh — mem-lane ② tier-2 loop-body reclaim DETECTOR oracle.
# REPORT-ONLY: transpiles each repro with HEXA_ARENA_DETECT=1 and captures the
# [arena-detect] fire-rate lines. The two combo-corruption cases
# (global_store_escape, global_arena_slice_escape) MUST show 0 reclaim-safe
# loops (their escaping binding is NEVER flagged safe); the positive control
# (loop_body_transient_safe) MUST show >=1 reclaim-safe loop (discrimination).
#
# Usage: run_detector_oracle.sh <compiler-binary> [transpile-args...]
#   The compiler binary is a hexa compiler built from the branch's codegen.hexa
#   (e.g. build/lx8664/cc_native). It must run gen2_fn_decl when compiling.
set -u
CC="${1:?usage: run_detector_oracle.sh <cc_native> [args...]}"; shift || true
HERE="$(cd "$(dirname "$0")" && pwd)"
REPROS="$HERE/repros"
echo "=== d8 loop-body reclaim DETECTOR oracle (HEXA_ARENA_DETECT=1) ==="
for f in "$REPROS"/*.hexa; do
  base="$(basename "$f")"
  echo "----- $base -----"
  # Compile the repro; capture only the detector's stderr fire-rate lines.
  HEXA_ARENA_DETECT=1 "$CC" "$@" "$f" 2>&1 1>/dev/null | grep -E '\[arena-detect\]' || echo "  (no loop-bearing fn / no [arena-detect] line)"
done
echo "=== oracle verdict rule ==="
echo "  global_store_escape / global_arena_slice_escape : every [arena-detect] line MUST be 0/N (ESCAPING, rejected)"
echo "  loop_body_transient_safe                        : must show a >=1/N line (reclaim-safe, discrimination)"
