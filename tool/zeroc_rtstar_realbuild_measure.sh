#!/usr/bin/env bash
# tool/zeroc_rtstar_realbuild_measure.sh — RFC061 zero-c #29 Target-2:
# prove the 43 rt_* drop-ON link residual is a PROBE-ARTIFACT, not a wall.
#
# The shim-TU measurement (zeroc_shim_tu_measure.sh) links ONLY the C floor
# (runtime.c + runtime_core.c + hxlcl shim + seed .o + libc). It does NOT link
# the hexa-authored HI-tier stdlib (stdlib/runtime/{io,ctype,math,numeric}.hexa
# → rt_print/rt_sqrt/rt_format/…), because those live in the COMPILED PROGRAM
# OBJECT, not the runtime substrate. So 43 rt_* show as undefined.
#
# In a REAL hexa build the program object (transpiled from compiler/main.hexa,
# which transitively imports the rt_* stdlib) DOES define them. This tool builds
# that real program object (flatten → hexat transpile → cc -c, the exact
# release path from tool/build_aprime.sh) and re-runs the drop-ON M3-link WITH
# the program object present. Expectation: the 43 rt_* resolve, residual → 1
# (only the genuinely frozen-coupled _hexa_init_fn_shims) or 0.
#
# MEASURE-ONLY: /tmp + build/*.o (gitignored). Never stages/commits/flips.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="${OUT:-/tmp/zeroc_rtstar}"; CC="${CC:-clang}"
HEXA_V2="${HEXA_V2:-$ROOT/build/hexat_linux}"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
[ -f self/runtime_core_emit.hexa ] || { echo "run at repo root" >&2; exit 1; }
[ -x "$HEXA_V2" ] || { echo "no hexat at $HEXA_V2" >&2; exit 1; }
case "$(uname -m)" in x86_64) ARCH=x86_64;; aarch64|arm64) ARCH=arm64;; *) ARCH=$(uname -m);; esac
OS="$(uname -s)"
[ "$OS" = "Darwin" ] && LIBS="-lm" || LIBS="-lm -lc -ldl -lpthread"

echo "════ zeroc_rtstar_realbuild_measure — Target-2 ($(uname -srm)) ════"
echo "[0] restore frozen seeds + regen runtime_core.c + drop guard…"
bash tool/restore_frozen_seeds         >/dev/null 2>&1 || true
bash tool/regen_runtime_core_c.sh      >/dev/null 2>&1 || { echo "regen failed" >&2; exit 1; }
bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1 || true

echo "[1] flatten compiler/main.hexa import+use closure (build_aprime stage-1)…"
REPO="$ROOT" FLAT="$OUT/flat.hexa" python3 - <<'PY'
import re, os
repo=os.environ["REPO"]; flat=os.environ["FLAT"]; os.chdir(repo)
seen=[]; sset=set()
STUB=('pub let ATLAS_HASH: string = "fixture"\n'
      'pub let ATLAS_SOURCE_COUNT: i64 = 0\n'
      'pub let ATLAS_GENERATED_AT: string = "fixture"\n'
      + ''.join(f'pub let ATLAS_{k}_NODES: [AtlasNode] = []\n' for k in "PCLEFRSXQ"))
def walk(f):
    f=os.path.normpath(f)
    if f in sset or not os.path.exists(f): return
    sset.add(f); d=os.path.dirname(f)
    txt=open(f,encoding="utf-8",errors="replace").read(); deps=[]
    for m in re.finditer(r'^\s*import\s+"([^"]+)"',txt,re.M):
        deps.append(os.path.normpath(os.path.join(d,m.group(1))))
    for m in re.finditer(r'^\s*use\s+"([^"]+)"',txt,re.M):
        p=m.group(1)
        if not p.endswith(".hexa"): p+=".hexa"
        for c in [p,os.path.join(d,p),os.path.join(d,os.path.basename(p))]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    for x in deps: walk(x)
    seen.append(f)
walk("compiler/main.hexa")
out=[]
for f in seen:
    if f.endswith("embedded.gen.hexa"): out.append("// STUB\n"+STUB); continue
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M)
    out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out))
