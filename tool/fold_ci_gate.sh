#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# tool/fold_ci_gate.sh — OP-34: machine-independence FOLD regression gate.
#
# Runs the two SELF-CONTAINED cross-platform determinism oracles
#   stdlib/flame/op19_crossplatform_selfcontained.hexa   (CE-bwd dt_exp fold)
#   stdlib/flame/op19b_crossplatform_erf.hexa            (GELU dt_erf fwd/bwd folds)
# via `hexa run` and asserts the DETERMINISTIC fold lines equal the RECORDED
# golden values — proven byte-identical across 4 environments (arm64-macos
# local+ghost · x86_64-linux glibc aiden · arm64-linux glibc pi5 · musl;
# F-OP19 #3002 · F-OP19B #3008 · F-OP19C · F-OP19D):
#
#   CEBWD-TAYLOR-bits  (dt_exp)      = 7679248634312321699
#   GELUFWD-DET-bits   (dt_erf fwd)  = 4548590605583584556
#   GELUBWD-DET-bits   (dt_erf bwd)  = 4249661408190172843
#
# Any drift = a REAL machine-independence regression (compiler codegen changed
# FP semantics, a deterministic primitive was edited, or someone re-routed a
# deterministic site through libm). The platform-dependent *-LIBM-bits lines
# are intentionally NOT asserted (they legitimately differ per libm).
#
# LOW BLAST RADIUS (the OP-5b/OP-19f gate discipline):
#   * Runs ONLY the two self-contained oracles (no `use`, no flame stdlib
#     import) — grandfathered/unrelated code can never fail this gate.
#   * Asserts ONLY the three deterministic fold lines above.
#   * The script is the SSOT (also runnable locally: `sh tool/fold_ci_gate.sh
#     [hexa-bin]`); the CI step is a thin wrapper around it.
#
# Usage: sh tool/fold_ci_gate.sh [path-to-hexa]   (default ./hexa)
# 0-GPU, $0: tiny CPU runs (<1 s each).
# ─────────────────────────────────────────────────────────────────────────────
set -eu

HEXA_BIN="${1:-./hexa}"

# Golden folds (recorded, 4-environment byte-identical — see header).
GOLD_CEBWD=7679248634312321699
GOLD_GELUFWD=4548590605583584556
GOLD_GELUBWD=4249661408190172843

ORACLE_19=stdlib/flame/op19_crossplatform_selfcontained.hexa
ORACLE_19B=stdlib/flame/op19b_crossplatform_erf.hexa

# .c=0 seam: on a seeds-removed checkout (the faithful-nobaseline jobs) the
# `hexa build` final link must consume the prebuilt runtime archive instead of
# compiling self/runtime.c (absent). Stage 0b leaves it at build/runtime.a.
# No-op when the env is already set or the archive is absent (source path).
if [ -z "${HEXA_PREBUILT_RUNTIME:-}" ] && [ -f build/runtime.a ]; then
  HEXA_PREBUILT_RUNTIME="$PWD/build/runtime.a"
  export HEXA_PREBUILT_RUNTIME
fi

[ -x "$HEXA_BIN" ] || { echo "fold_ci_gate: FAIL — hexa binary not executable: $HEXA_BIN" >&2; exit 1; }
[ -f "$ORACLE_19" ]  || { echo "fold_ci_gate: FAIL — oracle missing: $ORACLE_19" >&2; exit 1; }
[ -f "$ORACLE_19B" ] || { echo "fold_ci_gate: FAIL — oracle missing: $ORACLE_19B" >&2; exit 1; }

echo "fold_ci_gate: running $ORACLE_19 ..."
OUT19="$("$HEXA_BIN" run "$ORACLE_19" 2>&1)" || {
  echo "$OUT19"
  echo "fold_ci_gate: FAIL — oracle did not run: $ORACLE_19" >&2
  exit 1
}
echo "$OUT19"

echo "fold_ci_gate: running $ORACLE_19B ..."
OUT19B="$("$HEXA_BIN" run "$ORACLE_19B" 2>&1)" || {
  echo "$OUT19B"
  echo "fold_ci_gate: FAIL — oracle did not run: $ORACLE_19B" >&2
  exit 1
}
echo "$OUT19B"

# Extract the deterministic fold lines (exact-line match; one value each).
CEBWD="$(printf '%s\n' "$OUT19"  | sed -n 's/^ *CEBWD-TAYLOR-bits = //p'  | head -1)"
GELUFWD="$(printf '%s\n' "$OUT19B" | sed -n 's/^ *GELUFWD-DET-bits = //p' | head -1)"
GELUBWD="$(printf '%s\n' "$OUT19B" | sed -n 's/^ *GELUBWD-DET-bits = //p' | head -1)"

FAIL=0
check() { # name actual golden
  if [ "$2" = "$3" ]; then
    echo "fold_ci_gate: OK   $1 = $2"
  else
    echo "fold_ci_gate: DRIFT $1 = '${2:-<missing>}' (golden $3)" >&2
    FAIL=1
  fi
}

check "CEBWD-TAYLOR-bits (dt_exp)"    "$CEBWD"   "$GOLD_CEBWD"
check "GELUFWD-DET-bits  (dt_erf fwd)" "$GELUFWD" "$GOLD_GELUFWD"
check "GELUBWD-DET-bits  (dt_erf bwd)" "$GELUBWD" "$GOLD_GELUBWD"

if [ "$FAIL" -ne 0 ]; then
  echo "fold_ci_gate: FAIL — machine-independence fold REGRESSION detected." >&2
  echo "  A deterministic fold drifted from its 4-environment recorded golden value." >&2
  echo "  See .verdicts/hexa-0pod/F-OP19*-*.txt + docs/flame-determinism-contract.md." >&2
  exit 1
fi
echo "fold_ci_gate: PASS — all 3 deterministic folds match the recorded goldens."
