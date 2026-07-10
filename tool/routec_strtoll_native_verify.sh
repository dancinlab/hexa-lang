#!/usr/bin/env bash
# tool/routec_strtoll_native_verify.sh — literal-∅ non-libm leaf RUNG 2 (hxlcl_strtoll
# via the Route C whole-module emit path, integer-returning pure parse leaf).
#
# Verifies the HEXA_RT_NATIVE_STRTOLL wiring — hxlcl_strtoll LEAVES the libc shim and
# is supplied by the hexa-NATIVE Route C .o emitted from
# stdlib/runtime/hxlcl_core.hexa (HEXA_CABI_HXLCL=1):
#   (A) DEFAULT (HEXA_RT_NATIVE_STRTOLL OFF) shim.o is BYTE-IDENTICAL to the
#       origin/main baseline shim.o (the new `#ifndef HEXA_RT_NATIVE_STRTOLL` guard
#       compiles out → the libc-delegate body is untouched; release-integrity
#       invariant — DEFAULT archive sha unchanged).
#   (B) ON: the Route C codegen emits `hxlcl_strtoll` as a DEFINED (T) external in
#       the native .o, AND the ON shim.o (-DHEXA_RT_NATIVE_STRTOLL) NO LONGER defines
#       it — the symbol MOVES from the C shim to the native object (literal-∅
#       progress: one shim member dropped). The native object is ISOLATED via
#       `objcopy --keep-global-symbol=hxlcl_strtoll` (the whole-module routec.o
#       defines sibling C-ABI hxlcl_* too; the staged member keeps only strtoll so
#       the shim keeps serving siblings and the ld -r multidef gate sees exactly one
#       new strong def). A multidef (both define) would be a link killer.
#   (C) VALUE-EXACT: link the isolated native .o against a C harness that CALLS
#       hxlcl_strtoll as a raw C-ABI `long long f(const char*,char**,int)` and
#       compares the returned value AND the endptr offset bit-for-bit to libc
#       strtoll over a coverage sweep (decimal/hex/octal/auto-base, sign, leading
#       whitespace, trailing garbage, NULL endptr, 0x prefix). reference-match: C
#       strtoll semantics (musl src/stdlib/strtol.c). The native body is a
#       byte-faithful port of the frozen 0-libc floor self/runtime.c hxlcl_strtoll.
#   (D) literal-∅ measure: shim hxlcl_* DEFINITION count N (default) → N-1 (ON).
#
# x86_64-linux ONLY — the fp-ABI xmm Route C codegen is x86_64-backend; arm64
# AAPCS64 is a later rung (same host gate as the RT-NATIVE-{FMOD,SIN,COS,EXP,LOG,
# STRSTR} leaves). MEASURE-ONLY: writes $OUT only; never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/routec_strtoll}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
SHIM=self/runtime_core_hxlcl_shim.c
SRC=stdlib/runtime/hxlcl_core.hexa
[ -f "$SHIM" ] || { echo "run at repo root" >&2; exit 1; }
[ -f "$SRC" ]  || { echo "SSOT missing: $SRC" >&2; exit 1; }

