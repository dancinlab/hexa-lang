#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# tool/op39_constfold_gate.sh — HEXA-0POD OP-39/OP-42: float const-fold byte-eq
# REGRESSION tripwire. Locks the OP-37 (#3069) + OP-37b (#3073) + OP-40 (#3084)
# compile-time float const-fold fixes so they can NEVER silently regress.
#
# THE BUGS THIS GUARDS (silent — no crash, just subtly wrong float bytes):
#   OP-37  — `let a = 0.0 - <float literal>` const-folded through `%g`
#            (6-sig-digit lossy serialize) → corrupt low mantissa, max|Δ|=
#            2.027e-6 on the A&S erf coefficients. Fixed: preserve the operand's
#            EXACT source text for the additive-identity idioms (0.0-X, X-0.0,
#            0.0+X, X+0.0) — BYTE-EXACT.
#   OP-37b — computed folds (`<lit> * <lit>`, `<lit> + <lit>`) re-parsed operands
#            via the naive hxlcl_atof accumulator (≤1 ULP/operand, MAX 3 ULP
#            compounded). Fixed: route the operand parse through the correctly-
#            rounded strtod path (str.parse_float()) — operands byte-exact.
#   OP-40  — the remaining 1 ULP on computed products was the host's hand-rolled
#            %.17e fold SERIALIZE (rt_format_float_sci / hxlcl_vsnprintf — not
#            correctly-rounded; drifted ≈13% of folds). Fixed: serialize the
#            folded double as a bit-exact C99 hex-float literal (0x1.<mant>p<exp>,
#            integer ops only) — clang re-parses with ZERO loss → MAX 0 ULP. The
#            MUL_HF* cases exercise this path (correctly-rounded products the old
#            %.17e mis-served).
#
# Runs the SELF-CONTAINED oracle stdlib/flame/op39_constfold_byteeq.hexa via
# `hexa run` and asserts each compile-time-folded float's IEEE-754 LE bit
# pattern (decoded to a signed-64 int) equals the recorded golden. The bit
# pattern of a double is PORTABLE (identical on every arch/OS iff the float bits
# are), so this byte-eq assertion is MACHINE-INDEPENDENT — the same goldens hold
# on arm64-macos, x86_64-linux, arm64-linux, musl.
#
# Any drift = a REAL const-fold regression (someone re-broke the serialize path
# back to %g, or re-routed the operand parse through the naive hxlcl_atof).
#
# GOLDENS (verified by running the FIXED-compiler-built oracle binary; see
# .verdicts/hexa-0pod/F-OP39-CONSTFOLD-CI-GATE.txt):
#   (a) NEGATION / additive-identity idioms — python struct.pack('<d', ...)
#       ground truth, byte-EXACT (max|Δ|=0).
#   (b) COMPUTED folds — the bits the FIXED compiler produces; ≤1 ULP of python
#       ground truth (operands byte-exact; MUL1 product 1 ULP via host rt_mul,
#       the documented OP-37b host-arithmetic residual — locking the compiler's
#       correct output, NOT python's, so a re-broken parse drifts away from it).
#
# LOW BLAST RADIUS (the OP-19f/OP-34 gate discipline):
#   * Runs ONLY this one self-contained oracle (no `use`, no flame import) —
#     unrelated code can never fail this gate.
#   * Asserts ONLY the 18 const-fold bits lines below.
#   * This script is the SSOT (also runnable locally:
#       sh tool/op39_constfold_gate.sh [hexa-bin]); the CI step is a thin wrapper.
#
# Usage: sh tool/op39_constfold_gate.sh [path-to-hexa]   (default ./hexa)
# 0-GPU, $0: one tiny CPU run (<1 s).
# ─────────────────────────────────────────────────────────────────────────────
set -eu

HEXA_BIN="${1:-./hexa}"
ORACLE=stdlib/flame/op39_constfold_byteeq.hexa

