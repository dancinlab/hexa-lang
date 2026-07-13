#!/usr/bin/env bash
# regen_array_new_leaf_native_s.sh — re-bake the frozen array ARR-NEW DISPATCHER
# native .s seeds from the SSOT stdlib/runtime/array_new_leaf.hexa (axis-② unit #5).
#
# The empty-array constructor hexa_array_new() that runtime_core.c
# externs away under HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE. Both are (HexaVal)->HexaVal
# = pair-clean (no float/char* param → NO ABI wall / NO C-shim). Each is the EXACT C
# body re-authored native: calloc the boxed HexaArr descriptor (items@0 len@8 cap@16
# heap_water@24, sizeof=32) + malloc a 16B*n run of HexaVal + fill each element {tag,0}
# via TWO __hx_ptr_store64 (tag@off, payload@off+8) + __hx_payload_* leaf arithmetic
# (NOT plain int ops — those emit boxed hexa_mul/add_slow; convergence array-core-hexa-1).
#
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s array_new_leaf.hexa
#   2) frozen into self/native/array_new_leaf_{x86_64,arm64,arm64-linux}.s
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + $CC (clang) to
# cross-assemble the sanity check. POOL ONLY (aprime emit is a heavy build).
#
#   tool/regen_array_new_leaf_native_s.sh [darwin|x86_64|arm64-linux|all]
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_array_new] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/array_new_leaf.hexa"
[ -f "$SRC" ] || { echo "[regen_array_new] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_array_new.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# the 1 native empty-array constructor global this seed must export.
SYMS="hexa_array_new"
NSYMS=1
# the carrier/libc externs this seed is ALLOWED to leave undefined. calloc is the only
# new floor entrant vs the arr-i64/f64 leaves (sanctioned); exit may lower to hexa_exit.
# CARRIER-ONLY. A raw libc name here is a pair-vs-C-ABI miscompile (the #4930 break), not a
# sanctioned floor entrant. hexa_bool is the backend's own leaf-truth helper (codegen controls its
# ABI); hexa_heap_zalloc is the HEAP carrier — hexa_ptr_alloc is ARENA and must never appear.
ALLOWED_U="hexa_heap_zalloc hexa_exit hexa_bool"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local sym n
    for sym in $SYMS; do
        n="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${sym}\$" "$raw" || true)"
        [ "${n:-0}" -ge 1 ] || { echo "[regen_array_new] ERROR: $triple emitted only ${n:-0}/1 $sym" >&2; exit 1; }
    done
    # sealed contract: EXACTLY 2 .globl (extern decls emit no .globl).
    local gtot; gtot="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$raw" || true)"
    [ "${gtot:-0}" -eq "$NSYMS" ] || { echo "[regen_array_new] ERROR: $triple emitted ${gtot:-0} .globl, want $NSYMS (sibling-global leak)" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ARR-NEW constructors).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_array_new_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/array_new_leaf.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the empty-array constructor native (hexa_array_new · calloc mint).\n'
        printf '//   ABI: %s. External U-floor: %s (calloc the only new floor entrant; pair-clean, no shim).\n' "$abi" "$ALLOWED_U"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this\n'
        printf '//   .o into runtime.a so hexa_array_new drops from the compiled runtime_core.c.\n'
        sed -E -e 's#"[^"]*array_new_leaf\.hexa"#"stdlib/runtime/array_new_leaf.hexa"#g' \
               -e 's#^// source: .*array_new_leaf\.hexa#// source: stdlib/runtime/array_new_leaf.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-globals + assert the U-floor.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local tcount=0 t
        for sym in $SYMS; do
            t="$( (nm "$o" 2>/dev/null || echo) | grep -cE " T _?${sym}\$" || true)"
            tcount=$((tcount + ${t:-0}))
        done
        # U-floor: every undefined external must be in ALLOWED_U (carrier/libc only).
        local bad; bad="$(nm "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | while read -r u; do
            b="${u#_}"; printf '%s\n' " $ALLOWED_U " | grep -q " $b " || echo "$b"; done | tr '\n' ' ')"
        [ -z "${bad// /}" ] || { echo "[regen_array_new] ERROR: $triple carries non-carrier undefined externals ($bad) — U-floor breach" >&2; exit 1; }
        echo "[regen_array_new] $triple → $out ($tcount/$NSYMS T defined, U-floor clean)"
    else
        echo "[regen_array_new] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_array_new] $triple → $out (globl emitted)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/array_new_leaf_arm64.s" "Mach-O, _-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/array_new_leaf_x86_64.s" "ELF, no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/array_new_leaf_arm64-linux.s" "ELF aarch64, no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/array_new_leaf_arm64.s" "Mach-O, _-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/array_new_leaf_x86_64.s" "ELF, no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/array_new_leaf_arm64-linux.s" "ELF aarch64, no underscore"
        ;;
    *) echo "[regen_array_new] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_array_new] done."
