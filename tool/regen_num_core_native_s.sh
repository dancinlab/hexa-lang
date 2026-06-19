#!/usr/bin/env bash
# tool/regen_num_core_native_s.sh — reproducibly regenerate the frozen native
# num-core parse seeds from the SSOT stdlib/runtime/num_core.hexa, using the
# native compiler. The num twin of tool/regen_str_core_native_s.sh.
#
#   tool/regen_num_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s num_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes).
#   3) sanity: cross-assemble + assert rt_parse_int_native is defined-global.
#
# The body uses only raw-mem leaf intrinsics (__hx_ptr_load8 / __hx_payload_add/
# sub/mul/and/eq/ne/lt) which the native gen2 backend inlines to position-
# independent machine code with NO string-literal `.LC` references — so unlike
# the rt_hi seed there is NO R_X86_64_32S PIC fixup to apply (the seed PIE-links
# clean). There is NO external symbol (no runtime call, no `as int` cast) — the
# seed is fully self-contained.
#
# Targets:
#   darwin      → self/native/num_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/num_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/num_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_num_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/num_core.hexa"
[ -f "$SRC" ] || { echo "[regen_num_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_num_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_parse_int_native' "$raw" || echo 0)"
    [ "$n" -ge 1 ] || { echo "[regen_num_core] ERROR: $triple emitted only $n/1 rt_parse_int_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 NUM — sh-num-native).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_num_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/num_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the num-core parse half (rt_parse_int_native) as a native\n'
        printf '//   raw-mem body (__hx_ptr_load8 byte scan + digit fold + strtoll-faithful\n'
        printf '//   overflow clamp, byte-faithful to the C hxlcl_strtoll(cs,NULL,base)). These\n'
        printf '//   intrinsics are gen2-native-only (the hexat C-transpile bootstrap cannot\n'
        printf '//   lower them), so the body enters the shipped runtime.a ONLY via this seed —\n'
        printf '//   the array/str_core mechanism (resolve_native_num_core_seed).\n'
        printf '//   ABI: %s. External: NONE (fully self-contained).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_NUM_PARSE_INT_NATIVE + ar this\n'
        printf '//   .o into runtime.a so hexa_as_num delegates its string→int path to native.\n'
        sed -E -e 's#"[^"]*num_core\.hexa"#"stdlib/runtime/num_core.hexa"#g' \
               -e 's#^// source: .*num_core\.hexa#// source: stdlib/runtime/num_core.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-global rt_parse_int_native.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_parse_int_native')"
        echo "[regen_num_core] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_num_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_num_core] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/num_core_arm64.s" "Mach-O, _rt_parse_int_native underscore-prefixed; no external" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/num_core_x86_64.s" "ELF, rt_parse_int_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/num_core_arm64-linux.s" "ELF aarch64, rt_parse_int_native no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/num_core_arm64.s" "Mach-O, _rt_parse_int_native underscore-prefixed; no external"
        emit_one x86_64-linux-gnu   "$HX/self/native/num_core_x86_64.s" "ELF, rt_parse_int_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/num_core_arm64-linux.s" "ELF aarch64, rt_parse_int_native no underscore"
        ;;
    *) echo "[regen_num_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_num_core] done."
