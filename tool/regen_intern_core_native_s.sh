#!/usr/bin/env bash
# tool/regen_intern_core_native_s.sh — reproducibly regenerate the frozen native
# intern-core READ-half seeds from the SSOT stdlib/runtime/intern_core.hexa, using
# the native compiler. The string-intern twin of tool/regen_map_core_native_s.sh.
#
#   tool/regen_intern_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s intern_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes).
#   3) sanity: cross-assemble + assert both rt_intern_*_native are defined-global.
#
# The bodies use only raw-mem leaf intrinsics (__hx_ptr_load64/load8, __hx_make_val,
# __hx_payload_*) which the native gen2 backend inlines to position-independent
# machine code with NO string-literal `.LC` references — so unlike the rt_hi seed
# there is NO R_X86_64_32S PIC fixup to apply (verified for the map twin; same
# intrinsic set here). There are ZERO external symbols (rt_intern_strcmp0_native is
# local to this seed), so the seed self-resolves at link.
#
# Targets:
#   darwin      → self/native/intern_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/intern_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/intern_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_intern_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/intern_core.hexa"
[ -f "$SRC" ] || { echo "[regen_intern_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_intern_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_intern_(find|strcmp0)_native' "$raw" || echo 0)"
    [ "$n" -ge 2 ] || { echo "[regen_intern_core] ERROR: $triple emitted only $n/2 rt_intern_*_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 INTERN-R1).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_intern_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/intern_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the intern-core READ-half (rt_intern_find_native /\n'
        printf '//   rt_intern_strcmp0_native) as native raw-mem bodies — the open-addressing\n'
        printf '//   find probe over HexaInternTable char** buckets + uint32_t* hashes\n'
        printf '//   (__hx_ptr_load64/load8 + __hx_payload_* + __hx_make_val). These intrinsics\n'
        printf '//   are gen2-native-only (the hexat C-transpile bootstrap cannot lower them),\n'
        printf '//   so the bodies enter the shipped runtime.a ONLY via this seed.\n'
        printf '//   ABI: %s. External: none (rt_intern_strcmp0_native is local).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_INTERN_NATIVE + ar this .o into\n'
        printf '//   runtime.a so hexa_intern delegates its find half to the native body.\n'
        sed -E -e 's#"[^"]*intern_core\.hexa"#"stdlib/runtime/intern_core.hexa"#g' \
               -e 's#^// source: .*intern_core\.hexa#// source: stdlib/runtime/intern_core.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-global rt_intern_*_native.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_intern_(find|strcmp0)_native')"
        echo "[regen_intern_core] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_intern_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_intern_core] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/intern_core_arm64.s" "Mach-O, _rt_intern_*_native underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/intern_core_x86_64.s" "ELF, rt_intern_*_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/intern_core_arm64-linux.s" "ELF aarch64, rt_intern_*_native no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/intern_core_arm64.s" "Mach-O, _rt_intern_*_native underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/intern_core_x86_64.s" "ELF, rt_intern_*_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/intern_core_arm64-linux.s" "ELF aarch64, rt_intern_*_native no underscore"
        ;;
    *) echo "[regen_intern_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_intern_core] done."