# Golden const-fold bit patterns (signed-64 IEEE-754 LE; see header + verdict).
# (a) negation / additive-identity — byte-exact vs python ground truth.
GOLD_NEG1=-4625109815114573186
GOLD_NEG2=-4624575379359918999
GOLD_NEG3=-4614291739287821993
GOLD_NEG4=-4614148802754819015
GOLD_NEG5=-4615913072587595475
GOLD_NEG6=-4623799060313310324
GOLD_SUB0=4609080297566953815
GOLD_ADD0a=4609080297566953815
GOLD_ADD0b=4609080297566953815
# (b) computed folds — fixed-compiler output. OP-40 closed MUL1's former +1 ULP
# residual (was 4589888465602041183): that 1 ULP was NOT host-rt_mul rounding but
# the host's hand-rolled %.17e serialize (not correctly-rounded). The fold now
# serializes a bit-exact hex-float, so MUL1 == python's correctly-rounded IEEE
# product (…182). On CI's FROZEN pre-OP-37/40 seed `./hexa` this reads as advisory
# DRIFT (seed still emits …183); it auto-goes-GREEN once the source fix is promoted
# into the seed — the same promote coupling OP-39/OP-39b documented (gate is
# continue-on-error precisely for this window). MUL2/ADD1/DIV1 were already exact.
GOLD_MUL1=4589888465602041182
GOLD_MUL2=4604576697939583319
GOLD_ADD1=4599075939470750516
GOLD_DIV1=4599676419421066581
# (c) HEX-FLOAT serialize path (OP-40, #3084). These products are the ones whose
# correctly-rounded IEEE value the OLD hand-rolled %.17e fold serialize MIS-rounded
# by 1 ULP (≈13% of computed folds drifted; rt_format_float_sci / hxlcl_vsnprintf
# are not correctly-rounded). The fixed compiler emits each as a bit-exact hex-float
# (`0x1.<mant>p<exp>`) that clang re-parses with ZERO loss, so the golden is python
# struct.pack('<d', a*b) — the correctly-rounded value. A regression to %g/%.17e
# serialize drifts these away from the golden (verified: ~/.hx/bin/build/hexat
# emitted the lossy hexa_float(0.0834799) for MUL_HF1 vs the fixed 0x1.55ef06babe355p-4).
GOLD_MUL_HF1=4590679781865677653
GOLD_MUL_HF2=4599111362625910598
GOLD_MUL_HF3=-4633483571252734626
GOLD_MUL_HF4=4599935351876617150
GOLD_MUL_HF5=4602247188257481376

# .c=0 seam: on a seeds-removed checkout the `hexa build` final link consumes the
# prebuilt runtime archive instead of compiling self/runtime.c (absent). No-op
# when the env is already set or the archive is absent (source path).
if [ -z "${HEXA_PREBUILT_RUNTIME:-}" ] && [ -f build/runtime.a ]; then
  HEXA_PREBUILT_RUNTIME="$PWD/build/runtime.a"
  export HEXA_PREBUILT_RUNTIME
fi

[ -x "$HEXA_BIN" ] || { echo "op39_constfold_gate: FAIL — hexa binary not executable: $HEXA_BIN" >&2; exit 1; }
[ -f "$ORACLE" ]   || { echo "op39_constfold_gate: FAIL — oracle missing: $ORACLE" >&2; exit 1; }

echo "op39_constfold_gate: running $ORACLE ..."
OUT="$("$HEXA_BIN" run "$ORACLE" 2>&1)" || {
  echo "$OUT"
  echo "op39_constfold_gate: FAIL — oracle did not run: $ORACLE" >&2
  exit 1
}
echo "$OUT"

