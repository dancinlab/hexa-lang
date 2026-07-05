#!/usr/bin/env bash
# tool/regen_hxlcl_strncmp_native_s.sh — reproducibly regenerate the frozen native
# hxlcl_strncmp seeds from the SSOT stdlib/runtime/hxlcl_core.hexa, using the native
# compiler. The WALL-2 free twin of tool/regen_regex_rt_native_s.sh
# (zero-c #29 WALL-2 free-flip prereq-(a) — Fable bmtd0lpxf).
#
#   tool/regen_hxlcl_strncmp_native_s.sh [darwin|x86_64|arm64-linux|all]   (default: all)
#
# WHY this seed exists (prereq-(a), root-caused #4489/#4545):
#   The old resolver emitted hxlcl_strncmp's Route-C .o LIVE at Stage 0b via
#   `$bin _drv.hexa --emit=asm --target=<t> -o out.s hxlcl_core.hexa`. That argv is the
#   standalone `aprime_cc` contract, but faithful CI resolves the binary to the CLI
#   `hexa` (self/main.hexa), whose `.hexa`-first dispatch runs the driver in COMPAT mode
#   (`cmd_run`) and IGNORES `--emit=asm -o … hxlcl_core.hexa` → a no-op driver runs,
#   rc=0, and NO .s is produced → the `[ -s ]` gate FATALs "empty" → runtime.a missing →
#   faithful RED on all 3 targets. And build/aprime_cc (the ONLY binary that honours the
#   emit contract) needs runtime.a, so it CANNOT exist at Stage 0b — the live-emit is
#   structurally impossible in the faithful build. Fix: bake the .s ONCE on the pool with
#   aprime_cc and check it in as a frozen seed (the #4535 regex / alloc_syscall pattern),
#   so the resolver just consumes a git-tracked .s (no build-time emit binary needed).
#
# Pipeline (per target):
#   1) aprime_cc _drv.hexa --emit=asm --target=<triple> -o <out>.s hxlcl_core.hexa
#   2) .globl DEMOTION post-pass: keep ONLY hxlcl_strncmp (`_hxlcl_strncmp` on Mach-O) global,
#      demote every other .globl to local (the label stays → intra-.o calls resolve since
#      this is a SINGLE .s → single .o). This seals the seed to a 1-symbol contract and
#      kills the multi-def risk at ld (so the resolver needs no per-OS objcopy isolate).
#   3) normalize the source path in comments (deterministic) + prepend the frozen header.
#   4) sanity: cross-assemble + assert EXACTLY 1 defined-global hxlcl_strncmp + no libc U.
#
# hxlcl_core.hexa defines the whole hxlcl_* libc-floor family (strstr/strchr/strtoll/
# calloc/realloc/free/…); emitting the module gives them all as globals, so the demotion
# to a 1-symbol (hxlcl_strncmp) contract is what makes this seed ar-able next to the
# libc-shim member for the OTHER hxlcl_* (which stay shim-served until their own flip).
#
# Targets:
#   darwin      → self/native/hxlcl_strncmp_arm64.s        (arm64-apple-darwin, Mach-O)
#   x86_64      → self/native/hxlcl_strncmp_x86_64.s        (x86_64-linux-gnu,   ELF)
#   arm64-linux → self/native/hxlcl_strncmp_arm64-linux.s   (arm64-linux-gnu,    ELF)
#
# Requires a native compiler at $APRIME (default build/aprime_cc) + a C driver
# ($CC, default clang) to cross-assemble. POOL ONLY (aprime emit is a heavy build).
set -euo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
APRIME="${APRIME:-$HX/build/aprime_cc}"
CC="${CC:-clang}"
WHICH="${1:-all}"

[ -x "$APRIME" ] || { echo "[regen_hxlcl_strncmp] ERROR: native compiler not at $APRIME (set APRIME=)" >&2; exit 1; }

SRC_MAIN="$HX/stdlib/runtime/hxlcl_core.hexa"
[ -f "$SRC_MAIN" ] || { echo "[regen_hxlcl_strncmp] ERROR: SSOT missing: $SRC_MAIN" >&2; exit 1; }

# The single external-contract symbol the resolver ar's into runtime.a on flip.
CONTRACT='hxlcl_strncmp'

TMP="$(mktemp -d -t regen_hxlcl_strncmp.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
printf 'fn _drv_unused() {}\n' > "$TMP/_drv.hexa"

