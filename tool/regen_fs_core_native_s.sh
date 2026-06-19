#!/usr/bin/env bash
# tool/regen_fs_core_native_s.sh — reproducibly regenerate the frozen native
# FS-core WRITE-half seeds from the SSOT stdlib/runtime/fs_write_core.hexa, using
# the native compiler. The FS-write twin of tool/regen_array_core_native_s.sh.
#
#   tool/regen_fs_core_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s fs_write_core.hexa
#      (the dummy `_drv.hexa` first token satisfies the standalone driver's
#       "missing SOURCE" guard; the real source is the trailing arg).
#   2) normalize the `.file` source path (deterministic) + prepend the frozen
#      header (provenance + ABI notes), then STRIP any synthesized entry `main`
#      (a library seed must not export main — would clash with runtime.o's main).
#   3) per-target codegen-gap fixups (arm64-linux @PAGE → ELF :lo12:).
#   4) sanity: cross-assemble + assert both fs_*_all_native are defined-global.
#
# fs_write_core.hexa is SELF-CONTAINED (no `use`): the bodies call only the
# codegen leaf intrinsics __hx_syscall6 / __hx_target_os / __hx_target_arch
# (lowered inline, no emitted symbol) over inlined per-target syscall numbers +
# open flags. So the seed exports ONLY fs_write_all_native + fs_append_all_native
# and has NO external `.globl` to clash with the alloc seed's syscall surface.
# These intrinsics are gen2-native-only (the hexat C-transpile bootstrap cannot
# lower them), so the bodies enter the shipped runtime.a ONLY via this seed.
#
# Targets:
#   darwin      → self/native/fs_core_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/fs_core_x86_64.s        (x86_64-linux-gnu,    ELF)
#   arm64-linux → self/native/fs_core_arm64-linux.s   (arm64-linux-gnu,     ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc — the gen3
# self-host binary) + a C driver ($CC, default clang) to cross-assemble.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_fs_core] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/stdlib/runtime/fs_write_core.hexa"
[ -f "$SRC" ] || { echo "[regen_fs_core] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_fs_core.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$SRC" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?fs_(write|append)_all_native' "$raw" || echo 0)"
    [ "$n" -ge 2 ] || { echo "[regen_fs_core] ERROR: $triple emitted only $n/2 fs_*_all_native" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE leg B FS-R1 write-half).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_fs_core_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s stdlib/runtime/fs_write_core.hexa.\n' "$triple" "$(basename "$out")"
        printf '//   Provides the FS-core WRITE-half (fs_write_all_native = open(O_WRONLY|\n'
        printf '//   O_CREAT|O_TRUNC,0644)+write+close; fs_append_all_native = O_APPEND) as\n'
        printf '//   native syscall bodies over the leaf intrinsics __hx_syscall6 /\n'
        printf '//   __hx_target_os / __hx_target_arch (lowered inline). SELF-CONTAINED — no\n'
        printf '//   external .globl (the per-target syscall numbers + open flags are inlined),\n'
        printf '//   so NO clash with the alloc seed`s syscall surface. These intrinsics are\n'
        printf '//   gen2-native-only (hexat C-transpile cannot lower them), so the bodies enter\n'
        printf '//   the shipped runtime.a ONLY via this seed.\n'
        printf '//   ABI: %s.\n' "$abi"
        printf '//   Lets stage_resolve_runtime_a define HEXA_RT_FS_NATIVE + ar this .o into\n'
        printf '//   runtime.a so rt_write_bytes / rt_write_bytes_append delegate to it.\n'
        # Normalize the `.file` quoted path + the unquoted `// source:` comment so
        # the frozen seed is byte-stable + host-independent. Then strip any
        # synthesized entry `main` (a library seed must not export main).
        sed -E -e 's#"[^"]*fs_write_core\.hexa"#"stdlib/runtime/fs_write_core.hexa"#g' \
               -e 's#^// source: .*fs_write_core\.hexa#// source: stdlib/runtime/fs_write_core.hexa#' "$raw" \
        | awk '
            /^[[:space:]]*\.globl[[:space:]]+_?main$/ { next }
            /^[[:space:]]*\.type[[:space:]]+_?main,/ { next }
            /^[[:space:]]*\.size[[:space:]]+_?main,/ { next }
            /^_?main:[[:space:]]*$/ { inmain=1; next }
            inmain==1 && /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*$/ { inmain=0 }
            inmain==1 && /^[[:space:]]*\.globl[[:space:]]/ { inmain=0 }
            inmain==1 && /^[[:space:]]*\.(section|data|text|bss|rodata)([[:space:]]|$)/ { inmain=0 }
            inmain!=1 { print }
        '
    } > "$out"
    # arm64-linux codegen gap (same as alloc seed): the arm64 backend emits Mach-O
    # textual page refs (`adrp X, sym@PAGE` + `add X, X, sym@PAGEOFF`) for BOTH
    # darwin and linux; GNU `as` (used to assemble the .s into runtime.a on
    # linux-arm64) needs the ELF aarch64 form (bare symbol on adrp + :lo12: on
    # add). Translate if present. fs_write_core references no global/cstring, so
    # this is normally a no-op, but kept defensively (mirrors the alloc regen).
    case "$triple" in
        arm64-linux-*)
            if grep -q '@PAGE' "$out"; then
                perl -i -pe 's/(adrp\s+[xw]\d+,\s*)([._A-Za-z][._A-Za-z0-9]*)\@PAGE\b/$1$2/; s/(add\s+[xw]\d+,\s*[xw]\d+,\s*)([._A-Za-z][._A-Za-z0-9]*)\@PAGEOFF\b/$1:lo12:$2/' "$out"
                if grep -q '@PAGE' "$out"; then
                    echo "[regen_fs_core] ERROR: $triple still has @PAGE after ELF reloc translate" >&2; exit 1
                fi
                echo "  [regen_fs_core] translated @PAGE/@PAGEOFF → ELF :lo12: (arm64-linux GNU-as codegen gap)"
            fi
            ;;
    esac
    # Sanity: the stripped seed must NOT export main.
    if grep -qE '^[[:space:]]*\.globl[[:space:]]+_?main$' "$out"; then
        echo "[regen_fs_core] ERROR: $out still exports main after strip" >&2; exit 1
    fi
    # Sanity: cross-assemble + count defined-global fs_*_all_native.
    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?fs_(write|append)_all_native')"
        echo "[regen_fs_core] $triple → $out ($n globl · $t T)"
    else
        echo "[regen_fs_core] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_fs_core] $triple → $out ($n globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/fs_core_arm64.s"       "Mach-O, _fs_*_all_native underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/fs_core_x86_64.s"      "ELF, fs_*_all_native no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/fs_core_arm64-linux.s" "ELF aarch64, fs_*_all_native no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/fs_core_arm64.s"       "Mach-O, _fs_*_all_native underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/fs_core_x86_64.s"      "ELF, fs_*_all_native no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/fs_core_arm64-linux.s" "ELF aarch64, fs_*_all_native no underscore"
        ;;
    *) echo "[regen_fs_core] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_fs_core] done."
