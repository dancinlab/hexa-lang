#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4b3_build.sh — flame Phase 4-B-3-2 build wrapper
#
# Extends tool/flame_phase4b_build.sh (Phase 4-B-2 IPCP) with Phase
# 4-B-3-2 caller wire-up + trampoline emit. Produces a binary where
# the IPCP-rewritten call sites invoke specialized trampolines that
# currently forward to the existing HexaVal fn (fallback path, no
# perf gain yet — captures the integration mechanism).
#
# Pipeline:
#   1. module_loader flatten          → /tmp/<stem>_expanded.hexa
#   2. flame_phase4b_ipcp rewriter     → /tmp/<stem>_ipcp.hexa
#   3. hexa_v2 transpile               → build/artifacts/<stem>_ipcp.c
#   3.5 (NEW) flame_phase4b3_emit_trampoline → trampoline.c + decls.c
#   3.6 (NEW) sed-rewrite call sites  → build/artifacts/<stem>_b3_rewritten.c
#   3.7 (NEW) sed-insert decls + cat trampoline → build/artifacts/<stem>_b3.c
#   4. clang -O2                       → output binary
#
# Falsifier:
#   F-RFC047-CALL-REWRITE-BYTE-EQ — output binary stdout byte-id with
#   baseline (since trampolines forward to existing HexaVal fn)
#
# Usage:
#   tool/flame_phase4b3_build.sh <flame_test.hexa> <out_binary>
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-B-3-2 trampoline-wired build (RFC 047)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
EXP="/tmp/${STEM}_expanded.hexa"
IPCP="/tmp/${STEM}_ipcp.hexa"
CFILE="build/artifacts/${STEM}_ipcp.c"
TRAMP="build/artifacts/${STEM}_trampoline.c"
DECLS="build/artifacts/${STEM}_decls.c"
REWRITTEN="build/artifacts/${STEM}_b3_rewritten.c"
B3="build/artifacts/${STEM}_b3.c"

mkdir -p build/artifacts

INTERP=$(find /Users/ghost/.hx/packages/hexa/build -name "hexa_interp.real" 2>/dev/null | head -1)
# Select the EXACT canonical transpiler — never a `hexa_v2*` glob.
# `find -name "hexa_v2*" | head -1` returns directory order and can pick
# self/native/hexa_v2_baseline (an Apr-15 stale binary that strips
# multi-line fn signatures → dropped params → undeclared identifiers).
if [ -x self/native/hexa_v2 ]; then
    V2="self/native/hexa_v2"
else
    V2=$(find self/native -name "hexa_v2" 2>/dev/null | head -1)
fi

if [ -z "$INTERP" ] || [ -z "$V2" ]; then
    echo "FATAL: cannot locate interp or hexa_v2"
    exit 2
fi

echo "═══ flame Phase 4-B-3-2 build (trampoline-wired, RFC 047) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo ""

echo "[1/4] module_loader flatten → $EXP"
"$INTERP" self/module_loader.hexa "$SRC" "$EXP" 2>&1 | tail -1

echo "[2/4] IPCP rewrite → $IPCP"
./hexa run tool/flame_phase4b_ipcp.hexa "$EXP" "$IPCP" 2>&1 | grep -E "PASS|FAIL|substitutions|total" | head -10

echo "[3/4] hexa_v2 transpile → $CFILE"
"$V2" "$IPCP" "$CFILE" 2>&1 | tail -1
# Restore single-TU `#include "runtime.c"` — the canonical hexa_v2 emits
# `#include "runtime.h"` (separate-TU) but step 3.7 sed-inserts decls
# after the `#include "runtime.c"` anchor, and clang never links
# runtime.c separately. See flame_phase4b_build.sh for the rationale.
if grep -q '^#include "runtime.h"' "$CFILE"; then
    sed -i '' 's|^#include "runtime.h"|#include "runtime.c"|' "$CFILE"
fi

echo "[3.5] emit trampolines + decls"
./hexa run tool/flame_phase4b3_emit_trampoline.hexa "$IPCP" "$TRAMP" "$DECLS" 2>&1 | grep -E "PASS|FAIL|emitted" | head -10

echo "[3.6] sed-rewrite call sites → $REWRITTEN"
# Currently hard-coded for d=32·3L dims (T=16, d=32, nh=4, nkv=2, h=64).
# Future work: parse dims from emitted decls + generate sed program.
sed -E '
s|nn_decoder_block_fwd\(([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), hexa_int\(16\), hexa_int\(32\), hexa_int\(4\), hexa_int\(2\), hexa_int\(64\)\);|flame_block_T16_d32_nh4_nkv2_h64_fwd((int)\1.i, (int)\2.i, (int)\3.i, (int)\4.i, (int)\5.i);|
s|nn_decoder_block_bwd\(([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), ([A-Za-z_]+), hexa_int\(16\), hexa_int\(32\), hexa_int\(4\), hexa_int\(2\), hexa_int\(64\)\);|flame_block_T16_d32_nh4_nkv2_h64_bwd((int)\1.i, (int)\2.i, (int)\3.i, (int)\4.i, (int)\5.i, (int)\6.i, (int)\7.i, (int)\8.i);|
' "$CFILE" > "$REWRITTEN"

echo "[3.7] insert decls + append trampoline → $B3"
sed '/^#include "runtime.c"/r '"$DECLS" "$REWRITTEN" > "${B3}.tmp"
cat "${B3}.tmp" "$TRAMP" > "$B3"
rm -f "${B3}.tmp"

echo "[4/4] clang -O2 → $OUT"
clang -O2 -I self -lm "$B3" -o "$OUT" 2>&1 | tail -3

if [ -f "$OUT" ]; then
    echo ""
    echo "✓ Built: $OUT"
    echo "  Run: $OUT"
else
    echo "✗ Build FAILED"
    exit 1
fi
