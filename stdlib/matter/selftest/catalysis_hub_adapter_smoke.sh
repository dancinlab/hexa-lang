#!/usr/bin/env bash
# selftest/catalysis_hub_adapter_smoke.sh
#
# Phase J.3 (2026-05-13): dedicated top-level selftest gate for the
# Catalysis-Hub (NTNU + Stanford SUNCAT) adapter.
#
# Why a dedicated gate (separate from absorption_bridge_smoke.sh)?
#   The aggregator at selftest/absorption_bridge_smoke.sh sweeps every
#   _absorption_bridge/selftest/*.py wrapper as a single gate. This
#   dedicated gate runs the Catalysis-Hub adapter DIRECTLY so that a
#   Catalysis-Hub-only regression is identifiable in selftest output
#   without rerunning the full bridge aggregator. Mirrors the discipline
#   of the COD / OQMD / AFLOW / NOMAD / NIMS-MatNavi adapter gates.
#
# Behaviour:
#   - Invokes: python3 _absorption_bridge/catalysis_hub/catalysis_hub_search_smoke.py --selftest
#   - PASS  : exit 0 AND stdout contains "__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ PASS"
#   - FAIL  : exit != 0 OR sentinel absent
#
# Honest C3: this is an OFFLINE selftest. The adapter's --selftest path is
# fixture-replay only (cache/sample_record.json); no live GraphQL hits to
# api.catalysis-hub.org occur in CI.
#
# Sentinel emitted:
#   __HEXA_MATTER_CATALYSIS_HUB_ADAPTER__ PASS / FAIL

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
ADAPTER="$REPO_ROOT/_absorption_bridge/catalysis_hub/catalysis_hub_search_smoke.py"
SENTINEL="__HEXA_MATTER_CATALYSIS_HUB_ADAPTER__"
ADAPTER_SENTINEL="__HEXA_MATTER_CATALYSIS_HUB_SEARCH_SMOKE__ PASS"

echo "hexa-matter/selftest/catalysis_hub_adapter_smoke — Catalysis-Hub (NTNU/SUNCAT, offline)"
echo "  adapter: $ADAPTER"

if [[ ! -f "$ADAPTER" ]]; then
  echo "  [FAIL] adapter not found"
  echo "$SENTINEL FAIL (adapter missing)"
  exit 1
fi

out="$(python3 "$ADAPTER" --selftest 2>&1)"
rc=$?

echo "$out" | sed 's/^/    /'

if [[ "$rc" -ne 0 ]]; then
  echo "$SENTINEL FAIL (adapter exit $rc)"
  exit 1
fi

if ! echo "$out" | grep -q "$ADAPTER_SENTINEL"; then
  echo "$SENTINEL FAIL (adapter sentinel '$ADAPTER_SENTINEL' missing)"
  exit 1
fi

echo "$SENTINEL PASS"
exit 0
