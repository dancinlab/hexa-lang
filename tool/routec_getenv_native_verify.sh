#!/usr/bin/env bash
# tool/routec_getenv_native_verify.sh — literal-∅ non-libm leaf RUNG 4, the FIRST
# extern-DATA leaf (hxlcl_getenv via the Route C whole-module emit path).
#
# Verifies the HEXA_RT_NATIVE_GETENV wiring — hxlcl_getenv LEAVES the libc shim and
# is supplied by the hexa-NATIVE Route C .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_GETENV OFF) shim.o is BYTE-IDENTICAL to the
#       origin/main baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_GETENV` guard
#       compiles out → the libc-delegate body is untouched; release-integrity
#       invariant — DEFAULT archive sha unchanged).
#   (B) ON: the Route C codegen emits `hxlcl_getenv` as a DEFINED (T) external in
#       the native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_GETENV) NO LONGER
#       defines it — the symbol MOVES from the C shim to the native object
#       (literal-∅ progress: one shim member dropped). The native object is
#       ISOLATED via `objcopy --keep-global-symbol=hxlcl_getenv` (the whole-module
#       routec.o defines sibling C-ABI hxlcl_* too; the staged member keeps only
#       getenv so the shim continues serving the siblings and the ld -r multidef
#       gate sees exactly one new strong def). A multidef would be a link killer.
#       UNLIKE the pure-leaves (strstr/strtoll/free), the isolated getenv object
#       carries exactly ONE permitted external reloc: `environ@GOTPCREL` (the libc
#       global, via __hx_environ_ptr #4098). That reloc is provider-PRESENT — every
#       final link pulls libc, which defines `environ` — so it is NOT a missing
#       provider. The gate FAILS only on a NON-environ external reloc (a stray
#       hxlcl_* / __errno_location / syscall dep would mean the leaf is not isolated).
#   (C) VALUE-EXACT: link the isolated native .o against a C harness that CALLS
#       hxlcl_getenv as a raw C-ABI `char *f(const char*)` and compares the returned
#       value pointer bit-for-bit (same address AND same string content) to libc
#       getenv over a coverage sweep: existing key (PATH), set key (content-exact),
#       empty-value key, absent key → NULL, prefix-of-existing → NULL (no false
#       partial match), superstring-of-existing → NULL, NULL name → NULL. reference-
#       match: C getenv semantics (first matching `NAME=` entry → value ptr; the
#       native body is a byte-faithful port of the frozen 0-libc floor self/runtime.c
#       hxlcl_getenv, walking the SAME `environ` array via the GOT-loaded &environ).
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the Route C codegen is x86_64-backend; arm64 AAPCS64 is the
# NEXT rung (same host gate as the RT-NATIVE-{FMOD,SIN,COS,EXP,LOG,STRSTR,STRTOLL,FREE}
# leaves). MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_getenv}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-getenv] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_getenv_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_GETENV OFF) shim.o byte-identity vs origin/main…"
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
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_GETENV)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_GETENV "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
GE_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_getenv$' | wc -l | tr -d ' ')
GE_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_getenv$' | wc -l | tr -d ' ')
echo "    hxlcl_getenv defined in shim:  default=$GE_DEF_DEFAULT  ON=$GE_DEF_ON  (expect 1 → 0)"
[ "$GE_DEF_DEFAULT" = "1" ] && [ "$GE_DEF_ON" = "0" ] && echo "SHIM_GETENV_MEMBER_DROPPED=YES" || echo "SHIM_GETENV_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_getenv (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnge_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
GE_T_NATIVE=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E ' T _?hxlcl_getenv$' | wc -l | tr -d ' ')
echo "    hxlcl_getenv defined (T) in native routec.o = $GE_T_NATIVE  (expect 1)"
# isolate getenv (keep only that global) — proves it carries no sibling C-ABI defs
objcopy --keep-global-symbol=hxlcl_getenv "$OUT/routec_full.o" "$OUT/getenv_only.o" 2>/dev/null \
    || cp "$OUT/routec_full.o" "$OUT/getenv_only.o"