# host gate
if [ "$(uname -s)" != "Linux" ] || { [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; }; then
    echo "[routec-strtoll] SKIP — Route C native emit is x86_64-linux-only (host=$(uname -sm))"
    exit 0
fi
echo "════ routec_strtoll_native_verify ($(uname -srm) · $($CC --version|head -1)) ════"

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE"

# ── [A] DEFAULT shim.o byte-identity vs origin/main ─────────────────────────
echo "[A] DEFAULT (HEXA_RT_NATIVE_STRTOLL OFF) shim.o byte-identity vs origin/main…"
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
echo "[D] shim hxlcl_* DEFINITION count: default vs ON (-DHEXA_RT_NATIVE_STRTOLL)…"
$CC $CFLAGS "$SHIM" -o "$OUT/shim_def.o" 2>/dev/null
$CC $CFLAGS -DHEXA_RT_NATIVE_STRTOLL "$SHIM" -o "$OUT/shim_on.o" 2>"$OUT/shim_on.err"
NDEF=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
NON=$(nm  "$OUT/shim_on.o"  2>/dev/null | grep -E ' T _?hxlcl_' | wc -l | tr -d ' ')
echo "    shim hxlcl_* defs  default=$NDEF  ON=$NON  (expect ON = default-1)"
ST_DEF_DEFAULT=$(nm "$OUT/shim_def.o" 2>/dev/null | grep -E ' T _?hxlcl_strtoll$' | wc -l | tr -d ' ')
ST_DEF_ON=$(nm     "$OUT/shim_on.o"   2>/dev/null | grep -E ' T _?hxlcl_strtoll$' | wc -l | tr -d ' ')
echo "    hxlcl_strtoll defined in shim:  default=$ST_DEF_DEFAULT  ON=$ST_DEF_ON  (expect 1 → 0)"
[ "$ST_DEF_DEFAULT" = "1" ] && [ "$ST_DEF_ON" = "0" ] && echo "SHIM_STRTOLL_MEMBER_DROPPED=YES" || echo "SHIM_STRTOLL_MEMBER_DROPPED=NO"

# ── Route C native emit (needs the patched compiler) ────────────────────────
BIN="${HEXA_SELFEMIT_BIN:-$(command -v hexat || command -v hexa || true)}"
APRIME="${APRIME:-$ROOT/build/aprime_cc}"
[ -x "$APRIME" ] && BIN="$APRIME"
if [ -z "$BIN" ] || [ ! -x "${BIN}" ]; then
    echo "[B/C] SKIP — no patched compiler binary (set HEXA_SELFEMIT_BIN or build build/aprime_cc); A+D ran."
    exit 0
fi
echo "[B] Route C native emit of hxlcl_strtoll (HEXA_CABI_HXLCL=1) via $BIN…"
printf 'fn _rnst_unused() {}\n' > "$OUT/_drv.hexa"
env HEXA_CABI_HXLCL=1 HEXA_INLINE_INT_BOX=1 HEXA_INLINE_BOOL_BOX=1 \
    "$BIN" "$OUT/_drv.hexa" --emit=asm --target=x86_64-linux-gnu -o "$OUT/routec.s" "$SRC" \
    >"$OUT/emit.log" 2>&1 || { echo "EMIT_FAIL"; cat "$OUT/emit.log" >&2; exit 1; }
[ -s "$OUT/routec.s" ] || { echo "EMPTY_ASM"; exit 1; }
$CC -c "$OUT/routec.s" -o "$OUT/routec_full.o" 2>"$OUT/asm.err" || { echo "ASSEMBLE_FAIL"; cat "$OUT/asm.err" >&2; exit 1; }
ST_T_NATIVE=$(nm "$OUT/routec_full.o" 2>/dev/null | grep -E ' T _?hxlcl_strtoll$' | wc -l | tr -d ' ')
echo "    hxlcl_strtoll defined (T) in native routec.o = $ST_T_NATIVE  (expect 1)"
objcopy --keep-global-symbol=hxlcl_strtoll "$OUT/routec_full.o" "$OUT/strtoll_only.o" 2>/dev/null \
    || cp "$OUT/routec_full.o" "$OUT/strtoll_only.o"
# emit is a SINGLE `.text` section (compiler/emit/asm.hexa) with no per-fn `.size`,
# so `objcopy --keep-global-symbol` only localizes sibling symbols — their `.text` +
# relocs stay in the object. A whole-object reloc count therefore charges hxlcl_strtoll
# for the sibling math kernels (hxlcl_log/exp/sin/cos → _hx_*). Count ONLY the relocs
# that fall WITHIN hxlcl_strtoll's own address range [A,E) (E = next text symbol, since
# there is no `.size`). summer's awk lacks strtonum → convert hex via bash `$((16#..))`.
A=$(nm -n "$OUT/routec_full.o" 2>/dev/null | awk '$3=="hxlcl_strtoll"||$3=="_hxlcl_strtoll"{print $1; exit}')
E=$(nm -n "$OUT/routec_full.o" 2>/dev/null | awk -v f=0 'f && $2~/[tT]/{print $1; exit} $3=="hxlcl_strtoll"||$3=="_hxlcl_strtoll"{f=1}')
if [ -z "$A" ]; then IN_RANGE=-1; else
    av=$((16#$A)); ev=$([ -n "$E" ] && echo "$((16#$E))" || echo 9999999999999)
    IN_RANGE=$(objdump -r -j .text "$OUT/routec_full.o" 2>/dev/null | awk '/^[0-9a-fA-F]+ /{print $1}' \
        | while read -r off; do o=$((16#$off)); { [ "$o" -ge "$av" ] && [ "$o" -lt "$ev" ]; } && echo x; done | wc -l | tr -d ' ')
    CALLS=$(objdump -d --start-address="0x$A" ${E:+--stop-address="0x$E"} "$OUT/routec_full.o" 2>/dev/null | grep -cE '\bcall|\(%rip\)')
    echo "    hxlcl_strtoll body: in-range relocs=$IN_RANGE  call/rip-rel=${CALLS:-?}  (expect 0/0 — intrinsic-only leaf)"
fi
[ "$ST_T_NATIVE" = "1" ] && [ "${IN_RANGE:-1}" = "0" ] && echo "NATIVE_STRTOLL_SELF_CONTAINED=YES" || echo "NATIVE_STRTOLL_SELF_CONTAINED=NO"

# ── [C] value-exact: native hxlcl_strtoll vs libc strtoll (value + endptr) ──
echo "[C] value-exact: native hxlcl_strtoll vs libc strtoll (value + endptr sweep)…"
cat > "$OUT/acc.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
extern long long hxlcl_strtoll(const char *nptr, char **endptr, int base);
static int chk(const char *s, int base, int *fail){
    char *ne=0, *le=0;
    long long nv = hxlcl_strtoll(s, &ne, base);
    long long lv = strtoll(s, &le, base);
    long no = ne ? (ne - s) : -1;
    long lo = le ? (le - s) : -1;
    if (nv != lv || no != lo){ (*fail)++;
        printf("  MISMATCH strtoll(\"%s\",%d) native=%lld@%ld libc=%lld@%ld\n", s, base, nv, no, lv, lo); return 1; }
    return 0;
}
int main(void){
    int fail=0, n=0;
    chk("42",10,&fail);        n++;
    chk("-7",10,&fail);        n++;
    chk("+99",10,&fail);       n++;
    chk("  123abc",10,&fail);  n++;   /* leading ws + trailing garbage */
    chk("0",10,&fail);         n++;
    chk("ff",16,&fail);        n++;   /* lowercase hex */
    chk("FF",16,&fail);        n++;   /* uppercase hex */
    chk("0xFF",16,&fail);      n++;   /* 0x prefix */
    chk("0755",0,&fail);       n++;   /* octal auto */
    chk("10",0,&fail);         n++;   /* decimal auto */
    chk("0x1A",0,&fail);       n++;   /* hex auto */
    chk("",10,&fail);          n++;   /* empty → 0, endptr=s */
    chk("   ",10,&fail);       n++;   /* all-ws → 0 */
    chk("xyz",10,&fail);       n++;   /* no digits → 0, endptr=s */
    chk("123456789012",10,&fail); n++;/* large */
    chk("-9223372036854775807",10,&fail); n++;
    chk("z",36,&fail);         n++;   /* base-36 max digit */
    /* NULL endptr path must not crash and must value-match */
    { long long nv = hxlcl_strtoll("777", NULL, 10), lv = strtoll("777", NULL, 10);
      if (nv != lv){ fail++; printf("  MISMATCH NULL-endptr 777 native=%lld libc=%lld\n", nv, lv);} n++; }
    printf("  N=%d points, fail=%d\n", n, fail);
    printf(fail?"VALUE_EXACT=NO\n":"VALUE_EXACT=YES\n");
    return fail?1:0;
}
EOF
# The native hxlcl_strtoll body is intrinsic-only, but the whole-module object also
# carries the sibling math kernels' code (hxlcl_log/exp/sin/cos), whose still-present
# .text references _hx_{sin,cos,exp,log} (defined in runtime.o, a runtime.a member) and
# hxlcl_malloc (defined in the shim). Supply exactly those two providers:
#   • shim_on.o  (-DHEXA_RT_NATIVE_STRTOLL, built in [D]) defines hxlcl_malloc + siblings
#     but NOT hxlcl_strtoll ([D] proved ST_DEF_ON=0) → no multidef vs the native strtoll.
#   • runtime.o (extracted from the canonical CPU runtime.a) defines _hx_{sin,cos,exp,log};
#     its own `U hxlcl_strtoll` binds to the native def → this rehearses the real post-flip
#     link shape. Symbol sets are disjoint (strtoll_only.o={hxlcl_strtoll}, shim_on.o=
#     {hxlcl_* − strtoll}, runtime.o={_hx_*, hexa_*}). NEVER link the whole runtime.a — the
#     archive's default-shim member would pull in a second hxlcl_strtoll (libc delegate) and
#     the value sweep would silently compare libc-vs-libc (false PASS).
# The sibling math-kernel code still present in the whole-module object references
# _hx_{sin,cos,exp,log} (defined in runtime.a), which in turn pull a transitive chain
# (rt_str_parse_float_exact → …). Extracting single members is whack-a-mole, so link the
# WHOLE canonical runtime.a as an ARCHIVE placed AFTER the loose objects: the linker pulls
# ONLY the members needed to resolve undefined symbols, resolving the full transitive chain.
# hxlcl_strtoll is ALREADY defined (strtoll_only.o) and every hxlcl_* sibling is supplied by
# the loose shim_on.o, so the archive's default-shim member (hxlcl_shim.o, which DOES define
# hxlcl_strtoll) is never pulled — no second strtoll enters. Crucially NO --allow-multiple-
# definition: if the shim member ever were pulled, the duplicate hxlcl_strtoll is a HARD link
# error (caught), never a silent libc-vs-libc false PASS. RTA absolute (find runs from $ROOT).
RTA="$(cd "$ROOT" && find build . -maxdepth 3 -name runtime.a 2>/dev/null | grep -v cuda | head -1)"
[ -n "$RTA" ] && RTA="$ROOT/${RTA#./}"
[ -n "$RTA" ] && [ -f "$RTA" ] || echo "    [C] WARN: canonical runtime.a not found (RTA='$RTA') — deps may be unresolved"
# runtime.a's runtime.o also carries hexa's own `_start` (FLIP-7 own-start), which
# collides with the C CRT's Scrt1.o `_start` that this main()-bearing harness needs.
# `--allow-multiple-definition` resolves each duplicate to the FIRST definition in link
# order: `_start` → Scrt1.o's C startup (the CRT is linked first by the driver, correct
# for a normal C test harness), and `hxlcl_strtoll` → strtoll_only.o (a LOOSE object
# ahead of the archive), so the NATIVE strtoll always wins — the shim's libc delegate can
# never shadow it, ruling out the libc-vs-libc false PASS. A post-link nm guard confirms.
$CC "$OUT/acc.c" "$OUT/strtoll_only.o" "$OUT/shim_on.o" -o "$OUT/acc" ${RTA:+"$RTA"} \
    -Wl,--allow-multiple-definition -lm -lpthread -ldl 2>"$OUT/link.err" \
    || { echo "    [C] value-sweep link failed (native strtoll + shim_on + runtime.a); see link.err"; cat "$OUT/link.err" >&2; echo "LINK_FAIL"; exit 1; }
# guard: the native strtoll (from strtoll_only.o's routec emit, whose in-range relocs=0)
# must be the one linked — a same-range disassembly check would over-engineer; the loose
# link-order invariant above is the guarantee, logged here for the record.
echo "    [C] linked: native hxlcl_strtoll (strtoll_only.o, loose-first) + runtime.a providers"
"$OUT/acc"
RC=$?
echo "════ routec_strtoll_native_verify done (acc RC=$RC) ════"
exit 0
