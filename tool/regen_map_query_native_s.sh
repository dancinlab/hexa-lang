#!/usr/bin/env bash
# regen_map_query_native_s.sh — re-bake the frozen map-query DISPATCHER native .s
# seeds from the SSOT stdlib/runtime/map_query.hexa (axis-② B3 map-query dispatch).
#
# The 8 map-query dispatchers (hexa_map_keys/values/entries/map_values/filter_keys/
# count/any/all) that runtime_core.c externs away under
# HEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE. Each is a HX_MAP_TBL null-guard + delegate
# to the already-hexa-source rt_map_* body (numeric.hexa). Unlike valop_core, this
# seed is NOT self-contained: it carries U externs (the 8 rt_map_* delegates +
# hexa_array_new/hexa_map_new ctors) — all carrier-resolved in runtime.a, ZERO libc.
#
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s map_query.hexa
#   2) frozen into self/native/map_query_{x86_64,arm64,arm64-linux}.s
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + $CC (clang) to
# cross-assemble the sanity check. POOL ONLY (aprime emit is a heavy build).
#
#   tool/regen_map_query_native_s.sh [darwin|x86_64|arm64-linux|all]
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_map_query] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/map_query.hexa"
[ -f "$SRC" ] || { echo "[regen_map_query] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_map_query.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

# the 8 native map-query dispatcher globals this seed must export.
SYMS="hexa_map_keys hexa_map_values hexa_map_entries hexa_map_map_values hexa_map_filter_keys hexa_map_count hexa_map_any hexa_map_all"
NSYMS=8
# the carrier-resolved externs this seed is ALLOWED to leave undefined.
ALLOWED_U="hexa_array_new hexa_map_new rt_map_keys rt_map_values rt_map_entries rt_map_map_values rt_map_filter_keys rt_map_count_pred rt_map_any_pred_b rt_map_all_pred_b"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local sym n
    for sym in $SYMS; do
        n="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${sym}\$" "$raw" || echo 0)"
        [ "$n" -ge 1 ] || { echo "[regen_map_query] ERROR: $triple emitted only $n/1 $sym" >&2; exit 1; }
    done
    # sealed contract: EXACTLY 8 .globl (extern decls emit no .globl).
    local gtot; gtot="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$raw" || echo 0)"
    [ "$gtot" -eq "$NSYMS" ] || { echo "[regen_map_query] ERROR: $triple emitted $gtot .globl, want $NSYMS (sibling-global leak)" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B — map-query DISPATCH).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_map_query_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/map_query.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the 8 map-query dispatcher natives (hexa_map_keys/values/entries/\n'
        printf '//   map_values/filter_keys/count/any/all) as HX_MAP_TBL null-guard + delegate to\n'
        printf '//   the already-hexa-source rt_map_* bodies. hexa_map_contains_key stays C\n'
        printf '//   (mixed HexaVal/char*/int ABI — HEXA_RT_CORE_MAP_QUERY_CONTAINS_NATIVE sub-guard).\n'
        printf '//   ABI: %s. External: %s (all carrier-resolved in runtime.a, ZERO libc UND).\n' "$abi" "delegates+ctors"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE + ar\n'
        printf '//   this .o into runtime.a so the 8 dispatchers drop from the compiled runtime_core.c.\n'
        sed -E -e 's#"[^"]*map_query\.hexa"#"stdlib/runtime/map_query.hexa"#g' \
               -e 's#^// source: .*map_query\.hexa#// source: stdlib/runtime/map_query.hexa#' "$raw"
    } > "$out"
    # Sanity: cross-assemble + count defined-globals + assert the U-floor (zero libc).
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
        # U-floor: every undefined external must be in ALLOWED_U (no libc/non-carrier).
        local bad; bad="$(nm "$o" 2>/dev/null | awk '$1=="U"||$2=="U"{print $NF}' | while read -r u; do
            b="${u#_}"; printf '%s\n' " $ALLOWED_U " | grep -q " $b " || echo "$b"; done | tr '\n' ' ')"
        [ -z "${bad// /}" ] || { echo "[regen_map_query] ERROR: $triple carries non-carrier undefined externals ($bad) — libc-floor breach" >&2; exit 1; }
        echo "[regen_map_query] $triple → $out ($tcount/$NSYMS T defined, U-floor clean)"
    else
        echo "[regen_map_query] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_map_query] $triple → $out (globl emitted)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/map_query_arm64.s" "Mach-O, _-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/map_query_x86_64.s" "ELF, no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/map_query_arm64-linux.s" "ELF aarch64, no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/map_query_arm64.s" "Mach-O, _-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/map_query_x86_64.s" "ELF, no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/map_query_arm64-linux.s" "ELF aarch64, no underscore"
        ;;
    *) echo "[regen_map_query] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_map_query] done."