emit_one() {
    local triple="$1" out="$2" abi="$3"
    local raw="$TMP/raw.s" demoted="$TMP/demoted.s"
    # aprime_cc honours the `<runner>.hexa --emit=asm --target=… -o out.s SOURCE.hexa`
    # contract (the CLI hexa does NOT — that mis-binding was the #4489/#4545 empty-emit
    # bug this seed replaces). Preserve emit stderr so a real diagnostic is LOUD.
    if ! env HEXA_CABI_HXLCL=1 "$APRIME" "$TMP/_drv.hexa" --emit=asm --target="$triple" \
            -o "$raw" "$SRC_MAIN" 2>"$TMP/emit.err"; then
        echo "[regen_hxlcl_strncmp] ERROR: $triple aprime --emit=asm failed:" >&2
        sed 's/^/    /' "$TMP/emit.err" >&2
        exit 1
    fi

    # --- .globl DEMOTION post-pass: keep ONLY hxlcl_strncmp .globl, drop the rest ---
    # `_?` matches the Mach-O underscore prefix. The kept label stays defined; every
    # other global is demoted to local (its `.globl` line deleted).
    #
    # Mach-O ALSO emits a `.private_extern _hxlcl_*` per function (N_PEXT). Dropping the
    # `.globl` alone leaves those symbols EXTERNAL (private_extern still sets N_EXT), so a
    # whole-module seed collides on `ld -r` (multidef=49: _hxlcl_atof/atoi/calloc/… all
    # defined in both the seed and the shim) — the exact darwin-arm64 faithful failure.
    # ELF has no `.private_extern` (arm64-linux/x86_64 seeds carry 0), so this rule is a
    # no-op there. Strip ALL `.private_extern` lines: the contract keeps its own `.globl`
    # (a public external), every sibling becomes a true local → no ld -r duplicate.
    sed -E "/^[[:space:]]*\.globl[[:space:]]+_?${CONTRACT}([[:space:]]|\$)/b
            /^[[:space:]]*\.globl[[:space:]]/d
            /^[[:space:]]*\.private_extern[[:space:]]/d" "$raw" > "$demoted"

    local kept total pext
    kept="$(grep -cE "^[[:space:]]*\.globl[[:space:]]+_?${CONTRACT}([[:space:]]|\$)" "$demoted" || echo 0)"
    total="$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$demoted" || echo 0)"
    # NOTE: `grep -c` prints "0" AND exits 1 when there are no matches, so `|| echo 0`
    # (the kept/total idiom, safe there because those counts are always >=1) would append
    # a SECOND "0" here → "0\n0" → `[ -eq ]` integer error. Use `|| true` to keep grep's own "0".
    pext="$(grep -cE '^[[:space:]]*\.private_extern[[:space:]]' "$demoted" || true)"
    [ "$kept" -eq 1 ] || { echo "[regen_hxlcl_strncmp] ERROR: $triple kept $kept/1 hxlcl_strncmp global (raw emit missing the shim?)" >&2; exit 1; }
    [ "$total" -eq 1 ] || { echo "[regen_hxlcl_strncmp] ERROR: $triple demotion left $total globals (expected 1 — sed pattern drift)" >&2; exit 1; }
    [ "$pext" -eq 0 ] || { echo "[regen_hxlcl_strncmp] ERROR: $triple demotion left $pext .private_extern (Mach-O N_PEXT stays external → ld -r multidef)" >&2; exit 1; }

    # ── ISOLATION pass (convergence stage-resolve-runtime-a-3) ───────────────────────
    # Whole-module Route-C emit bundles every hxlcl_* sibling (incl. syscall leaves whose
    # `bl __errno_location` is glibc-only, darwin-absent) as local bodies; .globl-demotion
    # leaves them in the .o, detonating build/hexat on darwin (Undefined ___errno_location)
    # when consumed default-ON. Slice to the ONE contract fn (+ referenced data/stamps);
    # sibling calls stay shim/carrier-served externals. Byte-neutral on the flag-OFF path.
    python3 "$(dirname "$0")/isolate_native_seed.py" "$demoted" "$CONTRACT" "$demoted.iso" \
        || { echo "[regen_hxlcl_strncmp] ERROR: $triple isolation slice failed" >&2; exit 1; }
    mv "$demoted.iso" "$demoted"
    [ "$(grep -cE '^[[:space:]]*\.globl[[:space:]]' "$demoted")" -eq 1 ] \
        || { echo "[regen_hxlcl_strncmp] ERROR: $triple isolation left != 1 global" >&2; exit 1; }
    ! grep -qE 'errno_location' "$demoted" \
        || { echo "[regen_hxlcl_strncmp] ERROR: $triple isolation left an errno_location ref" >&2; exit 1; }

    {
        printf '// %s — FROZEN BOOTSTRAP SEED (RT-NATIVE zero-c #29 — WALL-2 hxlcl_strncmp).\n' "$(basename "$out")"
        printf '// GENERATED: tool/regen_hxlcl_strncmp_native_s.sh — aprime_cc _drv.hexa --emit=asm\n'
        printf '//   --target=%s -o %s hxlcl_core.hexa, then a .globl DEMOTION post-pass\n' "$triple" "$(basename "$out")"
        printf '//   keeping ONLY the hxlcl_strncmp shim global.\n'
        printf '//   Provides hxlcl_strncmp (native Route-C body, no libc free) that\n'
        printf '//   stage_resolve_runtime_a ar'"'"'s into runtime.a under HEXA_RT_NATIVE_FREE,\n'
        printf '//   replacing the libc-shim free member so `free` drops from the nm-UND floor.\n'
        printf '//   Baked as a seed (not live-emitted) because the emit contract needs\n'
        printf '//   build/aprime_cc, which cannot exist at Stage 0b (#4489/#4545 root).\n'
        printf '//   Every other hxlcl_* global is demoted to local (1-symbol contract).\n'
        printf '//   ABI: %s. External: hexa string/value runtime (resolved within runtime.a).\n' "$abi"
        # Strip the absolute build-root prefix so comment paths / .file directives are
        # RELATIVE → the frozen seed is reproducible across build hosts.
        sed -E -e "s@${HX%/}/@@g" \
               -e 's@"[^"]*hxlcl_core\.hexa"@"stdlib/runtime/hxlcl_core.hexa"@g' \
               -e 's@^(#|//) source: .*hxlcl_core\.hexa@\1 source: stdlib/runtime/hxlcl_core.hexa@' "$demoted"
    } > "$out"

    local cc_extra="" s="$TMP/check.s" o="$TMP/check.o"
    grep -vE '^// ' "$out" > "$s"
    case "$triple" in
        x86_64-linux-gnu) [ "$(uname -s)" = Darwin ] && cc_extra="-target x86_64-linux-gnu" ;;
        arm64-linux-gnu)  [ "$(uname -s)" = Darwin ] && cc_extra="-target aarch64-linux-gnu" ;;
    esac
    if $CC $cc_extra -c "$s" -o "$o" 2>/dev/null; then
        local t; t="$( (nm "$o" 2>/dev/null || echo) | grep -cE ' T _?hxlcl_strncmp')"
        [ "$t" -eq 1 ] || { echo "[regen_hxlcl_strncmp] ERROR: $triple nm shows $t/1 T hxlcl_strncmp" >&2; exit 1; }
        # Floor-reduction assert: the seed must introduce NO new libc UND (a libc name in
        # U would defeat the flip). Only the hexa carrier (hexa_*/__hx_*) may be U.
        local libc_u; libc_u="$( (nm "$o" 2>/dev/null || echo) | grep -E '^[[:space:]]*U ' | grep -vE ' _?(hexa_|__hx_|hxlcl_)' | grep -cvE ' _?(GLOBAL_OFFSET_TABLE|__stack_chk)' || echo 0)"
        echo "[regen_hxlcl_strncmp] $triple → $out (1 globl · $t T hxlcl_strncmp · ${libc_u} non-carrier U)"
        [ "${libc_u:-0}" -eq 0 ] || echo "[regen_hxlcl_strncmp] WARN $triple: seed has ${libc_u} non-carrier undefined symbols — inspect (floor-reduction assert)" >&2
    else
        echo "[regen_hxlcl_strncmp] WARN $triple: cross-assemble check skipped (no matching toolchain)" >&2
        echo "[regen_hxlcl_strncmp] $triple → $out (1 globl)"
    fi
}

