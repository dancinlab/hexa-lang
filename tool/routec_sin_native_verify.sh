#!/usr/bin/env bash
# tool/routec_sin_native_verify.sh — literal-∅ libm-leaf RUNG 3 (hxlcl_sin via the
# fp-ABI xmm Route C codegen path).
#
# Verifies the HEXA_RT_NATIVE_SIN wiring — hxlcl_sin LEAVES the libc shim and is
# supplied by the hexa-NATIVE Route C fp-ABI (xmm) .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_SIN OFF) shim.o is BYTE-IDENTICAL to the origin/main
#       baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_SIN` guard compiles out →
#       the libc-delegate body is untouched; release-integrity invariant).
#   (B) ON: the Route C codegen emits `hxlcl_sin` (with the __sin/__cos kernels inlined
#       into its body) as a DEFINED (T) external in the native .o, AND the
#       ON shim.o (-DHEXA_RT_NATIVE_SIN) NO LONGER defines hxlcl_sin — the symbol
#       MOVES from the C shim to the native object (literal-∅ progress: one member
#       dropped). NO undefined libm `sin` ref in the native object (libm-free).
#   (C) VALUE-EXACT: link the native .o against a C harness that CALLS hxlcl_sin as a
#       raw C-ABI `double f(double)` and compares to libc sin over an N-point sweep
#       INSIDE the covered domain (|x| < 2^20*pi/2 ≈ 1.647e6 — the small + medium
#       argument-reduction paths). musl's reduction is NEARLY-ROUNDED (≤1 ULP), so the
#       gate asserts max|ULP| ≤ 1 (NOT 0-ULP — glibc sin is a different correctly-
#       rounded algorithm). reference-match: musl src/math/{sin,__sin,__cos,
#       __rem_pio2}.c. The LARGE path (Payne-Hanek __rem_pio2_large) is NOT ported —
#       the sweep stays inside the covered domain.
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY. MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_sin}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-sin] SKIP — fp-ABI xmm Route C is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_sin_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_SIN OFF) shim.o byte-identity vs origin/main…"
BN=runtime_core_hxlcl_shim.c
rm -rf "$OUT/base" "$OUT/new"; mkdir -p "$OUT/base" "$OUT/new"
git show "origin/main:$SHIM" > "$OUT/base/$BN" 2>/dev/null || cp "$SHIM" "$OUT/base/$BN"
cp "$SHIM" "$OUT/new/$BN"
( cd "$OUT/base" && $CC $CFLAGS "$BN" -o shim.o 2>err )
( cd "$OUT/new"  && $CC $CFLAGS "$BN" -o shim.o 2>err )
objcopy -O binary --only-section=.text "$OUT/base/shim.o" "$OUT/base.text" 2>/dev/null
objcopy -O binary --only-section=.text "$OUT/new/shim.o"  "$OUT/new.text"  2>/dev/null
TB=$(sha256sum "$OUT/base.text" 2>/dev/null | cut -d' ' -f1)
TN=$(sha256sum "$OUT/new.text"  2>/dev/null | cut -d' ' -f1)
echo "    .text base sha=$TB"
echo "    .text new  sha=$TN"
[ "$TB" = "$TN" ] && echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES" || echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=NO"

# ── [D] shim member count: default vs ON ────────────────────────────────────
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_SIN)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_SIN "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
SIN_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_sin$' | wc -l | tr -d ' ')
SIN_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_sin$' | wc -l | tr -d ' ')
echo "    hxlcl_sin defined in shim:  default=$SIN_DEF_DEFAULT  ON=$SIN_DEF_ON  (expect 1 → 0)"
[ "$SIN_DEF_DEFAULT" = "1" ] && [ "$SIN_DEF_ON" = "0" ] && echo "SHIM_SIN_MEMBER_DROPPED=YES" || echo "SHIM_SIN_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_sin (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rns_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
SIN_T_NATIVE=$(nm "$OUT/routec.o" 2>/dev/null | grep -E ' T _?hxlcl_sin$' | wc -l | tr -d ' ')
echo "    hxlcl_sin defined (T) in native routec.o = $SIN_T_NATIVE  (expect 1; __sin/__cos kernels inlined)"
# undefined libm sin/cos ref in the native object? (must be ZERO — libm-free)
SIN_U_NATIVE=$(nm "$OUT/routec.o" 2>/dev/null | grep -E ' U _?(sin|cos)$' | wc -l | tr -d ' ')
echo "    undefined libm 'sin'/'cos' refs in native routec.o = $SIN_U_NATIVE  (expect 0)"
[ "$SIN_T_NATIVE" = "1" ] && [ "$SIN_U_NATIVE" = "0" ] && echo "NATIVE_SIN_SUPPLIED_LIBMFREE=YES" || echo "NATIVE_SIN_SUPPLIED_LIBMFREE=NO"

