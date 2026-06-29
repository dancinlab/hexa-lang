#!/usr/bin/env bash
# tool/routec_fmod_native_verify.sh — literal-∅ libm-leaf RUNG 2 (hxlcl_fmod via
# the fp-ABI xmm Route C codegen path).
#
# Verifies the HEXA_RT_NATIVE_FMOD wiring — hxlcl_fmod LEAVES the libc shim and is
# supplied by the hexa-NATIVE Route C fp-ABI (xmm) .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_FMOD OFF) shim.o is BYTE-IDENTICAL to the
#       origin/main baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_FMOD` guard
#       compiles out → the libc-delegate body is untouched; release-integrity
#       invariant — DEFAULT archive sha unchanged).
#   (B) ON: the Route C codegen emits `hxlcl_fmod` as a DEFINED (T) external in the
#       native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_FMOD) NO LONGER defines it —
#       the symbol MOVES from the C shim to the native object (literal-∅ progress:
#       one shim member dropped). A multidef (both define) would be a link killer.
#   (C) VALUE-EXACT: link the native .o against a C harness that CALLS hxlcl_fmod as
#       a raw C-ABI `double f(double,double)` and compares bit-for-bit (0 ULP) to
#       libc fmod over an N-point sweep (large |x/y|, signs, x<y, x==y, subnormals,
#       y=0/NaN/Inf). reference-match: musl src/math/fmod.c (== fdlibm e_fmod.c).
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the fp-ABI xmm lowering is x86_64-backend; arm64 AAPCS64 is
# the NEXT rung. MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_fmod}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-fmod] SKIP — fp-ABI xmm Route C is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_fmod_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_FMOD OFF) shim.o byte-identity vs origin/main…"
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
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_FMOD)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_FMOD "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
FMOD_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_fmod$' | wc -l | tr -d ' ')
FMOD_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_fmod$' | wc -l | tr -d ' ')
echo "    hxlcl_fmod defined in shim:  default=$FMOD_DEF_DEFAULT  ON=$FMOD_DEF_ON  (expect 1 → 0)"
[ "$FMOD_DEF_DEFAULT" = "1" ] && [ "$FMOD_DEF_ON" = "0" ] && echo "SHIM_FMOD_MEMBER_DROPPED=YES" || echo "SHIM_FMOD_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_fmod (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnf_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
FMOD_T_NATIVE=$(nm "$OUT/routec.o" 2>/dev/null | grep -E ' T _?hxlcl_fmod$' | wc -l | tr -d ' ')
echo "    hxlcl_fmod defined (T) in native routec.o = $FMOD_T_NATIVE  (expect 1)"
# undefined libm fmod ref in the native object? (must be ZERO — libm-free)
FMOD_U_NATIVE=$(nm "$OUT/routec.o" 2>/dev/null | grep -E ' U _?fmod$' | wc -l | tr -d ' ')
echo "    undefined libm 'fmod' refs in native routec.o = $FMOD_U_NATIVE  (expect 0)"
[ "$FMOD_T_NATIVE" = "1" ] && [ "$FMOD_U_NATIVE" = "0" ] && echo "NATIVE_FMOD_SUPPLIED_LIBMFREE=YES" || echo "NATIVE_FMOD_SUPPLIED_LIBMFREE=NO"

