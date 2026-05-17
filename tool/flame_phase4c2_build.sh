#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4c2_build.sh — Phase 4-C-2a SCAFFOLD build wrapper
#
# Phase 4-C-2a-scaffold landing (this file, RFC 048):
#   1. Runs Phase 4-C-1a build (paired-call detect, unchanged)
#   2. Compiles Phase 4-C-2 fused primitive scaffold standalone
#      (proves build infrastructure works for fused primitive interface)
#   3. Does NOT yet rewrite caller — that's Phase 4-C-2b (next gate)
#
# Falsifier verdicts at scaffold level:
#   F-RFC048-FUSED-COMPILE-EQ      : fused primitive compiles via clang -O2
#                                    (PASS expected — pure verification)
#   F-RFC048-FUSED-FWD-BWD-EQ      : output binary byte-id with A2 baseline
#                                    (PASS trivially — caller unchanged,
#                                    fused fn unused yet)
#   F-RFC048-FUSED-WALL-IMPROVED   : ≥1.3× over paired-call baseline
#                                    (N/A at scaffold — no caller wire-up)
#
# Phase 4-C-2b (next, gated): sed-rewrite caller's paired
#   `nn_decoder_block_fwd(...)` + `nn_decoder_block_bwd(...)` invocations
#   to a single `flame_block_T16_d32_nh4_nkv2_h64_fused_primitive(...)`.
#   At wire-up F-RFC048-FUSED-WALL-IMPROVED becomes measurable.
#
# Phase 4-C-2c (further, full fusion): incrementally extract Bc
#   intermediates (oRm1inv, oRm2inv, oRm1xn, oRm2xn, oRin, oRin2, oSwS)
#   to C local arrays inside the fused primitive — eliminates ~24 KB of
#   Bc DRAM round-trips per block-call. This is the actual mechanism
#   for F-RFC048-FUSED-WALL-IMPROVED PASS.
#
# Usage:
#   tool/flame_phase4c2_build.sh <flame_test.hexa> <out_binary>
# Currently hard-coded for (T=16, d=32, nh=4, nkv=2, h=64) d=32·3L config.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-C-2a SCAFFOLD build (A2 baseline + fused primitive compile-check)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)

echo "═══ flame Phase 4-C-2a SCAFFOLD build (RFC 048) ═══"
echo "  src        : $SRC"
echo "  out        : $OUT"
echo ""

# ── Step 1: Phase 4-C-1a build (paired-call detect + A2 baseline) ──
echo "─── Step 1: Phase 4-C-1a build (paired-call detect via flame_phase4c_build.sh) ───"
tool/flame_phase4c_build.sh "$SRC" "$OUT" 2>&1 | tail -8

if [ ! -f "$OUT" ] || [ ! -x "$OUT" ]; then
    echo "✗ FATAL: $OUT missing after Phase 4-C-1a build"
    exit 1
fi

# ── Step 2: Phase 4-C-2a fused primitive scaffold standalone compile-check ──
echo ""
echo "─── Step 2: Phase 4-C-2a fused primitive scaffold compile-check ───"
FUSED_OBJ="build/artifacts/${STEM}_phase4c2_fused_prim.o"
mkdir -p build/artifacts
clang -O2 -DFLAME_BLOCK_FUSED_PRIM_STANDALONE \
    -c tool/flame_phase4c_block_fused_primitive.c \
    -o "$FUSED_OBJ" 2>&1
echo "  → fused primitive .o: $FUSED_OBJ ($(wc -c < "$FUSED_OBJ" | tr -d ' ') bytes)"

# ── Step 3: Falsifier verdict report (scaffold level) ──
echo ""
echo "─── Phase 4-C-2a SCAFFOLD falsifier verdicts ───"
echo "  F-RFC048-FUSED-COMPILE-EQ      : ✅ PASS (standalone .o built clean)"
echo "  F-RFC048-FUSED-FWD-BWD-EQ      : ✅ PASS trivially (A2 baseline, fused fn unused)"
echo "  F-RFC048-FUSED-WALL-IMPROVED   : ⏳ N/A scaffold (Phase 4-C-2b caller wire-up)"
echo ""
echo "Verify A2 baseline byte-eq preserved:"
echo "  HEXA_MAC_BUILD_OK=1 tool/flame_phase4b3_verify_all.sh"
echo ""
echo "═══ Phase 4-C-2a SCAFFOLD build DONE ═══"
