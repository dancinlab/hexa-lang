#!/usr/bin/env bash
# tool/regen_regex_rt_native_s.sh — reproducibly regenerate the frozen native REGEX-RT
# seeds from the SSOT stdlib/runtime/regex_rt.hexa (+ its thompson/backtrack backing),
# using the native compiler. The regex twin of
# tool/regen_float_parse_hexinfnan_native_s.sh (zero-c #29 regex-flip wiring follow-on).
#
#   tool/regen_regex_rt_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s \
#        regex_rt.hexa thompson.hexa backtrack.hexa            (single combined .s)
#   2) .globl DEMOTION post-pass (regex-specific — see below) + normalize the `.file`
#      source path (deterministic) + prepend the frozen header.
#   3) sanity: cross-assemble + assert EXACTLY 6 defined-global rt_regex_* + nm T count.
#
# WHY the .globl demotion (regex-specific, absent in strtod): the backing modules
# stdlib/regex/thompson.hexa + backtrack.hexa are PUBLIC stdlib modules a user program
# can `use` directly. hexa fns emit as GLOBAL symbols by name, so the raw seed exports
# ~80 globals (regex_compile, bt_search_from, …). If ar'd into runtime.a as-is, a user
# program that imports thompson AND links a flip-ON runtime.a would get a DUPLICATE
# SYMBOL at ld (the seed's regex_compile vs the user .o's). The external CONTRACT of
# this seed is exactly the 6 rt_regex_* shims the emitted runtime.c delegates to; every
# other global is an internal implementation detail. Demoting them to local (deleting
# their `.globl` directive — the label stays, so intra-.o calls still resolve since this
# is a SINGLE .s → single .o) seals the seed to a 6-symbol contract. The resolver's
# `.globl == 6` SAFETY refuses a seed where demotion was missed.
#
# LIKE float_parse_hexinfnan, the rt_regex_* bodies use string/array accessors → the .o
# carries EXTERNAL references to the hexa string/value runtime (hexa_string_byte_at /
# __hx_make_val / hexa_array_* / …). Those resolve WITHIN runtime.a when the seed is
# ar'd in; an in-isolation `nm` showing U entries for that runtime is EXPECTED and NOT
# an error. We assert ONLY that the 6 rt_regex_* are defined T globals AND that no libc
# symbol appears in the seed's U set (floor-reduction is the point — a new libc UND
# would defeat the flip).
#
# Targets:
#   darwin      → self/native/regex_rt_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/regex_rt_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/regex_rt_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + a C driver
# ($CC, default clang) to cross-assemble. POOL ONLY (aprime emit is a heavy build).
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_regex_rt] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC_MAIN="$HX/stdlib/runtime/regex_rt.hexa"
SRC_THOMPSON="$HX/stdlib/regex/thompson.hexa"
SRC_BT="$HX/stdlib/regex/backtrack.hexa"
for f in "$SRC_MAIN" "$SRC_THOMPSON" "$SRC_BT"; do
    [ -f "$f" ] || { echo "[regen_regex_rt] ERROR: SSOT missing: $f" >&2; exit 1; }
done

# The 6 external-contract symbols (extended-regex alternation of the shim names).
CONTRACT='rt_regex_(match|match_full|search|findall|split|replace)'

