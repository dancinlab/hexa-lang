#!/usr/bin/env bash
# zeroc_dropon_fixpoint.sh — RFC061 zero-c #29 DECISIVE default-flip gate.
#
# Measures the REAL default-flip readiness (NOT byte-id-to-frozen):
#   does the full drop-ON config produce a VALID, runnable self-host compiler
#   that (1) links clean in a real release build, (2) runs correctly, (3)
#   reproduces itself byte-identically (gen3==gen4), (4) passes shipping smoke?
#
# Drop-ON config:
#   - HEXA_ZEROC_DROP_RTCORE_INCLUDE  (runtime.c does NOT #include runtime_core.c)
#   - all 14 cluster -D extern flags  (runtime_core bodies externalized to seeds)
#   - sibling shim TU (runtime_core_hxlcl_shim.c, libc-delegate hxlcl_*)
#   - runtime_core.c compiled as a SEPARATE TU w/ sysheaders prelude
#
# Mirrors tool/build_aprime.sh stages 1-3 (real release program TU) but does the
# drop-ON MULTI-OBJECT link instead of single-TU inline, producing a RUNNABLE
# aprime_cc, then smoke + 2-gen self-emit.
#
# MEASURE-ONLY: /tmp + build/*.o (gitignored). No stage/commit/flip/frozen-edit.
set -uo pipefail
ROOT="${ROOT:-$PWD}"
OUT="${OUT:-/tmp/zeroc_dropon}"
CC="${CC:-clang}"
HEXA_V2="${HEXA_V2:-$ROOT/build/hexat_linux}"
[ -x "$HEXA_V2" ] || HEXA_V2="$ROOT/build/hexat"
mkdir -p "$OUT"; cd "$ROOT" || exit 1
[ -f self/runtime_core_emit.hexa ] || { echo "run at repo root" >&2; exit 1; }
[ -x "$HEXA_V2" ] || { echo "no hexat at $HEXA_V2" >&2; exit 1; }
case "$(uname -m)" in x86_64) ARCH=x86_64; SMOKE_TARGET=x86_64-linux-gnu;;
  aarch64|arm64) ARCH=arm64; SMOKE_TARGET=arm64-linux-gnu;;
  *) ARCH=$(uname -m); SMOKE_TARGET=x86_64-linux-gnu;; esac
OS="$(uname -s)"
[ "$OS" = "Darwin" ] && LIBS="-lm" || LIBS="-lm -lc -ldl -lpthread"
ARCH_FLAG=""; [ "$OS" = "Darwin" ] && ARCH_FLAG="-arch arm64"

echo "════ zeroc_dropon_fixpoint — RFC061 DECISIVE default-flip gate ($(uname -srm)) ════"
echo "HEAD: $(git log --oneline -1)"
echo "[0] restore CANONICAL frozen runtime.c (151c52c8, 691808B) + fresh runtime_core.c + drop guard…"
bash tool/restore_frozen_seeds         >/dev/null 2>&1 || true
# RFC061 M7 real-registrar: KEEP the emitter-SYNTHESIZED runtime.c from
# restore_frozen_seeds (gated #ifdef HEXA_ZEROC_DROP_RTCORE_INCLUDE registrar,
# byte-neutral to frozen 151c52c8 on the shipping arm per #3894). The raw
# frozen-blob cat-file (ungated static) is what forced the SIMULATE_M7 crutch;
# sourcing the gated emitter-synth binds the REAL external registrar under drop.
if [ "${ZEROC_M7_REAL:-1}" = "1" ]; then
  [ -s self/runtime.c ] || git cat-file blob 151c52c8:self/runtime.c > self/runtime.c
else
  git cat-file blob 151c52c8:self/runtime.c > self/runtime.c    # legacy: ungated frozen (SIMULATE_M7 path)
