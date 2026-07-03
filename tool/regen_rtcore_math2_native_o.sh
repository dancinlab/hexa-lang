#!/usr/bin/env bash
# tool/regen_rtcore_math2_native_o.sh — assemble build/rtcore_math2_native.o from
# the C SSOT self/native/rtcore_math2.c (zero-c leg-B r8 else-math link de-risk).
#
# The seed provides 12 #else-armed math HexaVal wrappers
# (hexa_sqrt/hexa_pow/hexa_floor/hexa_ceil/hexa_u_floor/hexa_abs/hexa_tan/
#  hexa_log10/hexa_round/hexa_tanh/hexa_log2/hexa_to_float) as a SEPARATE object,
# so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_MATH2_NATIVE externing them out of the inline runtime_core.c)
# instead of compiling the inline #else bodies. The .o is produced from a 1-line
# wrapper TU that pulls in self/runtime.h for the HexaVal types/macros/protos then
# #include's the seed body. byte-faithful to the runtime_core.c shipping (#else)
# arm by construction (same C, same callees resolved from the rest of the link).
#
# Every callee of these 12 is external-linkage or a macro (the seed-portability
# rule): hexa_float/hexa_int/__hx_to_double are external T symbols in the linked
# binary, HX_IS_INT/HX_INT/HX_FLOAT are macros, and rt_sqrt/rt_pow_*/rt_floor/
# rt_ceil/rt_u_floor/rt_abs_*/rt_tan/rt_log10/rt_round/rt_tanh/rt_log2/rt_to_float
# are EXTERNAL T cores (pub fn in stdlib/runtime/{math,numeric}.hexa). Unlike r7
# there is NO frozen-static callee in this cluster — the #else arm is already the
# clean delegate, so the seed copies it verbatim (no external-delegate re-route).
#
# Usage: bash tool/regen_rtcore_math2_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_math2_native.o · CC/ARCH_FLAG honored.
#
# SSOT NOTE (zero-c leg-B recursive, ING #29): self/native/rtcore_math2.c is no
# longer a tracked file — it is a .gitignore'd artifact regenerated here from its
# .hexa text-emitter SSOT (self/native/rtcore_math2_emit.hexa) via
# tool/regen_rtcore_math2_c.sh (deterministic awk un-escape, byte-identical to the
# former tracked .c). We synthesize the .c FIRST, then compile it.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_math2.c"
OUT="${1:-$ROOT/build/rtcore_math2_native.o}"
# Regenerate the .c artifact from its emitter SSOT before compiling (so the .c can
# be gitignored). NO-OP-SAFE: emitter absent → keeps any in-tree .c untouched.
bash "$ROOT/tool/regen_rtcore_math2_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_math2: missing $SEED (emitter regen produced no .c)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_math2_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_math2.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_math2: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (_hexa_sqrt); ELF does not.
# Match an OPTIONAL leading underscore so the 12/12 check passes on both platforms.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_sqrt|hexa_pow|hexa_floor|hexa_ceil|hexa_u_floor|hexa_abs|hexa_tan|hexa_log10|hexa_round|hexa_tanh|hexa_log2|hexa_to_float)$')"
echo "regen_rtcore_math2: $OUT — $N/12 else-math symbols exported"
[ "$N" = "12" ] || { echo "regen_rtcore_math2: expected 12 symbols, got $N" >&2; exit 3; }
