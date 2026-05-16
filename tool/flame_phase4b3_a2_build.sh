#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4b3_a2_build.sh — Phase 4-B-3-2-third A2 reproducible build
#
# Single-command build for A2 SHIPPED state (commit cfbba144):
#   - Phase 4-B-2 IPCP rewrite
#   - Phase 4-B-3-2-first/second trampoline + caller wire-up
#   - Phase 4-B-3-2-third A2 primitive block_fwd body
#   - Caller redirect: flame_block_..._fwd → flame_block_..._fwd_primitive
#
# Pipeline (extends tool/flame_phase4b3_build.sh):
#   1-3.7: as flame_phase4b3_build.sh (IPCP + trampoline + wire-up)
#   3.8 (NEW): strip standalone-block from primitive .c
#   3.9 (NEW): concat primitive after trampoline body
#   3.10 (NEW): sed-redirect caller _fwd(...) → _fwd_primitive(...)
#   4: clang -O2 → binary
#
# Falsifier (CI gate):
#   F-RFC047-A2-COMPILE  primitive concat'd build compiles via clang -O2
#   F-RFC047-A2-BYTE-EQ  output binary stdout byte-id with baseline
#
# Usage:
#   tool/flame_phase4b3_a2_build.sh <flame_test.hexa> <out_binary>
#
# Currently hard-coded for (T=16, d=32, nh=4, nkv=2, h=64) d=32·3L config.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-B-3-2-third A2 primitive block_fwd build (RFC 047)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
B3_C="build/artifacts/${STEM}_b3.c"
PRIM_SRC="tool/flame_phase4b3_block_fwd_primitive.c"
PRIM_STRIPPED="build/artifacts/${STEM}_prim_stripped.c"
B3_REDIRECTED="build/artifacts/${STEM}_b3_a2_redirected.c"
A2_C="build/artifacts/${STEM}_a2.c"

mkdir -p build/artifacts

echo "═══ flame Phase 4-B-3-2-third A2 build (RFC 047) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo ""

# Steps 1-3.7: delegate to existing wrapper
echo "[1..3.7] running tool/flame_phase4b3_build.sh (IPCP + trampoline + wire-up)"
tool/flame_phase4b3_build.sh "$SRC" "/tmp/${STEM}_b3_tmp" 2>&1 | tail -5

if [ ! -f "$B3_C" ]; then
    echo "✗ FATAL: $B3_C missing after phase4b3_build.sh"
    exit 1
fi

echo "[3.8] strip standalone-only block from primitive C"
sed '/^#ifdef FLAME_BLOCK_PRIM_STANDALONE/,/^#endif/d' "$PRIM_SRC" > "$PRIM_STRIPPED"

echo "[3.9] sed-redirect caller: _fwd(...) → _fwd_primitive(...)"
sed 's|flame_block_T16_d32_nh4_nkv2_h64_fwd((int)|flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive((int)|g' \
    "$B3_C" > "$B3_REDIRECTED"

echo "[3.10] insert primitive body after #include \"runtime.c\""
sed '/^#include "runtime.c"/r '"$PRIM_STRIPPED" "$B3_REDIRECTED" > "$A2_C"
echo "  concat'd: $A2_C ($(wc -l < "$A2_C") lines)"

echo "[4/4] clang -O2 → $OUT"
clang -O2 -I self -lm "$A2_C" -o "$OUT" 2>&1 | tail -3

if [ ! -f "$OUT" ]; then
    echo "✗ Build FAILED"
    exit 1
fi
echo "✓ Built: $OUT"
echo ""

# Run + byte-eq check (if /tmp/baseline.out exists)
echo "─── byte-eq verification ───"
"$OUT" > /tmp/a2_check.out 2>&1
if [ -f /tmp/baseline.out ]; then
    if diff -q /tmp/baseline.out /tmp/a2_check.out > /dev/null; then
        echo "PASS  F-RFC047-A2-BYTE-EQ  output byte-id with /tmp/baseline.out"
    else
        echo "FAIL  byte-eq diff:"
        diff /tmp/baseline.out /tmp/a2_check.out | head -5
        exit 1
    fi
else
    echo "SKIP  /tmp/baseline.out missing — run baseline first to enable byte-eq gate"
    echo "      (mkdir -p build && ./hexa build $SRC -o build/<stem>_baseline; ./build/<stem>_baseline > /tmp/baseline.out)"
fi

echo ""
echo "═══ A2 build complete ═══"
echo "  Run: $OUT"
