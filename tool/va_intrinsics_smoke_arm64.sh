#!/usr/bin/env bash
# tool/va_intrinsics_smoke_arm64.sh — RFC061 §M8 varargs-ABI (literal-∅ feature B)
# r2 arm64 ON-PATH smoke (LINUX arm64 / AAPCS64 + DARWIN arm64 / Apple ABI).
#
# WHAT THIS PROVES
# ─────────────────────────────────────────────────────────────────────
# A self-emitted arm64 VARIADIC function — compiled natively by the hexa codegen
# (NO frozen runtime.c va_list) under HEXA_VA_INTRINSICS=1 — walks its unnamed INT
# and DOUBLE arguments value-EXACTLY through BOTH the register path and the stack
# (overflow) path, on BOTH arm64 ABIs:
#   • LINUX  — AAPCS64 §B.4 __va_list {__stack,__gr_top,__vr_top,__gr_offs,__vr_offs};
#     the prologue spills x0..x7 → 64B GP save + q0..q7 → 128B FP save; va_arg(int)
#     walks __gr_offs (>=0 → stack, else __gr_top+__gr_offs, +=8) and va_arg_fp walks
#     __vr_offs (>=0 → stack, else __vr_top+__vr_offs, +=16). Reference-match: clang
#     AArch64ABIInfo::EmitAAPCSVAArg.
#   • DARWIN — Apple ARM64 passes ALL varargs on the stack; va_list is a char*;
#     va_start = &first stack vararg ([x29,#16]); va_arg loads 8 bytes and bumps the
#     pointer. Reference-match: Apple "Writing ARM64 Code for Apple Platforms".
#
# HOST MODES
#   • darwin-arm64 host: emits arm64-apple-darwin asm, links + runs NATIVELY.
#   • linux-arm64 host: emits arm64-linux-gnu asm, links + runs NATIVELY.
#   • linux-x86_64 host: emits arm64-linux-gnu asm, cross-links with
#     aarch64-linux-gnu-gcc and runs under qemu-aarch64 (if both present; else SKIP).
#
# aprime_cc (the native-codegen compiler) builds via tool/build_aprime.sh — runs on a
# pool host (aiden/summer/ghost), NOT mini. Loud SKIP where the toolchain is absent.
#
#   tool/va_intrinsics_smoke_arm64.sh
#
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

# ── select target triple + toolchain by host ────────────────────────────────
RUN="";  CC=""; TARGET=""
if [ "$UNAME_S" = "Darwin" ] && [ "$UNAME_M" = "arm64" ]; then
    TARGET="arm64-apple-darwin"; CC="${CC:-cc}"; RUN=""          # native
elif [ "$UNAME_S" = "Linux" ] && { [ "$UNAME_M" = "aarch64" ] || [ "$UNAME_M" = "arm64" ]; }; then
    TARGET="arm64-linux-gnu"; CC="${CC:-cc}"; RUN=""             # native
elif [ "$UNAME_S" = "Linux" ] && [ "$UNAME_M" = "x86_64" ]; then
    TARGET="arm64-linux-gnu"
    QEMU=""
    if command -v qemu-aarch64 >/dev/null 2>&1; then QEMU="qemu-aarch64"
    elif command -v qemu-aarch64-static >/dev/null 2>&1; then QEMU="qemu-aarch64-static"; fi
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 && [ -n "$QEMU" ]; then
        CC="aarch64-linux-gnu-gcc"; RUN="$QEMU -L /usr/aarch64-linux-gnu"
    else
        echo "[va-arm64-smoke] SKIP — need aarch64-linux-gnu-gcc + qemu-aarch64(-static) to cross-run arm64 on x86_64 (host=$UNAME_S/$UNAME_M)"
        exit 0
    fi
else
    echo "[va-arm64-smoke] SKIP — no arm64 run path on host=$UNAME_S/$UNAME_M"
    exit 0
fi
echo "[va-arm64-smoke] target=$TARGET  cc=$CC  run='${RUN:-native}'"

APRIME="${APRIME:-$HX/build/aprime_cc}"
if [ ! -x "$APRIME" ]; then
    echo "[va-arm64-smoke] building aprime_cc (tool/build_aprime.sh) …"
    bash "$HX/tool/build_aprime.sh" -o "$APRIME"
fi
[ -x "$APRIME" ] || { echo "[va-arm64-smoke] FATAL: aprime_cc not at $APRIME" >&2; exit 1; }

