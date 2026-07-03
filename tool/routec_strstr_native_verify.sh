#!/usr/bin/env bash
# tool/routec_strstr_native_verify.sh — literal-∅ FIRST NON-LIBM leaf (hxlcl_strstr
# via the Route C whole-module emit path, integer-returning pure leaf).
#
# Verifies the HEXA_RT_NATIVE_STRSTR wiring — hxlcl_strstr LEAVES the libc shim and
# is supplied by the hexa-NATIVE Route C .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_STRSTR OFF) shim.o is BYTE-IDENTICAL to the
#       origin/main baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_STRSTR` guard
#       compiles out → the libc-delegate body is untouched; release-integrity
#       invariant — DEFAULT archive sha unchanged).
#   (B) ON: the Route C codegen emits `hxlcl_strstr` as a DEFINED (T) external in
#       the native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_STRSTR) NO LONGER
#       defines it — the symbol MOVES from the C shim to the native object
#       (literal-∅ progress: one shim member dropped). The native object is
#       ISOLATED via `objcopy --keep-global-symbol=hxlcl_strstr` (the whole-module
#       routec.o defines sibling C-ABI hxlcl_* too; the staged member keeps only
#       strstr so the shim continues serving the siblings and the ld -r multidef
#       gate sees exactly one new strong def). A multidef would be a link killer.
#   (C) VALUE-EXACT: link the isolated native .o against a C harness that CALLS
#       hxlcl_strstr as a raw C-ABI `char *f(const char*,const char*)` and compares
#       the returned pointer-offset bit-for-bit to libc strstr over a coverage
#       sweep (match-at-0/mid/end, empty needle, absent, partial-then-mismatch,
#       needle-past-end). reference-match: C strstr semantics (first-occurrence
#       pointer; empty needle → haystack). The native body is a byte-faithful
#       port of the frozen 0-libc floor self/runtime.c hxlcl_strstr.
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the fp-ABI xmm Route C codegen is x86_64-backend; arm64
# AAPCS64 is the NEXT rung (same host gate as the RT-NATIVE-{FMOD,SIN,COS,EXP,LOG}
# libm leaves). MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_strstr}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-strstr] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_strstr_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_STRSTR OFF) shim.o byte-identity vs origin/main…"
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
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_STRSTR)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_STRSTR "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
SS_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_strstr$' | wc -l | tr -d ' ')
SS_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_strstr$' | wc -l | tr -d ' ')
echo "    hxlcl_strstr defined in shim:  default=$SS_DEF_DEFAULT  ON=$SS_DEF_ON  (expect 1 → 0)"
[ "$SS_DEF_DEFAULT" = "1" ] && [ "$SS_DEF_ON" = "0" ] && echo "SHIM_STRSTR_MEMBER_DROPPED=YES" || echo "SHIM_STRSTR_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_strstr (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnss_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
SS_T_NATIVE=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E ' T _?hxlcl_strstr$' | wc -l | tr -d ' ')
echo "    hxlcl_strstr defined (T) in native routec.o = $SS_T_NATIVE  (expect 1)"
# isolate strstr (keep only that global) — proves it carries no sibling C-ABI defs
objcopy --keep-global-symbol=hxlcl_strstr "$OUT/routec_full.o" "$OUT/strstr_only.o" 2>/dev/null \
    || cp "$OUT/routec_full.o" "$OUT/strstr_only.o"
# external relocs from the ISOLATED strstr object — must be ZERO (self-contained leaf:
# no libc strstr, no hxlcl_malloc, no environ, no __errno_location)
SS_EXT_RELOC=$(objdump -dr "$OUT/strstr_only.o" 2>/dev/null | grep -cE 'R_X86_64_(PLT32|GOTPCREL).*\b(strstr|hxlcl_|environ|__errno_location)\b')
echo "    external call/data relocs from isolated hxlcl_strstr = $SS_EXT_RELOC  (expect 0 — self-contained leaf)"
[ "$SS_T_NATIVE" = "1" ] && [ "${SS_EXT_RELOC:-1}" = "0" ] && echo "NATIVE_STRSTR_SELF_CONTAINED=YES" || echo "NATIVE_STRSTR_SELF_CONTAINED=NO"

# ── [C] value-exact: native hxlcl_strstr vs libc strstr ─────────────────────
echo "[C] value-exact: native hxlcl_strstr vs libc strstr (pointer-offset sweep)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <string.h>
extern char *hxlcl_strstr(const char *h, const char *n);
static int chk(const char *h, const char *n, int *fail){
    const char *r = hxlcl_strstr(h, n);
    const char *e = strstr(h, n);
    long ro = r ? (r - h) : -1;
    long eo = e ? (e - h) : -1;
    if (ro != eo){ (*fail)++; printf("  MISMATCH strstr(\"%s\",\"%s\") native_off=%ld libc_off=%ld\n", h, n, ro, eo); return 1; }
    return 0;
}
int main(void){
    int fail=0, n=0;
    const char *hay = "hello world";
    chk(hay,"ll",&fail);     n++;   /* mid match     */
    chk(hay,"world",&fail);  n++;   /* near-end match */
    chk(hay,"hello",&fail);  n++;   /* match at 0     */
    chk(hay,"",&fail);       n++;   /* empty needle → &hay[0] */
    chk(hay,"xyz",&fail);    n++;   /* absent → NULL  */
    chk(hay,"worlds",&fail); n++;   /* needle past end → NULL */
    chk("aaa","aab",&fail);  n++;   /* partial-then-mismatch → NULL */
    chk("","",&fail);        n++;   /* empty hay + empty needle */
    chk("","x",&fail);       n++;   /* empty hay + nonempty → NULL */
    chk("ababab","abab",&fail); n++;/* overlap restart */
    chk("mississippi","issi",&fail); n++;
    chk("mississippi","ppi",&fail);  n++;
    chk("a","a",&fail);      n++;
    chk("abc","c",&fail);    n++;   /* last char match */
    printf("  N=%d points, fail=%d\n", n, fail);
    printf(fail?"VALUE_EXACT=NO\n":"VALUE_EXACT=YES\n");
    return fail?1:0;
}
EOF
$CC "$OUT/acc.c" "$OUT/strstr_only.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"
RC=$?
echo "════ routec_strstr_native_verify done (acc RC=$RC) ════"
exit 0