case "$WHICH" in
    darwin)      emit_one arm64-apple-darwin "$HX/self/native/hxlcl_strncmp_arm64.s" "Mach-O, _hxlcl_strncmp underscore-prefixed" ;;
    x86_64)      emit_one x86_64-linux-gnu   "$HX/self/native/hxlcl_strncmp_x86_64.s" "ELF, hxlcl_strncmp no underscore" ;;
    arm64-linux) emit_one arm64-linux-gnu    "$HX/self/native/hxlcl_strncmp_arm64-linux.s" "ELF aarch64, hxlcl_strncmp no underscore" ;;
    all)
        emit_one arm64-apple-darwin "$HX/self/native/hxlcl_strncmp_arm64.s" "Mach-O, _hxlcl_strncmp underscore-prefixed"
        emit_one x86_64-linux-gnu   "$HX/self/native/hxlcl_strncmp_x86_64.s" "ELF, hxlcl_strncmp no underscore"
        emit_one arm64-linux-gnu    "$HX/self/native/hxlcl_strncmp_arm64-linux.s" "ELF aarch64, hxlcl_strncmp no underscore"
        ;;
    *) echo "[regen_hxlcl_strncmp] usage: $0 [darwin|x86_64|arm64-linux|all]" >&2; exit 1 ;;
esac
echo "[regen_hxlcl_strncmp] done."
