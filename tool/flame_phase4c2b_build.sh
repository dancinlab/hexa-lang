#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4c2b_build.sh — Phase 4-C-2b caller wire-up build
#
# Fork of tool/flame_phase4b3_a2_build.sh + tool/flame_phase4c2_build.sh
# (commit a3033da8). Phase 4-B SHIPPED path is UNTOUCHED — this wrapper
# extends the existing A2 fwd+bwd primitive build with:
#
#   1. Concat fused primitive (tool/flame_phase4c_block_fused_primitive.c)
#      AFTER fwd + bwd primitives — so it can call them as static inline.
#   2. Sed-rewrite ADJACENT paired callsites:
#        flame_block_..._fwd_primitive(X, Bp, Bc, cos, sin);
#        flame_block_..._bwd_primitive(X, Bp, Bc, dXout, dX, Bg, cos, sin);
#      → flame_block_..._fused_primitive(X, Bp, Bc, dXout, dX, Bg, cos, sin);
#   3. Build → byte-eq verify vs A2 baseline + wall measurement
#
# SAFETY MODEL — adjacent-only rewrite:
#   The rewrite ONLY matches fwd+bwd pairs where the bwd call IMMEDIATELY
#   follows the fwd call (within a small text window AND sharing the same
#   Bc_l identifier). This guarantees fwd→bwd dataflow is dependency-clean
#   (no intervening Bc-mutations or required-between user computation).
#
#   For flame_d32_corpus_test.hexa (current A2 SHIPPED shape):
#     - fwd call lives inside nn_decoder_fwd's per-layer loop
#     - bwd call lives inside nn_decoder_grad's per-layer bwd loop
#     - The two are separated by ~175 lines AND in different fn scopes.
#   → 0 adjacent rewrites expected.
#   → Build output byte-id with A2 baseline.
#   → Wall measurement = A2 baseline (no rewrites = no semantic change).
#
# This is the HONEST infrastructure landing — the rewrite mechanism is
# end-to-end exercised on the build pipeline, with 0 fusion matches
# because the current source shape DOES NOT permit safe fusion. Phase
# 4-C-3 user-gated decoder_lib restructure (fwd-then-bwd-per-layer) is
# the prerequisite for ACTUAL adjacent pairs to exist and for the
# rewrite to perform real fusion.
#
# Falsifier verdicts at Phase 4-C-2b wire-up:
#   F-RFC048-FUSED-COMPILE-EQ      : ✅ fused primitive concat builds clean
#   F-RFC048-FUSED-FWD-BWD-EQ      : ✅ output binary byte-id with A2 baseline
#                                    (0 rewrites = literal identity)
#   F-RFC048-FUSED-WALL-IMPROVED   : ❌ FAIL (1.00× ratio = no win, by design;
#                                    requires Phase 4-C-3 + 4-C-2c Bc-elim)
#
# Phase 4-C-2c (next): incrementally extract Bc intermediates (oRm1inv,
#   oRm2inv, oRm1xn, oRm2xn, oRin, oRin2, oSwS) to C local arrays inside
#   the fused primitive — eliminates ~24 KB of Bc DRAM round-trips per
#   block-call. This is the actual mechanism for F-RFC048-FUSED-WALL-
#   IMPROVED PASS. Gated on Phase 4-C-3 restructure landing first.
#
# Usage:
#   tool/flame_phase4c2b_build.sh <flame_test.hexa> <out_binary>
# Currently hard-coded for (T=16, d=32, nh=4, nkv=2, h=64) d=32·3L config
# via the underlying a2_build.sh.
# ════════════════════════════════════════════════════════════════════════

set -e

