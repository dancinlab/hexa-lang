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
# r29 (ING #29) — CARRIER-EMIT bare-wrapper bulk harvest (52). 52 HI-tier
# dispatch/FFI/term/ad/farr/forge bodies ported VERBATIM from the frozen
# runtime.c #else branch — each a single return-delegate to its hexa_*/term_*
# impl (the r28 FFI extern-call pattern). The impl callees stay UNDEFINED
# link-deps (shipping stdlib/runtime resolves them at final link). Forward
# callee protos are emitted fresh seed-local so the seed TU compiles WITHOUT
# the frozen blob (151c52c8 never edited). Hard assert.
S12="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(ad_matmul|adamw_step|adamw_step_mixed|ansatz_pack|exec_stream_async|exec_stream_close|exec_stream_close_stdin|exec_stream_kill|exec_stream_open|exec_stream_poll|exec_stream_write|farr_adamw_step_gpu|farr_adamw_step_inplace|farr_ce_seed|farr_ce_seed_gpu|farr_matmul_gpu|farr_packed_gemv_offset|farr_parameter_shift_grad|farr_pauli_exp_inplace|farr_pauli_expectation|farr_rope_bwd_gpu|farr_rope_gpu|farr_simplex_set|farr_uccsd_apply|farr_vec_blend|farr_vec_reflect|farr_vertex_copy|forge_dispatch_ffn_fp64_via_bf16|forge_dispatch_matmul|ham_pack|hexa_exec_stream_async|hexa_exec_stream_close|hexa_exec_stream_close_stdin|hexa_exec_stream_kill|hexa_exec_stream_open|hexa_exec_stream_poll|hexa_exec_stream_write|hexa_exec_with_status3|hexa_is_alpha|hexa_is_alphanumeric|hexa_json_decode|hexa_json_encode|hexa_term_getppid|hexa_term_install_sigint|hexa_term_install_sigwinch|hexa_term_isatty_stdin|hexa_term_isatty_stdout|hexa_term_raw_enter|hexa_term_raw_restore|hexa_term_read_byte|hexa_term_sigint_pending|hexa_term_sigwinch_pending)$')"
# r30 (ING #29 batch 13) -- CARRIER-EMIT real-impl harvest: the FP32 farr32
# (8) + int64 farr_int (7 clean) handle-table subsystems. Each body routes
# through a file-static handle table (_hx_farr32_* / _hx_iarr_* + freelist) --
# the r24 census's '(C) forbidden-wall' class, FALSIFIED by r26: a file-static
# carrier exports no link symbol + the frozen copy is in the DROPPED TU, so a
# fresh co-located carrier in the seed TU collides with nothing. Every callee
# supplied-outside-residual (hexa_as_num/int/float/void prims + __hx_to_double/
# HX_INT runtime.h + hxlcl_memcpy r23-delegate + libc calloc/realloc/free).
# Hard assert. STILL-WALLED (honest, measured r30): FP64 hexa_farr_matmul/
# hexa_ad_matmul (337-ref _hx_farr_table + hx_r4_gemm -- deeply coupled) and
# hexa_farr_int_fill_from_array (interp-coupled: struct HexaValStruct +
# HX_ARR_ITEMS/LEN + array_store interp-unwrap, a frozen interp-ABI dep).
S13="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(hexa_farr32_zeros|hexa_farr32_get|hexa_farr32_set|hexa_farr32_len|hexa_farr32_free|hexa_farr32_matmul|hexa_farr32_matmul_NT_b|hexa_farr32_matmul_NT_a|hexa_farr_int_zeros|hexa_farr_int_get|hexa_farr_int_set|hexa_farr_int_len|hexa_farr_int_copy|hexa_farr_int_sum|hexa_farr_int_free)$')"
# r31 (ING #29 batch 14) -- CARRIER-EMIT real-impl harvest: the term_ffi.c
# TUI-PRIM L1 subsystem (21 lowercase term_* bodies), ported VERBATIM from the
# frozen runtime.c #include "native/term_ffi.c" amalgam. ISOLATED-state cluster:
# the file-static _term_saved/_sigwinch_flag/_sigint_flag carriers are co-emitted
# FRESH seed-local (frozen copy in the DROPPED TU -> no collision; r26 lens). The
# 7 hxlcl_* helper callees (close/ioctl/poll/waitpid -> libc; isatty/sigaction/
# tcgetattr/tcsetattr/forkpty -> rt_posix_ok/rt_net_fail stubs, already seeded) are
# emitted fresh seed-local as static helpers in the frozen LIBC/stub branch.
# hxlcl_read/hxlcl_write/hxlcl_execvp stay link-deps (seedprov r25/r29);
# cfmakeraw/getppid/memcpy/memset = libc link-deps. Hard assert.
S14="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?(term_raw_enter|term_raw_restore|term_get_winsize|term_poll_stdin|term_getppid|term_read_byte|term_read_bytes|term_write|term_install_sigwinch|term_sigwinch_pending|term_install_sigint|term_sigint_pending|term_isatty_stdin|term_isatty_stdout|term_pty_spawn|term_fd_read|term_fd_write|term_fd_close|term_fd_poll|term_pty_reap|term_pty_spawn_sh)$')"
echo "regen_runtime_hi_seed: $OUT — $N/12 leaf rt_* + $M/16 libm-leaf hexa_math_* + $A/13 HexaVal-tail accessor + $S6/10 str/coerce/poly (r19) + $S7/9 fs/ffi/ml + $S7B/5 hxlcl-math (r21) + $S8/8 hxlcl mem/str-static (r23) + $S9/4 ml/math array (r24) + $S10/11 time/sleep/input (r25) + $S11/2 carrier-emit array-ctor (r26) + $S12/52 carrier-emit bare-wrapper (r29) + $S13/15 carrier-emit real-impl farr32+farr_int (r30) + $S14/21 carrier-emit real-impl term_ffi (r31) bodies exported"
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
[ "$S12" = "52" ] || { echo "regen_runtime_hi_seed: expected 52 carrier-emit bare-wrapper (r29), got $S12" >&2; exit 13; }
[ "$S13" = "15" ] || { echo "regen_runtime_hi_seed: expected 15 carrier-emit real-impl farr32+farr_int (r30), got $S13" >&2; exit 14; }
[ "$S14" = "21" ] || { echo "regen_runtime_hi_seed: expected 21 carrier-emit real-impl term_ffi (r31), got $S14" >&2; exit 15; }
