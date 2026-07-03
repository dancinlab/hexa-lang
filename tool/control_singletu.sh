#!/usr/bin/env bash
# control_singletu.sh — build a DEFAULT (non-drop, single-TU, REAL _hexa_init_fn_shims)
# aprime_cc from the SAME flatten/transpile + SAME atlas-fixture stub, then run the
# SAME emit smoke. Isolates whether the drop-ON "index out of bounds (len 0)" emit
# failure is the no-op fn-shim STUB (load-bearing) or the ATLAS fixture stub.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="/tmp/ctrl_singletu"; CC=clang
mkdir -p "$OUT"; cd "$ROOT"
ARCH=x86_64; SMOKE_TARGET=x86_64-linux-gnu; LIBS="-lm -lc -ldl -lpthread"
echo "════ control single-TU (non-drop, REAL init_fn_shims) ════"
echo "[0] restore CANONICAL frozen runtime.c (691808B) + fresh runtime_core.c…"
rm -f build/*.o
git cat-file blob 151c52c8:self/runtime.c > self/runtime.c
bash tool/regen_runtime_core_c.sh "$ROOT" >/dev/null 2>&1 || bash tool/stage_resolve_runtime_a >/dev/null 2>&1
echo "    runtime.c=$(wc -l < self/runtime.c)L runtime_core.c=$(wc -l < self/runtime_core.c)L float_to_bits_defs=$(grep -c 'HexaVal hexa_float_to_bits' self/runtime.c)"

echo "[1] flatten + transpile (reuse if present)…"
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
    for m in re.finditer(r'^\s*import\s+"([^"]+)"',txt,re.M): deps.append(os.path.normpath(os.path.join(d,m.group(1))))
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
HEXA_V2="$ROOT/build/hexat_linux"; [ -x "$HEXA_V2" ] || HEXA_V2="$ROOT/build/hexat"
"$HEXA_V2" "$OUT/flat.hexa" "$OUT/ap.c" >"$OUT/transpile.log" 2>&1
echo "  ap.c=$(wc -l < "$OUT/ap.c")L"

echo "[2] post-process (EXACT build_aprime single-TU recipe, NO drop)…"
cp "$OUT/ap.c" "$OUT/flat4.c"
python3 tool/s4_flatc_post.py "$OUT/flat4.c" >/dev/null 2>&1 || true
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' "$OUT/flat4.c" > "$OUT/ap_post.c"
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' "$OUT/ap_post.c"; rm -f "$OUT/ap_post.c.bak"
sed -i.bak3 '1i\
#define HEXA_HAS_HEXA_RT_STDLIB 1
' "$OUT/ap_post.c"; rm -f "$OUT/ap_post.c.bak3"
if ! grep -q 'HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) {' self/runtime_core.c 2>/dev/null; then
cat >> "$OUT/ap_post.c" <<'RTFS'
#ifndef HEXA_RT_SELFEMIT
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) { (void)path; (void)data; return hexa_int(-1); }
HexaVal rt_fs_stat(HexaVal path) { (void)path; return hexa_void(); }
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep) { (void)path; (void)max_bytes; (void)keep; return hexa_int(0); }
#endif
RTFS
fi
# Z2a + alloc native (default build), build the seeds
sed -i 's|#include "runtime_hi_gen.c"|/* Z2a */|' self/runtime_core.c
[ ! -f build/rt_hi_native.o ] && [ -f self/native/runtime_hi_x86_64.s ] && { grep -vE '^// ' self/native/runtime_hi_x86_64.s > "$OUT/rt_hi.s"; $CC -c "$OUT/rt_hi.s" -o build/rt_hi_native.o 2>/dev/null; }
for n in array_core map_core alloc_syscall; do o="build/${n}_native.o"; seed="self/native/${n}_x86_64.s"; [ -f "$seed" ] && { grep -vE '^// ' "$seed" > "$OUT/${n}.s"; $CC -c "$OUT/${n}.s" -o "$o" 2>/dev/null; }; done

echo "[3] compile single-TU aprime_cc (REAL init_fn_shims, no drop)…"
$CC -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -DHEXA_RT_ALLOC_NATIVE=1 -I self -I . \
    "$OUT/ap_post.c" build/rt_hi_native.o build/array_core_native.o build/map_core_native.o build/alloc_syscall_native.o \
    -o "$OUT/aprime_ctrl" $LIBS 2>"$OUT/cc.err"
echo "  compile RC=$?  errors=$(grep -c error: "$OUT/cc.err" 2>/dev/null||echo 0)"
[ ! -x "$OUT/aprime_ctrl" ] && { grep error: "$OUT/cc.err" | head -6 | sed 's/^/    /'; echo "CONTROL BUILD FAIL"; exit 1; }
echo "  aprime_ctrl=$(ls -la "$OUT/aprime_ctrl"|awk '{print $5}')B"

echo "[4] SAME emit smoke on CONTROL (atlas-fixture stub, REAL init_fn_shims)…"
printf 'fn main() {\n  exit(6 * 7)\n}\n' > "$OUT/e42.hexa"
"$OUT/aprime_ctrl" _drv.hexa --emit=asm --target="$SMOKE_TARGET" -o "$OUT/e42.s" "$OUT/e42.hexa" 2>&1 | head -3
echo "  emit RC=$? slines=$(wc -l < "$OUT/e42.s" 2>/dev/null||echo 0)"
if [ -s "$OUT/e42.s" ]; then
  $CC "$OUT/e42.s" build/rt_hi_native.o build/array_core_native.o build/map_core_native.o build/alloc_syscall_native.o -o "$OUT/e42" $LIBS 2>/dev/null
  # need full runtime for the emitted program; link the single-TU runtime obj
  $CC -c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -DHEXA_RT_ALLOC_NATIVE=1 -I self -I . self/runtime.c -o "$OUT/rt.o" 2>/dev/null
  $CC "$OUT/e42.s" "$OUT/rt.o" build/rt_hi_native.o build/array_core_native.o build/map_core_native.o build/alloc_syscall_native.o -o "$OUT/e42" $LIBS 2>"$OUT/e42link.err"
  [ -x "$OUT/e42" ] && { "$OUT/e42"; echo "  CONTROL exit42 rc=$? (expect 42)"; } || { echo "  CONTROL link fail"; grep -iE 'undefined|error' "$OUT/e42link.err"|head -3|sed 's/^/    /'; }
else echo "  CONTROL EMIT ALSO FAILS (len 0) → atlas-fixture stub is the cause, NOT the fn-shim"; fi
echo "════ control DONE ════"
