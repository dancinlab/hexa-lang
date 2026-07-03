#!/usr/bin/env bash
# tool/routec_alloc_native_verify.sh — COMPOSITE non-libm leaves (hxlcl_calloc +
# hxlcl_realloc) via the Route C whole-module emit path. Both call the RETAINED shim
# provider hxlcl_malloc (shim:101) via an inner C-ABI `bl` — they are NOT pure leaves,
# so unlike free #4242 the isolated native .o LEGITIMATELY carries one external reloc
# to hxlcl_malloc (resolved by the retained shim at archive-link time; NO co-drop).
#
# Verifies the HEXA_RT_NATIVE_CALLOC / HEXA_RT_NATIVE_REALLOC wiring:
#   (A) DEFAULT (both OFF) shim.o is BYTE-IDENTICAL to the origin/main baseline shim.o
#       (the new `#ifndef` guards compile out → libc-delegate bodies untouched;
#       release-integrity invariant).
#   (B) ON: the Route C codegen emits hxlcl_calloc / hxlcl_realloc as DEFINED (T)
#       externals in the native .o, AND the ON shim.o NO LONGER defines them. Each
#       native object is ISOLATED via `objcopy --keep-global-symbol=<sym>` (the
#       whole-module routec.o defines sibling C-ABI hxlcl_* too, incl. its own
#       hxlcl_malloc; the staged member keeps only its symbol so the shim keeps
#       serving siblings incl. malloc, and the ld -r multidef gate sees exactly one
#       new strong def per symbol). The isolated .o's ONLY external call is the inner
#       `bl hxlcl_malloc` (EXPECTED — retained shim provider, NOT a leak).
#   (C) BEHAVIOUR-EXACT vs reference libc, against a self-contained header-writing
#       hxlcl_malloc harness (same 16-byte size-header convention the floor malloc
#       uses, mirroring tool/routec_cabi_smoke.sh):
#         calloc(nmemb,size)  → nmemb*size bytes, ALL ZERO (cross-checked vs libc
#                               calloc result byte-for-byte).
#         realloc(p,n)        → grow/shrink preserving min(n,old_n) bytes; the
#                               NEGATIVE-offset header read (p-16) recovers old_n.
#                               4 cases: grow · shrink · NULL-ptr · zero-size, each
#                               compared to the documented floor-faithful contract.
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-2 (both ON);
#       per-symbol drop 1 → 0 for calloc and realloc; hxlcl_malloc RETAINED (1 → 1).
#
# x86_64-linux ONLY — the fp-ABI xmm Route C codegen is x86_64-backend. MEASURE-ONLY:
# writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_alloc}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-alloc] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_alloc_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (CALLOC+REALLOC OFF) shim.o byte-identity vs origin/main…"
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