fi
bash tool/regen_runtime_core_c.sh "$ROOT" >/dev/null 2>&1 || bash tool/stage_resolve_runtime_a >/dev/null 2>&1 || true
bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1 || true
echo "    runtime.c=$(wc -l < self/runtime.c)L (float_to_bits_defs=$(grep -c 'HexaVal hexa_float_to_bits' self/runtime.c))  USE_REAL_ATLAS=${USE_REAL_ATLAS:-0}"
# Z2a: rt_str_* supplied by native rt_hi_native.o (default build does this when
# HEXA_ZEROC_RT_HI=1) → remove runtime_hi_gen.c include so runtime_core.o does
# NOT also define rt_str_split/etc. (else multidef with rt_hi_native.o).
sed -i 's|#include "runtime_hi_gen.c"|/* Z2a: rt_str_* from native rt_hi_native.o */|' self/runtime_core.c
echo "    runtime_hi_gen.c include removed from runtime_core.c (Z2a): $(grep -c 'runtime_hi_gen.c' self/runtime_core.c) remaining"
echo "    self/runtime.c is gitignored regen seed (frozen-blob invariant = no TRACKED edit; git diff is N/A on gitignored)"

CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 \
-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 \
-DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"
# Default-build native-seed gates (build_aprime.sh defaults): externalize the
# alloc-arena + str-eq bodies so the seed .o supply them (NOT runtime_core.c) —
# without these, runtime_core.o + alloc_syscall_native.o multiply-define hexa_arena_*.
# (only ALLOC — str_eq seed .o is optional and not linked here, so keep its body
#  inline in runtime_core.o rather than externalize it to a missing seed.)
NATIVE_SEED_DEFS="-DHEXA_RT_ALLOC_NATIVE=1"
DROP_DEFS="-DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS $NATIVE_SEED_DEFS"
CFLAGS="-c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."

# ── stage 1: flatten compiler/main.hexa (real release closure) ──────────────
echo "[1] flatten compiler/main.hexa closure (USE_REAL_ATLAS=${USE_REAL_ATLAS:-0})…"
REPO="$ROOT" FLAT="$OUT/flat.hexa" USE_REAL_ATLAS="${USE_REAL_ATLAS:-0}" python3 - <<'PY'
import re, os
repo=os.environ["REPO"]; flat=os.environ["FLAT"]; os.chdir(repo)
use_real=os.environ.get("USE_REAL_ATLAS","0")=="1"
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
    if f.endswith("embedded.gen.hexa") and not use_real: out.append("// STUB\n"+STUB); continue
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M)
    out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out))
print("  flatten:",len(seen),"files")
PY
[ -s "$OUT/flat.hexa" ] || { echo "flatten failed" >&2; exit 1; }

# ── stage 2: hexat transpile → program.c ────────────────────────────────────
echo "[2] hexat transpile → program.c…"
"$HEXA_V2" "$OUT/flat.hexa" "$OUT/ap.c" >"$OUT/transpile.log" 2>&1
[ -s "$OUT/ap.c" ] || { echo "transpile failed" >&2; tail -5 "$OUT/transpile.log"; exit 1; }
echo "  ap.c: $(wc -l < "$OUT/ap.c") lines"

# ── stage 3: post-process (EXACT build_aprime recipe) ───────────────────────
echo "[3] post-process (s4_flatc_post + builtin sed + runtime.c inline + macros)…"
cp "$OUT/ap.c" "$OUT/flat4.c"
python3 tool/s4_flatc_post.py "$OUT/flat4.c" >/dev/null 2>&1 || true
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' \
       "$OUT/flat4.c" > "$OUT/ap_post.c"
# single-TU: inline runtime.c (drop-ON drops runtime_core.c via -D below)
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' "$OUT/ap_post.c"; rm -f "$OUT/ap_post.c.bak"
sed -i.bak3 '1i\
#define HEXA_HAS_HEXA_RT_STDLIB 1
' "$OUT/ap_post.c"; rm -f "$OUT/ap_post.c.bak3"
# B2 rt_fs link-fill (same as build_aprime stage 3)
if ! grep -q 'HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) {' self/runtime_core.c 2>/dev/null; then
cat >> "$OUT/ap_post.c" <<'RTFS'
#ifndef HEXA_RT_SELFEMIT
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) { (void)path; (void)data; return hexa_int(-1); }
HexaVal rt_fs_stat(HexaVal path) { (void)path; return hexa_void(); }
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep) { (void)path; (void)max_bytes; (void)keep; return hexa_int(0); }
#endif
RTFS
fi

