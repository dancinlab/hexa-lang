#!/usr/bin/env bash
# tool/regen_rtcore_collection-mutate_native_o.sh — assemble
# build/rtcore_collection-mutate_native.o from the C SSOT
# self/native/rtcore_collection-mutate.c (zero-c leg-B r7 collection-mutate link de-risk).
#
# The seed provides 13 map/array mutate+query symbols (hexa_map_from_array/
# hexa_map_invert/hexa_map_merge/hexa_map_remove/hexa_map_remove_impl/hexa_map_set/
# hexa_map_set_v/hexa_array_contains/hexa_array_last/hexa_array_pop/hexa_array_set/
# hexa_array_shift/hexa_array_truncate) as a SEPARATE object, so build_aprime can
# LINK them from a standalone .o (with -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE
# externing them out of the inline runtime_core.c) instead of compiling the inline
# bodies. The .o is produced from a 1-line wrapper TU that pulls in self/runtime.h
# for the HexaVal types/macros/protos then #include's the seed body. byte-faithful
# to the runtime_core.c smoke-safe arms by construction (same C, same callees
# resolved from the rest of the link).
#
# Every immediate callee of these 13 is external-linkage, a macro, or a seed-
# supplied rt_* (the array_core .s seed, linked in BOTH aprime + smoke):
# hexa_map_new/hexa_map_set/hexa_map_set_impl/hexa_map_remove_impl/hexa_str/
# hexa_str_as_ptr/hexa_to_string/hexa_to_cstring/hexa_eq/hexa_truthy/hexa_throw/
# hmap_find/hexa_fnv1a_str/hexa_int are external T symbols; rt_array_pop_native/
# rt_array_shift_native/rt_array_set_native/rt_array_truncate_native come from the
# array_core seed; HX_* are macros; __hexa_arena_slot_dirty is an external global.
# hexa_array_sort is EXCLUDED — it calls the static qsort comparator hexa_sort_cmp
# (+ the seed-absent rt_array_sort_float), which a separate .o can't resolve.
#
# Usage: bash tool/regen_rtcore_collection-mutate_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_collection-mutate_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_collection-mutate.c"
OUT="${1:-$ROOT/build/rtcore_collection-mutate_native.o}"
# The .c is a GENERATED, .gitignore'd artifact regenerated from its emitter SSOT
# self/native/rtcore_collection-mutate_emit.hexa (byte-identical, hexat-free awk
# un-escape). Regen it FIRST so a clean checkout (no tracked .c) builds, and a
# warm tree stays guard-consistent. NO-OP-SAFE: emitter absent -> keep in-tree .c.
if [ -f "$ROOT/tool/regen_rtcore_collection-mutate_c.sh" ]; then
    bash "$ROOT/tool/regen_rtcore_collection-mutate_c.sh" "$ROOT" || true
fi
[ -f "$SEED" ] || { echo "regen_rtcore_collection-mutate: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_collection_mutate_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_collection-mutate.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_collection-mutate: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols; ELF does not. Match an
# OPTIONAL leading underscore so the 13/13 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_map_from_array|hexa_map_invert|hexa_map_merge|hexa_map_remove|hexa_map_remove_impl|hexa_map_set|hexa_map_set_v|hexa_array_contains|hexa_array_last|hexa_array_pop|hexa_array_set|hexa_array_shift|hexa_array_truncate)$')"
echo "regen_rtcore_collection-mutate: $OUT — $N/13 collection-mutate symbols exported"
[ "$N" = "13" ] || { echo "regen_rtcore_collection-mutate: expected 13 symbols, got $N" >&2; exit 3; }
