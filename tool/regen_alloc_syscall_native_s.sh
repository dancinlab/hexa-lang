#!/usr/bin/env bash
# tool/regen_alloc_syscall_native_s.sh — reproducibly freeze the alloc+syscall
# standalone native seed from the SSOT self/rt/alloc.hexa (RT-NATIVE-ZEROC b3a).
# The alloc twin of tool/regen_array_core_native_s.sh, with TWO deltas:
#   Δ1 FLATTEN — self/rt/alloc.hexa `use`s self/rt/syscall, so the seed source is
#      the FLATTENED alloc+syscall (tool/larm64_flatten.py), not a single file.
#   Δ2 GLOBAL .data — the seed carries the `__arena_tbl` module-global `.data g0`
#      slot (the global-write path, F-M5-GSLOT-VAL-DONE / F-M5-GSLOT-DATA-SLOT).
#
#   tool/regen_alloc_syscall_native_s.sh [darwin|x86_64|arm64-linux|all]  (default all)
#
# Pipeline (per target):
#   1) larm64_flatten self/rt/alloc.hexa  → alloc-flat.hexa  (alloc + syscall)
#   2) aprime _drv.hexa --emit=asm --target=<triple> alloc-flat.hexa → raw .s
#   3) normalize the `.file` source path (deterministic, host-independent) +
#      prepend the frozen provenance header.
#   4) sanity: assert >= 30 defined-global symbols (sys_* + hexa_arena_* +
#      hexa_ptr_* + rt_init; the full set is ~116).
#
# The bodies use the M5-completed shipping leaf surface — __hx_syscall6/0,
# __hx_ptr_load64/store64, __hx_target_os, __hx_str_ptr, + the module-global write
# path (arena_id==-999 → [rip+g<id>] / stp [x15]) — which the hexat C-transpile
# bootstrap cannot lower, so the bodies enter the shipped runtime.a ONLY via this
# seed (the rt_hi / array_core mechanism). The b2 gate proved them RUN-correct
# end-to-end (F-M5-GSLOT-VAL-DONE: exit 0).
#
# Requires a native compiler at $APRIME that carries the global-write codegen
# (>= #3517 / main e6f1c238e) — e.g. build/aprime_cc (gen3) or a fresh build.
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_alloc_syscall] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC="$HX/self/rt/alloc.hexa"
[ -f "$SRC" ] || { echo "[regen_alloc_syscall] ERROR: SSOT missing: $SRC" >&2; exit 1; }

TMP="$(mktemp -d -t regen_alloc_syscall.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

FLAT="$TMP/alloc-flat.hexa"
python3 "$HX/tool/larm64_flatten.py" "$SRC" "$FLAT" >/dev/null

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s"
    "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" -o "$raw" "$FLAT" >/dev/null 2>&1
    local n; n="$(grep -cE '^[[:space:]]*\.globl' "$raw" || echo 0)"
    [ "$n" -ge 30 ] || { echo "[regen_alloc_syscall] ERROR: $triple emitted only $n globl (expected ~116)" >&2; exit 1; }
    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE-ZEROC b3a alloc+syscall).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_alloc_syscall_native_s.sh — aprime _drv.hexa --emit=asm\n'
        printf '//   --target=%s (flattened self/rt/alloc.hexa = alloc+syscall).\n' "$triple"
        printf '//   Native alloc+syscall bodies (hexa_arena_*/hexa_ptr_*/sys_*/rt_init) over the\n'
        printf '//   M5 leaf surface (__hx_syscall6/__hx_ptr_*/__hx_target_os/__hx_str_ptr + the\n'
        printf '//   module-global write path). hexat C-transpile cannot lower these, so they\n'
        printf '//   enter runtime.a ONLY via this seed. RUN-proven (F-M5-GSLOT-VAL-DONE, exit 0).\n'
        printf '//   ABI: %s.\n' "$abi"
        # Normalize the flatten path, THEN strip the synthesized entry `main`
        # (aprime --emit=asm adds a default entry; the flattened alloc.hexa has no
        # `fn main`). A library seed must NOT export `main` — it would multiple-
        # definition-clash with runtime.o's main at runtime.a ar. Drop the
        # `.globl/.type/.size main` directives + the `main:`-to-next-symbol body.
        sed -E -e 's#"[^"]*alloc-flat\.hexa"#"self/rt/alloc.hexa"#g' \
               -e 's#^// source: .*alloc-flat\.hexa#// source: self/rt/alloc.hexa#' "$raw" \
        | awk '
            /^[[:space:]]*\.globl[[:space:]]+_?main$/ { next }
            /^[[:space:]]*\.type[[:space:]]+_?main,/ { next }
            /^[[:space:]]*\.size[[:space:]]+_?main,/ { next }
            /^_?main:[[:space:]]*$/ { inmain=1; next }
            inmain==1 && /^[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*$/ { inmain=0 }
            inmain==1 && /^[[:space:]]*\.globl[[:space:]]/ { inmain=0 }
            inmain!=1 { print }
        '
    } > "$out"
    # Sanity: the stripped seed must NOT export main.
    if grep -qE '^[[:space:]]*\.globl[[:space:]]+_?main$' "$out"; then
        echo "[regen_alloc_syscall] ERROR: $out still exports main after strip" >&2; exit 1
    fi
    echo "[regen_alloc_syscall] $triple → $out ($n globl, main-stripped)"
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/alloc_syscall_arm64.s"       "Mach-O arm64" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/alloc_syscall_x86_64.s"      "ELF x86_64" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/alloc_syscall_arm64-linux.s" "ELF aarch64" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/alloc_syscall_arm64.s"       "Mach-O arm64"
        emit_one x86_64-linux-gnu   "$HX/self/native/alloc_syscall_x86_64.s"      "ELF x86_64"
        emit_one arm64-linux-gnu    "$HX/self/native/alloc_syscall_arm64-linux.s" "ELF aarch64"
        ;;
    *) echo "[regen_alloc_syscall] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_alloc_syscall] done."
