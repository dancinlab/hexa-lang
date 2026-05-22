#!/usr/bin/env bash
# selftest/uff_predictions_smoke.sh
#
# Phase J.2 (2026-05-13): top-level selftest gate for the universal-FF
# proxy predictions ledger under `_absorption_bridge/universal_ff/predictions/`.
#
# Why a dedicated gate?
#   Phase J.2 promotes 7 Tier-1 NOVEL.md candidates from `DESIGN` to a new
#   `SIM-NNP-PROXY` status. Each promoted candidate has a vendored JSON
#   prediction-snapshot under `_absorption_bridge/universal_ff/predictions/`.
#   Per raw#10 C3 every snapshot MUST carry `is_measurement: false` AND
#   `is_external_verification: false` AND `n6_lattice_fit_applied: false`.
#   A regression here would silently degrade the honesty discipline, so
#   this gate validates each snapshot's invariants explicitly.
#
# Behaviour:
#   - Invokes: python3 _absorption_bridge/universal_ff/predictions_smoke.py --selftest
#   - PASS  : exit 0 AND stdout contains "__HEXA_MATTER_UFF_PREDICTIONS__ PASS"
#   - FAIL  : exit != 0 OR sentinel absent
#
# Honest C3: this is an OFFLINE selftest. The smoke walks bundled JSON
# fixtures under `_absorption_bridge/universal_ff/predictions/*.json` —
# no live API hits to MaterialsProject / Matlantis / HuggingFace.
#
# Defensive numbering note: at the worktree base where this gate was
# authored, `selftest/run_all.sh` had 30 gates and Phase J.1 (gates #31-33)
# had not yet merged. This gate's run_all.sh slot is therefore "next available".
# Integrator will reconcile if Phase J.1 has landed.
#
# Sentinel emitted:
#   __HEXA_MATTER_UFF_PREDICTIONS_SMOKE__ PASS / FAIL

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
SMOKE="$REPO_ROOT/_absorption_bridge/universal_ff/predictions_smoke.py"
SENTINEL="__HEXA_MATTER_UFF_PREDICTIONS_SMOKE__"
INNER_SENTINEL="__HEXA_MATTER_UFF_PREDICTIONS__ PASS"

echo "hexa-matter/selftest/uff_predictions_smoke — universal-FF proxy predictions (offline)"
echo "  smoke: $SMOKE"

if [[ ! -f "$SMOKE" ]]; then
  echo "  [FAIL] smoke script not found"
  echo "$SENTINEL FAIL (smoke missing)"
  exit 1
fi

out="$(python3 "$SMOKE" --selftest 2>&1)"
rc=$?

echo "$out" | sed 's/^/    /'

if [[ "$rc" -ne 0 ]]; then
  echo "$SENTINEL FAIL (smoke exit $rc)"
  exit 1
fi

if ! echo "$out" | grep -q "$INNER_SENTINEL"; then
  echo "$SENTINEL FAIL (inner sentinel '$INNER_SENTINEL' missing)"
  exit 1
fi

echo "$SENTINEL PASS"
exit 0
