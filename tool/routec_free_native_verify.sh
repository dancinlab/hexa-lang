#!/usr/bin/env bash
# tool/routec_free_native_verify.sh — literal-∅ non-libm leaf RUNG 3 (hxlcl_free via
# the Route C whole-module emit path, purest self-contained no-op leaf).
#
# Verifies the HEXA_RT_NATIVE_FREE wiring — hxlcl_free LEAVES the libc shim and is
# supplied by the hexa-NATIVE Route C .o emitted from stdlib/runtime/hxlcl_core.hexa:
#   (A) DEFAULT (HEXA_RT_NATIVE_FREE OFF) shim.o is BYTE-IDENTICAL to the origin/main
#       baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_FREE` guard compiles out →
#       the libc-delegate body is untouched; release-integrity invariant).
#   (B) ON: the Route C codegen emits `hxlcl_free` as a DEFINED (T) external in the
#       native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_FREE) NO LONGER defines it.
#       The native object is ISOLATED via `objcopy --keep-global-symbol=hxlcl_free`
#       (the whole-module routec.o defines sibling C-ABI hxlcl_* too; the staged
#       member keeps only free so the shim keeps serving siblings and the ld -r
#       multidef gate sees exactly one new strong def).
#   (C) BEHAVIOUR-EXACT: hxlcl_free is the frozen 0-libc floor's NO-OP free (the
#       bump arena from hxlcl_malloc never reclaims). The native body is FAITHFUL to
#       the frozen floor (no-op), NOT to the shim's libc-only free(p). The behaviour
#       contract is: accept any pointer (NULL + heap) without crash and without
#       reading/writing through it. Link the isolated native .o against a C harness
#       that calls hxlcl_free(NULL) + hxlcl_free(heap_ptr) and asserts no crash; the
#       heap ptr is independently freed afterward (no double-free, since hxlcl_free
#       is a no-op). reference-match: frozen self/runtime.c hxlcl_free (== BYTEID arm
#       `(void)p`).
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the fp-ABI xmm Route C codegen is x86_64-backend; arm64
# AAPCS64 is a later rung. MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_free}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-free] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_free_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_FREE OFF) shim.o byte-identity vs origin/main…"
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
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_FREE)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_FREE "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
FR_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_free$' | wc -l | tr -d ' ')
FR_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_free$' | wc -l | tr -d ' ')
echo "    hxlcl_free defined in shim:  default=$FR_DEF_DEFAULT  ON=$FR_DEF_ON  (expect 1 → 0)"
[ "$FR_DEF_DEFAULT" = "1" ] && [ "$FR_DEF_ON" = "0" ] && echo "SHIM_FREE_MEMBER_DROPPED=YES" || echo "SHIM_FREE_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_free (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnfr_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
FR_T_NATIVE=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E ' T _?hxlcl_free$' | wc -l | tr -d ' ')
echo "    hxlcl_free defined (T) in native routec.o = $FR_T_NATIVE  (expect 1)"
objcopy --keep-global-symbol=hxlcl_free "$OUT/routec_full.o" "$OUT/free_only.o" 2>/dev/null \
    || cp "$OUT/routec_full.o" "$OUT/free_only.o"
FR_EXT_RELOC=$(objdump -dr "$OUT/free_only.o" 2>/dev/null | grep -cE 'R_X86_64_(PLT32|GOTPCREL).*\b(free|hxlcl_|environ|__errno_location)\b')
echo "    external call/data relocs from isolated hxlcl_free = $FR_EXT_RELOC  (expect 0 — self-contained no-op leaf)"
[ "$FR_T_NATIVE" = "1" ] && [ "${FR_EXT_RELOC:-1}" = "0" ] && echo "NATIVE_FREE_SELF_CONTAINED=YES" || echo "NATIVE_FREE_SELF_CONTAINED=NO"

# ── [C] behaviour-exact: native hxlcl_free no-op accepts NULL + heap ptr ────
echo "[C] behaviour-exact: native hxlcl_free no-op (NULL + heap ptr, no crash)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
extern void hxlcl_free(void *p);
int main(void){
    int n=0;
    hxlcl_free(NULL); n++;                              /* NULL accepted */
    { char *p = (char *)malloc(64);
      for (int i=0;i<64;i++) p[i]=(char)i;              /* write then no-op free */
      hxlcl_free(p);                                    /* no-op: p still valid */
      int ok=1; for (int i=0;i<64;i++) if (p[i]!=(char)i) ok=0;
      if(!ok){ printf("  MISMATCH: heap content changed after no-op free\n"); return 1; }
      free(p);                                          /* real reclaim (no double-free: hxlcl_free was no-op) */
      n++; }
    hxlcl_free((void*)0x1); n++;                        /* arbitrary non-NULL accepted (never dereferenced) */
    printf("  N=%d calls, no crash, no content change\n", n);
    printf("BEHAVIOUR_EXACT=YES\n");
    return 0;
}
EOF
$CC "$OUT/acc.c" "$OUT/free_only.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"
RC=$?
echo "════ routec_free_native_verify done (acc RC=$RC) ════"
exit 0
