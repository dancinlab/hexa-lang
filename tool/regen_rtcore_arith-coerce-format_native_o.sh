#!/usr/bin/env bash
# tool/regen_rtcore_arith-coerce-format_native_o.sh — assemble
# build/rtcore_arith-coerce-format_native.o from the C SSOT
# self/native/rtcore_arith-coerce-format.c (zero-c leg-B arith-coerce-format
# link de-risk).
#
# The seed provides 10 numeric/coercion/format HexaVal wrappers
# (hexa_concat_many/hexa_fma/hexa_len/hexa_null_coal/hexa_to_int/hexa_format/
# hexa_format_float/hexa_format_float_sci/hexa_print/hexa_str_char_at) as a
# SEPARATE object, so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline #else / non-native bodies. The
# .o is produced from a 1-line wrapper TU that pulls in self/runtime.h for the
# HexaVal types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c HEXA_HAS_HEXA_RT_STDLIB arms by construction (same C, same
# callees resolved from the rest of the link).
#
# Every callee of these 10 is external-linkage or a macro (the seed-portability
# rule): hexa_int/hexa_float/hexa_str/hexa_void/hexa_array_new/hexa_array_push/
# hexa_to_string/__hx_to_double + the rt_* delegates are external T symbols in
# the linked binary, HX_INT/HX_IS_STR/HX_IS_INT are macros. hexa_add_slow/sub/
# mul/div/truthy (VALOP-lane inner guard) and hexa_str_byte_at/char_code_at
# (HX_STRLEN → static-inline hexa_strlen_v_inline) are EXCLUDED — not clean.
#
# Usage: bash tool/regen_rtcore_arith-coerce-format_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_arith-coerce-format_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_arith-coerce-format.c"
OUT="${1:-$ROOT/build/rtcore_arith-coerce-format_native.o}"
# zero-c leg-B (ING #29): the seed .c is now a GENERATED, .gitignore'd artifact
# regenerated from its tracked emitter SSOT
# (self/native/rtcore_arith-coerce-format_emit.hexa). Regen it FIRST (hexat-free,
# byte-deterministic) so the .c is always present + fresh before we compile it.
bash "$ROOT/tool/regen_rtcore_arith-coerce-format_c.sh" "$ROOT" || true
[ -f "$SEED" ] || { echo "regen_rtcore_arith-coerce-format: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_acf_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_arith-coerce-format.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_arith-coerce-format: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols; ELF does not. Match an
# OPTIONAL leading underscore so the 10/10 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_concat_many|hexa_fma|hexa_len|hexa_null_coal|hexa_to_int|hexa_format|hexa_format_float|hexa_format_float_sci|hexa_print|hexa_str_char_at)$')"
echo "regen_rtcore_arith-coerce-format: $OUT — $N/10 arith-coerce-format symbols exported"
[ "$N" = "10" ] || { echo "regen_rtcore_arith-coerce-format: expected 10 symbols, got $N" >&2; exit 3; }
