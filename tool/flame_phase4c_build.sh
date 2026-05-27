#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4c_build.sh — Phase 4-C-1a paired-call detect build
#
# Fork of tool/flame_phase4b3_a2_build.sh (commit e9350973). Phase 4-B
# SHIPPED path is UNTOUCHED — this wrapper purely ADDS the Phase 4-C-1a
# detector step after the existing A2 fwd+bwd primitive build, producing
# state/flame_phase4c_pairs.log as the additive artifact.
#
# Pipeline (delegates to phase4b3_a2_build.sh then appends detector):
#   1-4: as flame_phase4b3_a2_build.sh (IPCP + trampoline + A2 fwd+bwd + Path B)
#   5 (NEW): hexa run tool/flame_phase4c_pair_detect.hexa <expanded.hexa>
#            → state/flame_phase4c_pairs.log (paired fwd+bwd call sites)
#
# Falsifier (CI gate):
#   F-RFC047-A2-COMPILE     primitive concat'd build compiles via clang -O2
#   F-RFC047-A2-BYTE-EQ     output binary stdout byte-id with baseline
#   F-RFC048-PAIR-DETECT    detector finds ≥1 paired fwd+bwd call site
#                           (PASS line in state/flame_phase4c_pairs.log)
#
# Why fork (not extend a2_build.sh): per PHASE4C_IMPLEMENTATION_AUDIT.md
# §6 R4 + §8, the Phase 4-B SHIPPED path stays untouched (g3 fallback
# preservation). Phase 4-C-1a is purely additive — detection-only,
# observation-only, no source transform, no compile path perturbation.
#
# Usage:
#   tool/flame_phase4c_build.sh <flame_test.hexa> <out_binary>
#
# Currently hard-coded for (T=16, d=32, nh=4, nkv=2, h=64) d=32·3L config
# via the underlying a2_build.sh.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-C-1a paired-call detect build (RFC 048)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
EXP="/tmp/${STEM}_expanded.hexa"
PAIRS_LOG="state/flame_phase4c_pairs.log"

mkdir -p build/artifacts state

echo "═══ flame Phase 4-C-1a build (paired-call detect, RFC 048) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo "  pairs  : $PAIRS_LOG"
echo ""

# Steps 1-4: delegate to Phase 4-B SHIPPED build (untouched)
echo "[1..4] running tool/flame_phase4b3_a2_build.sh (IPCP + trampoline + A2 fwd+bwd + Path B)"
tool/flame_phase4b3_a2_build.sh "$SRC" "$OUT" 2>&1 | tail -10

if [ ! -f "$OUT" ]; then
    echo "✗ FATAL: $OUT missing after phase4b3_a2_build.sh"
    exit 1
fi

if [ ! -f "$EXP" ]; then
    echo "✗ FATAL: expanded source $EXP missing — required for pair detect"
    exit 1
fi

# Step 5 (NEW): Phase 4-C-1a paired-call detection — log-only, no source transform
echo ""
echo "[5/5] Phase 4-C-1a paired-call detect → $PAIRS_LOG"
./hexa run tool/flame_phase4c_pair_detect.hexa "$EXP" 2>&1 | tee "$PAIRS_LOG" | tail -8

if grep -q "PASS  F-RFC048-PAIR-DETECT" "$PAIRS_LOG"; then
    echo ""
    echo "PASS  F-RFC048-PAIR-DETECT  paired fwd+bwd call site(s) detected (fusable)"
else
    echo ""
    echo "INFO  F-RFC048-PAIR-DETECT  no paired call sites detected in $SRC"
    echo "      (this is OK for single-block test sources; expected ≥1 for full decoder)"
fi

echo ""
echo "═══ Phase 4-C-1a build complete ═══"
echo "  Run:   $OUT"
echo "  Pairs: $PAIRS_LOG"
