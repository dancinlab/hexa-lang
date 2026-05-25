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
#   3. hexat transpile            → build/artifacts/<stem>_ipcp.c
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

INTERP=$(tool/find_local_hexa.sh 2>/dev/null || true)
if [ -z "$INTERP" ]; then
    echo "FATAL: cannot locate a local hexa driver (tool/find_local_hexa.sh)"
    exit 2
fi

# Select the EXACT canonical transpiler — never a `hexat*` glob.
# `find -name "hexat*" | head -1` returns directory order and can pick
# self/native/hexat_baseline (an Apr-15 stale binary that strips
# multi-line fn signatures — emits `HexaVal _db_grad_accum_farr(... HexaVal )`
# with dropped params → undeclared identifiers → ~20 clang errors).
# The canonical self/native/hexat carries the May-11+ fixes and emits
# the full multi-line signature.
if [ -x self/native/hexat ]; then
    V2="self/native/hexat"
else
    V2=$(find self/native -name "hexat" 2>/dev/null | head -1)
fi
if [ -z "$V2" ]; then
    echo "FATAL: cannot locate hexat transpiler (self/native/hexat)"
    exit 2
fi

echo "═══ flame Phase 4-B-2 IPCP build (RFC 047) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo ""

echo "[1/4] module_loader flatten → $EXP"
"$INTERP" run self/module_loader.hexa "$SRC" "$EXP" 2>&1 | tail -1

echo "[2/4] IPCP rewrite → $IPCP"
./hexa run tool/flame_phase4b_ipcp.hexa "$EXP" "$IPCP" 2>&1 | grep -E "PASS|FAIL|substitutions|total" | head -10

echo "[3/4] hexat transpile → $CFILE"
"$V2" "$IPCP" "$CFILE" 2>&1 | tail -1
# The canonical hexat emits `#include "runtime.h"` (separate-TU
# convention). This flame build pipeline is architected around the
# single-TU `#include "runtime.c"` form (clang compiles only the one
# .c, never links runtime.c separately). Restore single-TU so runtime
# symbols (__hexa_fn_arena_enter, __hx_to_double, ...) resolve.
if grep -q '^#include "runtime.h"' "$CFILE"; then
    sed -i '' 's|^#include "runtime.h"|#include "runtime.c"|' "$CFILE"
fi

echo "[4/4] clang -O2 → $OUT"
clang -O2 -I self -lm "$CFILE" -o "$OUT" 2>&1 | tail -3

echo ""
echo "✓ Built: $OUT"
echo "  Run: $OUT"
