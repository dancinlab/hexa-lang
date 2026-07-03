#!/usr/bin/env bash
# tool/regen_rtcore_fs-read-write_native_o.sh — assemble
# build/rtcore_fs-read-write_native.o from the C SSOT
# self/native/rtcore_fs-read-write.c (zero-c leg-B fs-read-write link de-risk).
#
# The seed provides 9 stdio-based binary file-I/O HexaVal wrappers
# (rt_read_file/rt_write_bytes/rt_write_bytes_v/rt_read_file_bytes/
# rt_read_bytes_at/rt_read_f32_at/rt_read_f32_array_at/rt_write_bytes_append/
# rt_write_bytes_append_v) as a SEPARATE object, so build_aprime can LINK them
# from a standalone .o (with -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE externing them
# out of the inline runtime_core.c) instead of compiling the inline #else bodies.
# The .o is produced from a 1-line wrapper TU that pulls in self/runtime.h for the
# HexaVal types/macros/protos then #include's the seed body. byte-faithful to the
# runtime_core.c bodies by construction (same C, same callees resolved from the
# rest of the link).
#
# Every callee of these 9 is external-linkage or a macro (the seed-portability
# rule): hexa_str/hexa_str_own/hexa_array_new/hexa_int/hexa_float/hexa_bool/
# hexa_valstruct_int/hexa_farr*_zeros/hexa_farr*_set are external T symbols in the
# linked binary; HX_STR/HX_INT/HX_FLOAT/HX_IS_INT/HX_IS_ARRAY/HX_TAG/HX_ARR_*/
# HX_SET_ARR_* are macros; fopen/fread/fwrite/fseek/ftell/fclose/malloc/free
# resolve from libc. rt_fs_append_atomic/rt_fs_stat/rt_fs_rotate_if_over are
# EXCLUDED — they are config-conditional definers (stage-4 failure-stubs vs the
# faithful/release standalone arm in runtime.c) a separate .o would double-define.
#
# Usage: bash tool/regen_rtcore_fs-read-write_native_o.sh [OUT_O]  (run at repo root)
#   OUT_O defaults to build/rtcore_fs-read-write_native.o · CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/rtcore_fs-read-write.c"
OUT="${1:-$ROOT/build/rtcore_fs-read-write_native.o}"
# Regen the .c from its emitter SSOT (self/native/rtcore_fs-read-write_emit.hexa)
# first, so the .c can be a .gitignore-d generated artifact (zero-c leg-B,
# recursive zero-c ING #29 - one fewer tracked self/**/*.c). NO-OP-SAFE: emitter
# absent keeps any in-tree .c; byte-DETERMINISTIC (fresh tree => SHA-identical).
bash "$ROOT/tool/regen_rtcore_fs-read-write_c.sh" "$ROOT" >&2 || true
[ -f "$SEED" ] || { echo "regen_rtcore_fs-read-write: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/rtcore_fs_rw_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/rtcore_fs-read-write.c"\n' > "$TU"
EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:|undefined' | head -5
if [ ! -f "$OUT" ]; then
    echo "regen_rtcore_fs-read-write: compile failed (no $OUT)" >&2; exit 2
fi
# Mach-O prepends a leading underscore to C symbols (_rt_read_file); ELF does not.
# Match an OPTIONAL leading underscore so the 9/9 check passes on both platforms.
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(rt_read_file|rt_write_bytes|rt_write_bytes_v|rt_read_file_bytes|rt_read_bytes_at|rt_read_f32_at|rt_read_f32_array_at|rt_write_bytes_append|rt_write_bytes_append_v)$')"
echo "regen_rtcore_fs-read-write: $OUT — $N/9 fs-read-write symbols exported"
[ "$N" = "9" ] || { echo "regen_rtcore_fs-read-write: expected 9 symbols, got $N" >&2; exit 3; }
