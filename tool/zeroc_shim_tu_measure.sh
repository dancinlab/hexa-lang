#!/usr/bin/env bash
# tool/zeroc_shim_tu_measure.sh — RFC061 zero-c #29 SIBLING-SHIM TU measurement.
#
# PURPOSE
# ───────
# The M3-include-drop wall (measured in project_hexa_rfc061_ladder GO/NO-GO
# scorecard) was: runtime_core.c CANNOT compile as a standalone TU, so the
# drop-ON link orphaned 82 runtime_core.c-internal bodies. Root cause:
# runtime_core.c is a #include FRAGMENT — it lacks (a) the system-header block
# (FILE/stdout/NULL/errno/…) and (b) the file-local hxlcl_* static helpers that
# the surrounding FROZEN runtime.c blob supplied by textual concatenation.
#
# This tool measures the SIBLING-SHIM attack (opt-in HEXA_ZEROC_RTCORE_SHIM_TU,
# default OFF, frozen-immutable — never edits self/runtime.c):
#   (1) self/runtime_core_sysheaders.h  — system #includes + hxlcl_* prototypes
#       force-included into the standalone runtime_core.c compile.
#   (2) self/runtime_core_hxlcl_shim.c  — external-linkage hxlcl_* definitions
#       (libc delegates) so runtime_core.o links against the sibling .o instead
#       of the frozen statics. The frozen statics still serve the DEFAULT #else.
#
# It reports: does runtime_core.c now compile STANDALONE, and what is the
# drop-ON link residual after the shim resolves the hxlcl_* + runtime_core
# bodies.  MEASURE-ONLY: writes to /tmp + build/*.o (gitignored). Never
# stages/commits/flips a default.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/zeroc_shim_tu}"; CC="${CC:-clang}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
[ -f self/runtime_core_emit.hexa ] || { echo "run at repo root" >&2; exit 1; }
case "$(uname -m)" in x86_64) ARCH=x86_64;; aarch64|arm64) ARCH=arm64;; *) ARCH=$(uname -m);; esac
OS="$(uname -s)"
[ "$OS" = "Darwin" ] && LIBS="-lm" || LIBS="-lm -lc -ldl -lpthread"

echo "════ zeroc_shim_tu_measure — RFC061 sibling-shim TU ($(uname -srm)) ════"
echo "[1] restore frozen seeds + regen runtime_core.c + drop guard…"
bash tool/restore_frozen_seeds       >/dev/null 2>&1 || true
bash tool/regen_runtime_core_c.sh    >/dev/null 2>&1 || { echo "regen failed" >&2; exit 1; }
bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1 || true

CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."
[ "$OS" = "Darwin" ] && CFLAGS="$CFLAGS -D_DARWIN_C_SOURCE"
CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 \
-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 \
-DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"

echo "[2] build native seed objects…"
for s in leaf arith math math2 valop-dispatch map-query-dispatch map-query-fold collection-mutate \
         array-typed-leaf fs-read-write arith-coerce-format runtime-misc strarr-read; do
  scr="tool/regen_rtcore_${s}_native_o.sh"; [ -f "$scr" ] && bash "$scr" "build/rtcore_${s//-/_}_native.o" >/dev/null 2>&1
done
for n in array_core map_core alloc_syscall valop_core num_core num_float_core intern_core fs_core str_core runtime_hi; do
  out="build/${n}_native.o"; seed="self/native/${n}_${ARCH}.s"
  [ -f "$out" ] && continue; [ -f "$seed" ] && $CC -c "$seed" -o "$out" 2>/dev/null
