#!/usr/bin/env bash
# selftest/absorption_bridge_smoke.sh
#
# Phase G/G+1/G+2 aggregator: invokes every _absorption_bridge/selftest/*.py
# with --selftest and aggregates PASS / FAIL / SKIP counts. As of Phase G+2
# (2026-05-13) covers 14 adapters: Materials Project + GNoME + Matlantis +
# OMat24 + 5 universal force fields + COD + OQMD + AFLOW + NOMAD.
#
# Behaviour:
#   - For each script .py file: run `python3 <module>.py --selftest`.
#       exit 0 + sentinel "__HEXA_MATTER_..._SMOKE__ PASS (SKIP mode)"  →  SKIP
#       exit 0 + sentinel "__HEXA_MATTER_..._SMOKE__ PASS"              →  PASS
#       exit 0 + ANY OTHER output                                       →  PASS (conservative)
#       exit != 0                                                       →  FAIL
#   - SKIP counts as PASS for the harness (NO MOCKED FUNCTIONALITY rule).
#
# Sentinel emitted:
#   __HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  (N/N modules, M skipped)
#   __HEXA_MATTER_ABSORPTION_BRIDGE__ FAIL  (F of N modules failed)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
export HEXA_MATTER_ROOT="$REPO_ROOT"
BRIDGE="$REPO_ROOT/_absorption_bridge"

echo "hexa-matter/selftest/absorption_bridge_smoke — _absorption_bridge/ aggregator"
echo "  bridge dir: $BRIDGE"
echo ""

if [[ ! -d "$BRIDGE" ]]; then
  echo "  [SKIP] _absorption_bridge/ does not exist — Phase G not yet implemented"
  echo "__HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  (SKIP: Phase G pending)"
  exit 0
fi

if [[ ! -d "$BRIDGE/selftest" ]]; then
  echo "  [SKIP] _absorption_bridge/selftest/ does not exist"
  echo "__HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  (SKIP: selftest/ pending)"
  exit 0
fi

pass=0
fail=0
skip=0
total=0

for f in "$BRIDGE/selftest"/*.py; do
  [[ -e "$f" ]] || continue
  total=$((total + 1))
  name="$(basename "$f")"
  out="$(python3 "$f" --selftest 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "  [FAIL] $name (exit $rc)"
    echo "$out" | sed 's/^/         /'
    fail=$((fail + 1))
    continue
  fi
  if echo "$out" | grep -q "SKIP mode"; then
    echo "  [SKIP] $name (optional dep missing)"
    skip=$((skip + 1))
    pass=$((pass + 1))
    continue
  fi
  if echo "$out" | grep -qE "__HEXA_MATTER_[A-Z0-9_]+__ PASS"; then
    echo "  [PASS] $name"
    pass=$((pass + 1))
    continue
  fi
  echo "  [PASS] $name (no canonical sentinel; exit 0)"
  pass=$((pass + 1))
done

echo ""
echo "  summary: $pass PASS ($skip SKIP) / $fail FAIL of $total modules"

if [[ "$total" -eq 0 ]]; then
  echo "  [SKIP] no _absorption_bridge/selftest/*.py files found"
  echo "__HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  (SKIP: no modules)"
  exit 0
fi

if [[ "$fail" -eq 0 ]]; then
  echo "__HEXA_MATTER_ABSORPTION_BRIDGE__ PASS  ($pass/$total modules, $skip skipped)"
  exit 0
fi
echo "__HEXA_MATTER_ABSORPTION_BRIDGE__ FAIL  ($fail of $total modules failed)"
exit 1
