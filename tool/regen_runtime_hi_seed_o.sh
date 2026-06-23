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
# r21 (ING #35 batch 7) — syscall/libc fs + ffi-dlsym + ml leaves (9 bodies)
# whose every callee is supplied-outside-residual (libc getcwd/unlink/close/
# mkdtemp/mkstemp/opendir/glob/dlsym = link-dep + supplied prims). Hard assert.
S7="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(flush_stdout_c|hexa_cwd|hexa_matvec|hexa_tempdir|hexa_tempfile|rt_delete_file|hexa_listdir|hexa_glob|hexa_ffi_dlsym)$')"
# r21 batch 7b — hxlcl-delegate math leaves (5). hxlcl_sin/cos/log/exp
# supplied by zeroc_hxlcl_delegate.o seed (link-dep). Hard assert.
S7B="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_math_sin|hexa_math_cos|hexa_math_log|hexa_math_exp|hexa_swiglu_vec)$')"
# r23 (ING #35 batch 8) — 8 HI-tier bodies UNLOCKED by the r23 supply of the 7
# runtime.c-private mem/str statics (memcpy/memset/strlen/strncmp/getenv/strdup/
# strtoll) as EXTERNAL delegates in zeroc_hxlcl_delegate.o. Each static is now a
# link-dep, NOT a wall (r21 lens). Hard assert. STILL-WALLED (honest): the strbuf
# string-builder family (hexa_bytes_to_str_raw/hexa_chr_byte → hexa_strbuf_alloc
# = static-inline + file-static counter, NOT delegatable; r19 verdict).
S8="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_is_error|rt_read_lines|hexa_from_char_code|hexa_list_dir|rt_append_file|hexa_utc_iso_format|hexa_utc_iso_parse|hexa_http_get)$')"
# r24 (ING #35 batch 9) — ml/math array leaves (census-clean tail, 4 bodies).
# r24 CENSUS measured the 309-body hexa_* tail: only these 4 are clean supplied-
# link-dep leaves (every callee supplied-outside-residual or a supplied delegate
# hxlcl_exp/fmod or libc malloc/free). The rest route through measured walls
# (farr_gpu/syscall-static/strbuf/file-static pools/#ifdef-amalgam). Hard assert.
S9="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_silu|hexa_softmax|hexa_math_fmod|hexa_farr_set_out_disposition)$')"
# r25 (ING #35 batch 10) — time/sleep/input syscall-delegate leaves (11 bodies)
# UNLOCKED by the r25 supply of the 3 runtime.c-private syscall statics
# (clock_gettime/read/nanosleep) as EXTERNAL delegates in zeroc_hxlcl_delegate.o
# (byte-faithful to the frozen Linux-branch bodies; seedprov 0 → 1). Each static
# is now a link-dep, NOT a wall (r21/r23 lens). Hard assert. STILL-WALLED (honest):
# the exec_* / pipe_spawn / sha* family (file-static _hexa_stream_slots pool +
# native/exec_argv_sha256.c _hxa_* static helpers) + hexa_env_var (hxlcl_strcmp
# has no delegate + hexa_val_arena_* coupling).
S10="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_clock|hexa_timestamp|hexa_time_ms|hexa_now_monotonic_s|hexa_sleep|hexa_sleep_s|hexa_sleep_ms|hexa_sleep_ns|hexa_input|hexa_read_stdin|read_stdin_n_c)$')"
# r26 (ING #35 batch 11) — CARRIER-EMIT: 2 HI-tier array-ctor bodies
# (hexa_array_alloc/hexa_array_zeros_float) UNLOCKED by emitting their file-static
# _hx_stats counter carrier (_hx_r26_stats_array_new + _hx_stats_on guard) FRESH
# IN THE SEED TU. The r24 census's '(C) forbidden-wall' (needs frozen-blob
# de-static) is FALSIFIED: a file-static carrier exports no link symbol, the
# frozen runtime_core.c copy is in the DROPPED TU → emitting a fresh co-located
# copy collides with nothing. Hard assert. The body compiles the SHIPPING
# (HEXA_HAS_HEXA_RT_STDLIB) branch → rt_array_alloc/zeros_float (stdlib) link-dep.
S11="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_array_alloc|hexa_array_zeros_float)$')"
echo "regen_runtime_hi_seed: $OUT — $N/12 leaf rt_* + $M/16 libm-leaf hexa_math_* + $A/13 HexaVal-tail accessor + $S6/10 str/coerce/poly (r19) + $S7/9 fs/ffi/ml + $S7B/5 hxlcl-math (r21) + $S8/8 hxlcl mem/str-static (r23) + $S9/4 ml/math array (r24) + $S10/11 time/sleep/input (r25) + $S11/2 carrier-emit array-ctor (r26) bodies exported"
[ "$N" = "12" ] || { echo "regen_runtime_hi_seed: expected 12 rt_*, got $N" >&2; exit 3; }
[ "$M" = "16" ] || { echo "regen_runtime_hi_seed: expected 16 hexa_math_*, got $M" >&2; exit 4; }
[ "$A" = "13" ] || { echo "regen_runtime_hi_seed: expected 13 HexaVal-tail accessors, got $A" >&2; exit 5; }
[ "$S6" = "10" ] || { echo "regen_runtime_hi_seed: expected 10 str/coerce/poly (r19), got $S6" >&2; exit 6; }
[ "$S7" = "9" ] || { echo "regen_runtime_hi_seed: expected 9 fs/ffi/ml (r21), got $S7" >&2; exit 7; }
[ "$S7B" = "5" ] || { echo "regen_runtime_hi_seed: expected 5 hxlcl-math (r21), got $S7B" >&2; exit 8; }
[ "$S8" = "8" ] || { echo "regen_runtime_hi_seed: expected 8 hxlcl mem/str-static (r23), got $S8" >&2; exit 9; }
[ "$S9" = "4" ] || { echo "regen_runtime_hi_seed: expected 4 ml/math array (r24), got $S9" >&2; exit 10; }
[ "$S10" = "11" ] || { echo "regen_runtime_hi_seed: expected 11 time/sleep/input (r25), got $S10" >&2; exit 11; }
[ "$S11" = "2" ]  || { echo "regen_runtime_hi_seed: expected 2 carrier-emit array-ctor (r26), got $S11" >&2; exit 12; }
