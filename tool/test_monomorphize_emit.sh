#!/usr/bin/env bash
# tool/test_monomorphize_emit.sh — static-generic monomorphization END-TO-END
# emit assertion (RFC state/rfc_static_generics_monomorphization.md, lane ①·R2).
#
# Proves the R2 marker wiring (compiler/lower/hir_to_mir.hexa::_lower_fn suffixes
# an @specialize fn's MFunc name with `$$g` under HEXA_MONOMORPHIZE=1) makes the
# merged monomorphize pass actually emit per-type instances:
#
#   HEXA_MONOMORPHIZE=1  --emit=asm  →  `id$int` AND `id$str` symbols present
#   (flag unset)         --emit=asm  →  NEITHER present (one type-erased shape)
#
# It also asserts byteeq-neutrality of the DEFAULT path: the flag-OFF asm is
# byte-identical with and without the env var exported-but-not-"1" (the gate is
# strict `== "1"`), i.e. the only thing that flips emission is HEXA_MONOMORPHIZE=1.
#
# Run on a build host (aiden/summer/ghost) — mini is git/gh-only, and the
# source-compiler-via-interpreter path is too heavy there (atlas load timeout).
#   HEXA=build/aprime_cc bash tool/test_monomorphize_emit.sh
#
# $HEXA must be a compiler that emits asm for `--emit=asm` (build/aprime_cc, a
# gen2+ self-host binary, or an installed `hexa`). Defaults to build/aprime_cc.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO"
HEXA="${HEXA:-build/aprime_cc}"
[ -x "$HEXA" ] || HEXA="$(command -v hexa || true)"
[ -n "$HEXA" ] && [ -x "$HEXA" ] || { echo "FAIL: no usable HEXA compiler ($HEXA)"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/mono_src.hexa"
cat > "$SRC" <<'HEXA'
@specialize fn id<T>(x: T) -> T { return x }
fn main() {
    let a = id(7)
    let b = id("ok")
    println(to_string(a) + b)
}
HEXA

fail() { echo "FAIL: $1"; exit 1; }

# ── (1) flag ON → instances emitted ─────────────────────────────────────────
HEXA_MONOMORPHIZE=1 "$HEXA" --emit=asm -o "$WORK/on.s" "$SRC" \
    || fail "compile (HEXA_MONOMORPHIZE=1) errored"
grep -qE 'id\$int' "$WORK/on.s" || fail "id\$int instance NOT emitted under HEXA_MONOMORPHIZE=1"
grep -qE 'id\$str' "$WORK/on.s" || fail "id\$str instance NOT emitted under HEXA_MONOMORPHIZE=1"
echo "PASS  HEXA_MONOMORPHIZE=1 → id\$int + id\$str instances present"

# ── (2) flag OFF → single erased shape, no instance symbols ──────────────────
"$HEXA" --emit=asm -o "$WORK/off.s" "$SRC" \
    || fail "compile (flag off) errored"
! grep -qE 'id\$int|id\$str' "$WORK/off.s" \
    || fail "instance symbol leaked on the DEFAULT path (byteeq violation)"
echo "PASS  flag-off → no id\$int/id\$str (type-erased default)"

# ── (3) byteeq-neutral DEFAULT — non-'1' values do not flip emission ─────────
HEXA_MONOMORPHIZE=0 "$HEXA" --emit=asm -o "$WORK/off0.s" "$SRC" \
    || fail "compile (HEXA_MONOMORPHIZE=0) errored"
cmp -s "$WORK/off.s" "$WORK/off0.s" \
    || fail "HEXA_MONOMORPHIZE=0 asm differs from unset — gate is not strict =='1'"
echo "PASS  HEXA_MONOMORPHIZE=0 ≡ unset (strict gate, DEFAULT byte-identical)"

echo "--- monomorphize emit: 3/3 PASS ---"
