#!/usr/bin/env bash
# tool/regen_rtcore_math_native_o.sh — assemble build/rtcore_math_native.o from
# the C SSOT self/native/rtcore_math.c (zero-c leg-B r7 clean-4 transcendental
# link de-risk).
#
# The seed provides 4 pure-transcendental HexaVal wrappers
# (hexa_sin/hexa_cos/hexa_exp/hexa_log) as a SEPARATE object, so build_aprime can
# LINK them from a standalone .o (with -DHEXA_RT_CORE_MATH_NATIVE externing them
# out of the inline runtime_core.c) instead of compiling the inline #else bodies.
# The .o is produced from a 1-line wrapper TU that pulls in self/runtime.h for the
# HexaVal types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c inline arm by construction (same C, same callees resolved from
# the rest of the link).
#
# Every callee of these 4 is external-linkage or a macro (the seed-portability
# rule): hexa_float/__hx_to_double are external T symbols in the linked binary,
# HX_FLOAT is a macro, and rt_sin/rt_cos/rt_exp/rt_log are EXTERNAL T cores. The
# inline body's only non-extern callee was the frozen-STATIC hxlcl_sin/cos/exp/log
# — but each is a 1-line delegate to the corresponding external rt_* (the r6
# external-delegate route), so the seed routes through rt_* directly. The
# #else-armed math fns (hexa_sqrt/pow/floor/…) are NOT in this seed — they are
# seed-portable but live inside a #if/#else and are deferred to a later round.
#
# Usage: bash tool/regen_rtcore_math_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_math_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_math.c"
OUT="${1:-$ROOT/build/rtcore_math_native.o}"
[ -f "$SEED" ] || { echo "regen_rtcore_math: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_math_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_math.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_math: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (_hexa_sin); ELF does not.
# Match an OPTIONAL leading underscore so the 4/4 check passes on both platforms.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_sin|hexa_cos|hexa_exp|hexa_log)$')"
echo "regen_rtcore_math: $OUT — $N/4 transcendental symbols exported"
[ "$N" = "4" ] || { echo "regen_rtcore_math: expected 4 symbols, got $N" >&2; exit 3; }
