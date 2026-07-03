#!/usr/bin/env bash
# tool/regen_str_core_native_s.sh — reproducibly regenerate the frozen native
# str-core scan/compare seeds from the SSOT stdlib/runtime/str_core.hexa, using
# the native compiler. The str twin of tool/regen_array_core_native_s.sh.
#
#   tool/regen_str_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s str_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes).
#   3) sanity: cross-assemble + assert rt_str_eq_native is defined-global.
#
# The body uses only raw-mem leaf intrinsics (__hx_ptr_load8 / __hx_payload_add /
# __hx_payload_eq) which the native gen2 backend inlines to position-independent
# machine code with NO string-literal `.LC` references — so unlike the rt_hi seed
# there is NO R_X86_64_32S PIC fixup to apply (the seed PIE-links clean). There is
# NO external symbol (no `as int` cast, no runtime call) — the seed is fully
# self-contained.
#
# Targets:
#   darwin      → self/native/str_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/str_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/str_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_str_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/str_core.hexa"
[ -f "$SRC" ] || { echo "[regen_str_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_str_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_eq_native' "$raw" || echo 0)"
    [ "$n" -ge 1 ] || { echo "[regen_str_core] ERROR: $triple emitted only $n/1 rt_str_eq_native" >&2; exit 1; }
    # r2 (sh-str-scan): the seed now also carries rt_str_starts_with_native.
    local nsw; nsw="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_starts_with_native' "$raw" || echo 0)"
    [ "$nsw" -ge 1 ] || { echo "[regen_str_core] ERROR: $triple emitted only $nsw/1 rt_str_starts_with_native" >&2; exit 1; }
    # r3 (sh-str-scan): + rt_str_ends_with_native.
    local new; new="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_ends_with_native' "$raw" || echo 0)"
    [ "$new" -ge 1 ] || { echo "[regen_str_core] ERROR: $triple emitted only $new/1 rt_str_ends_with_native" >&2; exit 1; }
    # r4 (sh-str-scan): + rt_str_index_of_native + rt_str_contains_native (substring search).
    local nio; nio="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_index_of_native' "$raw" || echo 0)"
    [ "$nio" -ge 1 ] || { echo "[regen_str_core] ERROR: $triple emitted only $nio/1 rt_str_index_of_native" >&2; exit 1; }
    local nco; nco="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_str_contains_native' "$raw" || echo 0)"
    [ "$nco" -ge 1 ] || { echo "[regen_str_core] ERROR: $triple emitted only $nco/1 rt_str_contains_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 STR — sh-construct-str + sh-str-scan).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_str_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/str_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the str-core scan/compare prims (rt_str_eq_native +\n'
        printf '//   rt_str_starts_with_native + rt_str_ends_with_native + rt_str_index_of_native\n'
        printf '//   + rt_str_contains_native, str r2/r3/r4 sh-str-scan) as native raw-mem bodies\n'
        printf '//   (__hx_ptr_load8 NUL-stop byte walks + naive O(n*m) substring search,\n'
        printf '//   byte-faithful to the C hxlcl_strcmp/strncmp/strstr family). These intrinsics\n'
        printf '//   are gen2-native-only (the hexat C-transpile bootstrap cannot lower them),\n'
        printf '//   so the bodies enter the shipped runtime.a ONLY via this seed — the rt_hi /\n'
        printf '//   array_core mechanism (resolve_native_str_core_seed).\n'
        printf '//   ABI: %s. External: NONE (fully self-contained).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_STR_{EQ,STARTS_WITH,ENDS_WITH,\n'
        printf '//   INDEX_OF,CONTAINS}_NATIVE + ar this .o into runtime.a so the matching\n'
        printf '//   hexa_str_* / rt_str_* wrappers delegate to the native bodies.\n'
        sed -E -e 's#"[^"]*str_core\.hexa"#"stdlib/runtime/str_core.hexa"#g' \
               -e 's#^// source: .*str_core\.hexa#// source: stdlib/runtime/str_core.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-global rt_str_eq_native.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_eq_native')"
        local tsw; tsw="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_starts_with_native')"
        local tew; tew="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_ends_with_native')"
        local tio; tio="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_index_of_native')"
        local tco; tco="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_contains_native')"
        echo "[regen_str_core] $triple → $out (eq:$n/$t · starts:$nsw/$tsw · ends:$new/$tew · index_of:$nio/$tio · contains:$nco/$tco globl/T)"
    else
        echo "[regen_str_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_str_core] $triple → $out (eq:$n · starts:$nsw · ends:$new · index_of:$nio · contains:$nco globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/str_core_arm64.s" "Mach-O, _rt_str_eq_native underscore-prefixed; no external" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/str_core_x86_64.s" "ELF, rt_str_eq_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/str_core_arm64-linux.s" "ELF aarch64, rt_str_eq_native no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/str_core_arm64.s" "Mach-O, _rt_str_eq_native underscore-prefixed; no external"
        emit_one x86_64-linux-gnu   "$HX/self/native/str_core_x86_64.s" "ELF, rt_str_eq_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/str_core_arm64-linux.s" "ELF aarch64, rt_str_eq_native no underscore"
        ;;
    *) echo "[regen_str_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_str_core] done."
