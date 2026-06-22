#!/usr/bin/env bash
# tool/regen_rtcore_arith_native_o.sh — assemble build/rtcore_arith_native.o from
# the C SSOT self/native/rtcore_arith.c (zero-c leg-B r5 clean-6 arith link de-risk).
#
# The seed provides 6 pure-arithmetic __raw_* / __map_raw_* HexaVal wrappers
# (__raw_idiv/__raw_imod/__raw_d2i/__raw_code_is/__raw_add_f/__map_raw_len) as a
# SEPARATE object, so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_ARITH_NATIVE externing them out of the inline runtime_core.c)
# instead of compiling the inline #else bodies. The .o is produced from a 1-line
# wrapper TU that pulls in self/runtime.h for the HexaVal types/macros/protos
# then #include's the seed body. byte-faithful to the runtime_core.c #else arms
# by construction (same C, same callees resolved from the rest of the link).
#
# Every callee of these 6 is external-linkage or a macro (the seed-portability
# rule): hexa_int/hexa_float/hexa_bool/__hx_to_double are external T symbols in
# the linked binary, HX_INT/HX_FLOAT/HX_BOOL/HX_IS_BOOL/HX_MAP_LEN are macros.
# __raw_fmod (static hxlcl_fmod) and __raw_cmp3 (static _hexa_enum_pair_idx etc)
# are EXCLUDED — they call internal-linkage statics a separate .o can't resolve.
#
# Usage: bash tool/regen_rtcore_arith_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_arith_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_arith.c"
OUT="${1:-$ROOT/build/rtcore_arith_native.o}"
[ -f "$SEED" ] || { echo "regen_rtcore_arith: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_arith_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_arith.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_arith: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (___raw_idiv = 1 prefix + 2
# source underscores); ELF does not. Match an OPTIONAL leading underscore so the
# 6/6 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(__raw_idiv|__raw_imod|__raw_d2i|__raw_code_is|__raw_add_f|__map_raw_len)$')"
echo "regen_rtcore_arith: $OUT — $N/6 arith symbols exported"
[ "$N" = "6" ] || { echo "regen_rtcore_arith: expected 6 symbols, got $N" >&2; exit 3; }
