#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4b_build.sh — flame Phase 4-B-2 IPCP build wrapper
#
# Single-command reproducible IPCP build for flame_d32_corpus_test (and
# any analogous flame test source with a top-level (T,d,nh,nkv,h)
# 5-tuple). Production `./hexa build` is untouched — this is a parallel
# build path for Phase 4-B-2 measurement (F-RFC047-FALLBACK-PRESERVED
# holds vacuously).
#
# Usage:
#   tool/flame_phase4b_build.sh <flame_test.hexa> <out_binary>
#
# Example:
#   tool/flame_phase4b_build.sh \
#     stdlib/flame/flame_d32_corpus_test.hexa \
#     build/flame_d32_corpus_ipcp
#
# Pipeline:
#   1. module_loader flatten        → /tmp/<stem>_expanded.hexa
#   2. flame_phase4b_ipcp.hexa      → /tmp/<stem>_ipcp.hexa
#   3. hexa_v2 transpile            → build/artifacts/<stem>_ipcp.c
#   4. clang -O2                    → <out_binary>
#
# Exit codes:
#   0   build succeeded
#   1   missing arg
#   2   pipeline stage failure
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-B-2 IPCP reproducible build wrapper (RFC 047)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
EXP="/tmp/${STEM}_expanded.hexa"
IPCP="/tmp/${STEM}_ipcp.hexa"
CFILE="build/artifacts/${STEM}_ipcp.c"

mkdir -p build/artifacts

INTERP=$(find /Users/ghost/.hx/packages/hexa/build -name "hexa_interp.real" 2>/dev/null | head -1)
if [ -z "$INTERP" ]; then
    echo "FATAL: cannot locate hexa_interp.real"
    exit 2
fi

V2=$(find self/native -name "hexa_v2*" 2>/dev/null | head -1)
if [ -z "$V2" ]; then
    echo "FATAL: cannot locate hexa_v2 transpiler"
    exit 2
fi

echo "═══ flame Phase 4-B-2 IPCP build (RFC 047) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo ""

echo "[1/4] module_loader flatten → $EXP"
"$INTERP" self/module_loader.hexa "$SRC" "$EXP" 2>&1 | tail -1

echo "[2/4] IPCP rewrite → $IPCP"
./hexa run tool/flame_phase4b_ipcp.hexa "$EXP" "$IPCP" 2>&1 | grep -E "PASS|FAIL|substitutions|total" | head -10

echo "[3/4] hexa_v2 transpile → $CFILE"
"$V2" "$IPCP" "$CFILE" 2>&1 | tail -1

echo "[4/4] clang -O2 → $OUT"
clang -O2 -I self -lm "$CFILE" -o "$OUT" 2>&1 | tail -3

echo ""
echo "✓ Built: $OUT"
echo "  Run: $OUT"
