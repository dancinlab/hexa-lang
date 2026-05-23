#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d7_a2_build.sh — Phase 4-D-7 GPU-RESIDENT A2 build
#
# Forks tool/flame_phase4d6_a2_build.sh. Same dimension-generic pipeline,
# but concats the Phase 4-D-7 GPU-RESIDENT block primitives instead of the
# Phase 4-D-6 CPU-loop ones:
#   tool/flame_phase4d7_block_fwd_primitive.c   (GPU-resident A2 fwd)
#   tool/flame_phase4d7_block_bwd_primitive.c   (GPU-resident A2 bwd)
#   tool/flame_phase4d6_matmul_primitives.c     (reused — Layer-2 cuBLAS)
#
# The phase4d7 primitives dimension-gate on FLAME_GPU_RESIDENT_THRESHOLD
# (default 256):
#   - d ≤ threshold (e.g. d=32·3L): CPU loop, byte-identical to phase4d6 →
#     F-RFC047-A2-PATHB-FULL-BYTE-EQ holds; verify_all 26/26 unaffected
#     (verify_all uses flame_phase4b3_a2_build.sh — a different pipeline).
#   - d  > threshold (e.g. d=768·12L): GPU-resident — model weights + cache
#     uploaded once per block (farr_to_device), non-matmul ops dispatched
#     to forge Phase B kernels, attention contractions to cuBLAS, result
#     downloaded once (farr_to_host). RoPE stays CPU (forge RoPE kernel
#     not yet shipped — RFC 041 gap, honest carve-out).
#
# Pipeline (identical to phase4d6):
#   1. module_loader flatten           → /tmp/<stem>_expanded.hexa
#   2. flame_phase4b_ipcp rewriter      → /tmp/<stem>_ipcp.hexa
#   3. hexa_v2 transpile + runtime.c restore → build/artifacts/<stem>_ipcp.c
#   4. dim-generic sed-rewrite block_fwd/bwd call sites
#   5. concat phase4d7 primitives after #include "runtime.c"
#   6. clang -O2 [optional -DHEXA_CUDA] → out binary
#
# Falsifiers:
#   F-RFC047-A2-COMPILE              primitive-concat'd build compiles
#   F-RFC047-A2-PATHB-FULL-BYTE-EQ   d=32·3L output byte-id with baseline
#   F-RFC046-GPU-RESIDENT            d≥threshold path = GPU-resident kernel
#                                    sequence (verified at GPU fire #6)
#
# Usage:
#   tool/flame_phase4d7_a2_build.sh <flame_test.hexa> <out_binary> [flags]
#   --cuda       add -DHEXA_CUDA (GPU branch — on no-CUDA Mac fails to LINK;
#                use a separate `clang -c` syntactic check)
#   --build-only skip the run + byte-eq step. REQUIRED for d=768·12L.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary> [--cuda] [--build-only]"
    echo "       Phase 4-D-7 GPU-resident A2 primitive build"
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
PRIM_FWD="tool/flame_phase4d7_block_fwd_primitive.c"
PRIM_BWD="tool/flame_phase4d7_block_bwd_primitive.c"
PRIM_FWD_STRIPPED="build/artifacts/${STEM}_d7_prim_fwd_stripped.c"
PRIM_BWD_STRIPPED="build/artifacts/${STEM}_d7_prim_bwd_stripped.c"
REDIRECTED="build/artifacts/${STEM}_d7_redirected.c"
A2_C="build/artifacts/${STEM}_d7_a2.c"

mkdir -p build/artifacts

echo "═══ flame Phase 4-D-7 GPU-resident A2 build ═══"
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
# Identical regex to phase4d6 — the rewrite target fn names
# (flame_block_generic_{fwd,bwd}_primitive) are unchanged; phase4d7 just
# redefines those names as the dimension-gated CPU/GPU dispatch wrappers.
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

echo "[5/6] strip standalone blocks + concat phase4d7 primitives → $A2_C"
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
    "$OUT" > /tmp/d7_a2_check.out 2>&1
    if diff -q /tmp/baseline.out /tmp/d7_a2_check.out > /dev/null; then
        echo "PASS  F-RFC047-A2-PATHB-FULL-BYTE-EQ  output byte-id with /tmp/baseline.out"
        echo "      (d=32·3L → CPU path, FLAME_GPU_RESIDENT_THRESHOLD not crossed)"
    else
        echo "FAIL  byte-eq diff:"
        diff /tmp/baseline.out /tmp/d7_a2_check.out | head -8
        exit 1
    fi
else
    echo "SKIP  /tmp/baseline.out missing — byte-eq gate not run."
fi

echo ""
echo "═══ Phase 4-D-7 GPU-resident A2 build complete ═══"
echo "  Run: $OUT"
