#!/usr/bin/env bash
# selftest/oqmd_adapter_smoke.sh
#
# Phase G+2 (2026-05-13): dedicated top-level selftest gate for the
# Open Quantum Materials Database (OQMD) adapter.
#
# Why a dedicated gate (separate from absorption_bridge_smoke.sh)?
#   The aggregator at selftest/absorption_bridge_smoke.sh sweeps every
#   _absorption_bridge/selftest/*.py wrapper as a single gate. This
#   dedicated gate runs the OQMD adapter DIRECTLY so that an OQMD-only
#   regression is identifiable in selftest output without rerunning the
#   full bridge aggregator. Mirrors the discipline of the COD adapter gate.
#
# Behaviour:
#   - Invokes: python3 _absorption_bridge/oqmd/oqmd_search_smoke.py --selftest
#   - PASS  : exit 0 AND stdout contains "__HEXA_MATTER_OQMD_SEARCH_SMOKE__ PASS"
#   - FAIL  : exit != 0 OR sentinel absent
#
# Honest C3: this is an OFFLINE selftest. The adapter's --selftest path is
# fixture-replay only (cache/sample_record.json); no live REST hits to
# oqmd.org occur in CI.
#
# Sentinel emitted:
#   __HEXA_MATTER_OQMD_ADAPTER_SMOKE__ PASS / FAIL

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
ADAPTER="$REPO_ROOT/_absorption_bridge/oqmd/oqmd_search_smoke.py"
SENTINEL="__HEXA_MATTER_OQMD_ADAPTER_SMOKE__"
ADAPTER_SENTINEL="__HEXA_MATTER_OQMD_SEARCH_SMOKE__ PASS"

echo "hexa-matter/selftest/oqmd_adapter_smoke — Open Quantum Materials Database (offline)"
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
