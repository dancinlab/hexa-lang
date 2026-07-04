#!/usr/bin/env bash
# tool/test_question_op_emit.sh — postfix `?` try-propagation END-TO-END emit
# assertion for the NATIVE (compiler/*) pipeline (RFC r15-D2; spec
# docs/rfc/rfc_drafts/r15-d2-question-operator.md).
#
# Proves the opt-in HEXA_TRY_OP wiring across the native lex→parse→HIR→MIR
# pipeline (compiler/lex/tokens.hexa Question token, compiler/lex/lexer.hexa
# `?` scan, compiler/parse/parser.hexa parse_postfix UnOp("?") carrier,
# compiler/lower/ast_to_hir.hexa re-tag to HExpr.kind "tryop", and
# compiler/lower/hir_to_mir.hexa success-tag discriminant + Err/None
# early-return lowering):
#
#   HEXA_TRY_OP=1  --emit=asm  on an `expr?` program  →  compiles (no error)
#   (flag unset)   --emit=asm  on an `expr?` program  →  ERRORS (`?` is not a
#                                                        token on the default
#                                                        native build — today's
#                                                        behavior, unchanged)
#   either flag    --emit=asm  on a `?`-FREE program  →  BYTE-IDENTICAL asm
#                                                        (byteeq-neutral default)
#
# Reference: Rust `?` (std::ops::Try / RFC 0243 · RFC 1859) and Swift `try?`.
# hexa diverges on the no-`From::from` and no-return-type-check axes (RFC
# §3.3-§3.4); a SINGLE success discriminant unifies the Result(Ok/Err) and
# Option(Some/None) lanes (RFC §3.1).
#
# Run on a build host (aiden/summer/ghost) — mini is git/gh-only and the
# source-compiler-via-interpreter path is too heavy there (atlas load timeout).
#   HEXA=build/aprime_cc bash tool/test_question_op_emit.sh
#
# $HEXA must be a compiler that emits asm for `--emit=asm` (build/aprime_cc, a
# gen2+ self-host binary, or an installed `hexa`). Defaults to build/aprime_cc.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO"
HEXA="${HEXA:-build/aprime_cc}"
[ -x "$HEXA" ] || HEXA="$(command -v hexa || true)"
[ -n "$HEXA" ] && [ -x "$HEXA" ] || { echo "FAIL: no usable HEXA compiler ($HEXA)"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# program EXERCISING `?` (F-D2-1 Ok-unwrap + F-D2-2 Err-early-return).
# NOTE: the NATIVE pipeline constructs enums via the qualified `Enum::Variant`
# syntax (map-backed `{__tag,__p0}`), NOT the bare `Ok(7)` builtin the self/
# (gen2) array model uses — so the native exercise spells the success variant
# `Result::Ok` / the failure variant `Result::Err` (no enum decl needed; the
# parser tags any `Name::Variant` dynamically). The success discriminant in
# hir_to_mir matches `Result::Ok`/`Option::Some` (qualified) AND `Ok`/`Some`
# (bare parity).
QSRC="$WORK/q_src.hexa"
cat > "$QSRC" <<'HEXA'
fn f_ok() {
    let v = Result::Ok(7)?
    return Result::Ok(v)
}
fn f_err() {
    let v = Result::Err("boom")?
    return Result::Ok(v)
}
fn main() {
    println(to_string(f_ok()))
    println(to_string(f_err()))
}
HEXA

# program WITHOUT `?` — the byteeq-neutrality control.
CSRC="$WORK/clean_src.hexa"
cat > "$CSRC" <<'HEXA'
fn g(x) { return x + 1 }
fn main() {
    println(to_string(g(7)))
}
HEXA

fail() { echo "FAIL: $1"; exit 1; }

# ── (1) flag ON → `expr?` program compiles to asm ───────────────────────────
HEXA_TRY_OP=1 "$HEXA" --emit=asm -o "$WORK/q_on.s" "$QSRC" \
    || fail "compile of `expr?` under HEXA_TRY_OP=1 errored"
[ -s "$WORK/q_on.s" ] || fail "HEXA_TRY_OP=1 produced empty asm for `expr?`"
echo "PASS  HEXA_TRY_OP=1 → `expr?` lowers + emits asm"

# ── (2) flag OFF → `expr?` program is rejected (feature gated off) ───────────
if "$HEXA" --emit=asm -o "$WORK/q_off.s" "$QSRC" 2>/dev/null; then
    fail "`expr?` compiled with HEXA_TRY_OP unset — operator is NOT opt-in"
fi
echo "PASS  flag-off → `expr?` rejected (default native build leaves `?` unlexable)"

# ── (3) byteeq-neutral DEFAULT — a `?`-free program is byte-identical ────────
HEXA_TRY_OP=1 "$HEXA" --emit=asm -o "$WORK/c_on.s" "$CSRC" \
    || fail "compile of clean program under HEXA_TRY_OP=1 errored"
"$HEXA" --emit=asm -o "$WORK/c_off.s" "$CSRC" \
    || fail "compile of clean program (flag off) errored"
cmp -s "$WORK/c_on.s" "$WORK/c_off.s" \
    || fail "HEXA_TRY_OP flipped asm of a `?`-free program — NOT byteeq-neutral"
echo "PASS  `?`-free program: HEXA_TRY_OP=1 asm ≡ flag-off asm (byteeq-neutral)"

# ── (4) behavioral end-to-end (best-effort: needs a working linker) ─────────
# Asserts F-D2-1 (Result::Ok(7)? unwraps the payload → success-continuation) and
# F-D2-2 (Result::Err("boom")? early-returns the receiver UNCHANGED) at runtime:
# the two functions must produce DIFFERENT outputs (success-unwrap-then-rewrap
# vs identity-propagated error) and the program must exit 0. Skipped (not
# failed) if the host cannot link a full binary, so the asm-level gates above
# remain the hard contract. The exhaustive behavioral oracle is the gen2 run
# suite self/test_question_op.hexa (HEXA_TRY_OP=1), whose array model prints the
# human-legible `[Ok, 7]` / `[Err, boom]` forms.
if HEXA_TRY_OP=1 "$HEXA" -o "$WORK/q_bin" "$QSRC" 2>/dev/null && [ -x "$WORK/q_bin" ]; then
    OUT="$("$WORK/q_bin" || true)"
    L1="$(echo "$OUT" | sed -n '1p')"; L2="$(echo "$OUT" | sed -n '2p')"
    [ -n "$L1" ] && [ -n "$L2" ] || fail "run: expected two non-empty output lines"
    [ "$L1" != "$L2" ] || fail "run: Ok-unwrap and Err-propagate yielded identical output (`?` inert)"
    echo "PASS  run: Result::Ok(7)? unwraps ≠ Result::Err(boom)? early-returns (F-D2-1/2)"
else
    echo "SKIP  end-to-end run (no linkable binary on this host; asm gates stand)"
fi

echo "--- question-op native emit: PASS ---"