TMP="$(mktemp -d -t regen_regex_rt.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s" demoted="$TMP/demoted.s"
    # V1 (pool-verified): pass all three source files so aprime emits ONE combined .s.
    # If `use`-import auto-resolution makes regex_rt.hexa alone sufficient, the extra
    # positionals are idempotent; if aprime rejects duplicate positionals, fall back to
    # SRC_MAIN only (the resolver still gates on the 6-symbol SAFETY either way).
    # Preserve emit stderr so a real diagnostic (e.g. an HX2001 undefined-builtin
    # from a bind allowlist gap) is LOUD, not swallowed — the silent `>/dev/null`
    # double-fail hid the `chr` bind gap on the first cut. On double-fail, echo the
    # captured diagnostics and abort.
    if ! "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" \
            "$SRC_MAIN" "$SRC_THOMPSON" "$SRC_BT" 2>"$TMP/emit.err"; then
        "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC_MAIN" 2>>"$TMP/emit.err" || {
            echo "[regen_regex_rt] ERROR: $triple aprime --emit=asm failed (both multi-file and regex_rt-only):" >&2
            sed 's/^/    /' "$TMP/emit.err" >&2
            exit 1
        }
    fi

    # --- .globl DEMOTION post-pass: keep ONLY the 6 rt_regex_* .globl, drop the rest ---
    # A .globl line for a contract symbol is kept (branch to end); any other .globl line
    # is deleted → its symbol becomes local. `_?` matches the Mach-O underscore prefix.
    sed -E "/^[[:space:]]*\.globl[[:space:]]+_?${CONTRACT}([[:space:]]|\$)/b
            /^[[:space:]]*\.globl[[:space:]]/d" "$raw" > "$demoted"

    local kept total
    kept="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${CONTRACT}([[:space:]]|\$)" "$demoted" || echo 0)"
    total="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$demoted" || echo 0)"
    [ "$kept" -eq 6 ] || { echo "[regen_regex_rt] ERROR: $triple kept $kept/6 rt_regex_* globals (raw emit missing a shim?)" >&2; exit 1; }
    [ "$total" -eq 6 ] || { echo "[regen_regex_rt] ERROR: $triple demotion left $total globals (expected 6 — sed pattern drift)" >&2; exit 1; }

    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE zero-c #29 — regex-rt).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_regex_rt_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s regex_rt.hexa thompson.hexa backtrack.hexa, then a\n' "$triple" "$(basename "$out")"
        printf '//   .globl DEMOTION post-pass keeping ONLY the 6 rt_regex_* shim globals.\n'
        printf '//   Provides the 6 rt_regex_* (match/match_full/search/findall/split/replace)\n'
        printf '//   the emitted runtime.c hexa_regex_* bodies delegate to under\n'
        printf '//   HEXA_REGEX_NATIVE, backed by a Thompson NFA + backtrack VM. Every other\n'
        printf '//   symbol is demoted to local so the seed exports a 6-symbol contract only\n'
        printf '//   (thompson/backtrack are public stdlib modules — undemoted globals would\n'
        printf '//   collide at ld with a user program that also imports them).\n'
        printf '//   These leaves are gen2-native-only (the hexat C-transpile bootstrap cannot\n'
        printf '//   lower them), so the body enters the shipped runtime.a ONLY via this seed.\n'
        printf '//   ABI: %s. External: hexa string/value/array runtime (resolved within runtime.a).\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_REGEX_NATIVE (opt-IN, default-OFF)\n'
        printf '//   + ar this .o into runtime.a so the regcomp/regexec/regfree seams route\n'
        printf '//   native, dropping those libc symbols from the nm-UND floor on flip.\n'
        sed -E -e 's#"[^"]*regex_rt\.hexa"#"stdlib/runtime/regex_rt.hexa"#g' \
               -e 's#^// source: .*regex_rt\.hexa#// source: stdlib/runtime/regex_rt.hexa#' "$demoted"
    } > "$out"

    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_regex_')"
        # Floor-reduction assert: no NEW libc symbol in the seed's undefined set. Only
        # the hexa carrier (hexa_*/__hx_*) may be U; a libc name (memcpy/malloc/strlen/…)
        # would defeat the flip's purpose. Advisory here (WARN), hard-gated in CI.
        local libc_u; libc_u="$( (nm "$o" 2>/dev/null || echo) | grep -E '^[[:space:]]*U ' | grep -vE ' _?(hexa_|__hx_|rt_regex_)' | grep -cvE ' _?(GLOBAL_OFFSET_TABLE|__stack_chk)' || echo 0)"
        echo "[regen_regex_rt] $triple → $out (6 globl · $t T rt_regex_* · ${libc_u} non-carrier U)"
        [ "${libc_u:-0}" -eq 0 ] || echo "[regen_regex_rt] WARN $triple: seed has ${libc_u} non-carrier undefined symbols — inspect (floor-reduction assert)" >&2
    else
        echo "[regen_regex_rt] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_regex_rt] $triple → $out (6 globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/regex_rt_arm64.s" "Mach-O, _rt_regex_* underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/regex_rt_x86_64.s" "ELF, rt_regex_* no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/regex_rt_arm64-linux.s" "ELF aarch64, rt_regex_* no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/regex_rt_arm64.s" "Mach-O, _rt_regex_* underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/regex_rt_x86_64.s" "ELF, rt_regex_* no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/regex_rt_arm64-linux.s" "ELF aarch64, rt_regex_* no underscore"
        ;;
    *) echo "[regen_regex_rt] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_regex_rt] done."
