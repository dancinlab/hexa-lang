#!/usr/bin/env bash
# tool/regen_rtcore_map-query-fold_native_o.sh — assemble
# build/rtcore_map_query_fold_native.o from the C SSOT
# self/native/rtcore_map-query-fold.c (zero-c leg-B map-query-fold link de-risk).
#
# The seed provides 8 UNGUARDED map query HexaVal symbols (__map_has_cstr_v /
# __map_get_cstr_v / __map_order_key_at / __map_order_val_at / __map_set_cstr_v /
# __map_remove_cstr_v / hexa_map_get_v / hexa_map_to_array) as a SEPARATE object,
# so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline bodies. The .o is produced from
# a 1-line wrapper TU that pulls in self/runtime.h for the HexaVal types/macros/
# protos then #include's the seed body. byte-faithful to the runtime_core.c bodies
# by construction (same C, same callees resolved from the rest of the link).
#
# Every immediate callee of these 8 is external-linkage or a macro (the seed-
# portability rule): hexa_bool/void/str/int/map_get/map_entries/map_set_impl/
# map_remove_impl + the de-staticized hmap_find/hexa_fnv1a_str are external T
# symbols in the linked binary; HX_INT/HX_STR/HX_MAP_TBL are macros. The 11 dual-
# arm (HEXA_HAS_HEXA_RT_STDLIB-guarded) cluster fns and __map_ptr_eq (static
# inline in runtime.h) are EXCLUDED — see the seed header for why.
#
# All 8 are UNGUARDED single-body fns: their runtime_core.c definition compiles
# identically in the aprime build AND the stage-5 standalone smoke link (no
# HEXA_HAS_HEXA_RT_STDLIB dependence), so a single -DNATIVE extern is collision-
# safe on both link paths.
#
# Usage: bash tool/regen_rtcore_map-query-fold_native_o.sh [OUT_O]  (run at repo root)
#   OUT_O defaults to build/rtcore_map_query_fold_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_map-query-fold.c"
OUT="${1:-$ROOT/build/rtcore_map_query_fold_native.o}"
# zero-c leg-B (ING #29): the .c is a GENERATED, .gitignore'd artifact — regen it
# from the emitter SSOT self/native/rtcore_map-query-fold_emit.hexa (byte-identical
# by construction) BEFORE compiling, so the .c can stay untracked.
bash "$ROOT/tool/regen_rtcore_map-query-fold_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_map_query_fold: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_map_query_fold_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_map-query-fold.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_map_query_fold: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols; ELF does not. Match an
# OPTIONAL leading underscore so the 8/8 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(__map_has_cstr_v|__map_get_cstr_v|__map_order_key_at|__map_order_val_at|__map_set_cstr_v|__map_remove_cstr_v|hexa_map_get_v|hexa_map_to_array)$')"
echo "regen_rtcore_map_query_fold: $OUT — $N/8 map query symbols exported"
[ "$N" = "8" ] || { echo "regen_rtcore_map_query_fold: expected 8 symbols, got $N" >&2; exit 3; }