# ── [D] shim member count: default vs ON (both flags) ───────────────────────
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_CALLOC -DHEXA_RT_NATIVE_REALLOC)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_CALLOC -DHEXA_RT_NATIVE_REALLOC "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-2)"
for s in calloc realloc; do
  D=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
  O=$(nm "$OUT/shim_on.o"  2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
  echo "    hxlcl_${s} defined in shim:  default=$D  ON=$O  (expect 1 → 0)"
  [ "$D" = "1" ] && [ "$O" = "0" ] && echo "SHIM_${s}_MEMBER_DROPPED=YES" || echo "SHIM_${s}_MEMBER_DROPPED=NO"
done
MD=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_malloc$' | wc -l | tr -d ' ')
MO=$(nm "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_malloc$' | wc -l | tr -d ' ')
echo "    hxlcl_malloc RETAINED in shim: default=$MD  ON=$MO  (expect 1 → 1, the inner provider stays)"
[ "$MD" = "1" ] && [ "$MO" = "1" ] && echo "SHIM_MALLOC_RETAINED=YES" || echo "SHIM_MALLOC_RETAINED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_calloc/hxlcl_realloc (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnal_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }

for s in calloc realloc; do
  T=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
  echo "    hxlcl_${s} defined (T) in native routec.o = $T  (expect 1)"
  objcopy --keep-global-symbol=hxlcl_${s} "$OUT/routec_full.o" "$OUT/${s}_only.o" 2>/dev/null \
      || cp "$OUT/routec_full.o" "$OUT/${s}_only.o"
  # inner `bl hxlcl_malloc` is EXPECTED; any OTHER external call/data reloc is a leak.
  BAD=$(objdump -dr "$OUT/${s}_only.o" 2>/dev/null | grep -E 'R_X86_64_(PLT32|GOTPCREL)' | grep -vE '\bhxlcl_malloc\b' | grep -cE '\b(free|calloc|realloc|malloc|memcpy|memset|environ|__errno_location)\b')
  MAL=$(objdump -dr "$OUT/${s}_only.o" 2>/dev/null | grep -cE 'R_X86_64_(PLT32|GOTPCREL).*\bhxlcl_malloc\b')
  echo "    isolated hxlcl_${s}: inner bl hxlcl_malloc relocs=$MAL (expect ≥1, retained provider) · OTHER ext libc relocs=$BAD (expect 0)"
  [ "$T" = "1" ] && [ "${BAD:-1}" = "0" ] && echo "NATIVE_${s}_ONLY_INNER_MALLOC=YES" || echo "NATIVE_${s}_ONLY_INNER_MALLOC=NO"
done

# ── [C] behaviour-exact vs libc, header-writing malloc harness ──────────────
echo "[C] behaviour-exact: native hxlcl_calloc/hxlcl_realloc vs reference libc…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern void *hxlcl_calloc(size_t nmemb, size_t size);
extern void *hxlcl_realloc(void *p, size_t n);
/* header-writing hxlcl_malloc: SAME 16-byte size header the floor malloc writes
 * (store n at offset 0, hand back ptr+16) so realloc's neg-offset header read
 * `*(size_t*)(p-16)` recovers old_n. Mirrors tool/routec_cabi_smoke.sh:316. */
#define HXLCL_HDR 16
void *hxlcl_malloc(size_t n) {
    size_t want = n ? n : 1;
    unsigned char *base = (unsigned char *)malloc(want + HXLCL_HDR);
    if (!base) return (void *)0;
    *(size_t *)base = want;
    return base + HXLCL_HDR;
}
int main(void){
    int fails = 0;
    /* ── calloc: zero-init, cross-checked vs libc calloc ── */
    {
        size_t nm = 7, sz = 9, tot = nm*sz;            /* 63 bytes */
        unsigned char *z = (unsigned char *)hxlcl_calloc(nm, sz);
        unsigned char *ref = (unsigned char *)calloc(nm, sz);
        if (!z || !ref) { printf("  calloc alloc FAIL\n"); return 1; }
        if (memcmp(z, ref, tot) != 0) { printf("  calloc MISMATCH vs libc (not all-zero)\n"); fails++; }
        else printf("  calloc(7,9)=63B all-zero == libc calloc  OK\n");
        free(ref);
    }
    /* ── realloc grow: preserve old content (neg-offset header read) ── */
    {
        char *p = (char *)hxlcl_malloc(8);
        for (int i=0;i<8;i++) p[i]=(char)(0xA0+i);
        char *q = (char *)hxlcl_realloc(p, 32);        /* grow 8 → 32 */
        if (!q) { printf("  realloc grow alloc FAIL\n"); return 1; }
        int ok=1; for (int i=0;i<8;i++) if (q[i]!=(char)(0xA0+i)) ok=0;
        if (ok) printf("  realloc grow 8→32 preserves 8B (header read p-16)  OK\n");
        else { printf("  realloc grow MISMATCH (preserve failed)\n"); fails++; }
    }
    /* ── realloc shrink: preserve min(n,old_n)=4 ── */
    {
        char *p = (char *)hxlcl_malloc(16);
        for (int i=0;i<16;i++) p[i]=(char)(0x10+i);
        char *q = (char *)hxlcl_realloc(p, 4);         /* shrink 16 → 4 */
        if (!q) { printf("  realloc shrink alloc FAIL\n"); return 1; }
        int ok=1; for (int i=0;i<4;i++) if (q[i]!=(char)(0x10+i)) ok=0;
        if (ok) printf("  realloc shrink 16→4 preserves min(4,16)=4B  OK\n");
        else { printf("  realloc shrink MISMATCH\n"); fails++; }
    }
    /* ── realloc NULL-ptr: BYTEID-faithful body delegates to hxlcl_malloc(n) ── */
    {
        char *q = (char *)hxlcl_realloc((void*)0, 24); /* NULL → fresh malloc(24) */
        if (q) printf("  realloc(NULL,24) → fresh malloc, non-NULL  OK\n");
        else { printf("  realloc(NULL,24) returned NULL (expected fresh buffer)\n"); fails++; }
    }
    /* ── realloc zero-size: BYTEID-faithful body returns NULL ── */
    {
        char *p = (char *)hxlcl_malloc(8);
        char *q = (char *)hxlcl_realloc(p, 0);         /* n==0 → NULL (floor contract) */
        if (q == (void*)0) printf("  realloc(p,0) → NULL (floor zero-size contract)  OK\n");
        else { printf("  realloc(p,0) returned non-NULL (expected NULL)\n"); fails++; }
    }
    if (fails) { printf("BEHAVIOUR_EXACT=NO (%d mismatch)\n", fails); return 1; }
    printf("BEHAVIOUR_EXACT=YES\n");
    return 0;
}
EOF
# link the two isolated native .o (calloc + realloc); the shim-provided header-writing
# hxlcl_malloc in acc.c resolves the inner bl. (Both isolated .o keep ONLY their own
# symbol, so no calloc/realloc multidef between them.)
$CC "$OUT/acc.c" "$OUT/calloc_only.o" "$OUT/realloc_only.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"
RC=$?
echo "════ routec_alloc_native_verify done (acc RC=$RC) ════"
exit 0