# Extract each labeled bits line (exact-prefix match; one value each).
get() { printf '%s\n' "$OUT" | sed -n "s/^ *$1 [^=]*= //p" | head -1; }
NEG1="$(get NEG1)";  NEG2="$(get NEG2)";  NEG3="$(get NEG3)"
NEG4="$(get NEG4)";  NEG5="$(get NEG5)";  NEG6="$(get NEG6)"
SUB0="$(get SUB0)";  ADD0a="$(get ADD0a)"; ADD0b="$(get ADD0b)"
MUL1="$(get MUL1)";  MUL2="$(get MUL2)";  ADD1="$(get ADD1)";  DIV1="$(get DIV1)"
HF1="$(get MUL_HF1)"; HF2="$(get MUL_HF2)"; HF3="$(get MUL_HF3)"
HF4="$(get MUL_HF4)"; HF5="$(get MUL_HF5)"

FAIL=0
check() { # name actual golden
  if [ "$2" = "$3" ]; then
    echo "op39_constfold_gate: OK   $1 = $2"
  else
    echo "op39_constfold_gate: DRIFT $1 = '${2:-<missing>}' (golden $3)" >&2
    FAIL=1
  fi
}

check "NEG1 (0.0 - 0.254829592)"        "$NEG1"  "$GOLD_NEG1"
check "NEG2 (0.0 - 0.284496736)"        "$NEG2"  "$GOLD_NEG2"
check "NEG3 (0.0 - 1.421413741)"        "$NEG3"  "$GOLD_NEG3"
check "NEG4 (0.0 - 1.453152027)"        "$NEG4"  "$GOLD_NEG4"
check "NEG5 (0.0 - 1.061405429)"        "$NEG5"  "$GOLD_NEG5"
check "NEG6 (0.0 - 0.3275911)"          "$NEG6"  "$GOLD_NEG6"
check "SUB0 (1.421413741 - 0.0)"        "$SUB0"  "$GOLD_SUB0"
check "ADD0a (0.0 + 1.421413741)"       "$ADD0a" "$GOLD_ADD0a"
check "ADD0b (1.421413741 + 0.0)"       "$ADD0b" "$GOLD_ADD0b"
check "MUL1 (0.254829592 * 0.284496736)" "$MUL1" "$GOLD_MUL1"
check "MUL2 (1.421413741 * 0.5)"        "$MUL2"  "$GOLD_MUL2"
check "ADD1 (0.1 + 0.2)"                "$ADD1"  "$GOLD_ADD1"
check "DIV1 (1.0 / 3.0)"                "$DIV1"  "$GOLD_DIV1"
# (c) hex-float serialize path (OP-40) — correctly-rounded products the old %.17e
# fold mis-served; the gate locks the exact IEEE value the hex-float emit produces.
check "MUL_HF1 (0.254829592 * 0.3275911)"    "$HF1" "$GOLD_MUL_HF1"
check "MUL_HF2 (0.284496736 * 1.061405429)"  "$HF2" "$GOLD_MUL_HF2"
check "MUL_HF3 (0.254829592 * -0.284496736)" "$HF3" "$GOLD_MUL_HF3"
check "MUL_HF4 (1.061405429 * 0.3275911)"    "$HF4" "$GOLD_MUL_HF4"
check "MUL_HF5 (1.453152027 * 0.3275911)"    "$HF5" "$GOLD_MUL_HF5"

if [ "$FAIL" -ne 0 ]; then
  echo "op39_constfold_gate: FAIL — float const-fold byte-eq REGRESSION detected." >&2
  echo "  A compile-time const-fold drifted from its recorded golden bit pattern." >&2
  echo "  This is the OP-37/OP-37b silent float-codegen bug re-surfacing — see" >&2
  echo "  .verdicts/hexa-0pod/F-OP37-FLOAT-CONSTFOLD-VERIFY.txt + F-OP37B-*.txt +" >&2
  echo "  F-OP39-CONSTFOLD-CI-GATE.txt. Likely a re-broken serialize (%g) or a" >&2
  echo "  const-folder operand parse re-routed through the naive hxlcl_atof." >&2
  exit 1
fi
echo "op39_constfold_gate: PASS — all 18 float const-folds match the recorded goldens."
