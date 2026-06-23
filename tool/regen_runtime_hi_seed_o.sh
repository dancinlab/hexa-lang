#!/usr/bin/env bash
# tool/regen_runtime_hi_seed_o.sh — RFC 061 ∅ campaign zero-c r13 (ING #35).
# Assemble build/runtime_hi_seed.o from the SSOT-emitted seed C
# self/native/runtime_hi_seed.c (the first batch of runtime.c PROPER's HI-tier
# bodies — 12 self-contained leaf rt_* prims). 1-line TU pulls runtime.h.
#
# Regenerates the .c from the emitter SSOT (self/runtime_emit.hexa) first, so
# the seed always tracks the emitter, hexat-free + byte-deterministic.
#
# The DEFAULT / shipping build NEVER compiles this (byte-identical OFF). The
# seed supplies the SAME symbols frozen runtime.c defines — used ONLY under
# the experimental drop path. CC/ARCH_FLAG honored.
set -uo pipefail
ROOT="$PWD"
OUT="${1:-$ROOT/build/runtime_hi_seed.o}"
SEED="$ROOT/self/native/runtime_hi_seed.c"

# (re)generate the seed .c from the committed emitter SSOT
bash "$ROOT/tool/regen_runtime_hi_seed_c.sh" "$ROOT" >/dev/null 2>&1 || true
[ -f "$SEED" ] || { echo "regen_runtime_hi_seed: missing $SEED (emitter regen failed)" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/runtime_hi_seed_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/runtime_hi_seed.c"\n' > "$TU"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_runtime_hi_seed: compile failed (no $OUT)" >&2; exit 2; }
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(rt_isalnum|rt_isalpha|rt_net_fail|rt_net_zero|rt_posix_ok|rt_pthread_noop|rt_pthread_create_policy|rt_fmod|rt_exp|rt_log|rt_cos|rt_sin)$')"
# r14 (ING #35 batch 2) — the libm-leaf hexa_math_* cluster: 16 self-contained
# one-line wrappers that delegate to native libm (tanh/asin/erf/j0/…). The libm
# symbol stays an UNDEFINED ref in this object-only .o and is resolved by -lm at
# the final link, so these are emittable leaves (libm = link-dep, not a body wall).
M="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_math_tanh|hexa_math_tan|hexa_math_asin|hexa_math_acos|hexa_math_atan|hexa_math_atan2|hexa_math_pow|hexa_math_lgamma|hexa_math_tgamma|hexa_math_erf|hexa_math_erfc|hexa_math_j0|hexa_math_j1|hexa_math_isnan|hexa_math_isinf|hexa_math_isfinite)$')"
# r16/r17 (ING #35 batch 3+4) — HexaVal-tail accessor leaves (13 total): r16's 6
# (clamp/is_empty/byte_len/from_cstring/struct_free/str_parse_float) + r17's 7
# (struct_pack/unpack/rect/point/size_pack/random/char_code). Informational count
# (the hard asserts stay on the rt_*/math_* clusters); these supply HI-tier bodies.
A="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_clamp|hexa_is_empty|hexa_byte_len|hexa_from_cstring|hexa_struct_free|hexa_str_parse_float|hexa_struct_pack|hexa_struct_unpack|hexa_struct_rect|hexa_struct_point|hexa_struct_size_pack|hexa_random|hexa_char_code)$')"
# r19 (ING #35 batch 6) — str/coerce/poly leaves UNLOCKED by the r18
# alloc-WALL-2 = portable-link-dep verdict (10 bodies whose every callee is
# supplied OUTSIDE the residual). Informational count (the hard asserts stay on
# the rt_*/math_*/accessor clusters); these supply HI-tier bodies, residual -10.
S6="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_str_substr|hexa_str_bytes|hexa_to_bool|hexa_float_to_int|hexa_find_poly|hexa_bin|hexa_hex|hexa_one_hot|hexa_sum|hexa_dict_keys)$')"
echo "regen_runtime_hi_seed: $OUT — $N/12 leaf rt_* + $M/16 libm-leaf hexa_math_* + $A/13 HexaVal-tail accessor + $S6/10 str/coerce/poly (r19) bodies exported"
[ "$N" = "12" ] || { echo "regen_runtime_hi_seed: expected 12 rt_*, got $N" >&2; exit 3; }
[ "$M" = "16" ] || { echo "regen_runtime_hi_seed: expected 16 hexa_math_*, got $M" >&2; exit 4; }
[ "$A" = "13" ] || { echo "regen_runtime_hi_seed: expected 13 HexaVal-tail accessors, got $A" >&2; exit 5; }
[ "$S6" = "10" ] || { echo "regen_runtime_hi_seed: expected 10 str/coerce/poly (r19), got $S6" >&2; exit 6; }