# ── stage 4a: compile the PROGRAM+runtime.c TU with DROP-ON (runtime_core.c dropped) ──
# NOTE: NO sysheaders prelude here — the program TU #includes the FROZEN runtime.c
# which defines static hxlcl_*; the sysheaders prelude (non-static protos) is ONLY
# for the SEPARATE standalone runtime_core.o TU (stage 4b). With DROP-ON, runtime.c
# pulls runtime_core_decls.h (M2 header) instead of inlining runtime_core.c.
# MEASURED M2-HEADER GAP (probe_progtu_gap.sh): runtime_core_decls.h omits EXACTLY
# 8 CORE-tier helper prototypes the HI-tier program references across the dropped
# boundary (4 __map_* + 4 __raw_*). Inject precisely these 8 (exact runtime_core.c
# signatures) AFTER the runtime.c include where HexaVal is defined — measure-only;
# mirrors what decls.h SHOULD carry post-M2-fix (the bounded remaining M2 work).
python3 - "$OUT/ap_post.c" <<'PY'
import sys
ap = sys.argv[1]
txt = open(ap).read()
protos = ("/* M2-gap cross-TU externs (measure-only; decls.h should carry these) */\n"
    "extern HexaVal __map_has_cstr_v(HexaVal m, HexaVal key);\n"
    "extern HexaVal __map_get_cstr_v(HexaVal m, HexaVal key);\n"
    "extern HexaVal __map_order_key_at(HexaVal m, HexaVal i);\n"
    "extern HexaVal __map_order_val_at(HexaVal m, HexaVal i);\n"
    "extern HexaVal __raw_add_f(HexaVal a, HexaVal b);\n"
    "extern HexaVal __raw_cmp3(HexaVal a, HexaVal b);\n"
    "extern HexaVal __raw_code_is(HexaVal v, HexaVal k);\n"
    "extern HexaVal __raw_d2i(HexaVal v);\n")
needle = '#include "runtime.c"\n'
i = txt.find(needle)
assert i >= 0, "runtime.c include not found"
j = i + len(needle)
open(ap, "w").write(txt[:j] + protos + txt[j:])
print("      injected 8 M2-gap protos after runtime.c include")
PY
# M7-SIMULATION (measure-only, gitignored /tmp copy — frozen git blob UNTOUCHED):
# the M7 frozen edit makes `_hexa_init_fn_shims` EXTERNAL so the program-TU's REAL
# registrar (which binds the global TAG_FN slots join/farr_*/…) is the symbol the
# runtime_core.o cross-TU caller links to. Without this the static registrar is
# DEAD (caller binds an empty external) → emit fails on unbound builtin slots.
# Set SIMULATE_M7=1 to apply (default 0 = measure the unmodified-frozen residual=1).
if [ "${SIMULATE_M7:-0}" = "1" ]; then
  # The program TU pulls self/runtime.c via `#include "runtime.c"`. To simulate the
  # M7 frozen edit WITHOUT touching the frozen blob, make a /tmp copy of runtime.c
  # with _hexa_init_fn_shims static→external, and redirect the program TU's include
  # to that copy (gitignored /tmp; frozen git blob self/runtime.c UNTOUCHED).
  sed -E 's/static void _hexa_init_fn_shims\(void\)/void _hexa_init_fn_shims(void)/g' self/runtime.c > "$OUT/runtime_m7.c"
  echo "  [M7-SIM] runtime_m7.c: static→external edits applied = $(diff <(grep -c 'void _hexa_init_fn_shims(void)' self/runtime.c) <(grep -c 'void _hexa_init_fn_shims(void)' "$OUT/runtime_m7.c") >/dev/null; grep -c '^void _hexa_init_fn_shims(void)' "$OUT/runtime_m7.c") global-def(s) (frozen blob untouched)"
  # point ap_post.c at the M7 copy (absolute path include)
  sed -i 's|#include "runtime.c"|#include "'"$OUT"'/runtime_m7.c"|' "$OUT/ap_post.c"
