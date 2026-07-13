#!/usr/bin/env bash
# regen_array_typed_leaf_f64_native_s.sh — re-bake the frozen array typed-leaf i64
# DISPATCHER native .s seeds from the SSOT stdlib/runtime/array_typed_leaf_f64.hexa
# (axis-② Tier-1 #3 array typed-leaf i64).
#
# The 4 packed-i64 array dispatchers (hexa_arr_f64_new/push/len/box) that
# runtime_core.c externs away under HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE. Each is the
# EXACT C body (single-thread arm) re-authored native: __hx_ptr_load/store{32,64}
# raw-mem field access + __hx_payload_* leaf arithmetic (NOT plain int ops — those
# emit boxed hexa_mul/add_slow/cmp_ge; convergence array-core-hexa-1) + extern
# realloc grow (the array_core.hexa:25 "realloc stays C" wall dissolved via the seed
# CALLING libc realloc — the C body carries the same libc undefs, net floor unchanged).
#
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s array_typed_leaf_f64.hexa
#   2) frozen into self/native/array_typed_leaf_f64_{x86_64,arm64,arm64-linux}.s
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + $CC (clang) to
# cross-assemble the sanity check. POOL ONLY (aprime emit is a heavy build).
#
#   tool/regen_array_typed_leaf_f64_native_s.sh [darwin|x86_64|arm64-linux|all]
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_arr_f64] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/array_typed_leaf_f64.hexa"
[ -f "$SRC" ] || { echo "[regen_arr_f64] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_arr_f64.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# the 4 native i64 typed-leaf dispatcher globals this seed must export.
SYMS="hexa_arr_f64_new hexa_arr_f64_push_bits hexa_arr_f64_len hexa_arr_f64_box"
NSYMS=4
# the carrier/libc externs this seed is ALLOWED to leave undefined. UNLIKE map-query
# (ZERO libc), this seed is libc-BEARING: malloc/realloc/write are the whole point
# (the realloc-grow the wall said "stays C"). hexa_exit/int/throw are runtime.a carriers.
ALLOWED_U="malloc realloc write hexa_exit hexa_throw"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local sym n
    for sym in $SYMS; do
        n="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${sym}\$" "$raw" || true)"
        [ "${n:-0}" -ge 1 ] || { echo "[regen_arr_f64] ERROR: $triple emitted only ${n:-0}/1 $sym" >&2; exit 1; }
    done
    # sealed contract: EXACTLY 4 .globl (extern decls emit no .globl).
    local gtot; gtot="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$raw" || true)"
    [ "${gtot:-0}" -eq "$NSYMS" ] || { echo "[regen_arr_f64] ERROR: $triple emitted ${gtot:-0} .globl, want $NSYMS (sibling-global leak)" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array typed-leaf i64 DISPATCH).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_array_typed_leaf_f64_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/array_typed_leaf_f64.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the 4 packed-i64 array dispatcher natives (hexa_arr_f64_new/push/len/box).\n'
        printf '//   ABI: %s. External U-floor: %s (libc-bearing: realloc grow dissolves the\n' "$abi" "$ALLOWED_U"
        printf '//   array_core.hexa:25 wall via extern realloc CALL; the C body carries the same undefs).\n'
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_I64_LEAF_NATIVE + ar this\n'
        printf '//   .o into runtime.a so the 4 i64 dispatchers drop from the compiled runtime_core.c.\n'
        sed -E -e 's#"[^"]*array_typed_leaf_f64\.hexa"#"stdlib/runtime/array_typed_leaf_f64.hexa"#g' \
               -e 's#^// source: .*array_typed_leaf_f64\.hexa#// source: stdlib/runtime/array_typed_leaf_f64.hexa#' "$raw"
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
        [ -z "${bad// /}" ] || { echo "[regen_arr_f64] ERROR: $triple carries non-carrier undefined externals ($bad) — U-floor breach" >&2; exit 1; }
        echo "[regen_arr_f64] $triple → $out ($tcount/$NSYMS T defined, U-floor clean)"
    else
        echo "[regen_arr_f64] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_arr_f64] $triple → $out (globl emitted)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/array_typed_leaf_f64_arm64.s" "Mach-O, _-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/array_typed_leaf_f64_x86_64.s" "ELF, no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/array_typed_leaf_f64_arm64-linux.s" "ELF aarch64, no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/array_typed_leaf_f64_arm64.s" "Mach-O, _-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/array_typed_leaf_f64_x86_64.s" "ELF, no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/array_typed_leaf_f64_arm64-linux.s" "ELF aarch64, no underscore"
        ;;
    *) echo "[regen_arr_f64] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_arr_f64] done."