SRC_INT="$HX/stdlib/runtime/hxlcl_va_smoke.hexa"
SRC_FP="$HX/stdlib/runtime/hxlcl_va_fp_smoke.hexa"
[ -f "$SRC_INT" ] || { echo "[va-arm64-smoke] FATAL: missing $SRC_INT" >&2; exit 1; }
[ -f "$SRC_FP" ]  || { echo "[va-arm64-smoke] FATAL: missing $SRC_FP" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    # $1 = source .hexa, $2 = output .o, $3 = symbol name
    local src="$1" outo="$2" sym="$3"
    local s="$TMP/$(basename "$outo" .o).s"
    echo "[va-arm64-smoke] emit $sym ($TARGET) …"
    HEXA_VA_INTRINSICS=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
        "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$TARGET" -o "$s" "$src"
    [ -s "$s" ] || { echo "[va-arm64-smoke] FATAL: empty $s" >&2; exit 1; }
    # arm64-linux ELF GNU-as fixup: the shared arm64 codegen emits Mach-O-style
    # `adrp X, sym@PAGE` + `add X, X, sym@PAGEOFF` (correct for darwin Mach-O via cc),
    # but GNU `as` for ELF wants bare `adrp X, sym` + `add X, X, :lo12:sym`. Same
    # established post-process the release regen_* scripts apply (codegen-emit gap, not a
    # va-codegen issue — it's the shared const_float/global pool load path). Darwin skips.
    if [ "$TARGET" = "arm64-linux-gnu" ]; then
        perl -i -pe 's/(adrp\s+[xw]\d+,\s*)([._A-Za-z][._A-Za-z0-9]*)\@PAGE\b/$1$2/; s/(add\s+[xw]\d+,\s*[xw]\d+,\s*)([._A-Za-z][._A-Za-z0-9]*)\@PAGEOFF\b/$1:lo12:$2/' "$s"
    fi
    "$CC" -c "$s" -o "$outo"
    [ -s "$outo" ] || { echo "[va-arm64-smoke] FATAL: empty $outo" >&2; exit 1; }
    # symbol is `_sym` on darwin Mach-O, bare on ELF.
    if ! nm "$outo" 2>/dev/null | grep -qE " T _?${sym}\$"; then
        echo "[va-arm64-smoke] FATAL: $sym not emitted as defined text" >&2
        nm "$outo" 2>/dev/null | grep -i va || true
        exit 1
    fi
}

emit_one "$SRC_INT" "$TMP/vai.o" "hxlcl_va_smoke"
emit_one "$SRC_FP"  "$TMP/vaf.o" "hxlcl_va_fp_smoke"

# ── C harness: value-exact int + double variadic contract ───────────────────
cat > "$TMP/harness.c" <<'CEOF'
#include <stdio.h>
#include <string.h>

extern long   hxlcl_va_smoke(long n, ...);      /* sum of n integer varargs */
extern double hxlcl_va_fp_smoke(long n, ...);   /* sum of n double  varargs */

static int fails = 0;
static void checki(const char *name, long got, long want) {
    if (got != want) { fprintf(stderr, "[va-arm64-smoke] FAIL %s: got %ld want %ld\n", name, got, want); fails++; }
    else             { fprintf(stderr, "[va-arm64-smoke]   ok  %s = %ld\n", name, got); }
}
static void checkf(const char *name, double got, double want) {
    unsigned long long gb, wb; memcpy(&gb,&got,8); memcpy(&wb,&want,8);
    if (gb != wb) { fprintf(stderr, "[va-arm64-smoke] FAIL %s: got %.17g want %.17g\n", name, got, want); fails++; }
    else          { fprintf(stderr, "[va-arm64-smoke]   ok  %s = %.17g\n", name, got); }
}

int main(void) {
    /* INTEGER class — register slots (x1..x7 / __gr_offs) + stack overflow. */
    checki("i0",  hxlcl_va_smoke(0L), 0L);
    checki("i1",  hxlcl_va_smoke(1L, 42L), 42L);
    checki("i7",  hxlcl_va_smoke(7L, 1L,2L,3L,4L,5L,6L,7L), 28L);     /* all GP reg slots */
    checki("i10", hxlcl_va_smoke(10L, 1L,2L,3L,4L,5L,6L,7L,8L,9L,10L), 55L); /* reg + stack */
    checki("ineg",hxlcl_va_smoke(3L, -100L, 1000000L, -7L), 999893L);

    /* SIMD/FP class — register slots (v0..v7 / __vr_offs) + stack overflow. */
    checkf("f0",  hxlcl_va_fp_smoke(0L), 0.0);
    checkf("f1",  hxlcl_va_fp_smoke(1L, 1.5), 1.5);
    checkf("f8",  hxlcl_va_fp_smoke(8L, 0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5), 4.0); /* all FP reg slots */
    checkf("f9",  hxlcl_va_fp_smoke(9L, 1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0), 45.0); /* reg + stack */
    checkf("f12", hxlcl_va_fp_smoke(12L, 1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0), 78.0);
    checkf("fneg",hxlcl_va_fp_smoke(3L, -100.25, 1000.5, -0.25), 900.0);

    if (fails) { fprintf(stderr, "[va-arm64-smoke] %d FAILURE(s)\n", fails); return 1; }
    fprintf(stderr, "[va-arm64-smoke] PASS — arm64 va_arg int+double reg+stack value-exact\n");
    return 0;
}
CEOF

echo "[va-arm64-smoke] compile harness + link + run …"
"$CC" -c "$TMP/harness.c" -o "$TMP/harness.o"
"$CC" "$TMP/harness.o" "$TMP/vai.o" "$TMP/vaf.o" -o "$TMP/va_smoke_arm64"
$RUN "$TMP/va_smoke_arm64"
echo "[va-arm64-smoke] DONE"
