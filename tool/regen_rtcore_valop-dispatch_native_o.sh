#!/usr/bin/env bash
# tool/regen_rtcore_valop-dispatch_native_o.sh — assemble build/rtcore_valop-dispatch_native.o from
# the C SSOT self/native/rtcore_valop-dispatch.c (zero-c leg-B r9 valop-dispatch link de-risk).
#
# The seed provides 9 scalar arith/compare DISPATCHER HexaVal wrappers
# (hexa_add_slow/hexa_sub/hexa_mul/hexa_div/hexa_mod/hexa_cmp_lt/hexa_cmp_gt/
#  hexa_cmp_le/hexa_cmp_ge) as a SEPARATE object, so build_aprime can LINK them
# from a standalone .o (with
# -DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE externing them out of the inline runtime_core.c)
# instead of compiling the inline shipping-arm bodies. The .o is produced from a 1-line
# wrapper TU that pulls in self/runtime.h for the HexaVal types/macros/protos then
# #include's the seed body. byte-faithful to the runtime_core.c shipping-arm bodies
# (HEXA_HAS_HEXA_RT_STDLIB + HEXA_RT_VALOP_NATIVE) by construction (same C, same
# callees resolved from the rest of the link).
#
# Every callee of these 9 is external-linkage or a macro (the seed-portability
# rule): hexa_int is an external T symbol in the linked binary, HX_IS_INT/HX_INT/
# HX_IS_FLOAT/HX_IS_BOOL/HX_BOOL + _HX_COERCE_BOOL/_HX_CMP_NATIVE_ELIGIBLE are
# macros, and rt_{add_native,add_slow,sub,sub_native,mul,mul_native,div,div_native,
# mod,mod_native,cmp_lt..ge,cmp_lt..ge_native} are EXTERNAL T cores (valop_core_*.s
# native seeds + hexa-source numeric.hexa). There is NO frozen-static callee in this
# cluster — the dispatchers only pick a native fast path or delegate, so the seed
# copies the shipping arm verbatim (no external-delegate re-route).
#
# Usage: bash tool/regen_rtcore_valop-dispatch_native_o.sh [OUT_O]   (run at repo root)
#   OUT_O defaults to build/rtcore_valop-dispatch_native.o · CC/ARCH_FLAG honored.
#
# SSOT NOTE (zero-c leg-B recursive, ING #29): self/native/rtcore_valop-dispatch.c is no
# longer a tracked file — it is a .gitignore'd artifact regenerated here from its
# .hexa text-emitter SSOT (self/native/rtcore_valop-dispatch_emit.hexa) via
# tool/regen_rtcore_valop-dispatch_c.sh (deterministic awk un-escape, byte-identical to the
# former tracked .c). We synthesize the .c FIRST, then compile it.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_valop-dispatch.c"
OUT="${1:-$ROOT/build/rtcore_valop-dispatch_native.o}"
# Regenerate the .c artifact from its emitter SSOT before compiling (so the .c can
# be gitignored). NO-OP-SAFE: emitter absent → keeps any in-tree .c untouched.
bash "$ROOT/tool/regen_rtcore_valop-dispatch_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_valop-dispatch: missing $SEED (emitter regen produced no .c)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_valop-dispatch_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_valop-dispatch.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_valop-dispatch: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (_hexa_sub); ELF does not.
# Match an OPTIONAL leading underscore so the 9/9 check passes on both platforms.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_add_slow|hexa_sub|hexa_mul|hexa_div|hexa_mod|hexa_cmp_lt|hexa_cmp_gt|hexa_cmp_le|hexa_cmp_ge)$')"
echo "regen_rtcore_valop-dispatch: $OUT — $N/9 valop-dispatch symbols exported"
[ "$N" = "9" ] || { echo "regen_rtcore_valop-dispatch: expected 9 symbols, got $N" >&2; exit 3; }
