#!/usr/bin/env bash
# tool/regen_rtcore_array-typed-leaf_native_o.sh — assemble
# build/rtcore_array_typed_leaf_native.o from the C SSOT
# self/native/rtcore_array-typed-leaf.c (zero-c leg-B ARRAY-TYPED-LEAF link de-risk).
#
# The seed provides 10 LEAF typed-array ctors/accessors + zero-fill builders
# (hexa_arr_i64_new/_push/_len/_box, hexa_arr_f64_new/_push/_len/_box,
# hexa_arr_zeros_leaf, hexa_arr_zeros_leaf_int) as a SEPARATE object, so
# build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline #else bodies. The .o is produced
# from a 1-line wrapper TU that pulls in self/runtime.h for the HexaVal
# types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c inline arm by construction (same C, same callees resolved from
# the rest of the link).
#
# Every callee of these 10 is external-linkage or a macro (the seed-portability
# rule): malloc/calloc/realloc/free/fprintf/exit are libc; hexa_int/hexa_float/
# hexa_throw/hexa_str/__hx_to_double are external T symbols in the linked binary;
# HX_SET_ARR_*/HX_IS_INT/HX_INT are macros. None is a frozen-STATIC body, so the
# cluster is directly seed-portable (no external-delegate route needed). The
# arena fns (hexa_arena_mark/reset/rewind) are NOT in this seed — under the
# shipping HEXA_RT_ALLOC_NATIVE build they are already externed to the native
# alloc syscall seed (no inline body to extern out here).
#
# Usage: bash tool/regen_rtcore_array-typed-leaf_native_o.sh [OUT_O]  (run at repo root)
#   OUT_O defaults to build/rtcore_array_typed_leaf_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_array-typed-leaf.c"
OUT="${1:-$ROOT/build/rtcore_array_typed_leaf_native.o}"
[ -f "$SEED" ] || { echo "regen_rtcore_array_typed_leaf: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_array_typed_leaf_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_array-typed-leaf.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_array_typed_leaf: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (_hexa_arr_i64_new); ELF does
# not. Match an OPTIONAL leading underscore so the 10/10 check passes on both.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_arr_i64_new|hexa_arr_i64_push|hexa_arr_i64_len|hexa_arr_i64_box|hexa_arr_f64_new|hexa_arr_f64_push|hexa_arr_f64_len|hexa_arr_f64_box|hexa_arr_zeros_leaf|hexa_arr_zeros_leaf_int)$')"
echo "regen_rtcore_array_typed_leaf: $OUT — $N/10 typed-array-leaf symbols exported"
[ "$N" = "10" ] || { echo "regen_rtcore_array_typed_leaf: expected 10 symbols, got $N" >&2; exit 3; }
