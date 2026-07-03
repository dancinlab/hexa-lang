#!/usr/bin/env bash
# tool/regen_rtcore_eqtruthy_native_o.sh — assemble
# build/rtcore_eqtruthy_native.o from the C SSOT
# self/native/rtcore_eqtruthy.c (zero-c leg-B r8 eqtruthy link de-risk).
#
# The seed provides 1 seed-portable runtime_core.c symbol (hexa_truthy) from the
# "eqtruthy" cluster (__vs_ptr_eq / hexa_fnv1a_str / hexa_index_get /
# hexa_index_set / hexa_iter_get / hexa_await_unwrap / hexa_valstruct_int /
# hexa_val_free_tree / hexa_mkdir / __hexa_try_pop / __hexa_try_cleanup) as a
# SEPARATE object, so build_aprime can LINK them from a standalone .o (with
# -DHEXA_RT_CORE_EQTRUTHY_NATIVE externing them out of the inline
# runtime_core.c) instead of compiling the inline #else bodies. The .o is
# produced from a small wrapper TU that pulls in self/runtime.h for the HexaVal
# types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c #else arms by construction (same C, same callees resolved from
# the rest of the link).
#
# Every callee AND referenced global of hexa_truthy is external-linkage or a macro
# (the seed-portability rule): hexa_array_new/get/set, hexa_map_get/set,
# hexa_str/str_char_at/to_cstring, hexa_int/bool/void, hexa_is_type/fnv1a_str,
# hmap_find, __hx_to_double are external T symbols; the only touched global is
# the PUBLIC extern __hexa_try_top (runtime.h:726); HX_* are macros; free/mkdir/
# fprintf/exit are libc. __hexa_try_push (static __hexa_try_stack),
# __hexa_last_error (static __hexa_error_val), hexa_args / hexa_real_args /
# hexa_script_path (static _hexa_argc / _hexa_argv) are EXCLUDED — they touch
# file-local statics a separate .o can't resolve.
#
# The wrapper TU pre-defines __vs_ptr_eq_DEFINED before including runtime.h so
# the header's `static inline __vs_ptr_eq` is suppressed and the seed's external
# definition is the one symbol (byte-identical body).
#
# Usage: bash tool/regen_rtcore_eqtruthy_native_o.sh [OUT_O]  (run at repo root)
#   OUT_O defaults to build/rtcore_eqtruthy_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_eqtruthy.c"
OUT="${1:-$ROOT/build/rtcore_eqtruthy_native.o}"
# The .c SEED is a GENERATED artifact (gitignored): regenerate it byte-identically
# from its emitter SSOT self/native/rtcore_eqtruthy_emit.hexa BEFORE compiling, so a
# clean checkout (where only the emitter is tracked) materializes the .c. The awk
# un-escape is byte-deterministic (proven cmp exit 0) -- a warm tree is a true no-op.
bash "$ROOT/tool/regen_rtcore_eqtruthy_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_eqtruthy: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_eqtruthy_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
# __vs_ptr_eq_DEFINED suppresses the static-inline in runtime.h so the seed's
# external __vs_ptr_eq is the single definition.
printf '#include "runtime.h"\n#include "native/rtcore_eqtruthy.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_eqtruthy: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols; ELF does not. Match an
# OPTIONAL leading underscore so the 1/1 check passes on both darwin and linux.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?hexa_truthy$')"
echo "regen_rtcore_eqtruthy: $OUT — $N/1 eqtruthy symbols exported"
[ "$N" = "1" ] || { echo "regen_rtcore_eqtruthy: expected 1 symbol, got $N" >&2; exit 3; }