# environ reloc is PERMITTED (provider = libc, present in every final link).
GE_ENVIRON_RELOC=$(objdump -dr "$OUT/getenv_only.o" 2>/dev/null | grep -cE 'R_X86_64_(REX_)?(GOTPCREL|GOTPCRELX).*\benviron\b')
echo "    environ@GOTPCREL relocs from isolated hxlcl_getenv = $GE_ENVIRON_RELOC  (expect ≥1 — libc-provided, OK)"
# FORBIDDEN external relocs — any external call/data dep that is NOT `environ`
# (a stray hxlcl_*, __errno_location, syscall, getenv, malloc … would mean the leaf
# is not cleanly isolated / has a missing provider).
GE_BAD_RELOC=$(objdump -dr "$OUT/getenv_only.o" 2>/dev/null \
    | grep -E 'R_X86_64_(PLT32|REX_)?(GOTPCREL|GOTPCRELX|PLT32)' \
    | grep -vE '\benviron\b' \
    | grep -cE '\b(getenv|hxlcl_|__errno_location|malloc|free|syscall)\b')
echo "    FORBIDDEN non-environ external relocs from isolated hxlcl_getenv = $GE_BAD_RELOC  (expect 0)"
[ "$GE_T_NATIVE" = "1" ] && [ "${GE_ENVIRON_RELOC:-0}" -ge 1 ] && [ "${GE_BAD_RELOC:-1}" = "0" ] \
    && echo "NATIVE_GETENV_ISOLATED_ENVIRON_ONLY=YES" || echo "NATIVE_GETENV_ISOLATED_ENVIRON_ONLY=NO"

# ── [C] value-exact: native hxlcl_getenv vs libc getenv ─────────────────────
echo "[C] value-exact: native hxlcl_getenv vs libc getenv (value-ptr + content sweep)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
extern char *hxlcl_getenv(const char *name);
static int chk(const char *name, int *fail){
    char *r = hxlcl_getenv(name);
    char *e = getenv(name);
    /* both NULL, or both non-NULL with identical pointer (same environ entry) */
    if (r == e) return 0;
    if (r && e && strcmp(r, e) == 0) return 0; /* content-exact fallback */
    (*fail)++;
    printf("  MISMATCH getenv(\"%s\") native=%p(%s) libc=%p(%s)\n",
           name, (void*)r, r?r:"(null)", (void*)e, e?e:"(null)");
    return 1;
}
int main(void){
    int fail=0, n=0;
    /* seed a controlled environment for content-exact + edge keys */
    setenv("RNGE_PRESENT", "value123", 1);
    setenv("RNGE_EMPTY", "", 1);
    chk("PATH", &fail);          n++;  /* pre-existing key → value ptr */
    chk("RNGE_PRESENT", &fail);  n++;  /* set key, content-exact */
    chk("RNGE_EMPTY", &fail);    n++;  /* empty value (entry "RNGE_EMPTY=") */
    chk("RNGE_ABSENT_XYZ", &fail); n++;/* absent → NULL */
    chk("RNGE_PRESEN", &fail);   n++;  /* prefix of existing → NULL (no partial match) */
    chk("RNGE_PRESENTX", &fail); n++;  /* superstring of existing → NULL */
    chk("HOME", &fail);          n++;  /* another pre-existing key */
    chk("", &fail);              n++;  /* empty name → NULL */
    printf("  N=%d points, fail=%d\n", n, fail);
    printf(fail?"VALUE_EXACT=NO\n":"VALUE_EXACT=YES\n");
    return fail?1:0;
}
EOF
$CC "$OUT/acc.c" "$OUT/getenv_only.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"
RC=$?
echo "════ routec_getenv_native_verify done (acc RC=$RC) ════"
exit 0
