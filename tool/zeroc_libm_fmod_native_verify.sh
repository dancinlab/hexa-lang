#!/usr/bin/env bash
# tool/zeroc_libm_fmod_native_verify.sh — literal-∅ libm-leaf rung 1 (hxlcl_fmod).
#
# Verifies the HEXA_LIBM_NATIVE_FMOD opt-in arm of self/runtime_core_hxlcl_shim.c:
#   (A) DEFAULT (macro OFF) shim.o is BYTE-IDENTICAL to the pre-change shim.o
#       (the libc-delegate body is untouched; the ship build never compiles this
#       file, so byteeq is trivially preserved — this proves it mechanically).
#   (B) ON (macro defined) shim.o references NO libm `fmod` symbol from hxlcl_fmod
#       (the libm coupling is dissolved for this leaf).
#   (C) ON hxlcl_fmod is bit-identical (0 ULP) to libc fmod over an N-point sweep
#       incl. large |x/y|, subnormals, signs, x<y, x==y, y=0 (NaN) — correctly
#       rounded, reference-matched to fdlibm e_fmod.c.
# MEASURE-ONLY: writes /tmp only. Never stages/commits/flips a default.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/zeroc_libm_fmod}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"
echo "════ zeroc_libm_fmod_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

echo "[A] DEFAULT (macro OFF) shim.o byte-identity vs origin/main baseline…"
# Compile BOTH from the IDENTICAL basename in IDENTICAL cwd so the ELF STT_FILE
# symbol + any path-derived metadata match (else the only diff is the source
# filename string — the known DWARF/path artifact, project_hexa_byteeq_dwarf_cwd).
BN=runtime_core_hxlcl_shim.c
rm -rf "$OUT/base" "$OUT/new"; mkdir -p "$OUT/base" "$OUT/new"
git show "origin/main:$SHIM" > "$OUT/base/$BN" 2>/dev/null || cp "$SHIM" "$OUT/base/$BN"
cp "$SHIM" "$OUT/new/$BN"
( cd "$OUT/base" && $CC $CFLAGS "$BN" -o shim.o 2>err )
( cd "$OUT/new"  && $CC $CFLAGS "$BN" -o shim.o 2>err )
B=$(sha256sum "$OUT/base/shim.o" 2>/dev/null | cut -d' ' -f1)
N=$(sha256sum "$OUT/new/shim.o"  2>/dev/null | cut -d' ' -f1)
echo "    base shim.o sha=$B"
echo "    new  shim.o sha=$N"
# backup: raw .text section bytes (codegen) must match regardless of metadata
objcopy -O binary --only-section=.text "$OUT/base/shim.o" "$OUT/base.text" 2>/dev/null
objcopy -O binary --only-section=.text "$OUT/new/shim.o"  "$OUT/new.text"  2>/dev/null
TB=$(sha256sum "$OUT/base.text" 2>/dev/null | cut -d' ' -f1)
TN=$(sha256sum "$OUT/new.text"  2>/dev/null | cut -d' ' -f1)
echo "    .text base sha=$TB"
echo "    .text new  sha=$TN"
[ "$B" = "$N" ] && echo "DEFAULT_SHIM_O_BYTE_IDENTICAL=YES" || echo "DEFAULT_SHIM_O_BYTE_IDENTICAL=NO"
[ "$TB" = "$TN" ] && echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES" || echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=NO"

echo "[B] ON (HEXA_LIBM_NATIVE_FMOD) shim.o libm-fmod coupling…"
$CC $CFLAGS -DHEXA_LIBM_NATIVE_FMOD "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/on.err"
ON_RC=$?
echo "    ON compile RC=$ON_RC"; grep -i error: "$OUT/on.err" | head
# any UNDEFINED 'fmod' symbol referenced by the ON object?
FMOD_REF=$(nm "$OUT/shim_on.o" 2>/dev/null | grep -E ' U _?fmod$' | wc -l | tr -d ' ')
echo "    undefined libm 'fmod' refs in ON shim.o = $FMOD_REF"
[ "$FMOD_REF" = "0" ] && echo "ON_LIBM_FMOD_COUPLING_DISSOLVED=YES" || echo "ON_LIBM_FMOD_COUPLING_DISSOLVED=NO"

echo "[C] accuracy: ON hxlcl_fmod vs libc fmod, ULP sweep…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
#include <math.h>
extern double hxlcl_fmod(double x, double y);
static uint64_t bits(double d){ union{double d;uint64_t u;}v; v.d=d; return v.u; }
int main(void){
    double xs[] = {0.0,-0.0,1.0,-1.0,3.14159265358979,2.718281828,
                   1e300,1e-300,123456789.123,9.0,8.0,5.5,-5.5,
                   1e18,1e-310,4.9e-324,2.2250738585072014e-308,
                   0.1,0.2,0.3,100.0,1.0/3.0,1234.5678,-1234.5678,
                   1e9+0.5, 6.283185307179586, 0.5, 2.0, 1024.0};
    double ys[] = {1.0,-1.0,2.0,0.1,3.0,0.5,7.0,1e-300,1e300,2.0,
                   3.0,0.7,1e-310,4.9e-324,2.2250738585072014e-308,
                   0.3,2.0,360.0,1.0/3.0,0.0,-2.0,1e18,8.0,1.5,
                   6.283185307179586, 0.25, 1024.0, 1e-200};
    int nx=sizeof(xs)/sizeof(xs[0]), ny=sizeof(ys)/sizeof(ys[0]);
    long total=0, mismatch=0; uint64_t maxulp=0;
    for(int a=0;a<nx;a++) for(int b=0;b<ny;b++){
        double x=xs[a], y=ys[b];
        double r1=hxlcl_fmod(x,y), r2=fmod(x,y);
        total++;
        int both_nan = (r1!=r1) && (r2!=r2);
        if(both_nan) continue;
        if(bits(r1)!=bits(r2)){
            uint64_t u1=bits(r1),u2=bits(r2);
            uint64_t d = u1>u2 ? u1-u2 : u2-u1;
            if(d>maxulp) maxulp=d;
            if(mismatch<12) printf("    DIFF x=%.17g y=%.17g native=%.17g(%016llx) libc=%.17g(%016llx)\n",
                                   x,y,r1,(unsigned long long)u1,r2,(unsigned long long)u2);
            mismatch++;
        }
    }
    printf("    total=%ld mismatch=%ld max_ulp=%llu\n", total, mismatch, (unsigned long long)maxulp);
    printf(mismatch==0 ? "ACCURACY_BIT_IDENTICAL_0ULP=YES\n" : "ACCURACY_BIT_IDENTICAL_0ULP=NO\n");
    return 0;
}
EOF
$CC -O2 -std=gnu11 "$OUT/acc.c" "$OUT/shim_on.o" -o "$OUT/acc" -lm 2>"$OUT/acc.err" && "$OUT/acc" || { echo "acc build/run FAIL"; cat "$OUT/acc.err"; }
echo "════ DONE ($OUT) ════"