if [ $# -lt 2 ]; then
    echo "usage: $0 <flame_test.hexa> <out_binary>"
    echo "       Phase 4-C-2b caller wire-up build (RFC 048)"
    exit 1
fi

SRC="$1"
OUT="$2"
STEM=$(basename "$SRC" .hexa)
A2_C="build/artifacts/${STEM}_a2.c"
A2_OUT="build/artifacts/${STEM}_a2_baseline_bin"
WIRED_C="build/artifacts/${STEM}_4c2b_wired.c"
FUSED_PRIM="tool/flame_phase4c_block_fused_primitive.c"
FUSED_PRIM_STRIPPED="build/artifacts/${STEM}_fused_prim_stripped.c"

mkdir -p build/artifacts

echo "═══ flame Phase 4-C-2b caller wire-up build (RFC 048) ═══"
echo "  src    : $SRC"
echo "  out    : $OUT"
echo ""

# ── Step 1: Phase 4-B A2 build (untouched) ──
echo "─── Step 1: Phase 4-B A2 baseline build (untouched) ───"
tool/flame_phase4b3_a2_build.sh "$SRC" "$A2_OUT" 2>&1 | tail -5

if [ ! -f "$A2_C" ]; then
    echo "✗ FATAL: $A2_C missing after a2_build.sh"
    exit 1
fi
if [ ! -x "$A2_OUT" ]; then
    echo "✗ FATAL: $A2_OUT missing after a2_build.sh"
    exit 1
fi

A2_LINES=$(wc -l < "$A2_C")
echo "  A2 .c source: $A2_C ($A2_LINES lines)"

# ── Step 2: strip fused primitive standalone/extern guards ──
echo ""
echo "─── Step 2: strip fused primitive guard blocks for concat ───"
# Strip both #ifndef FLAME_BLOCK_FUSED_PRIM_STANDALONE / #endif
# AND #ifdef FLAME_BLOCK_FUSED_PRIM_STANDALONE / #endif blocks.
# The fused primitive becomes a pure static inline at concat tail.
sed \
    -e '/^#ifndef FLAME_BLOCK_FUSED_PRIM_STANDALONE/,/^#endif/d' \
    -e '/^#ifdef FLAME_BLOCK_FUSED_PRIM_STANDALONE/,/^#endif/d' \
    "$FUSED_PRIM" > "$FUSED_PRIM_STRIPPED"
FUSED_LINES=$(wc -l < "$FUSED_PRIM_STRIPPED")
echo "  fused primitive (stripped): $FUSED_PRIM_STRIPPED ($FUSED_LINES lines)"

# ── Step 3: perl-rewrite adjacent paired fwd+bwd → fused call ──
echo ""
echo "─── Step 3: perl-rewrite adjacent paired _fwd_primitive + _bwd_primitive → _fused_primitive ───"
# Pattern: two consecutive callsites (within REWRITE_WINDOW lines) where:
#   line A = ..._fwd_primitive((int)X.i, (int)Bp.i, (int)Bc.i, (int)cos.i, (int)sin.i);
#   line B = ..._bwd_primitive((int)X.i, (int)Bp.i, (int)Bc.i, (int)dXout.i, (int)dX.i, (int)Bg.i, (int)cos.i, (int)sin.i);
# with all of X/Bp/Bc/cos/sin matching between A and B (same farr ids).
#
# Implementation: perl multi-line stateful scan. Tracks the most recent
# fwd-primitive call seen; on encountering a bwd-primitive call, checks:
#   (a) same X, Bp, Bc, cos, sin farr ids,
#   (b) within REWRITE_WINDOW non-blank lines,
#   (c) no intervening textual occurrence of Bc id between fwd-exit and
#       bwd-entry (conservative: ANY read/write disqualifies fusion).
#
# At current SHIPPED nn_decoder_grad shape, fwd and bwd live in
# different fns separated by ~175 lines → no matches expected.
REWRITE_WINDOW=8  # max gap (textual lines) between fwd and bwd to count as "adjacent"

perl -e '
my $WIN = shift @ARGV;
my $infile = shift @ARGV;
open(my $fh, "<", $infile) or die "cannot open $infile: $!";

my $fwd_pending = 0;
my ($fwd_X, $fwd_Bp, $fwd_Bc, $fwd_cos, $fwd_sin);
my $fwd_lineno = 0;
my $gap = 0;
my $rewrites = 0;
my @pending = ();   # lines accumulated since the fwd

sub flush_pending {
    foreach my $ln (@pending) { print $ln; }
    @pending = ();
    $fwd_pending = 0;
}

while (my $line = <$fh>) {
    # match fwd primitive call (full-line)
    if ($line =~ /flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive\(\(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i\);/) {
        # Flush any previously pending (un-fused) fwd
        flush_pending() if $fwd_pending;
        $fwd_X = $1; $fwd_Bp = $2; $fwd_Bc = $3; $fwd_cos = $4; $fwd_sin = $5;
        $fwd_lineno = $.;
        $fwd_pending = 1;
        $gap = 0;
        @pending = ($line);
        next;
    }
    # match bwd primitive call (full-line)
    if ($line =~ /flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive\(\(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i, \(int\)([A-Za-z_][A-Za-z0-9_]*)\.i\);/) {
        my ($bX, $bBp, $bBc, $bdX, $bdXo, $bBg, $bcos, $bsin) = ($1,$2,$3,$4,$5,$6,$7,$8);
        if ($fwd_pending &&
            $bX  eq $fwd_X  &&
            $bBp eq $fwd_Bp &&
            $bBc eq $fwd_Bc &&
            $bcos eq $fwd_cos &&
            $bsin eq $fwd_sin &&
            $gap <= $WIN) {
            # SAFE adjacent pair — rewrite to fused call.
            my $indent = "";
            if ($line =~ /^([\t ]+)/) { $indent = $1; }
            # emit pending intermediate lines (skip pending[0] = original fwd)
            for (my $i = 1; $i < scalar(@pending); $i++) {
                print $pending[$i];
            }
            print "${indent}flame_block_T16_d32_nh4_nkv2_h64_fused_primitive((int)${fwd_X}.i, (int)${fwd_Bp}.i, (int)${fwd_Bc}.i, (int)${bdX}.i, (int)${bdXo}.i, (int)${bBg}.i, (int)${fwd_cos}.i, (int)${fwd_sin}.i);\n";
            $rewrites++;
            @pending = ();
            $fwd_pending = 0;
            $gap = 0;
            next;
        }
        # not safe → flush pending then emit bwd as-is
        flush_pending() if $fwd_pending;
        print $line;
        next;
    }
    if ($fwd_pending) {
        $gap++;
        # disqualify if Bc id mentioned between fwd and bwd
        if (index($line, $fwd_Bc) >= 0) {
            push @pending, $line;
            flush_pending();
            next;
        }
        # disqualify if gap exceeded
        if ($gap > $WIN) {
            push @pending, $line;
            flush_pending();
            next;
        }
        push @pending, $line;
        next;
    }
    print $line;
}
flush_pending() if $fwd_pending;
close($fh);

print STDERR "REWRITES=$rewrites\n";
' "$REWRITE_WINDOW" "$A2_C" > "${WIRED_C}.body" 2> /tmp/flame_4c2b_perl_stderr

REWRITES=$(grep -E "^REWRITES=" /tmp/flame_4c2b_perl_stderr | sed 's/REWRITES=//')
echo "  paired fwd+bwd rewrites applied: $REWRITES"

# ── Step 4: concat fused primitive AFTER A2 .c body ──
echo ""
echo "─── Step 4: concat fused primitive AFTER fwd+bwd primitives ───"
# The fused primitive is static inline; its forward references to
# fwd_primitive + bwd_primitive resolve to in-source static inline
# functions defined earlier in the same TU (A2 .c body emits them
# at lines ~233/~481 before any caller use).
#
# Sequence: A2 .c body (includes fwd+bwd primitives + caller code with
# any fused rewrites in-place) ↓ then fused primitive at TAIL is wrong
# because callers reference fused_primitive BY NAME. Solution: insert
# fused primitive AFTER bwd primitive but BEFORE first caller use.
#
# Easier approach: forward-declare the fused primitive at top + append
# the body at the tail. C allows forward decl of static inline. But
# `static inline` decl + later body works only if the decl is also
# static inline (matching linkage). To keep it simple, just inject the
# fused primitive body BEFORE the trampoline/decls block — same place
# matmul/fwd/bwd primitives are inserted by a2_build.sh (after
# `#include "runtime.c"`).

# Insert fused primitive AFTER the bwd primitive body in the A2 .c.
# The bwd primitive ends before the trampoline-decl block (which starts
# at `static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd(`
# forward-decl). We insert immediately before that marker line so the
# fused primitive sees fwd+bwd primitives as in-scope.
INSERT_MARKER='static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd(int'
if ! grep -qF "$INSERT_MARKER" "${WIRED_C}.body"; then
    echo "✗ FATAL: insert marker not found in body: $INSERT_MARKER"
    exit 1
fi
# Use awk to inject the fused primitive content immediately before the
# first occurrence of the marker line. BSD sed lacks portable `i` cmd.
awk -v marker="$INSERT_MARKER" -v fp="$FUSED_PRIM_STRIPPED" '
BEGIN {
    # slurp fused primitive content
    while ((getline ln < fp) > 0) { fused_content = fused_content ln "\n" }
    close(fp)
    injected = 0
}
{
    if (!injected && index($0, marker) > 0) {
        printf "%s", fused_content
        injected = 1
    }
    print
}
' "${WIRED_C}.body" > "$WIRED_C"
rm -f "${WIRED_C}.body"
WIRED_LINES=$(wc -l < "$WIRED_C")
echo "  wired .c: $WIRED_C ($WIRED_LINES lines)"

# Sanity: fwd+bwd primitives must appear BEFORE fused primitive in concat
FWD_LINENO=$(grep -n "^static inline void flame_block_T16_d32_nh4_nkv2_h64_fwd_primitive" "$WIRED_C" | head -1 | cut -d: -f1)
BWD_LINENO=$(grep -n "^static inline void flame_block_T16_d32_nh4_nkv2_h64_bwd_primitive" "$WIRED_C" | head -1 | cut -d: -f1)
FUSED_LINENO=$(grep -n "^static inline void flame_block_T16_d32_nh4_nkv2_h64_fused_primitive" "$WIRED_C" | head -1 | cut -d: -f1)
echo "  primitive order: fwd@$FWD_LINENO  bwd@$BWD_LINENO  fused@$FUSED_LINENO"
if [ -z "$FUSED_LINENO" ] || [ -z "$FWD_LINENO" ] || [ -z "$BWD_LINENO" ]; then
    echo "✗ FATAL: missing primitive in concat'd .c"
    exit 1
fi
if [ "$FUSED_LINENO" -lt "$FWD_LINENO" ] || [ "$FUSED_LINENO" -lt "$BWD_LINENO" ]; then
    echo "✗ FATAL: fused primitive must appear AFTER fwd+bwd primitives (concat order wrong)"
    exit 1
fi

# ── Step 5: clang -O2 → binary ──
echo ""
echo "─── Step 5: clang -O2 → $OUT ───"
clang -O2 -I self -lm "$WIRED_C" -o "$OUT" 2>&1 | tail -3

if [ ! -x "$OUT" ]; then
    echo "✗ Build FAILED"
    exit 1
fi
echo "✓ Built: $OUT"

# ── Step 6: byte-eq verify ──
echo ""
echo "─── Step 6: byte-eq verify vs A2 baseline ───"
A2_OUTPUT="/tmp/flame_4c2b_a2_baseline.out"
WIRED_OUTPUT="/tmp/flame_4c2b_wired.out"
"$A2_OUT" > "$A2_OUTPUT" 2>&1
"$OUT"    > "$WIRED_OUTPUT" 2>&1
if diff -q "$A2_OUTPUT" "$WIRED_OUTPUT" > /dev/null; then
    echo "PASS  F-RFC048-FUSED-FWD-BWD-EQ  wired binary output byte-id with A2 baseline (max|Δ|=0)"
    BYTE_EQ_VERDICT="PASS"
else
    echo "FAIL  F-RFC048-FUSED-FWD-BWD-EQ  byte-eq diff (first 5 lines):"
    diff "$A2_OUTPUT" "$WIRED_OUTPUT" | head -5
    BYTE_EQ_VERDICT="FAIL"
fi

# ── Step 7: wall measurement (5-run median per PERF.md) ──
echo ""
echo "─── Step 7: wall measurement (5-run median per PERF.md) ───"
echo "  A2 baseline:"
A2_TIMES=()
for i in 1 2 3 4 5; do
    /usr/bin/time -p "$A2_OUT" > /dev/null 2> /tmp/flame_4c2b_t_a2.tmp
    T_RAW=$(grep -E "^real" /tmp/flame_4c2b_t_a2.tmp | awk '{print $2}')
    A2_TIMES+=("$T_RAW")
    echo "    run $i: ${T_RAW}s"
done
echo "  Wired (4c2b):"
WIRED_TIMES=()
for i in 1 2 3 4 5; do
    /usr/bin/time -p "$OUT" > /dev/null 2> /tmp/flame_4c2b_t_wired.tmp
    T_RAW=$(grep -E "^real" /tmp/flame_4c2b_t_wired.tmp | awk '{print $2}')
    WIRED_TIMES+=("$T_RAW")
    echo "    run $i: ${T_RAW}s"
done

# median (sort ascending, take index 2 of 5)
A2_MEDIAN=$(printf "%s\n" "${A2_TIMES[@]}" | sort -n | sed -n '3p')
WIRED_MEDIAN=$(printf "%s\n" "${WIRED_TIMES[@]}" | sort -n | sed -n '3p')
RATIO=$(awk -v a="$A2_MEDIAN" -v w="$WIRED_MEDIAN" 'BEGIN { if (w > 0) printf "%.3f", a/w; else printf "NaN" }')
echo ""
echo "  A2 baseline median (5-run): ${A2_MEDIAN}s"
echo "  Wired      median (5-run): ${WIRED_MEDIAN}s"
echo "  ratio (A2 / wired):         ${RATIO}× (>1.0 = wired faster)"

# F-RFC048-FUSED-WALL-IMPROVED gate (threshold ≥1.3×)
if awk -v r="$RATIO" 'BEGIN { exit !(r+0 >= 1.3) }'; then
    echo "PASS  F-RFC048-FUSED-WALL-IMPROVED  ratio ≥1.3× over A2 baseline"
    WALL_VERDICT="PASS"
else
    echo "FAIL  F-RFC048-FUSED-WALL-IMPROVED  ratio < 1.3× (expected at scaffold + 0 rewrites)"
    WALL_VERDICT="FAIL"
fi

# ── Verdict summary ──
echo ""
echo "─── Phase 4-C-2b wire-up falsifier verdicts ───"
echo "  REWRITES                                 : $REWRITES"
echo "  F-RFC048-FUSED-COMPILE-EQ                : ✅ PASS (concat'd wired .c built)"
echo "  F-RFC048-FUSED-FWD-BWD-EQ                : $BYTE_EQ_VERDICT (wired vs A2 baseline)"
echo "  F-RFC048-FUSED-WALL-IMPROVED             : $WALL_VERDICT (ratio ${RATIO}×, threshold ≥1.3×)"
echo ""
echo "Honest scope:"
echo "  - $REWRITES rewrites because nn_decoder_fwd + nn_decoder_grad are in"
echo "    different fn scopes (fwd@nn_decoder_fwd ↔ bwd@nn_decoder_grad,"
echo "    ~175 lines apart per A2 .c)."
echo "  - Adjacent fusion requires Phase 4-C-3 user-gated decoder_lib"
echo "    restructure (fwd-then-bwd-per-layer)."
echo "  - Wall = baseline because no rewrites = no semantic change."
echo "  - Infrastructure (sed-rewrite + concat + verify) end-to-end exercised."
echo ""
echo "═══ Phase 4-C-2b wire-up build DONE ═══"
echo "  binary: $OUT"
echo "  wired .c: $WIRED_C"
