#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d6_a2_build.sh — Phase 4-D-6 dimension-generic A2 build
#
# Dimension-generic successor to tool/flame_phase4b3_a2_build.sh. Builds an
# A2-primitive binary for ANY flame test source whose decoder-block calls
# carry a top-level (T,d,nh,nkv,h) 5-tuple — d=32·3L OR d=768·12L OR any
# config — by capturing the IPCP-folded dim literals from the call site
# instead of hardcoding T16_d32_nh4_nkv2_h64.
#
# What is generic now (vs flame_phase4b3_a2_build.sh):
#   - block primitives: flame_block_generic_{fwd,bwd}_primitive take dims
#     as runtime fn args (tool/flame_phase4d6_block_{fwd,bwd}_primitive.c)
#   - matmul primitives: flame_proj_batch_generic_primitive +
#     flame_grad_accum_generic_primitive take dims as args
#     (tool/flame_phase4d6_matmul_primitives.c)
#   - call-site sed: a single dim-agnostic regex captures the 5 farr args
#     AND the 5 dim literals (hexa_int(N)) and forwards both to the
#     generic primitive — no per-config sed program
#
# Pipeline:
#   1. module_loader flatten           → /tmp/<stem>_expanded.hexa
#   2. flame_phase4b_ipcp rewriter      → /tmp/<stem>_ipcp.hexa
#   3. hexa_v2 transpile + runtime.c restore → build/artifacts/<stem>_ipcp.c
#   4. dim-generic sed-rewrite block_fwd/bwd call sites
#   5. concat generic primitives after #include "runtime.c"
#   6. clang -O2 [optional -DHEXA_CUDA] → out binary
#
# Falsifiers:
#   F-RFC047-A2-COMPILE        primitive-concat'd build compiles via clang -O2
#   F-RFC047-A2-PATHB-FULL-BYTE-EQ   d=32·3L output byte-id with baseline
#
# Usage:
#   tool/flame_phase4d6_a2_build.sh <flame_test.hexa> <out_binary> [flags]
#
#   --cuda       add -DHEXA_CUDA (the GPU branch — on a no-CUDA Mac this
#                fails to LINK; use a separate `clang -c` syntactic check).
#   --build-only skip the run + byte-eq step. REQUIRED for d=768·12L,
#                whose ~10 GB resident set forbids local execution.
#
# Flags are positional-free — pass any of them as $3 / $4.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary> [--cuda] [--build-only]"
    echo "       Phase 4-D-6 dimension-generic A2 primitive build (RFC 047)"
    exit 1
fi

SRC="$1"
OUT="$2"
CUDA_FLAG=""
BUILD_ONLY=0
for arg in "$3" "$4"; do
    case "$arg" in
        --cuda)       CUDA_FLAG="-DHEXA_CUDA";;
        --build-only) BUILD_ONLY=1;;
    esac
done

STEM=$(basename "$SRC" .hexa)
EXP="/tmp/${STEM}_expanded.hexa"
IPCP="/tmp/${STEM}_ipcp.hexa"
CFILE="build/artifacts/${STEM}_ipcp.c"
PRIM_MATMUL="tool/flame_phase4d6_matmul_primitives.c"
PRIM_FWD="tool/flame_phase4d6_block_fwd_primitive.c"
PRIM_BWD="tool/flame_phase4d6_block_bwd_primitive.c"
PRIM_FWD_STRIPPED="build/artifacts/${STEM}_d6_prim_fwd_stripped.c"
PRIM_BWD_STRIPPED="build/artifacts/${STEM}_d6_prim_bwd_stripped.c"
REDIRECTED="build/artifacts/${STEM}_d6_redirected.c"
A2_C="build/artifacts/${STEM}_d6_a2.c"

mkdir -p build/artifacts

echo "═══ flame Phase 4-D-6 dimension-generic A2 build (RFC 047) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo "  cuda   : ${CUDA_FLAG:-<no-CUDA>}"
echo ""

INTERP=$(tool/find_local_hexa.sh 2>/dev/null || true)
if [ -x self/native/hexa_v2 ]; then
    V2="self/native/hexa_v2"
else
    V2=$(find self/native -name "hexa_v2" 2>/dev/null | head -1)
fi
if [ -z "$INTERP" ] || [ -z "$V2" ]; then
    echo "FATAL: cannot locate a hexa driver or hexa_v2"
    exit 2
fi

echo "[1/6] module_loader flatten → $EXP"
"$INTERP" run self/module_loader.hexa "$SRC" "$EXP" 2>&1 | tail -1

echo "[2/6] IPCP rewrite → $IPCP"
./hexa run tool/flame_phase4b_ipcp.hexa "$EXP" "$IPCP" 2>&1 | grep -E "PASS|FAIL|substitutions|total" | head -10

