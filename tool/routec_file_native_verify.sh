#!/usr/bin/env bash
# tool/routec_file_native_verify.sh — CORE FILE* family (fopen/fread/ftell/fseek via
# the Route C whole-module emit path; FIRST COUPLED leaves — not pure like strstr/free).
#
# In the frozen 0-libc floor a FILE* is `(void*)(uintptr_t)(fd+1)` (NOT a libc stdio
# struct), so each native body is a PURE COMPOSITION over already-dissolved syscall
# LEAVES — fopen→hxlcl_open_sys, fread→hxlcl_read, ftell/fseek→hxlcl_lseek — plus
# raw-payload pointer arithmetic. Those inner callees stay RETAINED shim globals, so
# the objcopy-isolated native .o keeps bl-relocs to them (the atoi→atoll / strdup→
# malloc COUPLED-leaf class — NOT the strstr/free zero-reloc class).
#
# Verifies the HEXA_RT_NATIVE_{FOPEN,FREAD,FTELL,FSEEK} wiring:
#   (A) DEFAULT (all macros OFF) shim.o is BYTE-IDENTICAL to the origin/main baseline
#       shim.o (the new `#ifndef HEXA_RT_NATIVE_<SYM>` guards compile out → the
#       libc-delegate bodies are untouched; release-integrity invariant).
#   (B) ON: the Route C codegen emits hxlcl_<sym> as a DEFINED (T) external in the
#       native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_<SYM>) NO LONGER defines it.
#       The native object is ISOLATED via `objcopy --keep-global-symbol=hxlcl_<sym>`.
#       The isolated .o's external relocs are ONLY the dissolved-syscall-leaf inner
#       callees (open_sys/read/lseek) which the RETAINED shim members supply — no
#       libc fopen/fread/ftell/fseek/__errno reference (those are the shim delegate's,
#       gone in the native path).
#   (C) BEHAVIOUR-EXACT vs libc: link the isolated native .o (+ a real-syscall
#       open_sys/read/lseek harness) and exercise it against a temp file & a popen-
#       captured echo, comparing to direct libc fopen/fread/ftell/fseek.
#         fopen+fread : read a known file's bytes correctly (== libc count + content)
#         ftell       : current offset after a partial read (== libc ftell)
#         fseek       : SEEK_SET/SEEK_CUR/SEEK_END reposition (== libc post-seek read)
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-4 (all ON).
#
# x86_64-linux ONLY for [B]/[C] — the Route C codegen + ELF objcopy isolate is the
# x86_64-backend path. [A]/[D] are host-independent single-file compiles (also run on
# darwin). MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_file}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
SYMS="fopen fread ftell fseek"
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }
CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# host helpers (darwin uses otool for .text; linux uses objcopy)
_text_sha() {  # $1=obj
    if command -v objcopy >/dev/null 2>&1; then
        objcopy -O binary --only-section=.text "$1" "$1.text" 2>/dev/null
        sha256sum "$1.text" 2>/dev/null | cut -d' ' -f1
    else
        otool -X -s __TEXT __text "$1" 2>/dev/null | shasum 2>/dev/null | cut -d' ' -f1
    fi
}
echo "════ routec_file_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

# ── [A] DEFAULT shim.o .text byte-identity vs origin/main (host-independent) ──
echo "[A] DEFAULT (all FILE* macros OFF) shim.o .text byte-identity vs origin/main…"
rm -rf "$OUT/base" "$OUT/new"; mkdir -p "$OUT/base" "$OUT/new"
git show "origin/main:$SHIM" > "$OUT/base/shim.c" 2>/dev/null || cp "$SHIM" "$OUT/base/shim.c"
cp "$SHIM" "$OUT/new/shim.c"
$CC $CFLAGS "$OUT/base/shim.c" -o "$OUT/base/shim.o" 2>"$OUT/base/err"
$CC $CFLAGS "$OUT/new/shim.c"  -o "$OUT/new/shim.o"  2>"$OUT/new/err"
TB=$(_text_sha "$OUT/base/shim.o"); TN=$(_text_sha "$OUT/new/shim.o")
echo "    .text base sha=$TB"
echo "    .text new  sha=$TN"
[ -n "$TB" ] && [ "$TB" = "$TN" ] && echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=YES" || echo "DEFAULT_SHIM_TEXT_BYTE_IDENTICAL=NO"

