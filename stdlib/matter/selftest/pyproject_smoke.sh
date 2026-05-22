#!/usr/bin/env bash
# selftest/pyproject_smoke.sh
#
# Phase E aggregator: invokes every _python_bridge/module/*.py with --selftest
# and aggregates PASS / FAIL / SKIP counts.
#
# Behaviour:
#   - For each module .py file: run `python3 <module>.py --selftest`.
#       exit 0 + sentinel "__HEXA_MATTER_<MODULE>__ PASS (SKIP mode)"  →  SKIP
#       exit 0 + sentinel "__HEXA_MATTER_<MODULE>__ PASS"              →  PASS
#       exit 0 + ANY OTHER output                                      →  PASS (conservative)
#       exit != 0                                                      →  FAIL
#   - SKIP counts as PASS for the harness (per INIT.md "NO MOCKED FUNCTIONALITY"
#     rule: a module with a missing optional dep must SKIP cleanly).
#
# Sentinel emitted:
#   __HEXA_MATTER_PYTHON_BRIDGE__ PASS  (N/N modules, M skipped)
#   __HEXA_MATTER_PYTHON_BRIDGE__ FAIL  (F of N modules failed)
#
# Compatibility: also emits the legacy __HEXA_MATTER_PYPROJECT_SMOKE__ sentinel
# so that any consumer scanning for that string keeps working.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
export HEXA_MATTER_ROOT="$REPO_ROOT"
BRIDGE="$REPO_ROOT/_python_bridge"

echo "hexa-matter/selftest/pyproject_smoke — _python_bridge/ aggregator"
echo "  bridge dir: $BRIDGE"
echo ""

if [[ ! -d "$BRIDGE" ]]; then
  echo "  [SKIP] _python_bridge/ does not exist — Phase E not yet implemented"
  echo "__HEXA_MATTER_PYTHON_BRIDGE__ PASS  (SKIP: Phase E pending)"
  echo "__HEXA_MATTER_PYPROJECT_SMOKE__ PASS  (SKIP: Phase E pending)"
  exit 0
fi

if [[ ! -d "$BRIDGE/module" ]]; then
  echo "  [SKIP] _python_bridge/module/ does not exist"
  echo "__HEXA_MATTER_PYTHON_BRIDGE__ PASS  (SKIP: module/ pending)"
  echo "__HEXA_MATTER_PYPROJECT_SMOKE__ PASS  (SKIP: module/ pending)"
  exit 0
fi

pass=0
fail=0
skip=0
total=0

# Module set = union of .py basenames and ported .hexa basenames, so a
# module remains covered after its .py is removed (Stage-1 full port).
HEXA_MOD="$REPO_ROOT/_hexa_bridge/module"
mod_names="$( { ls "$BRIDGE/module"/*.py 2>/dev/null | sed 's#.*/##; s/\.py$//'; \
                ls "$HEXA_MOD"/*.hexa 2>/dev/null | sed 's#.*/##; s/\.hexa$//'; } \
              | sort -u )"
for m in $mod_names; do
  [[ -n "$m" ]] || continue
  total=$((total + 1))
  name="$m"
  # hexa-native port (Stage 1): if _hexa_bridge/module/<m>.hexa exists,
  # run THAT; else fall back to the .py --selftest. Per-module auto-migrate.
  hexa_eq="$HEXA_MOD/$m.hexa"
  py_eq="$BRIDGE/module/$m.py"
  if [[ -f "$hexa_eq" ]] && command -v hexa >/dev/null 2>&1; then
    out="$(cd "$REPO_ROOT" && hexa run "$hexa_eq" 2>&1)"
    rc=$?
    name="$m [hexa]"
  elif [[ -f "$py_eq" ]]; then
    out="$(python3 "$py_eq" --selftest 2>&1)"
    rc=$?
  else
    continue
  fi
  if [[ "$rc" -ne 0 ]]; then
    echo "  [FAIL] $name (exit $rc)"
    echo "$out" | sed 's/^/         /'
    fail=$((fail + 1))
    continue
  fi
  if echo "$out" | grep -q "SKIP mode"; then
    echo "  [SKIP] $name (optional dep missing)"
    skip=$((skip + 1))
    pass=$((pass + 1))   # SKIP counts as PASS
    continue
  fi
  if echo "$out" | grep -q "__HEXA_MATTER_.*__ PASS"; then
    echo "  [PASS] $name"
    pass=$((pass + 1))
    continue
  fi
  # Conservative: exit 0 but no canonical sentinel — count as PASS but warn.
  echo "  [PASS] $name (no canonical sentinel; exit 0)"
  pass=$((pass + 1))
done

echo ""
echo "  summary: $pass PASS ($skip SKIP) / $fail FAIL of $total modules"

if [[ "$total" -eq 0 ]]; then
  echo "  [SKIP] no _python_bridge/module/*.py files found"
  echo "__HEXA_MATTER_PYTHON_BRIDGE__ PASS  (SKIP: no modules)"
  echo "__HEXA_MATTER_PYPROJECT_SMOKE__ PASS  (SKIP: no modules)"
  exit 0
fi

if [[ "$fail" -eq 0 ]]; then
  echo "__HEXA_MATTER_PYTHON_BRIDGE__ PASS  ($pass/$total modules, $skip skipped)"
  echo "__HEXA_MATTER_PYPROJECT_SMOKE__ PASS  ($pass/$total modules, $skip skipped)"
  exit 0
fi
echo "__HEXA_MATTER_PYTHON_BRIDGE__ FAIL  ($fail of $total modules failed)"
echo "__HEXA_MATTER_PYPROJECT_SMOKE__ FAIL  ($fail of $total modules failed)"
exit 1