print("  flatten:",len(seen),"files")
PY
[ -f "$OUT/flat.hexa" ] || { echo "flatten failed" >&2; exit 1; }

echo "[2] hexat transpile flat.hexa → program.c…"
"$HEXA_V2" "$OUT/flat.hexa" "$OUT/program.c" >"$OUT/transpile.log" 2>&1
[ -s "$OUT/program.c" ] || { echo "transpile failed" >&2; tail -5 "$OUT/transpile.log"; exit 1; }
echo "  program.c: $(wc -l < "$OUT/program.c") lines"

echo "[3] post-process (s4_flatc_post + sha/list_dir rewrites)…"
cp "$OUT/program.c" "$OUT/flat4.c"
python3 tool/s4_flatc_post.py "$OUT/flat4.c" >/dev/null 2>&1 || true
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' \
       "$OUT/flat4.c" > "$OUT/program_post.c"
# Program object must NOT re-include runtime.c (drop-ON runtime.o supplies it).
# Strip the runtime include so the program TU contributes ONLY the hexa-source
# rt_* (+ user fns) and references the runtime externally — mirrors the
# multi-object drop-ON link (runtime.o + program.o + seeds).
#REMOVED-BAD-SED# sed -i 's|#include "runtime.c"|#include "runtime.h"|; s|#include "runtime.h"|/* runtime external */|' "$OUT/program_post.c"

CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 \
-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 \
-DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"
CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."

echo "[4] compile program object (the real release path: HEXA_HAS_HEXA_RT_STDLIB)…"
$CC $CFLAGS -DHEXA_HAS_HEXA_RT_STDLIB=1 -include self/runtime_core_decls.h "$OUT/program_post.c" -o "$OUT/program.o" 2>"$OUT/prog_cc.err"
PROG_RC=$?
if [ "$PROG_RC" -ne 0 ]; then
  echo "  program.o compile RC=$PROG_RC (errors below) — fallback: count rt_* defs in program.c"
  grep -c error: "$OUT/prog_cc.err"; grep error: "$OUT/prog_cc.err" | head -6 | sed 's/^/    /'
fi
PROG_RT_T=$(nm "$OUT/program.o" 2>/dev/null | grep -cE ' T rt_')
echo "  program.o rt_* T-symbols=$PROG_RT_T"

echo "[5] rebuild drop-ON runtime.o + standalone runtime_core.o + shim + seeds…"
$CC $CFLAGS -include self/runtime_core_sysheaders.h \
    -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime_core.c -o "$OUT/runtime_core.o" 2>"$OUT/rcore.err"
$CC $CFLAGS -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
    self/runtime.c -o "$OUT/runtime_dropON.o" 2>"$OUT/rton.err"
$CC -c -O2 -std=gnu11 -D_GNU_SOURCE self/runtime_core_hxlcl_shim.c -o "$OUT/hxlcl_shim.o" 2>/dev/null
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

echo "[6] M3-LINK drop-ON WITH real program object…"
$CC -O2 "$OUT/runtime_dropON.o" "$OUT/runtime_core.o" "$OUT/hxlcl_shim.o" "$OUT/program.o" $SEEDS \
    -o "$OUT/exe" $LIBS 2>"$OUT/link.err"
LINK_RC=$?
grep -oE "undefined reference to .[A-Za-z0-9_.]+" "$OUT/link.err" 2>/dev/null | sed -E "s/.*\`//" | sort -u > "$OUT/resid.txt"
sort -u "$OUT/resid.txt" -o "$OUT/resid.txt"
RESID=$(grep -cvE '^$' "$OUT/resid.txt")
RT=$(grep -cE '^rt_' "$OUT/resid.txt")
echo "DROPLINK_RESIDUAL_WITH_PROGRAM=$RESID"
echo "  rt_* still-undefined=$RT"
echo "  --- residual ---"; sed 's/^/    /' "$OUT/resid.txt"
echo "════ DONE. resid=$OUT/resid.txt ════"
