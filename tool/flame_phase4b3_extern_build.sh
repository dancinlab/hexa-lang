#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4b3_extern_build.sh — extern fn build wrapper
#
# Builds the Phase 4-B-3 extern fn ABI test (or any flame source with
# extern fn declarations). Pipeline:
#   1. module_loader flatten
#   2. hexat transpile (skip IPCP; extern fn is a single-call POC)
#   3. cat primitive .c body (provides extern fn body in same TU)
#   4. clang -O2 → binary
#
# Primitive .c body: hand-paste matching tool/flame_phase4b3_emit_trampoline.hexa
# output (rmsnorm primitive). For this POC, we inline it directly here.
#
# Usage:
#   tool/flame_phase4b3_extern_build.sh <flame_extern_test.hexa> <out_binary>
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_extern_test.hexa> <out_binary>"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
EXP="/tmp/${STEM}_expanded.hexa"
CFILE="build/artifacts/${STEM}.c"
PRIM="build/artifacts/${STEM}_primitive.c"
BUILT="build/artifacts/${STEM}_built.c"

mkdir -p build/artifacts

INTERP=$(tool/find_local_hexa.sh 2>/dev/null || true)
# Select the EXACT canonical transpiler — never a `hexat*` glob.
# `find -name "hexat*" | head -1` returns directory order and can pick
# self/native/hexat_baseline (an Apr-15 stale binary that strips
# multi-line fn signatures → dropped params → undeclared identifiers).
if [ -x self/native/hexat ]; then
    V2="self/native/hexat"
else
    V2=$(find self/native -name "hexat" 2>/dev/null | head -1)
fi

if [ -z "$INTERP" ] || [ -z "$V2" ]; then
    echo "FATAL: cannot locate a hexa driver or hexat"
    exit 2
fi

echo "═══ flame Phase 4-B-3 extern fn build (POC) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"

echo "[1/4] module_loader flatten → $EXP"
"$INTERP" run self/module_loader.hexa "$SRC" "$EXP" 2>&1 | tail -1

echo "[2/4] hexat transpile → $CFILE"
"$V2" "$EXP" "$CFILE" 2>&1 | tail -1
# Restore single-TU `#include "runtime.c"` — the canonical hexat emits
# `#include "runtime.h"` (separate-TU) but step 3 sed-inserts the
# primitive after the `#include "runtime.c"` anchor, and clang never
# links runtime.c separately.
if grep -q '^#include "runtime.h"' "$CFILE"; then
    sed -i '' 's|^#include "runtime.h"|#include "runtime.c"|' "$CFILE"
fi

echo "[3/4] write primitive .c body → $PRIM"
cat > "$PRIM" <<'PRIMEOF'
// ─── Phase 4-B-3 rmsnorm primitive (mirrors emit_trampoline output) ──
static inline void flame_rmsnorm_d32_fwd_primitive(
    int x_id, int g_id, int y_id, int xn_id, int inv_id
) {
    double* x   = _hx_farr_table[x_id].buf;
    double* g   = _hx_farr_table[g_id].buf;
    double* y   = _hx_farr_table[y_id].buf;
    double* xn  = _hx_farr_table[xn_id].buf;
    double* inv = _hx_farr_table[inv_id].buf;
    const double eps = 1e-6;
    double ms = 0.0;
    for (int i = 0; i < 32; i++) { ms += x[i] * x[i]; }
    ms /= (double)32;
    double iv = 1.0 / sqrt(ms + eps);
    inv[0] = iv;
    for (int j = 0; j < 32; j++) {
        double xni = x[j] * iv;
        xn[j] = xni;
        y[j]  = g[j] * xni;
    }
}
PRIMEOF

echo "[3.5] insert primitive after #include \"runtime.c\""
sed '/^#include "runtime.c"/r '"$PRIM" "$CFILE" > "$BUILT"

echo "[4/4] clang -O2 → $OUT"
clang -O2 -I self -lm "$BUILT" -o "$OUT" 2>&1 | tail -5

if [ -f "$OUT" ]; then
    echo "✓ Built: $OUT"
else
    echo "✗ Build FAILED"
    exit 1
fi