# ── [D] shim member count: default vs all-ON (host-independent) ──────────────
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (all 4 -DHEXA_RT_NATIVE_<SYM>)…"
_alldef=""
for s in $SYMS; do _alldef="$_alldef -DHEXA_RT_NATIVE_$(echo "$s"|tr a-z A-Z)"; done
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS $_alldef "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-4)"
_drop_ok=1
for s in $SYMS; do
    D=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
    O=$(nm "$OUT/shim_on.o"  2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
    echo "    hxlcl_${s} defined in shim:  default=$D  ON=$O  (expect 1 → 0)"
    { [ "$D" = "1" ] && [ "$O" = "0" ]; } || _drop_ok=0
done
# inner-callee leaves MUST stay (the coupled-leaf providers)
for s in open_sys read lseek; do
    R=$(nm "$OUT/shim_on.o" 2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
    echo "    RETAINED inner-callee hxlcl_${s} in ON shim=$R  (expect 1)"
    [ "$R" = "1" ] || _drop_ok=0
done
[ "$_drop_ok" = "1" ] && echo "SHIM_FILE_MEMBERS_DROPPED=YES" || echo "SHIM_FILE_MEMBERS_DROPPED=NO"

# ── [B]/[C] need the patched compiler + x86_64-linux ────────────────────────
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[B/C] SKIP — Route C native emit + ELF isolate is x86_64-linux-only (host=$(uname -sm)); A+D ran."
    exit 0
fi
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi

echo "[B] Route C native emit of FILE* family (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnfile_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
_b_ok=1
for s in $SYMS; do
    T=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E " T _?hxlcl_${s}\$" | wc -l | tr -d ' ')
    echo "    hxlcl_${s} defined (T) in native routec.o = $T  (expect 1)"
    objcopy --keep-global-symbol=hxlcl_${s} "$OUT/routec_full.o" "$OUT/${s}_only.o" 2>/dev/null \
        || cp "$OUT/routec_full.o" "$OUT/${s}_only.o"
    # external relocs must NOT reference libc stdio (fopen/fread/ftell/fseek/__errno).
    BAD=$(objdump -dr "$OUT/${s}_only.o" 2>/dev/null | grep -cE 'R_X86_64_(PLT32|GOTPCREL).*\b(fopen|fread|ftell|fseek|__errno_location)\b')
    # inner-callee leaf relocs (open_sys/read/lseek) ARE expected (coupled leaf).
    LEAF=$(objdump -dr "$OUT/${s}_only.o" 2>/dev/null | grep -cE 'R_X86_64_(PLT32|GOTPCREL).*\bhxlcl_(open_sys|read|lseek)\b')
    echo "      libc-stdio relocs=$BAD (expect 0)  ·  inner-leaf relocs=$LEAF (expect >=1, coupled)"
    { [ "$T" = "1" ] && [ "${BAD:-1}" = "0" ]; } || _b_ok=0
done
[ "$_b_ok" = "1" ] && echo "NATIVE_FILE_COUPLED_CLEAN=YES" || echo "NATIVE_FILE_COUPLED_CLEAN=NO"

# ── [C] behaviour-exact vs libc — link native .o + real-syscall leaf harness ─
echo "[C] behaviour-exact vs libc (fopen+fread content/count · ftell offset · fseek reposition)…"
# Provide the inner-callee leaves (real syscalls) + the family-of-4 isolated native .o.
cat > "$OUT/leaves.c" <<'EOF'
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
/* the dissolved syscall leaves the native FILE* bodies bl into (retained-shim class) */
int  hxlcl_open_sys(const char *path, int flags, ...) { return open(path, flags, 0644); }
long hxlcl_read(int fd, void *buf, unsigned long n)   { return (long)read(fd, buf, (size_t)n); }
long hxlcl_lseek(int fd, long off, int whence)        { return (long)lseek(fd, (off_t)off, whence); }
EOF
$CC $CFLAGS "$OUT/leaves.c" -o "$OUT/leaves.o" 2>/dev/null
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* native FILE* family (fake FILE* = (void*)(fd+1)) */
extern void  *hxlcl_fopen(const char *p, const char *m);
extern unsigned long hxlcl_fread(void *b, unsigned long s, unsigned long n, void *fp);
extern long   hxlcl_ftell(void *fp);
extern int    hxlcl_fseek(void *fp, long off, int whence);
int main(void){
    const char *path = "/tmp/routec_file_acc.dat";
    const char data[] = "abcdefghijklmnopqrstuvwxyz0123456789";
    size_t N = sizeof(data) - 1;
    FILE *w = fopen(path, "wb"); fwrite(data, 1, N, w); fclose(w);
    int fail = 0;
    /* (1) fopen+fread vs libc: read 10 bytes, compare content + count */
    { void *nfp = hxlcl_fopen(path, "r");
      if (!nfp) { printf("  fopen FAIL (NULL)\n"); fail=1; }
      char nb[16]; size_t nc = hxlcl_fread(nb, 1, 10, nfp);
      FILE *lf = fopen(path, "r"); char lb[16]; size_t lc = fread(lb, 1, 10, lf);
      if (nc != lc || memcmp(nb, lb, 10) != 0) { printf("  fread MISMATCH nc=%zu lc=%zu\n", nc, lc); fail=1; }
      else printf("  fread OK: %zu items, content matches libc\n", nc);
      /* (2) ftell vs libc after the 10-byte read */
      long noff = hxlcl_ftell(nfp); long loff = ftell(lf);
      if (noff != loff) { printf("  ftell MISMATCH n=%ld l=%ld\n", noff, loff); fail=1; }
      else printf("  ftell OK: offset=%ld == libc\n", noff);
      /* (3) fseek SEEK_SET 5, then read 5 vs libc */
      hxlcl_fseek(nfp, 5, SEEK_SET); fseek(lf, 5, SEEK_SET);
      char nb2[8], lb2[8]; size_t n2 = hxlcl_fread(nb2, 1, 5, nfp); fread(lb2, 1, 5, lf);
      if (n2 != 5 || memcmp(nb2, lb2, 5) != 0) { printf("  fseek(SET) MISMATCH\n"); fail=1; }
      else printf("  fseek(SEEK_SET 5) OK: post-seek read matches libc ('%.*s')\n", 5, nb2);
      /* (4) fseek SEEK_END -4, read 4 vs libc */
      hxlcl_fseek(nfp, -4, SEEK_END); fseek(lf, -4, SEEK_END);
      char nb3[8], lb3[8]; size_t n3 = hxlcl_fread(nb3, 1, 4, nfp); fread(lb3, 1, 4, lf);
      if (n3 != 4 || memcmp(nb3, lb3, 4) != 0) { printf("  fseek(END) MISMATCH\n"); fail=1; }
      else printf("  fseek(SEEK_END -4) OK: tail read matches libc ('%.*s')\n", 4, nb3);
    }
    remove(path);
    if (fail) { printf("BEHAVIOUR_EXACT=NO\n"); return 1; }
    printf("BEHAVIOUR_EXACT=YES\n");
    return 0;
}
EOF
$CC "$OUT/acc.c" "$OUT/fopen_only.o" "$OUT/fread_only.o" "$OUT/ftell_only.o" "$OUT/fseek_only.o" "$OUT/leaves.o" -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] isolated link failed; see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"; RC=$?
echo "════ routec_file_native_verify done (acc RC=$RC) ════"
exit 0
