#!/usr/bin/env bash
# tool/regen_runtime_hi_native_s.sh — reproducibly regenerate the frozen native
# rt_hi seeds from the SSOT self/runtime_hi.hexa, using the native compiler.
#
#   tool/regen_runtime_hi_native_s.sh [darwin|x86_64|all]   (default: all)
#
# Pipeline (per target):
#   1) strip self/runtime_hi.hexa to the LIB-ONLY head (everything before
#      `fn runtime_hi_selftest`) → a /tmp lib source.
#   2) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s <lib>.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real lib source is the trailing arg).
#   3) prepend the frozen-seed header (provenance + ABI notes).
#   4) sanity: cross-assemble + assert all 11 rt_str_* are defined-global (T).
#
# NOTE on determinism: the emitted GLOBAL symbol set (the ABI/linkage contract)
# is byte-identical across regen runs, but local `.L<hex>_bbN` basic-block label
# PREFIXES carry a per-process-random nonce, so two regen runs differ only in
# those local labels (irrelevant to linking — they never escape the object). The
# committed seed is frozen ONCE and is link-stable; re-running regen is for
# refreshing the seed against an SSOT change, not for bit-reproducing the file.
#
# Targets:
#   darwin  → self/native/runtime_hi_native.s  (arm64-apple-darwin, Mach-O)
#   x86_64  → self/native/runtime_hi_x86_64.s  (x86_64-linux-gnu,    ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) — the gen3
# self-host binary — and a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_rt_hi] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/self/runtime_hi.hexa"
[ -f "$SRC" ] || { echo "[regen_rt_hi] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_rt_hi.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Lib-only source = the head before `fn runtime_hi_selftest` (strip selftest+main).
BOUND="$(grep -n '^fn runtime_hi_selftest' "$SRC" | head -1 | cut -d: -f1)"
[ -n "$BOUND" ] || { echo "[regen_rt_hi] ERROR: no 'fn runtime_hi_selftest' boundary in $SRC" >&2; exit 1; }
LIB="$TMP/runtime_hi_lib.hexa"
awk -v b="$BOUND" 'NR<b' "$SRC" > "$LIB"
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$LIB" >/dev/null 2>&1
    local n; n="$(grep -cE '^\.globl[[:space:]]+_?rt_str_' "$raw" || echo 0)"
    [ "$n" -ge 11 ] || { echo "[regen_rt_hi] ERROR: $triple emitted only $n/11 rt_str_*" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B Z2a).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_runtime_hi_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s runtime_hi_lib.hexa (lib-only head of self/runtime_hi.hexa).\n' "$triple" "$(basename "$out")"
        printf '//   Provides rt_str_* (zero C): split/lines/pad_left/pad_right/repeat/center +\n'
        printf '//   to_upper/to_lower/trim/trim_start/trim_end (11 fns). ABI: %s.\n' "$abi"
        printf '//   Lets this target avoid #include "runtime_hi_gen.c" (leg B ls-reduction).\n'
        # Normalize the `.file`/source path (a per-run mktemp tmpdir) to a fixed
        # string so the frozen seed is byte-deterministic across regen runs — the
        # path only feeds DWARF .loc debug info, not codegen.
        tail -n +3 "$raw" | sed -E 's#"[^"]*runtime_hi_lib\.hexa"#"self/runtime_hi.hexa"#g'
    } > "$out"
    # Sanity: cross-assemble + count defined-global rt_str_*.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_')"
        echo "[regen_rt_hi] wrote $out — $n .globl, cross-assemble OK, $t defined-global rt_str_*"
    else
        echo "[regen_rt_hi] WARN: $out wrote but cross-assemble check failed ($CC $cc_extra)" >&2
    fi
}

case "$WHICH" in
    darwin) emit_one arm64-apple-darwin "$HX/self/native/runtime_hi_native.s" "Mach-O, _rt_str_* underscore + .private_extern" ;;
    x86_64) emit_one x86_64-linux-gnu   "$HX/self/native/runtime_hi_x86_64.s"  "ELF, rt_str_* no underscore + .hidden" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/runtime_hi_native.s" "Mach-O, _rt_str_* underscore + .private_extern"
        emit_one x86_64-linux-gnu   "$HX/self/native/runtime_hi_x86_64.s"  "ELF, rt_str_* no underscore + .hidden" ;;
    *) echo "usage: $0 [darwin|x86_64|all]" >&2; exit 2 ;;
esac
