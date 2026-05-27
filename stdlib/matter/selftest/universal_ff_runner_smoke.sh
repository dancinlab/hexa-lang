#!/usr/bin/env bash
# selftest/universal_ff_runner_smoke.sh
#
# Phase K.1 (2026-05-14): top-level selftest gate (#38) for the
# universal-FF runner infrastructure under
# `_python_bridge/universal_ff_runner.py`.
#
# Why a dedicated gate?
#   Phase K.1 lands the runner *infrastructure* — a unified entry point
#   for MACE / CHGNet / ALIGNN / SchNet / M3GNet runs against the 17
#   SIM-NNP-PROXY candidates. The runner MUST SKIP cleanly when each of
#   the 5 optional deps is missing — silent FAIL or fake "we ran MACE"
#   output would violate raw#10 C3 + NO MOCKED FUNCTIONALITY discipline.
#   This gate validates the 5 SKIP sentinels are reachable in mock mode.
#
# Behaviour:
#   - Invokes: python3 selftest/universal_ff_runner_smoke.py --selftest
#     (which in turn invokes _python_bridge/universal_ff_runner.py --selftest)
#   - PASS  : exit 0 AND stdout contains "__HEXA_MATTER_UFF_RUNNER_SMOKE__ PASS"
#   - FAIL  : exit != 0 OR sentinel absent
#
# Honest C3 boundary:
#   - selftest path is MOCK-ONLY — runner force-SKIPs every optional dep.
#   - NO live MACE / CHGNet / ALIGNN / SchNet / M3GNet inference in CI.
#   - SIM-NNP status tag distinct from SIM-NNP-PROXY (NOVEL.md §2);
#     this gate does NOT promote any candidate from SIM-NNP-PROXY to
#     SIM-NNP — that's a separate Phase K.2 action.
#
# Sentinel emitted:
#   __UNIVERSAL_FF_RUNNER__ PASS / FAIL

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
SMOKE="$HERE/universal_ff_runner_smoke.py"
SENTINEL="__UNIVERSAL_FF_RUNNER__"
INNER_SENTINEL="__HEXA_MATTER_UFF_RUNNER_SMOKE__ PASS"

echo "hexa-matter/selftest/universal_ff_runner_smoke — Phase K.1 runner (mock mode)"
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

echo "$SENTINEL PASS (5/5 models SKIP cleanly when deps missing)"
exit 0