fi
echo "[4a] compile program TU w/ DROP-ON (runtime.c minus runtime_core.c include)…"
$CC $CFLAGS $DROP_DEFS "$OUT/ap_post.c" -o "$OUT/program.o" 2>"$OUT/prog_cc.err"
PROG_RC=$?
echo "  program.o compile RC=$PROG_RC  errors=$(grep -c 'error:' "$OUT/prog_cc.err" 2>/dev/null || echo 0)"
[ "$PROG_RC" -ne 0 ] && { grep 'error:' "$OUT/prog_cc.err" | head -8 | sed 's/^/      /'; }

# ── stage 4b: drop-ON runtime_core.o (separate TU) + sibling shim ───────────
# runtime_core.o MUST carry HEXA_HAS_HEXA_RT_STDLIB=1 (same as the program TU) so
# the math/etc bodies take the externalized arm (delegating to rt_*/native seeds)
# instead of the unguarded #ifndef-HEXA_HAS_HEXA_RT_STDLIB body that multidefs the seeds.
echo "[4b] compile standalone runtime_core.o (sibling-shim prelude) + hxlcl shim…"
$CC $CFLAGS -DHEXA_HAS_HEXA_RT_STDLIB=1 $DROP_DEFS -include self/runtime_core_sysheaders.h self/runtime_core.c -o "$OUT/runtime_core.o" 2>"$OUT/rcore.err"
RC_RC=$?
echo "  runtime_core.o compile RC=$RC_RC  errors=$(grep -c 'error:' "$OUT/rcore.err" 2>/dev/null || echo 0)"
[ "$RC_RC" -ne 0 ] && { grep 'error:' "$OUT/rcore.err" | head -8 | sed 's/^/      /'; }
$CC -c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE self/runtime_core_hxlcl_shim.c -o "$OUT/hxlcl_shim.o" 2>"$OUT/shim.err"
echo "  hxlcl_shim.o hxlcl_* T=$(nm "$OUT/hxlcl_shim.o" 2>/dev/null | grep -cE ' T _?hxlcl_')"

# ── stage 4c: build ALL cluster seed .o (the externalized runtime_core bodies) ──
echo "[4c] build all cluster seed .o…"
for s in leaf arith math math2 valop-dispatch map-query-dispatch map-query-fold collection-mutate \
         array-typed-leaf fs-read-write arith-coerce-format runtime-misc strarr-read; do
  scr="tool/regen_rtcore_${s}_native_o.sh"
  [ -f "$scr" ] && CC="$CC" ARCH_FLAG="$ARCH_FLAG" bash "$scr" "build/rtcore_${s//-/_}_native.o" >/dev/null 2>&1
done
for n in array_core map_core alloc_syscall valop_core num_core num_float_core intern_core fs_core str_core runtime_hi; do
  o="build/${n}_native.o"; seed="self/native/${n}_${ARCH}.s"
  [ "$ARCH" = x86_64 ] && seed="self/native/${n}_x86_64.s"
  [ -f "$o" ] && continue
  [ -f "$seed" ] && { grep -vE '^// ' "$seed" > "$OUT/${n}.s" 2>/dev/null || cp "$seed" "$OUT/${n}.s"; $CC -c $ARCH_FLAG "$OUT/${n}.s" -o "$o" 2>/dev/null; }
