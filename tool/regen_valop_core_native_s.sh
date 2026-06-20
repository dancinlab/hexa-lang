#!/usr/bin/env bash
# tool/regen_valop_core_native_s.sh — reproducibly regenerate the frozen native
# valop-core seeds from the SSOT stdlib/runtime/valop_core.hexa, using the native
# compiler. The valop twin of tool/regen_num_core_native_s.sh.
#
#   tool/regen_valop_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s valop_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes).
#   3) sanity: cross-assemble + assert all 4 rt_*_native symbols are defined-global.
#
# The bodies use only the value-op leaf intrinsics (__hx_tag / __hx_make_val /
# __hx_payload_* / __hx_payload_f* / __hx_to_double) which the native gen2 backend
# inlines to position-independent machine code with NO string-literal `.LC`
# references — so like the num seed there is NO PIC fixup (PIE-links clean) and
# NO external symbol (no runtime call). The seed is fully self-contained.
#
# Targets:
#   darwin      → self/native/valop_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/valop_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/valop_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_valop_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/valop_core.hexa"
[ -f "$SRC" ] || { echo "[regen_valop_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_valop_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# the native value-op symbols this seed must export.
SYMS="rt_truthy_native rt_sub_native rt_mul_native rt_add_native"
NSYMS=4

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local sym n
    for sym in $SYMS; do
        n="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${sym}\$" "$raw" || echo 0)"
        [ "$n" -ge 1 ] || { echo "[regen_valop_core] ERROR: $triple emitted only $n/1 $sym" >&2; exit 1; }
    done
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 VALOP — sh-val-core).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_valop_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/valop_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the SCALAR value-op core (rt_truthy_native, rt_sub_native,\n'
        printf '//   rt_mul_native, rt_add_native) as native raw-mem bodies: __hx_tag\n'
        printf '//   tag-read + raw int/float payload arithmetic + __hx_make_val re-box,\n'
        printf '//   byte-faithful to the C hexa_truthy/sub/mul/add scalar arms. The\n'
        printf '//   intrinsics are\n'
        printf '//   gen2-native-only (the hexat C-transpile bootstrap cannot lower them), so\n'
        printf '//   the bodies enter the shipped runtime.a ONLY via this seed — the array/\n'
        printf '//   num_core mechanism (resolve_native_valop_core_seed).\n'
        printf '//   ABI: %s. External: NONE (fully self-contained).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_VALOP_NATIVE + ar this .o\n'
        printf '//   into runtime.a so hexa_truthy/sub/mul/add scalar paths go native.\n'
        sed -E -e 's#"[^"]*valop_core\.hexa"#"stdlib/runtime/valop_core.hexa"#g' \
               -e 's#^// source: .*valop_core\.hexa#// source: stdlib/runtime/valop_core.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-global symbols.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local tcount=0 t
        for sym in $SYMS; do
            t="$( (nm "$o" 2>/dev/null || echo) | grep -cE " T _?${sym}\$")"
            tcount=$((tcount + t))
        done
        echo "[regen_valop_core] $triple → $out ($tcount/$NSYMS T defined)"
    else
        echo "[regen_valop_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_valop_core] $triple → $out (globl emitted)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/valop_core_arm64.s" "Mach-O, _-prefixed; no external" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/valop_core_x86_64.s" "ELF, no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/valop_core_arm64-linux.s" "ELF aarch64, no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/valop_core_arm64.s" "Mach-O, _-prefixed; no external"
        emit_one x86_64-linux-gnu   "$HX/self/native/valop_core_x86_64.s" "ELF, no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/valop_core_arm64-linux.s" "ELF aarch64, no underscore"
        ;;
    *) echo "[regen_valop_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_valop_core] done."
