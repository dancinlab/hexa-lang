#!/usr/bin/env bash
# tool/regen_num_float_core_native_s.sh — reproducibly regenerate the frozen native
# num-float parse seeds from the SSOT stdlib/runtime/num_float_core.hexa, using the
# native compiler. The float twin of tool/regen_num_core_native_s.sh.
#
#   tool/regen_num_float_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s num_float_core.hexa
#   2) normalize the `.file` source path (deterministic) + prepend the frozen header.
#   3) sanity: cross-assemble + assert rt_parse_float_native is defined-global.
#
# The body uses raw-mem + FLOAT leaf intrinsics (__hx_ptr_load8 / __hx_payload_*
# integer leaves + __hx_to_double / __hx_payload_{fmul,fdiv} float leaves) which the
# native gen2 backend inlines to position-independent machine code (cvtsi2sd/mulsd/
# divsd on x86_64, scvtf/fmul/fdiv on arm64) with NO string-literal `.LC` references —
# so unlike the rt_hi seed there is NO R_X86_64_32S PIC fixup. There is NO external
# symbol — the seed is fully self-contained (the float leaves lower inline, no libm call).
#
# Targets:
#   darwin      → self/native/num_float_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/num_float_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/num_float_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + a C driver
# ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_num_float_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/num_float_core.hexa"
[ -f "$SRC" ] || { echo "[regen_num_float_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_num_float_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_parse_float_native' "$raw" || echo 0)"
    [ "$n" -ge 1 ] || { echo "[regen_num_float_core] ERROR: $triple emitted only $n/1 rt_parse_float_native" >&2; exit 1; }
    # R6 sh-float-format: the SAME SSOT module also exports the FORMAT half
    # (rt_format_float_native, musl fmt_fp i64 dtoa). Module-wide emit means a fresh
    # seed carries BOTH `.globl` symbols — assert format too so stage_resolve_runtime_a
    # can wire the native FORMAT path (HEXA_RT_FORMAT_FLOAT_NATIVE) without an
    # undefined `rt_format_float_native` at the app link.
    local nf; nf="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_format_float_native' "$raw" || echo 0)"
    [ "$nf" -ge 1 ] || { echo "[regen_num_float_core] ERROR: $triple emitted only $nf/1 rt_format_float_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-num-float).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_num_float_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/num_float_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides BOTH num-float halves as a native body: the PARSE half\n'
        printf '//   (rt_parse_float_native) — raw-mem + float (__hx_ptr_load8 byte scan +\n'
        printf '//   integer mantissa fold + __hx_to_double cast + __hx_payload_{fmul,fdiv}\n'
        printf '//   Clinger fast-path scale, bit-exact to strtod on the mantissa<=2^53 AND\n'
        printf '//   |exp10|<=22 domain; out of domain returns a TAG_VOID sentinel so the C\n'
        printf '//   wrapper falls back to strtod) — AND the FORMAT half (rt_format_float_native,\n'
        printf '//   a pure-i64 musl fmt_fp dtoa port, byte-exact to snprintf("%%.*g") on its\n'
        printf '//   verified domain). These leaves are gen2-native-only (the hexat C-transpile\n'
        printf '//   bootstrap cannot lower them), so the body enters the shipped runtime.a ONLY\n'
        printf '//   via this seed.\n'
        printf '//   ABI: %s. External: the PARSE half is self-contained (float leaves lower\n' "$abi"
        printf '//   inline, no libm call); the FORMAT half references the hexa string/array\n'
        printf '//   runtime (hexa_array_new/push, hexa_bytes_to_str_raw, hexa_arena_alloc,\n'
        printf '//   scalar ops) — resolved WITHIN runtime.a (the same archive this .o joins),\n'
        printf '//   so no NEW undefined symbol appears at the app link.\n'
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_NATIVE (parse,\n'
        printf '//   default-ON) + HEXA_RT_FORMAT_FLOAT_NATIVE (format, R6 opt-IN) + ar this .o\n'
        printf '//   into runtime.a so __hx_to_double and the float-repr path delegate to native.\n'
        sed -E -e 's#"[^"]*num_float_core\.hexa"#"stdlib/runtime/num_float_core.hexa"#g' \
               -e 's#^// source: .*num_float_core\.hexa#// source: stdlib/runtime/num_float_core.hexa#' "$raw"
    } > "$out"
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_parse_float_native')"
        local tf; tf="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_format_float_native')"
        echo "[regen_num_float_core] $triple → $out (parse $n globl·$t T · format $nf globl·$tf T)"
    else
        echo "[regen_num_float_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_num_float_core] $triple → $out (parse $n globl · format $nf globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/num_float_core_arm64.s" "Mach-O, _rt_parse_float_native underscore-prefixed; no external" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/num_float_core_x86_64.s" "ELF, rt_parse_float_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/num_float_core_arm64-linux.s" "ELF aarch64, rt_parse_float_native no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/num_float_core_arm64.s" "Mach-O, _rt_parse_float_native underscore-prefixed; no external"
        emit_one x86_64-linux-gnu   "$HX/self/native/num_float_core_x86_64.s" "ELF, rt_parse_float_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/num_float_core_arm64-linux.s" "ELF aarch64, rt_parse_float_native no underscore"
        ;;
    *) echo "[regen_num_float_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_num_float_core] done."
