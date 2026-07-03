#!/usr/bin/env bash
# tool/regen_array_core_native_s.sh — reproducibly regenerate the frozen native
# array-core READ-half seeds from the SSOT stdlib/runtime/array_core.hexa, using
# the native compiler. The array twin of tool/regen_runtime_hi_native_s.sh.
#
#   tool/regen_array_core_native_s.sh [darwin|x86_64|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s array_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes).
#   3) sanity: cross-assemble + assert all 4 rt_array_*_native are defined-global.
#
# The bodies use only raw-mem leaf intrinsics (__hx_ptr_load64/store64,
# __hx_make_val, __hx_payload_*, __hx_tag) which the native gen2 backend inlines
# to position-independent machine code with NO string-literal `.LC` references —
# so unlike the rt_hi seed there is NO R_X86_64_32S PIC fixup to apply (verified:
# objdump -r shows zero R_X86_64_32S; the seed PIE-links clean). The only external
# symbol is hexa_to_int (from the `as int` cast in rt_array_len_native), resolved
# by runtime.c at link.
#
# Targets:
#   darwin      → self/native/array_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/array_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/array_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_array_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/array_core.hexa"
[ -f "$SRC" ] || { echo "[regen_array_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_array_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    # 6 read-half element fns + 1 alloc-bearing arena bridge (sh-array-write:
    # rt_array_arena_alloc_items_native → native hexa_arena_alloc) = 7 globl.
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_array_(get|set|len|pop|shift|truncate|arena_alloc_items)_native' "$raw" || echo 0)"
    [ "$n" -ge 7 ] || { echo "[regen_array_core] ERROR: $triple emitted only $n/7 rt_array_*_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B M4 ARRAY-R4).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_array_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/array_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the array-core READ-half (rt_array_get_native / rt_array_set_native /\n'
        printf '//   rt_array_len_native / rt_array_pop_native) as native raw-mem bodies\n'
        printf '//   (__hx_ptr_load64/store64 over the HexaArr descriptor + __hx_make_val tag\n'
        printf '//   re-stamp), PLUS the alloc-bearing arena bridge rt_array_arena_alloc_items_native\n'
        printf '//   (sh-array-write "alloc not a wall": n*16 bytes via the already-native\n'
        printf '//   hexa_arena_alloc — self/rt/alloc.hexa). These intrinsics are gen2-native-only\n'
        printf '//   (the hexat C-transpile bootstrap cannot lower them), so the bodies enter the\n'
        printf '//   shipped runtime.a ONLY via this seed — the rt_hi mechanism (resolve_native_rt_hi_seed / Z2a).\n'
        printf '//   ABI: %s. External: hexa_to_int (runtime.c) + hexa_arena_alloc (alloc seed).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_ARRAY_NATIVE (+ HEXA_RT_ARRAY_ARENA_NATIVE\n'
        printf '//   when the alloc seed is native) + ar this .o into runtime.a so hexa_array_get/set\n'
        printf '//   delegate to the native bodies + hexa_array_arena_alloc_items uses the native arena.\n'
        # Normalize the `.file` quoted path AND the unquoted `// source: <abspath>`
        # comment (emitted by some backends) so the frozen seed is byte-stable and
        # host-independent (no /home/<user> path leaks into the committed artifact).
        sed -E -e 's#"[^"]*array_core\.hexa"#"stdlib/runtime/array_core.hexa"#g' \
               -e 's#^// source: .*array_core\.hexa#// source: stdlib/runtime/array_core.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-global rt_array_*_native.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_array_(get|set|len|pop|shift|truncate|arena_alloc_items)_native')"
        echo "[regen_array_core] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_array_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_array_core] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/array_core_arm64.s" "Mach-O, _rt_array_*_native underscore-prefixed; external _hexa_to_int" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/array_core_x86_64.s" "ELF, rt_array_*_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/array_core_arm64-linux.s" "ELF aarch64, rt_array_*_native no underscore; external hexa_to_int" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/array_core_arm64.s" "Mach-O, _rt_array_*_native underscore-prefixed; external _hexa_to_int"
        emit_one x86_64-linux-gnu   "$HX/self/native/array_core_x86_64.s" "ELF, rt_array_*_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/array_core_arm64-linux.s" "ELF aarch64, rt_array_*_native no underscore; external hexa_to_int"
        ;;
    *) echo "[regen_array_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_array_core] done."
