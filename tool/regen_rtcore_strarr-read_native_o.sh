#!/usr/bin/env bash
# tool/regen_rtcore_strarr-read_native_o.sh — assemble
# build/rtcore_strarr-read_native.o from the C SSOT
# self/native/rtcore_strarr-read.c (zero-c RFC061 M5 r11 str-byte-read link
# de-risk).
#
# The seed provides 2 seed-portable runtime_core.c symbols from the clean 1:1
# "str-byte-read" cluster (hexa_str_char_code_at / hexa_str_byte_at) as a
# SEPARATE object, so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_STRARR_READ_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline #else bodies. The .o is
# produced from a small wrapper TU that pulls in self/runtime.h for the HexaVal
# types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c #else arms by construction (same C, same callees resolved from
# the rest of the link).
#
# Every callee of these 2 is external-linkage or a macro (seed-portability rule):
# hexa_throw/hexa_str/hexa_void/hexa_int are external T; snprintf is libc;
# HX_IS_STR/HX_INT/HX_STRLEN/HX_STR are macros. NO in-body calloc/realloc/
# strbuf_alloc/malloc, NO tag-switch+recursion, NO file-local-static touch.
# (hexa_array_get is EXCLUDED — its HEXA_OOB_TRACE branch calls runtime.c
# file-local statics hxlcl_getenv/hxlcl_backtrace; it stays inline.)
#
# Usage: bash tool/regen_rtcore_strarr-read_native_o.sh [OUT_O]  (run at repo root)
#   OUT_O defaults to build/rtcore_strarr-read_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_strarr-read.c"
OUT="${1:-$ROOT/build/rtcore_strarr-read_native.o}"
bash "$ROOT/tool/regen_rtcore_strarr-read_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_strarr-read: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_strarr_read_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "runtime_core_decls.h"\n#include "native/rtcore_strarr-read.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_strarr-read: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols; ELF does not. Match an
# OPTIONAL leading underscore so the 2/2 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_str_char_code_at|hexa_str_byte_at)$')"
echo "regen_rtcore_strarr-read: $OUT — $N/2 strarr-read symbols exported"
[ "$N" = "2" ] || { echo "regen_rtcore_strarr-read: expected 2 symbols, got $N" >&2; exit 3; }
