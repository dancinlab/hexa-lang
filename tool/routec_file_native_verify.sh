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
#   (B) ARCHIVE: build runtime.a via stage_resolve_runtime_a (Case-B multi-object,
#       HEXA_RT_MULTIOBJ=1 + all 4 HEXA_RT_NATIVE_<SYM>=1). Each symbol must be
#       T-defined by its OWN isolated native member (hxlcl_<sym>_native.o), and the
#       ld -r multidef gate (S5) must report multiple_definition=0. This is the
#       AUTHORITATIVE release-path gate — NOT a standalone objcopy link: `objcopy
#       --keep-global-symbol=X` only re-binds the sibling globals to LOCAL, leaving
#       the whole-module .text present, so a standalone objdump over the isolated .o
#       reports the WHOLE module's relocs (popen/execve/fputs/…) — a false-fail of
#       "self-contained" that the merged strstr/free verify scripts also carry. The
#       coupled-leaf inner callees (open_sys/read/lseek) + hxlcl_malloc resolve from
#       the RETAINED shim members; the real proof is the archive links clean.
#   (C) BEHAVIOUR-EXACT vs libc: link a behaviour smoke against the ON runtime.a and
#       compare to direct libc fopen/fread/ftell/fseek:
#         fopen+fread : read a known file's bytes correctly (== libc count + content)
#         ftell       : current offset after a partial read (== libc ftell)
#         fseek       : SEEK_SET + SEEK_END reposition (== libc post-seek read)
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-4 (all ON).
#
# x86_64-linux ONLY for [B]/[C] — Route C codegen + ELF objcopy isolate + the archive
# build are the x86_64-backend path; needs a warm tree (self/runtime.c seeds present,
# via tool/build_aprime.sh) + a patched compiler ($APRIME/HEXA_SELFEMIT_BIN). [A]/[D]
# are host-independent single-file compiles (also run on darwin). MEASURE-ONLY:
# writes $OUT + rebuilds build/runtime.a; never stages/commits/flips git.
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

# [B]/[C] use the AUTHORITATIVE archive path (build_runtime_a_from_source via
# stage_resolve_runtime_a · Case-B multi-object), NOT a standalone objcopy link.
# Rationale: `objcopy --keep-global-symbol=X` only re-BINDS the sibling globals to
# LOCAL — the whole-module .text (popen/execve/fputs/…) stays present, so a
# standalone objdump reports the WHOLE module's relocs (a false-fail of "self-
# contained" — the merged strstr/free verify scripts share this artifact). The real
# release gate is: (i) the symbol is T-defined by its isolated native member in the
# built runtime.a, (ii) the ld -r multidef gate (S5) reports multiple_definition=0,
# (iii) a behaviour smoke links against that runtime.a and matches libc.
echo "[B] Route C native emit + ARCHIVE multidef gate (HEXA_RT_MULTIOBJ=1 + 4 gates ON) via $BIN…"
RA="$ROOT/build/runtime.a"
if [ ! -f "$ROOT/self/runtime.c" ]; then
    echo "[B/C] SKIP — no seeds (self/runtime.c absent); run tool/build_aprime.sh first to warm the tree. A+D ran."
    exit 0
fi
env CC="${CC:-clang}" LIBS="${LIBS:--lm}" CFLAGS_COMMON="${CFLAGS_COMMON:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}" \
    HEXA_SELFEMIT_BIN="$BIN" HEXA_RT_MULTIOBJ=1 \
    HEXA_RT_NATIVE_FOPEN=1 HEXA_RT_NATIVE_FREAD=1 HEXA_RT_NATIVE_FTELL=1 HEXA_RT_NATIVE_FSEEK=1 \
    bash tool/stage_resolve_runtime_a >"$OUT/archive.log" 2>&1 || { echo "ARCHIVE_BUILD_FAIL"; tail -30 "$OUT/archive.log" >&2; exit 1; }