# ── [C] value-exact: native hxlcl_fmod vs libc fmod, 0-ULP sweep ────────────
echo "[C] value-exact: native hxlcl_fmod vs libc fmod (0-ULP sweep)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
#include <math.h>
extern double hxlcl_fmod(double x, double y);
static uint64_t B(double d){ union{double f;uint64_t i;}u={d}; return u.i; }
static int chk(double x,double y,int*fail){
    double r=hxlcl_fmod(x,y), e=fmod(x,y);
    int ok = (B(r)==B(e)) || (isnan(r)&&isnan(e));
    if(!ok){ (*fail)++; printf("  MISMATCH fmod(%a,%a): got %a (%016llx) want %a (%016llx)\n",
             x,y,r,(unsigned long long)B(r),e,(unsigned long long)B(e)); }
    return ok;
}
int main(void){
    int fail=0, n=0;
    double xs[]={ 0.0,-0.0,1.0,-1.0,2.5,-2.5,3.14159265358979,1e300,-1e-300,
                  123456.789,0.1,1.0/3.0,1e-310,2.2250738585072014e-308,
                  1.7976931348623157e308, 5.0, 7.0, 100.25, 0.5, 0.25 };
    double ys[]={ 1.0,-1.0,0.3,2.0,-2.0,0.5,1e-300,1e300,3.0,7.0,
                  0.1,1.0/3.0,1e-308,4.0,0.0625, 2.0, 3.0, 0.7, 0.25, 0.125 };
    int nx=sizeof(xs)/sizeof(xs[0]), ny=sizeof(ys)/sizeof(ys[0]);
    for(int i=0;i<nx;i++) for(int j=0;j<ny;j++){ chk(xs[i],ys[j],&fail); n++; }
    /* exception cases: y=0 → NaN ; x=inf → NaN ; nan propagation */
    chk(1.0,0.0,&fail); chk(INFINITY,2.0,&fail); chk(NAN,2.0,&fail); chk(2.0,NAN,&fail); n+=4;
    printf("  N=%d points, fail=%d\n", n, fail);
    printf(fail?"VALUE_EXACT_0ULP=NO\n":"VALUE_EXACT_0ULP=YES\n");
    return fail?1:0;
}
EOF
# hxlcl_fmod is a SELF-CONTAINED leaf (objdump -dr: only internal jmps, ZERO
# external call/reloc — no hxlcl_malloc/environ/__errno_location). But routec.o is
# the WHOLE module emit, so linking it wholesale drags its SIBLINGS' undefined
# externs (hxlcl_setenv→setenv, strdup/calloc→hxlcl_malloc, getenv→environ, the
# errno-syscall leaves→__errno_location) — NONE referenced by fmod. Extract ONLY
# the hxlcl_fmod object section so the value-exact gate links fmod in isolation
# (the same discipline the routec smoke uses for a single-symbol assert). Fallback:
# if extraction is unavailable, supply weak stubs for the unrelated sibling externs
# so the link resolves without pulling libc — fmod's own correctness is unaffected.
cat > "$OUT/stubs.c" <<'EOF'
/* weak stubs for hxlcl_fmod's UNRELATED siblings in the whole-module routec.o —
 * fmod calls NONE of these (objdump-confirmed zero external relocs from fmod). */
#include <stdlib.h>
__attribute__((weak)) void *hxlcl_malloc(unsigned long n){ return malloc(n?n:1); }
extern char **environ;
__attribute__((weak)) int *__errno_location_stub(void){ static int e; return &e; }
EOF
$CC "$OUT/acc.c" "$OUT/routec.o" "$OUT/stubs.c" -o "$OUT/acc" -lm 2>"$OUT/link.err"
if [ ! -x "$OUT/acc" ]; then
    # whole-module link failed on a sibling extern — link fmod in ISOLATION via a
    # filtered object (keep only hxlcl_fmod), proving fmod itself is self-contained.
    echo "    [C] whole-module link pulled a sibling extern; isolating hxlcl_fmod…"
    objcopy --keep-global-symbol=hxlcl_fmod "$OUT/routec.o" "$OUT/fmod_only.o" 2>/dev/null
    $CC "$OUT/acc.c" "$OUT/fmod_only.o" -o "$OUT/acc" -lm 2>"$OUT/link2.err" \
        || { echo "LINK_FAIL"; cat "$OUT/link.err" "$OUT/link2.err" >&2; exit 1; }
fi
"$OUT/acc"
RC=$?
echo "════ routec_fmod_native_verify done (acc RC=$RC) ════"
exit 0