done
# HARNESS-FIX (rfc061 r-next): exclude stale FULL non-drop runtime objects from
# the seed glob (build/runtime.o is the 883KB amalgam → ~798 multidef + corrupt link).
SEEDS=$(ls build/*.o 2>/dev/null | grep -vE '(^|/)(runtime|runtime_dropON|runtime_core)\.o$' | tr '\n' ' ')
echo "    seeds: $(echo $SEEDS | wc -w) (runtime.o excluded)"

echo "[3] compile SHIM TU (self/runtime_core_hxlcl_shim.c)…"
$CC -c -O2 -std=gnu11 -D_GNU_SOURCE self/runtime_core_hxlcl_shim.c -o "$OUT/hxlcl_shim.o" 2>"$OUT/shim.err"
SHIM_RC=$?; SHIM_T=$(nm "$OUT/hxlcl_shim.o" 2>/dev/null | grep -cE ' T _?hxlcl_')
echo "    shim compile RC=$SHIM_RC  hxlcl_* T-symbols=$SHIM_T"
[ "$SHIM_RC" -eq 0 ] && echo "SHIM_TU_COMPILES=YES" || { echo "SHIM_TU_COMPILES=NO"; grep error: "$OUT/shim.err" | head; }

echo "[4] compile runtime_core.c STANDALONE w/ shim prelude (the WALL)…"
$CC $CFLAGS -include self/runtime_core_sysheaders.h \
    -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime_core.c -o "$OUT/runtime_core.o" 2>"$OUT/rcore.err"
RC_RC=$?; RC_ERRS=$(grep -c error: "$OUT/rcore.err")
echo "    runtime_core.c standalone compile RC=$RC_RC  errors=$RC_ERRS"
if [ "$RC_RC" -eq 0 ]; then echo "RT_CORE_STANDALONE_COMPILES=YES"
else echo "RT_CORE_STANDALONE_COMPILES=NO"; grep error: "$OUT/rcore.err" | head -8 | sed 's/^/      /'; fi

echo "[5] compile DROP-ON runtime.c + M3-LINK with shim…"
$CC $CFLAGS -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime.c -o "$OUT/runtime_dropON.o" 2>"$OUT/rton.err"
printf 'int main(void){return 0;}\n' > "$OUT/_main.c"; $CC -O2 -c "$OUT/_main.c" -o "$OUT/_main.o" 2>/dev/null
$CC -O2 "$OUT/runtime_dropON.o" "$OUT/runtime_core.o" "$OUT/hxlcl_shim.o" $SEEDS "$OUT/_main.o" \
    -o "$OUT/exe" $LIBS 2>"$OUT/link.err"
LINK_RC=$?
grep -oE "undefined reference to .[A-Za-z0-9_.]+" "$OUT/link.err" 2>/dev/null | sed -E "s/.*\`//" | sort -u > "$OUT/resid.txt"
grep -oE '"_?[A-Za-z0-9_.]+", referenced from' "$OUT/link.err" 2>/dev/null | sed -E 's/"(_?[A-Za-z0-9_.]+)".*/\1/' | sort -u >> "$OUT/resid.txt"
sort -u "$OUT/resid.txt" -o "$OUT/resid.txt"
RESID=$(grep -cvE '^$' "$OUT/resid.txt")
if [ "$LINK_RC" -eq 0 ]; then echo "    M3_LINK_WITH_SHIM=CLEAN (exe links)"; "$OUT/exe"; echo "    exe ran exit=$?"
else echo "    M3_LINK_WITH_SHIM=residual"; fi
echo "DROPLINK_RESIDUAL_AFTER_SHIM=$RESID"
RT=$(grep -cE '^rt_' "$OUT/resid.txt"); HX=$(grep -cE '^hexa_' "$OUT/resid.txt")
OTHER=$(grep -vE '^(rt_|hexa_)' "$OUT/resid.txt" | grep -cvE '^$')
echo "    partition: hexa-source-stdlib(rt_*)=$RT  hexa_*=$HX  other(frozen-coupled)=$OTHER"
echo "    --- non-rt_ residual (frozen-coupled floor) ---"; grep -vE '^rt_' "$OUT/resid.txt" | sed 's/^/      /'

# frozen immutability
git cat-file blob 151c52c8:self/runtime.c > "$OUT/frozen.c" 2>/dev/null
if diff -q "$OUT/frozen.c" self/runtime.c >/dev/null 2>&1; then echo "FROZEN_151c52c8_IMMUTABLE=YES"
else echo "FROZEN_151c52c8_IMMUTABLE=working-tree-mutated-by-droptool(restore to verify)"; fi
echo "════ DONE. resid=$OUT/resid.txt ════"