MULTIDEF=$(grep -oE 'multiple_definition=[0-9]+' "$OUT/archive.log" | tail -1 | cut -d= -f2)
echo "    ld -r multidef gate (S5): multiple_definition=${MULTIDEF:-?}  (expect 0)"
_b_ok=1
[ "${MULTIDEF:-1}" = "0" ] || _b_ok=0
for s in $SYMS; do
    # symbol must be T-defined by its OWN isolated native member in the built runtime.a
    PROV=""
    for m in $(ar t "$RA" 2>/dev/null | grep "hxlcl_${s}_native.o"); do
        ar p "$RA" "$m" > "$OUT/_m.o" 2>/dev/null
        nm "$OUT/_m.o" 2>/dev/null | grep -qE " T _?hxlcl_${s}\$" && PROV="$m"
    done
    echo "    hxlcl_${s}: T-defined by archive member = ${PROV:-NONE}  (expect hxlcl_${s}_native.o)"
    [ "$PROV" = "hxlcl_${s}_native.o" ] || _b_ok=0
done
[ "$_b_ok" = "1" ] && echo "NATIVE_FILE_ARCHIVE_CLEAN=YES" || echo "NATIVE_FILE_ARCHIVE_CLEAN=NO"

# ── [C] behaviour-exact vs libc — link the behaviour smoke against the ON runtime.a ─
echo "[C] behaviour-exact vs libc (fopen+fread content/count · ftell offset · fseek SEEK_SET/END)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* native FILE* family (fake FILE* = (void*)(fd+1)) — resolved from the ON runtime.a */
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
    void *nfp = hxlcl_fopen(path, "r");
    if (!nfp) { printf("  fopen FAIL (NULL)\n"); return 2; }
    char nb[16]; size_t nc = hxlcl_fread(nb, 1, 10, nfp);
    FILE *lf = fopen(path, "r"); char lb[16]; size_t lc = fread(lb, 1, 10, lf);
    if (nc != lc || memcmp(nb, lb, 10) != 0) { printf("  fread MISMATCH nc=%zu lc=%zu\n", nc, lc); fail=1; }
    else printf("  fopen+fread OK: %zu items, content==libc (\"%.*s\")\n", nc, 10, nb);
    long noff = hxlcl_ftell(nfp); long loff = ftell(lf);
    if (noff != loff) { printf("  ftell MISMATCH n=%ld l=%ld\n", noff, loff); fail=1; }
    else printf("  ftell OK: offset=%ld == libc\n", noff);
    hxlcl_fseek(nfp, 5, SEEK_SET); fseek(lf, 5, SEEK_SET);
    char nb2[8], lb2[8]; size_t n2 = hxlcl_fread(nb2, 1, 5, nfp); fread(lb2, 1, 5, lf);
    if (n2 != 5 || memcmp(nb2, lb2, 5) != 0) { printf("  fseek(SET) MISMATCH\n"); fail=1; }
    else printf("  fseek(SEEK_SET 5) OK: read==libc (\"%.*s\")\n", 5, nb2);
    hxlcl_fseek(nfp, -4, SEEK_END); fseek(lf, -4, SEEK_END);
    char nb3[8], lb3[8]; size_t n3 = hxlcl_fread(nb3, 1, 4, nfp); fread(lb3, 1, 4, lf);
    if (n3 != 4 || memcmp(nb3, lb3, 4) != 0) { printf("  fseek(END) MISMATCH\n"); fail=1; }
    else printf("  fseek(SEEK_END -4) OK: tail==libc (\"%.*s\")\n", 4, nb3);
    remove(path);
    printf(fail ? "BEHAVIOUR_EXACT=NO\n" : "BEHAVIOUR_EXACT=YES\n");
    return fail;
}
EOF
$CC "$OUT/acc.c" "$RA" ${LIBS:--lm} -o "$OUT/acc" 2>"$OUT/link.err" \
    || { echo "    [C] archive link failed; see link.err"; tail -20 "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
"$OUT/acc"; RC=$?
echo "════ routec_file_native_verify done (acc RC=$RC) ════"
exit 0