# ── [C] value-exact: native hxlcl_sin vs libc sin, ≤1-ULP sweep (covered domain) ──
echo "[C] value-exact: native hxlcl_sin vs libc sin (≤1-ULP sweep, |x|<2^20*pi/2)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <stdlib.h>
extern double hxlcl_sin(double x);
static uint64_t B(double d){ union{double f;uint64_t i;}u={d}; return u.i; }
/* signed ULP distance between two finite doubles (monotone-ordered bit trick). */
static long long ulp(double a, double b){
    int64_t ia=(int64_t)B(a), ib=(int64_t)B(b);
    if(ia<0) ia=(int64_t)0x8000000000000000ULL - ia;
    if(ib<0) ib=(int64_t)0x8000000000000000ULL - ib;
    long long d = ia-ib; return d<0?-d:d;
}
int main(void){
    long long maxulp=0, worst_n=0; int fail=0, n=0;
    /* dense sweep across the covered domain: small (|x|<9pi/4) + medium reduction. */
    double base[]={ 0.0, 1e-30, 1e-8, 0.1, 0.5, 0.7853981633974483 /*pi/4*/,
        1.0, 1.5707963267948966 /*pi/2*/, 2.0, 3.141592653589793 /*pi*/,
        4.0, 4.71238898038469 /*3pi/2*/, 6.283185307179586 /*2pi*/, 7.0, 10.0,
        100.0, 1000.0, 12345.6789, 100000.5, 1000000.25, 1600000.0 /*inside medium*/ };
    int nb=sizeof(base)/sizeof(base[0]);
    for(int i=0;i<nb;i++){
        for(int s=-1;s<=1;s+=2){
            double x=s*base[i];
            double r=hxlcl_sin(x), e=sin(x);
            long long u = (isnan(r)&&isnan(e))?0:ulp(r,e);
            if(u>maxulp){ maxulp=u; worst_n=(long long)n; }
            if(u>1){ fail++; if(fail<=12) printf("  >1ULP sin(%.17g): got %.17g want %.17g ulp=%lld\n", x, r, e, u); }
            n++;
        }
    }
    /* pseudo-random dense sweep inside the covered domain */
    srand(12345);
    for(int i=0;i<4000;i++){
        double x = ((double)rand()/RAND_MAX*2.0-1.0) * 1.6e6;  /* |x| < 1.6e6 */
        double r=hxlcl_sin(x), e=sin(x);
        long long u = (isnan(r)&&isnan(e))?0:ulp(r,e);
        if(u>maxulp){ maxulp=u; worst_n=(long long)n; }
        if(u>1){ fail++; if(fail<=12) printf("  >1ULP sin(%.17g): got %.17g want %.17g ulp=%lld\n", x, r, e, u); }
        n++;
    }
    printf("  N=%d points, max|ULP|=%lld (worst idx %lld), fail(>1ULP)=%d\n", n, maxulp, worst_n, fail);
    printf(fail?"VALUE_LE1ULP=NO\n":"VALUE_LE1ULP=YES\n");
    printf("MAX_ULP=%lld\n", maxulp);
    return fail?1:0;
}
EOF
# hxlcl_sin is SELF-CONTAINED (kernels inlined; no external call/reloc). routec.o is
# the WHOLE module emit, so wholesale linking drags siblings' undefined externs (setenv/
# malloc/environ/__errno_location — NONE referenced by sin). Keep only hxlcl_sin so the
# value-exact gate links sin in isolation. Fallback: weak stubs for siblings.
cat > "$OUT/stubs.c" <<'EOF'
#include <stdlib.h>
__attribute__((weak)) void *hxlcl_malloc(unsigned long n){ return malloc(n?n:1); }
EOF
$CC "$OUT/acc.c" "$OUT/routec.o" "$OUT/stubs.c" -o "$OUT/acc" -lm 2>"$OUT/link.err"
if [ ! -x "$OUT/acc" ]; then
    echo "    [C] whole-module link pulled a sibling extern; isolating hxlcl_sin…"
    objcopy --keep-global-symbol=hxlcl_sin "$OUT/routec.o" "$OUT/sin_only.o" 2>/dev/null
    $CC "$OUT/acc.c" "$OUT/sin_only.o" -o "$OUT/acc" -lm 2>"$OUT/link2.err" \
        || { echo "LINK_FAIL"; cat "$OUT/link.err" "$OUT/link2.err" >&2; exit 1; }
fi
"$OUT/acc"
RC=$?
echo "════ routec_sin_native_verify done (acc RC=$RC) ════"
exit 0
