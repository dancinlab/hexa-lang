#!/usr/bin/env bash
# tool/regen_rtcore_map-query-dispatch_native_o.sh — assemble build/rtcore_map-query-dispatch_native.o from
# the C SSOT self/native/rtcore_map-query-dispatch.c (zero-c leg-B r10 map-query-dispatch link de-risk).
#
# The seed provides 9 map query/projection DISPATCHER HexaVal wrappers
# (hexa_map_keys/values/contains_key/entries/map_values/filter_keys/count/any/all)
# as a SEPARATE object, so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline shipping-arm bodies. The .o is
# produced from a 1-line wrapper TU that pulls in self/runtime.h for the HexaVal
# types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c shipping-arm bodies (HEXA_HAS_HEXA_RT_STDLIB) by construction
# (same C, same callees resolved from the rest of the link).
#
# Every callee of these 9 is external-linkage or a macro (the seed-portability
# rule): rt_map_{keys,values,entries,contains_key_b,map_values,filter_keys,
# count_pred,any_pred_b,all_pred_b} are EXTERNAL T hexa-source bodies;
# hexa_array_new/hexa_map_new/hexa_str/hexa_int/hexa_bool/hexa_truthy are external
# T symbols; HX_MAP_TBL/HX_IS_VOID/HX_INT are macros. There is NO frozen-static
# callee in this cluster.
#
# Usage: bash tool/regen_rtcore_map-query-dispatch_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_map-query-dispatch_native.o · CC/ARCH_FLAG honored.
#
# SSOT NOTE (zero-c leg-B recursive, ING #29): self/native/rtcore_map-query-dispatch.c is no
# longer a tracked file — it is a .gitignore'd artifact regenerated here from its
# .hexa text-emitter SSOT (self/native/rtcore_map-query-dispatch_emit.hexa) via
# tool/regen_rtcore_map-query-dispatch_c.sh (deterministic awk un-escape, byte-identical to the
# former tracked .c). We synthesize the .c FIRST, then compile it.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_map-query-dispatch.c"
OUT="${1:-$ROOT/build/rtcore_map-query-dispatch_native.o}"
bash "$ROOT/tool/regen_rtcore_map-query-dispatch_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_map-query-dispatch: missing $SEED (emitter regen produced no .c)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_map-query-dispatch_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_map-query-dispatch.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_map-query-dispatch: compile failed (no $OUT)" >&2; exit 2
fi
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_map_keys|hexa_map_values|hexa_map_contains_key|hexa_map_entries|hexa_map_map_values|hexa_map_filter_keys|hexa_map_count|hexa_map_any|hexa_map_all)$')"
echo "regen_rtcore_map-query-dispatch: $OUT — $N/9 map-query-dispatch symbols exported"
[ "$N" = "9" ] || { echo "regen_rtcore_map-query-dispatch: expected 9 symbols, got $N" >&2; exit 3; }
