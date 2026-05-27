#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d9_orin_clobber_oracle.sh — build + run the $0 targeted
# Bc[oRin] CLOBBER-STEP oracle (tool/flame_phase4d9_orin_clobber_oracle.c).
#
# Splices the TWO REAL primitives UNMODIFIED in the SAME a2-build order as
# tool/flame_phase4d9_block_fwd_oracle.sh (matmul FIRST, then block fwd) at
# the //@FLAME_ORACLE_SPLICE_MARKER@ line. No runtime.c, no nvcc — the
# harness models the runtime_cuda.c residence FSM on a simulated device
# buffer so the residence-structural oRin clobber reproduces at $0.
# ════════════════════════════════════════════════════════════════════════
set -e

ORACLE_C="tool/flame_phase4d9_orin_clobber_oracle.c"
PRIM_MATMUL="tool/flame_phase4d6_matmul_primitives.c"   # spliced FIRST
PRIM_FWD="tool/flame_phase4d7_block_fwd_primitive.c"     # spliced SECOND
MARKER='//@FLAME_ORACLE_SPLICE_MARKER@'

mkdir -p build/artifacts
ASSEMBLED="build/artifacts/flame_phase4d9_orin_clobber_oracle_assembled.c"

for f in "$ORACLE_C" "$PRIM_MATMUL" "$PRIM_FWD"; do
    [ -f "$f" ] || { echo "FATAL: missing $f"; exit 2; }
done

awk -v p1="$PRIM_MATMUL" -v p2="$PRIM_FWD" -v marker="$MARKER" '
    $0 ~ marker && !done {
        print
        print "// ─── splice 1/2 (a2 order: FIRST): " p1 " ───"
        while ((getline line < p1) > 0) print line
        close(p1)
        print "// ─── splice 2/2 (a2 order: SECOND): " p2 " ───"
        while ((getline line < p2) > 0) print line
        close(p2)
        done=1
        next
    }
    { print }
' "$ORACLE_C" > "$ASSEMBLED"

echo "═══ flame Bc[oRin] CLOBBER-STEP \$0 oracle ═══"
echo "  assembled : $ASSEMBLED  ($(wc -l < "$ASSEMBLED" | tr -d ' ') lines)"
echo "  spliced   : $PRIM_MATMUL  →  $PRIM_FWD  (a2 concat order)"
echo ""

# -DHEXA_CUDA so the primitive's GPU transpose-scatter / forge-resident
# path is COMPILED IN (mm_c_id≥0 gate is under #ifdef HEXA_CUDA). The
# harness provides the residence-FSM shims (NOT real CUDA) so it still
# builds + runs at $0 on a no-nvcc Mac and reproduces the residence
# clobber. HEXA_CUDA_ORACLE_SIM tells the harness it owns the shims.
OUT="build/flame_phase4d9_orin_clobber_oracle"
clang -O2 -DHEXA_CUDA "$ASSEMBLED" -lm -o "$OUT"
echo "  built     : $OUT"
echo ""
"$OUT"
exit $?
