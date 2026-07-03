#!/usr/bin/env bash
# tool/regen_float_parse_exact_native_s.sh — reproducibly regenerate the frozen
# native EXACT-parse seeds from the SSOT stdlib/runtime/float_parse_exact.hexa,
# using the native compiler. The exact-tail twin of
# tool/regen_num_float_core_native_s.sh.
#
#   tool/regen_float_parse_exact_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s float_parse_exact.hexa
#   2) normalize the `.file` source path (deterministic) + prepend the frozen header.
#   3) sanity: cross-assemble + assert rt_str_parse_float_exact is defined-global.
#
# UNLIKE num_float_core (leaf-only, no external symbol), this EXACT body uses the
# big-integer (fpe_*) array helpers — its native .o carries EXTERNAL references to
# the hexa array runtime (hexa_array_push / hexa_array_new / …). Those resolve
# WITHIN runtime.a (the array_core / runtime_core members) when the seed is ar'd in,
# so an in-isolation `nm` shows undefined U entries for the array runtime; that is
# expected and NOT an error (the cross-assemble `-c` only checks the body itself
# emits, and we assert ONLY that rt_str_parse_float_exact is a defined T global).
#
# Targets:
#   darwin      → self/native/float_parse_exact_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/float_parse_exact_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/float_parse_exact_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + a C driver
# ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_float_parse_exact] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/float_parse_exact.hexa"
[ -f "$SRC" ] || { echo "[regen_float_parse_exact] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_float_parse_exact.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_parse_float_exact' "$raw" || echo 0)"
    [ "$n" -ge 1 ] || { echo "[regen_float_parse_exact] ERROR: $triple emitted only $n/1 rt_str_parse_float_exact" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM-FLOAT — sh-float-exact).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_float_parse_exact_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/float_parse_exact.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the EXACT correctly-rounded decimal->f64 tail\n'
        printf '//   (rt_str_parse_float_exact) as a native big-integer (David Gay / glibc\n'
        printf '//   strtod __mpn front + integer round-half-even) body that replaces the\n'
        printf '//   strtod TAIL the Clinger fast path declines. Bit-exact to strtod over the\n'
        printf '//   full finite-decimal domain; returns a TAG_VOID sentinel for\n'
        printf '//   hex/inf/nan/malformed so the C wrapper still falls back to strtod.\n'
        printf '//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot\n'
        printf '//   lower them), so the body enters the shipped runtime.a ONLY via this seed.\n'
        printf '//   ABI: %s. External: hexa array runtime (resolved within runtime.a).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_FLOAT_EXACT (opt-IN)\n'
        printf '//   + ar this .o into runtime.a so __hexa_num_parse_float composes\n'
        printf '//   fast(Clinger) -> exact(this) -> C strtod.\n'
        sed -E -e 's#"[^"]*float_parse_exact\.hexa"#"stdlib/runtime/float_parse_exact.hexa"#g' \
               -e 's#^// source: .*float_parse_exact\.hexa#// source: stdlib/runtime/float_parse_exact.hexa#' "$raw"
    } > "$out"
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_parse_float_exact')"
        echo "[regen_float_parse_exact] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_float_parse_exact] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_float_parse_exact] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/float_parse_exact_arm64.s" "Mach-O, _rt_str_parse_float_exact underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/float_parse_exact_x86_64.s" "ELF, rt_str_parse_float_exact no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/float_parse_exact_arm64-linux.s" "ELF aarch64, rt_str_parse_float_exact no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/float_parse_exact_arm64.s" "Mach-O, _rt_str_parse_float_exact underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/float_parse_exact_x86_64.s" "ELF, rt_str_parse_float_exact no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/float_parse_exact_arm64-linux.s" "ELF aarch64, rt_str_parse_float_exact no underscore"
        ;;
    *) echo "[regen_float_parse_exact] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_float_parse_exact] done."
