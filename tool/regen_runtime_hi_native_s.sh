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
#   4) sanity: cross-assemble + assert all 15 rt_str_* are defined-global (T).
#
# NOTE on determinism: the emitted GLOBAL symbol set (the ABI/linkage contract)
# is byte-identical across regen runs, but local `.L<hex>_bbN` basic-block label
# PREFIXES carry a per-process-random nonce, so two regen runs differ only in
# those local labels (irrelevant to linking — they never escape the object). The
# committed seed is frozen ONCE and is link-stable; re-running regen is for
# refreshing the seed against an SSOT change, not for bit-reproducing the file.
#
# Targets:
#   darwin      → self/native/runtime_hi_native.s       (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/runtime_hi_x86_64.s       (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/runtime_hi_arm64-linux.s  (arm64-linux-gnu,     ELF aarch64)
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
    [ "$n" -ge 15 ] || { echo "[regen_rt_hi] ERROR: $triple emitted only $n/15 rt_str_*" >&2; exit 1; }
    # PIC fixup (x86_64-linux only): the emitter loads a few string-literal
    # addresses with an ABSOLUTE `mov <reg>, .LCstrN`, which yields an
    # R_X86_64_32S relocation against `.rodata` — REJECTED when linking the
    # default-PIE executable GCC/ld produce on modern linux ("relocation
    # R_X86_64_32S … can not be used when making a PIE object"). Rewrite those
    # to the position-independent `lea <reg>, [rip+.LCstrN]` form (semantically
    # identical — both load the label's address into <reg>; the emitter already
    # uses the lea+rip form for the other string-arg payloads). arm64-darwin is
    # position-independent by construction (adrp/add), so it is left untouched.
    case "$triple" in
        x86_64-linux-gnu)
            sed -E -i.picbak 's/^([[:space:]]*)mov ([a-z0-9]+), (\.LC[A-Za-z0-9_]+)([[:space:]].*)?$/\1lea \2, [rip+\3]\4/' "$raw"
            rm -f "$raw.picbak"
            ;;
    esac
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B Z2a).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_runtime_hi_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s runtime_hi_lib.hexa (lib-only head of self/runtime_hi.hexa).\n' "$triple" "$(basename "$out")"
        printf '//   Provides rt_str_* (zero C): split/lines/pad_left/pad_right/repeat/center +\n'
        printf '//   to_upper/to_lower/trim/trim_start/trim_end +\n'
        printf '//   starts_with_b/ends_with_b/contains_b + from_int (15 fns). ABI: %s.\n' "$abi"
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
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?rt_str_')"
        # PIE-link check (x86_64): the seed is ar'd into runtime.a and linked into
        # the default-PIE ./hexa on linux — assert no absolute reloc survives by
        # PIE-linking a tiny stub that references one symbol. Catches the
        # R_X86_64_32S class at regen time, not in CI.
        local pie="ok"
        case "$triple" in
            x86_64-linux-gnu)
                local stub="$TMP/pie_stub.c" exe="$TMP/pie_exe"
                printf 'typedef struct{long a,b;}HexaVal;HexaVal rt_str_trim(HexaVal);int main(void){HexaVal z={0,0};rt_str_trim(z);return 0;}\n' > "$stub"
                # define the hexa_* externs the seed calls so the stub link resolves
                printf 'HexaVal hexa_array_new(void){HexaVal z={0,0};return z;}void hexa_array_push(HexaVal a,HexaVal b){(void)a;(void)b;}long hexa_len(HexaVal a){(void)a;return 0;}HexaVal hexa_str_byte_at(HexaVal a,long b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_str_join(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_str_substring(HexaVal a,long b,long c){(void)a;(void)b;(void)c;HexaVal z={0,0};return z;}HexaVal hexa_int(long a){(void)a;HexaVal z={0,0};return z;}HexaVal hexa_eq(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}int hexa_truthy(HexaVal a){(void)a;return 0;}\n' >> "$stub"
                # arithmetic/compare/index externs introduced by rt_str_from_int
                # (the construct-half itoa prim — integer math + array index).
                printf 'HexaVal hexa_add_slow(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_sub(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_mul(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_div(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_mod(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_cmp_lt(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_cmp_le(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_cmp_gt(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_cmp_ge(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}HexaVal hexa_index_get(HexaVal a,HexaVal b){(void)a;(void)b;HexaVal z={0,0};return z;}\n' >> "$stub"
                # Prefer a full cross toolchain (zig cc) for the PIE LINK — plain
                # clang on a non-linux host has no linux crt/libc and fails the
                # link for reasons unrelated to relocations (false negative). zig
                # cc bundles a complete x86_64-linux sysroot. If neither a native
                # linux $CC nor zig is available, fall back to a reloc SCAN of the
                # object (no R_X86_64_32S against .rodata) so the check still has
                # teeth without a linker.
                if command -v zig >/dev/null 2>&1; then
                    if zig cc -target x86_64-linux-gnu -pie "$stub" "$o" -o "$exe" 2>/dev/null; then pie="PIE-OK"; else pie="PIE-FAIL"; fi
                elif [ "$(uname -s)" = "Linux" ]; then
                    if $CC -pie "$stub" "$o" -o "$exe" 2>/dev/null; then pie="PIE-OK"; else pie="PIE-FAIL"; fi
                else
                    # No cross-linker: scan for the offending absolute reloc class.
                    local reloc
                    reloc="$( (objdump -r "$o" 2>/dev/null || llvm-objdump -r "$o" 2>/dev/null || echo) | grep -c 'R_X86_64_32S' )"
                    [ "${reloc:-0}" -eq 0 ] && pie="PIE-OK(reloc-scan)" || pie="PIE-FAIL"
                fi
                ;;
        esac
        echo "[regen_rt_hi] wrote $out — $n .globl, cross-assemble OK, $t defined-global rt_str_*${pie:+, $pie}"
        [ "$pie" = "PIE-FAIL" ] && { echo "[regen_rt_hi] ERROR: $out has a non-PIE relocation — the PIC fixup did not cover all absolute loads" >&2; exit 1; }
    else
        echo "[regen_rt_hi] WARN: $out wrote but cross-assemble check failed ($CC $cc_extra)" >&2
    fi
}

case "$WHICH" in
    darwin) emit_one arm64-apple-darwin "$HX/self/native/runtime_hi_native.s" "Mach-O, _rt_str_* underscore + .private_extern" ;;
    x86_64) emit_one x86_64-linux-gnu   "$HX/self/native/runtime_hi_x86_64.s"  "ELF, rt_str_* no underscore + .hidden" ;;
    arm64-linux) emit_one arm64-linux-gnu "$HX/self/native/runtime_hi_arm64-linux.s" "ELF aarch64, rt_str_* no underscore + .hidden" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/runtime_hi_native.s" "Mach-O, _rt_str_* underscore + .private_extern"
        emit_one x86_64-linux-gnu   "$HX/self/native/runtime_hi_x86_64.s"  "ELF, rt_str_* no underscore + .hidden"
        emit_one arm64-linux-gnu    "$HX/self/native/runtime_hi_arm64-linux.s" "ELF aarch64, rt_str_* no underscore + .hidden" ;;
    *) echo "usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 2 ;;
esac
