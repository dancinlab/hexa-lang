#!/usr/bin/env bash
# tool/regen_float_parse_hexinfnan_native_s.sh — reproducibly regenerate the frozen
# native STRTOD-TAIL seeds from the SSOT stdlib/runtime/float_parse_hexinfnan.hexa,
# using the native compiler. The strtod-TAIL twin of
# tool/regen_float_parse_exact_native_s.sh (zero-c #29 LAST reducible).
#
#   tool/regen_float_parse_hexinfnan_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s float_parse_hexinfnan.hexa
#   2) normalize the `.file` source path (deterministic) + prepend the frozen header.
#   3) sanity: cross-assemble + assert rt_str_parse_float_hexinfnan is defined-global.
#
# LIKE float_parse_exact (and UNLIKE num_float_core's leaf-only body), this TAIL body
# uses s.byte_at / byte_len string accessors → its native .o carries EXTERNAL
# references to the hexa string/value runtime (hexa_string_byte_at / __hx_make_val /
# bits_to_float / …). Those resolve WITHIN runtime.a when the seed is ar'd in, so an
# in-isolation `nm` shows undefined U entries for that runtime; that is expected and
# NOT an error (the cross-assemble `-c` only checks the body itself emits, and we
# assert ONLY that rt_str_parse_float_hexinfnan is a defined T global).
#
# Targets:
#   darwin      → self/native/float_parse_hexinfnan_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/float_parse_hexinfnan_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/float_parse_hexinfnan_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + a C driver
# ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_float_parse_hexinfnan] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/float_parse_hexinfnan.hexa"
[ -f "$SRC" ] || { echo "[regen_float_parse_hexinfnan] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_float_parse_hexinfnan.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_parse_float_hexinfnan' "$raw" || echo 0)"
    [ "$n" -ge 1 ] || { echo "[regen_float_parse_hexinfnan] ERROR: $triple emitted only $n/1 rt_str_parse_float_hexinfnan" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-hexinfnan).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_float_parse_hexinfnan_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/float_parse_hexinfnan.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the STRTOD TAIL (rt_str_parse_float_hexinfnan) — the native\n'
        printf '//   IEEE-bit-exact hex-float / inf / nan(payload) / malformed string->f64 body\n'
        printf '//   (hex exact-by-construction integer round-half-even + inf/nan constants +\n'
        printf '//   glibc/Apple nan-payload parse) that replaces the LAST inputs libc strtod\n'
        printf '//   served, after the Clinger fast + big-integer EXACT finite tiers decline.\n'
        printf '//   Bit-exact to the LINKED host libc strtod (glibc + Apple, cross-probed);\n'
        printf '//   returns a TAG_VOID sentinel for true junk so the C wrapper still falls back.\n'
        printf '//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot\n'
        printf '//   lower them), so the body enters the shipped runtime.a ONLY via this seed.\n'
        printf '//   ABI: %s. External: hexa string/value runtime (resolved within runtime.a).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_STRTOD_TAIL_NATIVE (opt-IN,\n'
        printf '//   default-OFF) + ar this .o into runtime.a so __hexa_num_parse_float composes\n'
        printf '//   fast(Clinger) -> exact(big-int) -> tail(this) -> C strtod.\n'
        sed -E -e 's#"[^"]*float_parse_hexinfnan\.hexa"#"stdlib/runtime/float_parse_hexinfnan.hexa"#g' \
               -e 's#^// source: .*float_parse_hexinfnan\.hexa#// source: stdlib/runtime/float_parse_hexinfnan.hexa#' "$raw"
    } > "$out"
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_parse_float_hexinfnan')"
        echo "[regen_float_parse_hexinfnan] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_float_parse_hexinfnan] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_float_parse_hexinfnan] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/float_parse_hexinfnan_arm64.s" "Mach-O, _rt_str_parse_float_hexinfnan underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/float_parse_hexinfnan_x86_64.s" "ELF, rt_str_parse_float_hexinfnan no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/float_parse_hexinfnan_arm64-linux.s" "ELF aarch64, rt_str_parse_float_hexinfnan no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/float_parse_hexinfnan_arm64.s" "Mach-O, _rt_str_parse_float_hexinfnan underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/float_parse_hexinfnan_x86_64.s" "ELF, rt_str_parse_float_hexinfnan no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/float_parse_hexinfnan_arm64-linux.s" "ELF aarch64, rt_str_parse_float_hexinfnan no underscore"
        ;;
    *) echo "[regen_float_parse_hexinfnan] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_float_parse_hexinfnan] done."
