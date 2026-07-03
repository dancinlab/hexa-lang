#!/usr/bin/env bash
# probe_progtu_gap.sh — enumerate the COMPLETE program-TU decl gap under drop-ON.
# Reuses the already-built /tmp/zeroc_dropon/ap.c (no re-transpile). Rebuilds
# ap_post.c WITHOUT the bad whole-extern injection, then compiles with
# -ferror-limit=0 to harvest EVERY undeclared symbol in ONE pass.
set -uo pipefail
ROOT="${ROOT:-$PWD}"; OUT="/tmp/zeroc_dropon"; CC=clang
cd "$ROOT"
CLUSTER_DEFS="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1 \
-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1 -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1 \
-DHEXA_RT_CORE_STRARR_READ_NATIVE=1 -DHEXA_ZEROC_RT_CORE_STRBUF_ARENA=1"
DROP_DEFS="-DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS"
CFLAGS="-c -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."

# rebuild a clean ap_post.c (no extern injection)
cp "$OUT/ap.c" "$OUT/flat4b.c"
python3 tool/s4_flatc_post.py "$OUT/flat4b.c" >/dev/null 2>&1 || true
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' \
       "$OUT/flat4b.c" > "$OUT/ap_post_b.c"
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' "$OUT/ap_post_b.c"; rm -f "$OUT/ap_post_b.c.bak"
sed -i.bak3 '1i\
#define HEXA_HAS_HEXA_RT_STDLIB 1
' "$OUT/ap_post_b.c"; rm -f "$OUT/ap_post_b.c.bak3"
if ! grep -q 'HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) {' self/runtime_core.c 2>/dev/null; then
cat >> "$OUT/ap_post_b.c" <<'RTFS'
#ifndef HEXA_RT_SELFEMIT
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) { (void)path; (void)data; return hexa_int(-1); }
HexaVal rt_fs_stat(HexaVal path) { (void)path; return hexa_void(); }
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep) { (void)path; (void)max_bytes; (void)keep; return hexa_int(0); }
#endif
RTFS
fi

echo "=== compile program TU drop-ON, -ferror-limit=0, harvest ALL undeclared ==="
$CC $CFLAGS $DROP_DEFS -ferror-limit=0 "$OUT/ap_post_b.c" -o "$OUT/program_b.o" 2>"$OUT/probe.err"
echo "RC=$?"
echo "--- distinct undeclared identifiers/functions ---"
grep -oE "(undeclared identifier|undeclared function) '[A-Za-z0-9_]+'" "$OUT/probe.err" | grep -oE "'[A-Za-z0-9_]+'" | sort -u | tr -d "'" | tee "$OUT/undeclared.txt"
echo "--- count ---"; wc -l < "$OUT/undeclared.txt"
echo "--- unknown type names ---"
grep -oE "unknown type name '[A-Za-z0-9_]+'" "$OUT/probe.err" | sort -u
echo "--- total error lines ---"; grep -c 'error:' "$OUT/probe.err"
echo "--- are these declared in runtime_core.c? (extern/def check, first 30) ---"
while read -r sym; do
  [ -z "$sym" ] && continue
  loc=$(grep -nE "(^| )(extern )?(HexaVal|int|void|long|double|char|size_t|bool)[ *]+$sym\(" self/runtime_core.c 2>/dev/null | head -1)
  echo "  $sym : ${loc:-<not in runtime_core.c>}"
done < <(head -30 "$OUT/undeclared.txt")
