#!/usr/bin/env bash
# regen_arr_zeros_leaf_native_s.sh — re-bake the frozen array ZEROS-LEAF DISPATCHER
# native .s seeds from the SSOT stdlib/runtime/arr_zeros_leaf.hexa (axis-② unit #5).
#
# The 2 boxed-zeros constructors (hexa_arr_zeros_leaf{,_int}) that runtime_core.c
# externs away under HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE. Both are (HexaVal)->HexaVal
# = pair-clean (no float/char* param → NO ABI wall / NO C-shim). Each is the EXACT C
# body re-authored native: calloc the boxed HexaArr descriptor (items@0 len@8 cap@16
# heap_water@24, sizeof=32) + malloc a 16B*n run of HexaVal + fill each element {tag,0}
# via TWO __hx_ptr_store64 (tag@off, payload@off+8) + __hx_payload_* leaf arithmetic
# (NOT plain int ops — those emit boxed hexa_mul/add_slow; convergence array-core-hexa-1).
#
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s arr_zeros_leaf.hexa
#   2) frozen into self/native/arr_zeros_leaf_{x86_64,arm64,arm64-linux}.s
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + $CC (clang) to
# cross-assemble the sanity check. POOL ONLY (aprime emit is a heavy build).
#
#   tool/regen_arr_zeros_leaf_native_s.sh [darwin|x86_64|arm64-linux|all]
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_arr_zeros] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/arr_zeros_leaf.hexa"
[ -f "$SRC" ] || { echo "[regen_arr_zeros] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_arr_zeros.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# the 2 native boxed-zeros constructor globals this seed must export.
SYMS="hexa_arr_zeros_leaf hexa_arr_zeros_leaf_int"
NSYMS=2
# the carrier/libc externs this seed is ALLOWED to leave undefined. calloc is the only
# new floor entrant vs the arr-i64/f64 leaves (sanctioned); exit may lower to hexa_exit.
# CARRIER-ONLY U-floor. A raw libc name here is NOT a sanctioned floor entrant — it is a
# pair-vs-C-ABI miscompile: aprime lowers every call in the seed with the hexa pair-ABI, but a raw
# libc U-symbol binds to the C-ABI body, so the args land in the wrong registers and the returned
# pointer (rax/x0 alone) is dropped for garbage in the dead second register. Measured on the pre-fix
# seed: linux-x86_64 exits 1 (its own OOM guard sees the garbage as NULL), darwin-arm64 returns a
# silently-wrong array. The sibling array_new seed died the same way and took #4930 down on 3 targets.
ALLOWED_U="hexa_ptr_alloc hexa_exit hexa_bool"
# hexa_bool is NOT a libc entrant — it is the BACKEND'S OWN helper (`HexaVal hexa_bool(int)`,
# runtime_core.c) that aprime emits for a leaf truth test (`if __hx_payload_eq(..)`), with an ABI the
# codegen itself controls. Every already-deployed seed carries it. What must NEVER appear here is a raw
# libc name (calloc/malloc/realloc/free/write/exit) — that is the pair-vs-C-ABI miscompile, not a floor
# entrant. Nor a BOXED slow-call (hexa_eq/hexa_mul/hexa_add_slow): those come from writing a plain `a == 0`
# instead of the `__hx_payload_*` leaf (convergence array-core-hexa-1), and they are TARGET-DEPENDENT —
# x86_64 folds them to an inline cmp while arm64 emits a real `bl`, so an x86-only check waves them through.

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local sym n
    for sym in $SYMS; do
        n="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${sym}\$" "$raw" || true)"
        [ "${n:-0}" -ge 1 ] || { echo "[regen_arr_zeros] ERROR: $triple emitted only ${n:-0}/1 $sym" >&2; exit 1; }
    done
    # sealed contract: EXACTLY 2 .globl (extern decls emit no .globl).
    local gtot; gtot="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$raw" || true)"
    [ "${gtot:-0}" -eq "$NSYMS" ] || { echo "[regen_arr_zeros] ERROR: $triple emitted ${gtot:-0} .globl, want $NSYMS (sibling-global leak)" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE — array ZEROS-LEAF constructors).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_arr_zeros_leaf_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/arr_zeros_leaf.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the 2 boxed-zeros constructor natives (hexa_arr_zeros_leaf{,_int}).\n'
        printf '//   ABI: %s. External U-floor: %s — CARRIER-ONLY (HexaVal-ABI); a raw libc U here is a\n' "$abi" "$ALLOWED_U"
        printf '//   pair-vs-C-ABI miscompile, not a sanctioned floor entrant.\n'
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_ARRAY_ZEROS_LEAF_NATIVE + ar this\n'
        printf '//   .o into runtime.a so the 2 zeros constructors drop from the compiled runtime_core.c.\n'
        sed -E -e 's#"[^"]*arr_zeros_leaf\.hexa"#"stdlib/runtime/arr_zeros_leaf.hexa"#g' \
               -e 's#^// source: .*arr_zeros_leaf\.hexa#// source: stdlib/runtime/arr_zeros_leaf.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-globals + assert the U-floor.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    # TOOLCHAIN-FREE U-floor scan — runs on EVERY target, no assembler required. The nm check below
    # only runs where a cross-assembler exists and silently DEGRADES to a WARN otherwise; that hole is
    # exactly how an arm64-only `bl hexa_eq` (a plain `==` lowering to the boxed slow-call, convergence
    # array-core-hexa-1) shipped past an x86-clean regen and broke the darwin link. Read the emitted asm
    # itself: every call/bl target not DEFINED in this file must be in ALLOWED_U.
    local _def _callees _bads
    _def="$( { grep -oE '^[[:space:]]*\.globl[[:space:]]+_?[A-Za-z_][A-Za-z0-9_]*' "$s" | awk '{print $2}';
               grep -oE '^_?[A-Za-z_][A-Za-z0-9_]*:' "$s" | tr -d ':'; } | sed 's/^_//' | sort -u)"
    _callees="$(grep -oE '^[[:space:]]*(call|bl)[[:space:]]+_?[A-Za-z_][A-Za-z0-9_]*' "$s" | awk '{print $2}' | sed 's/^_//' | sort -u)"
    _bads="$(for _c in $_callees; do
        printf '%s\n' " $ALLOWED_U " | grep -q " $_c " && continue
        printf '%s\n' "$_def" | grep -qxF "$_c" && continue
        echo "$_c"
      done | tr '\n' ' ')"
    [ -z "${_bads// /}" ] || { echo "[regen_arr_zeros] ERROR: $triple calls non-carrier externals ($_bads) — U-floor breach (asm scan)" >&2; exit 1; }

    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local tcount=0 t
        for sym in $SYMS; do
            t="$( (nm "$o" 2>/dev/null || echo) | grep -cE " T _?${sym}\$" || true)"
            tcount=$((tcount + ${t:-0}))
        done
        # U-floor: every undefined external must be in ALLOWED_U (carrier/libc only).
        local bad; bad="$(nm "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | while read -r u; do
            b="${u#_}"; printf '%s\n' " $ALLOWED_U " | grep -q " $b " || echo "$b"; done | tr '\n' ' ')"
        [ -z "${bad// /}" ] || { echo "[regen_arr_zeros] ERROR: $triple carries non-carrier undefined externals ($bad) — U-floor breach" >&2; exit 1; }
        echo "[regen_arr_zeros] $triple → $out ($tcount/$NSYMS T defined, U-floor clean)"
    else
        echo "[regen_arr_zeros] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_arr_zeros] $triple → $out (globl emitted)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/arr_zeros_leaf_arm64.s" "Mach-O, _-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/arr_zeros_leaf_x86_64.s" "ELF, no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/arr_zeros_leaf_arm64-linux.s" "ELF aarch64, no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/arr_zeros_leaf_arm64.s" "Mach-O, _-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/arr_zeros_leaf_x86_64.s" "ELF, no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/arr_zeros_leaf_arm64-linux.s" "ELF aarch64, no underscore"
        ;;
    *) echo "[regen_arr_zeros] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_arr_zeros] done."