echo "[3/6] hexa_v2 transpile → $CFILE"
"$V2" "$IPCP" "$CFILE" 2>&1 | tail -1
if grep -q '^#include "runtime.h"' "$CFILE"; then
    sed -i '' 's|^#include "runtime.h"|#include "runtime.c"|' "$CFILE"
fi
if [ ! -f "$CFILE" ]; then
    echo "✗ FATAL: $CFILE missing after transpile"
    exit 2
fi

echo "[4/6] dim-generic sed-rewrite block_fwd/bwd call sites → $REDIRECTED"
# Capture 5/8 farr args + the WHOLE dim-literal tail as ONE group (POSIX
# sed backrefs stop at \9, so 10/13-group regexes would mis-bind \10).
# Pass A: rename fn + box-strip farr args, keep the hexa_int(...) tail.
# Pass B: on the generic-primitive lines only, unwrap hexa_int(N) → N.
# Works for ANY config — the dim values come from the IPCP-folded literals.
sed -E '
s|nn_decoder_block_fwd\(([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), (hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\))\);|flame_block_generic_fwd_primitive((int)\1.i, (int)\2.i, (int)\3.i, (int)\4.i, (int)\5.i, \6);|g
s|nn_decoder_block_bwd\(([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), ([A-Za-z_][A-Za-z0-9_]*), (hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\), hexa_int\([0-9]+\))\);|flame_block_generic_bwd_primitive((int)\1.i, (int)\2.i, (int)\3.i, (int)\4.i, (int)\5.i, (int)\6.i, (int)\7.i, (int)\8.i, \9);|g
/flame_block_generic_/ s|hexa_int\(([0-9]+)\)|\1|g
' "$CFILE" > "$REDIRECTED"

FWD_HITS=$(grep -c 'flame_block_generic_fwd_primitive(' "$REDIRECTED" || true)
BWD_HITS=$(grep -c 'flame_block_generic_bwd_primitive(' "$REDIRECTED" || true)
echo "  rewrites: fwd=${FWD_HITS}  bwd=${BWD_HITS}"
if [ "$FWD_HITS" -eq 0 ]; then
    echo "✗ FATAL: no block_fwd call site rewritten — check IPCP fold + sed regex"
    exit 2
fi

echo "[5/6] strip standalone blocks + concat generic primitives → $A2_C"
sed '/^#ifdef FLAME_BLOCK_PRIM_STANDALONE/,/^#endif/d' "$PRIM_FWD" > "$PRIM_FWD_STRIPPED"
sed '/^#ifdef FLAME_BLOCK_BWD_PRIM_STANDALONE/,/^#endif/d' "$PRIM_BWD" > "$PRIM_BWD_STRIPPED"
# Order: matmul primitives FIRST (block fwd/bwd reference them).
cat "$PRIM_MATMUL" "$PRIM_FWD_STRIPPED" "$PRIM_BWD_STRIPPED" > "${A2_C}.tmp_prims"
sed '/^#include "runtime.c"/r '"${A2_C}.tmp_prims" "$REDIRECTED" > "$A2_C"
rm -f "${A2_C}.tmp_prims"
echo "  concat'd: $A2_C ($(wc -l < "$A2_C") lines)"

echo "[6/6] clang -O2 ${CUDA_FLAG} → $OUT"
clang -O2 $CUDA_FLAG -I self -lm "$A2_C" -o "$OUT" 2>&1 | tail -3

if [ ! -f "$OUT" ]; then
    echo "✗ Build FAILED  (F-RFC047-A2-COMPILE)"
    exit 1
fi
echo "✓ Built: $OUT  (F-RFC047-A2-COMPILE PASS)"
echo ""

# Run + byte-eq check (only for runnable configs — d=768·12L must NOT run).
echo "─── byte-eq verification ───"
if [ "$BUILD_ONLY" -eq 1 ]; then
    echo "SKIP  --build-only set — binary NOT executed."
    echo "      (required for d=768·12L: ~10 GB resident, run = GPU fire only)"
elif [ -f /tmp/baseline.out ]; then
    "$OUT" > /tmp/d6_a2_check.out 2>&1
    if diff -q /tmp/baseline.out /tmp/d6_a2_check.out > /dev/null; then
        echo "PASS  F-RFC047-A2-PATHB-FULL-BYTE-EQ  output byte-id with /tmp/baseline.out"
    else
        echo "FAIL  byte-eq diff:"
        diff /tmp/baseline.out /tmp/d6_a2_check.out | head -8
        exit 1
    fi
else
    echo "SKIP  /tmp/baseline.out missing — byte-eq gate not run."
fi

echo ""
echo "═══ Phase 4-D-6 A2 build complete ═══"
echo "  Run: $OUT"
