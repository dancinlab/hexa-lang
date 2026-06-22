#!/usr/bin/env bash
# tool/regen_rtcore_leaf_native_o.sh — assemble build/rtcore_leaf_native.o from
# the C SSOT self/native/rtcore_leaf.c (zero-c leg-B r4 leaf-cluster link de-risk).
#
# The seed provides the 10 HexaVal value-ctor/reinterpret symbols (hexa_int/
# float/bool/void/float_to_bits/bits_to_float/float_to_bits/bits_to_float/
# enum_str/enum_str_v) as a SEPARATE object, so build_aprime can LINK them from
# a standalone .o (with -DHEXA_RT_CORE_LEAF_NATIVE externing them out of the
# inline runtime_core.c) instead of compiling the inline #else bodies. The .o is
# produced from a 1-line wrapper TU that pulls in self/runtime.h for the HexaVal
# types then #include's the seed body. byte-faithful to the runtime_core.c #else
# arms by construction (same C aggregate-literals).
#
# Usage: bash tool/regen_rtcore_leaf_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_leaf_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_leaf.c"
OUT="${1:-$ROOT/build/rtcore_leaf_native.o}"
[ -f "$SEED" ] || { echo "regen_rtcore_leaf: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_leaf_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_leaf.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_leaf: compile failed (no $OUT)" >&2; exit 2
fi
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T (hexa_int|hexa_float|hexa_bool|hexa_void|hexa_float_to_bits|hexa_bits_to_float|float_to_bits|bits_to_float|hexa_enum_str|hexa_enum_str_v)$')"
echo "regen_rtcore_leaf: $OUT — $N/10 ctor symbols exported"
[ "$N" = "10" ] || { echo "regen_rtcore_leaf: expected 10 symbols, got $N" >&2; exit 3; }
