#!/usr/bin/env bash
# tool/regen_zeroc_rt_core_prims_o.sh — ZERO-C leg-B (ING #35, r11).
# Assemble build/zeroc_rt_core_prims.o from the C SSOT
# self/native/zeroc_rt_core_prims.c (the self-contained numeric/coercion rt_*
# CORE prims the drop-ON executable link needs). 1-line TU pulls runtime.h.
# Default build never compiles this (byte-identical OFF). CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/zeroc_rt_core_prims.c"
OUT="${1:-$ROOT/build/zeroc_rt_core_prims.o}"
[ -f "$SEED" ] || { echo "regen_zeroc_rt_core_prims: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/zeroc_rtprim_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/zeroc_rt_core_prims.c"\n' > "$TU"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_zeroc_rt_core_prims: compile failed (no $OUT)" >&2; exit 2; }
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(rt_abs_int|rt_abs_float|rt_floor|rt_ceil|rt_u_floor|rt_round|rt_fma_int|rt_fma_float|rt_pow_int|rt_to_float|rt_to_int|rt_len|rt_null_coal|rt_concat_many_arr|rt_format_float_f|rt_format_float_sci)$')"
echo "regen_zeroc_rt_core_prims: $OUT — $N/16 rt_* CORE prims exported"
[ "$N" = "16" ] || { echo "regen_zeroc_rt_core_prims: expected 16, got $N" >&2; exit 3; }