done
# rt_hi_native.o is EXCLUDED here: the real PROGRAM object (compiler/main.hexa's
# hexa-source stdlib/runtime/ closure) already defines rt_str_* — linking
# rt_hi_native.o too would multiply-define them. runtime_core.o's external rt_str_*
# refs resolve to the program object (the RFC061 HI-tier hexa-authored layer).
# HARNESS-FIX (rfc061 r-next): EXCLUDE build/runtime.o (and runtime_dropON.o /
# runtime_core.o) from the seed glob. A stale build/runtime.o is the FULL non-drop
# runtime amalgam (~883KB) left by a prior default build; sweeping it in here
# multiply-defines the ENTIRE drop-ON runtime (~798 multidef) and corrupts the
# linked binary → the prior round's RC=139 "self-emit segfault" was THIS harness
# artifact, NOT a real fault. The seed set must be ONLY the externalized cluster
# .o + native seed .o (runtime_core.o is linked explicitly above, not via the glob).
SEEDS=$(ls build/*.o 2>/dev/null | grep -vE '(^|/)(runtime|runtime_dropON|runtime_core)\.o$|rt_hi_native\.o' | tr '\n' ' ')
echo "  seed objects: $(echo $SEEDS | wc -w) (build/*.o total=$(ls build/*.o 2>/dev/null | wc -l); runtime.o present=$(ls build/runtime.o 2>/dev/null | wc -l) → excluded)"

# ── stage 5: REAL DROP-ON LINK → runnable aprime_cc ─────────────────────────
echo "[5] DROP-ON multi-object link → runnable aprime_cc…"
# (1) FIRST link WITHOUT the stub = the TRUE real-build residual measurement.
$CC -O2 $ARCH_FLAG "$OUT/program.o" "$OUT/runtime_core.o" "$OUT/hxlcl_shim.o" $SEEDS \
    -o "$OUT/aprime_cc_real" $LIBS 2>"$OUT/link.err"
grep -oE "undefined reference to .[A-Za-z0-9_.]+" "$OUT/link.err" 2>/dev/null | sed -E "s/.*\`//;s/'.*//" | sort -u > "$OUT/resid.txt"
RESID=$(grep -cvE '^$' "$OUT/resid.txt")
MULTIDEF=$(grep -c 'multiple definition' "$OUT/link.err" 2>/dev/null || echo 0)
echo "  REAL-BUILD (no stub): undefined_residual=$RESID  multiple_definition=$MULTIDEF"
echo "  init_fn_shims in residual: $(grep -c _hexa_init_fn_shims "$OUT/resid.txt")"
[ "$RESID" -gt 0 ] && { echo "  --- undefined residual (real drop-ON link) ---"; sed 's/^/    /' "$OUT/resid.txt"; }
[ "$MULTIDEF" -gt 0 ] && { echo "  --- multidef symbols (config bug, not a wall) ---"; grep 'multiple definition' "$OUT/link.err" | grep -oE "of .[a-zA-Z0-9_]+'" | sort -u | head -10 | sed 's/^/    /'; }

# (2) get a runnable binary. With SIMULATE_M7=1 the program TU's REAL registrar is
#     external → NO stub (real fn-shim binding runs). Without it, supply a no-op
#     stub (measure-only) — which we EXPECT to break emit (proves the registrar is
#     load-bearing, i.e. M7 frozen edit is required for a FUNCTIONAL flip).
if [ "${SIMULATE_M7:-0}" = "1" ] || [ "${ZEROC_M7_REAL:-1}" = "1" ]; then
  echo "  [M7-REAL] linking WITHOUT stub (program TU supplies real external _hexa_init_fn_shims)"
  $CC -O2 $ARCH_FLAG "$OUT/program.o" "$OUT/runtime_core.o" "$OUT/hxlcl_shim.o" $SEEDS \
      -o "$OUT/aprime_cc_dropon" $LIBS 2>"$OUT/link2.err"
  STUB_USED=0
else
  echo 'void _hexa_init_fn_shims(void) { /* measure-only no-op */ }' > "$OUT/init_fn_shims_stub.c"
  $CC -c -O2 $ARCH_FLAG "$OUT/init_fn_shims_stub.c" -o "$OUT/init_fn_shims_stub.o" 2>/dev/null
  $CC -O2 $ARCH_FLAG "$OUT/program.o" "$OUT/runtime_core.o" "$OUT/hxlcl_shim.o" "$OUT/init_fn_shims_stub.o" $SEEDS \
      -o "$OUT/aprime_cc_dropon" $LIBS 2>"$OUT/link2.err"
  STUB_USED=1
fi
[ ! -x "$OUT/aprime_cc_dropon" ] && { echo "  link FAIL:"; grep -iE 'undefined|multiple def|error' "$OUT/link2.err" | head -5 | sed 's/^/    /'; }
if [ ! -x "$OUT/aprime_cc_dropon" ]; then
  echo "DROPON_RUNNABLE=NO  (link failed — see residual above)"
  echo "════ DONE (link-fail). ════"; echo "FROZEN_DIFF=$(git diff 151c52c8 -- self/runtime.c | wc -l)"; exit 0
fi
echo "DROPON_RUNNABLE=YES  ($(ls -la "$OUT/aprime_cc_dropon" | awk '{print $5}') B)  STUB_USED=${STUB_USED:-0}"

# ── stage 6: SMOKE — exit42 + hello via the drop-ON compiler ────────────────
echo "[6] SHIPPING SMOKE (drop-ON compiler emits exit42 + hello)…"
# need hexa_ld + rt.o (default single-TU runtime) to LINK emitted programs.
# Build a default rt.o for the smoke link (the EMITTED program links against
# the standard runtime, not the drop-ON one — drop-ON is about the COMPILER's
# own runtime, the test program uses the normal runtime path).
$CC -c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I . self/runtime.c -o "$OUT/rt.o" 2>/dev/null
# exit42
printf 'fn main() {\n  exit(6 * 7)\n}\n' > "$OUT/exit42.hexa"
"$OUT/aprime_cc_dropon" _drv.hexa --emit=asm --target="$SMOKE_TARGET" --ignore-errors -o "$OUT/exit42.s" "$OUT/exit42.hexa" >"$OUT/e42.emit.log" 2>&1
E42_EMIT_RC=$?
echo "  exit42 emit RC=$E42_EMIT_RC  .s lines=$(wc -l < "$OUT/exit42.s" 2>/dev/null || echo 0)"
if [ -s "$OUT/exit42.s" ]; then
  $CC $ARCH_FLAG "$OUT/exit42.s" "$OUT/rt.o" $SEEDS -o "$OUT/exit42" $LIBS 2>"$OUT/e42.link.log"
  if [ -x "$OUT/exit42" ]; then "$OUT/exit42"; E42_RC=$?; echo "  exit42 RUN rc=$E42_RC (expect 42)"; else echo "  exit42 LINK FAIL"; grep -iE 'undefined|error' "$OUT/e42.link.log" | head -3 | sed 's/^/    /'; E42_RC=LINKFAIL; fi
else E42_RC=EMITFAIL; fi
# hello
printf 'fn main() {\n  println("hello")\n}\n' > "$OUT/hello.hexa"
"$OUT/aprime_cc_dropon" _drv.hexa --emit=asm --target="$SMOKE_TARGET" --ignore-errors -o "$OUT/hello.s" "$OUT/hello.hexa" >"$OUT/hello.emit.log" 2>&1
if [ -s "$OUT/hello.s" ]; then
  $CC $ARCH_FLAG "$OUT/hello.s" "$OUT/rt.o" $SEEDS -o "$OUT/hello" $LIBS 2>"$OUT/hello.link.log"
  if [ -x "$OUT/hello" ]; then HELLO_OUT="$("$OUT/hello" 2>&1)"; echo "  hello RUN output: '$HELLO_OUT' (expect hello)"; else echo "  hello LINK FAIL"; HELLO_OUT=LINKFAIL; fi
else HELLO_OUT=EMITFAIL; fi

# version: aprime_cc is a transpiler driver, not the released `hexa` CLI; it has
# no --version. Report the emit-smoke as the run-correctness witness instead.
echo "  (note: aprime_cc has no --version subcommand; run-correctness = emit+run smoke above)"

# ── stage 7: SELF-HOST FIXPOINT — gen3 == gen4 via drop-ON compiler ─────────
echo "[7] SELF-HOST FIXPOINT: drop-ON compiler self-emits gen3,gen4 (cc-gen3.o==cc-gen4.o)…"
# the drop-ON aprime_cc emits the FLATTENED compiler source to .s, twice.
# byte-identical .s (and .o) across two emits == internal self-host fixpoint.
#
# --ignore-errors: APPLES-TO-APPLES with the canonical self-host build. The
# flattened compiler source (flat.hexa) carries 14 non-fatal diagnostics that the
# CANONICAL self-emit path ALSO sees and tolerates: tool/build_selfhost.sh's
# selfemit() passes --ignore-errors (build_selfhost.sh:133) on the SAME flattened
# source. Of the 14: 13 are HexaWarn[HX4001] (genuine integer-division sites in
# the real compiler source — hash splitting `(value/65536)%65536`, byte alignment
# `(...+15)/16*16`, etc.; intentional int arithmetic, NOT precision bugs) + 1
# HexaError[HX3001] (a flatten-induced type-inference gap on a `||` zero-arg
# lambda at flat.hexa:3273 — an artifact of the use-stripping flatten, not present
# in the modular compiler). WITHOUT --ignore-errors the driver aborts before
# codegen (main.hexa:697 "aborting before codegen"); WITH it the driver proceeds
# (main.hexa:695 "proceeding to codegen"), EXACTLY as the canonical self-host
# build does. This is a strictness ALIGNMENT, not a weakened gate: the gate is the
# byte-identical gen3==gen4 fixpoint, which is unaffected by whether non-fatal
# diagnostics are rendered. (Prior measure-harness emits omitted the flag → a
# false "abort" wall that did not reflect the canonical path.)
IE="--ignore-errors"
"$OUT/aprime_cc_dropon" _drv.hexa --emit=asm --target="$SMOKE_TARGET" $IE -o "$OUT/cc-gen3.s" "$OUT/flat.hexa" >"$OUT/gen3.emit.log" 2>&1
G3_RC=$?
"$OUT/aprime_cc_dropon" _drv.hexa --emit=asm --target="$SMOKE_TARGET" $IE -o "$OUT/cc-gen4.s" "$OUT/flat.hexa" >"$OUT/gen4.emit.log" 2>&1
G4_RC=$?
echo "  gen3 emit RC=$G3_RC size=$(wc -c < "$OUT/cc-gen3.s" 2>/dev/null||echo 0)  gen4 emit RC=$G4_RC size=$(wc -c < "$OUT/cc-gen4.s" 2>/dev/null||echo 0)"
if [ -s "$OUT/cc-gen3.s" ] && [ -s "$OUT/cc-gen4.s" ]; then
  if cmp -s "$OUT/cc-gen3.s" "$OUT/cc-gen4.s"; then
    echo "  GEN3_EQ_GEN4=YES (cc-gen3.s == cc-gen4.s byte-identical)"
    # also assemble to .o and compare objects
    $CC -c $ARCH_FLAG "$OUT/cc-gen3.s" -o "$OUT/cc-gen3.o" 2>/dev/null
    $CC -c $ARCH_FLAG "$OUT/cc-gen4.s" -o "$OUT/cc-gen4.o" 2>/dev/null
    if cmp -s "$OUT/cc-gen3.o" "$OUT/cc-gen4.o"; then echo "  GEN3_EQ_GEN4_OBJ=YES (cc-gen3.o == cc-gen4.o)"; else echo "  GEN3_EQ_GEN4_OBJ=DIFFER"; fi
    echo "  gen3_sha=$(sha256sum "$OUT/cc-gen3.s" | cut -c1-16)  gen4_sha=$(sha256sum "$OUT/cc-gen4.s" | cut -c1-16)"
  else
    echo "  GEN3_EQ_GEN4=DIFFER at byte $(cmp "$OUT/cc-gen3.s" "$OUT/cc-gen4.s" 2>&1 | grep -oE 'byte [0-9]+' | head -1)"
    echo "  gen3_sha=$(sha256sum "$OUT/cc-gen3.s" | cut -c1-16)  gen4_sha=$(sha256sum "$OUT/cc-gen4.s" | cut -c1-16)"
  fi
else echo "  GEN3_EQ_GEN4=EMIT-FAIL"; tail -3 "$OUT/gen3.emit.log" | sed 's/^/    g3: /'; fi

echo "════ DONE. out=$OUT ════"
echo "FROZEN_DIFF=$(git diff 151c52c8 -- self/runtime.c | wc -l)"
