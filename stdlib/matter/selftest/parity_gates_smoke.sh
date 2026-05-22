#!/usr/bin/env bash
# selftest/parity_gates_smoke.sh — Phase H aggregator (gate #28),
# extended in Phase I.1 + I.2 to sweep 29 gates total
# (10 Phase H + 10 Phase I.1 + 9 Phase I.2).
#
# Discovers every tests/*_parity.py file, invokes each with --selftest,
# counts PASS / FAIL, and emits a top-level
# __HEXA_MATTER_PARITY_GATES__ PASS (N/N gates, 0 skipped) sentinel.
#
# Mirror of selftest/pyproject_smoke.sh / research_bridge_smoke.sh /
# absorption_bridge_smoke.sh shape — pure bash, no Python orchestration.
#
# Constraints (per PHASE_H_PLAN.md §H.3):
#   - SKIP not allowed: parity gates are stdlib-only; no optional deps.
#   - Exit 0 iff every gate exits 0 with its __<GROUP>_<GATE>__ PASS line.
#   - Vendored snapshots (tests/snapshots/*.json) are the source of truth;
#     no live API calls in any gate (raw#10 C3 / NO LIVE API rule).
#
# Phase I.1 (2026-05-13) added 10 Phase B target gates:
#   cer_b1 quartz n_d · cer_b7 Mohs ladder · pol_b2 PET hydrolysis Ea ·
#   fib_b1 cellulose Segal · met_b1 IN718 creep · met_b2 Ti-6Al-4V transus ·
#   met_b3 AISI 1080 TTT · gem_b2 ruby R-line · prc_b1 Hales packing ·
#   fas_b1 reactive dye yield. Backlog §B drained 19 → 9.
#
# Phase I.2 (2026-05-13) added 9 Phase F target gates (vendor-anchored,
# offline-replay):
#   cer_b6 UHPC compressive (Ductal+Cor-Tuf) · cer_b8 Si thermal donor
#   (Kaiser-Frisch + SEMI MF1188) · cer_b9 Si [O_i] (ASTM F121/F1188) ·
#   pol_b3 microplastic K_d (NOAA + Mato + Rochman) · pol_b5 UHMWPE
#   (DSM Dyneema SK99) · pol_b6 CNT yarn (Tsinghua/Bai 2018; UNPROVEN at
#   commodity scale, preserved verbatim) · prc_b2 recycling Gibbs floor
#   (ISO 14040 + Gibbs) · prc_b3 sol-gel TEOS (Hench-West + Brinker-Scherer) ·
#   fas_b2 K/S Kubelka-Munk (AATCC TM6 + Kubelka-Munk 1931).
#   Backlog §B fully drained 9 → 0; Category (a)+(b) closure = 100%.
#
# Sentinel emitted:
#   __HEXA_MATTER_PARITY_GATES__ PASS  (N/N gates, 0 skipped)
#   __HEXA_MATTER_PARITY_GATES__ FAIL  (F of N gates failed)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${HEXA_MATTER_ROOT:-$(cd "$HERE/.." && pwd)}"
export HEXA_MATTER_ROOT="$REPO_ROOT"
GATE_DIR="$REPO_ROOT/tests"

echo "hexa-matter/selftest/parity_gates_smoke — tests/*_parity.py aggregator"
echo "  gate dir: $GATE_DIR"
echo ""

if [[ ! -d "$GATE_DIR" ]]; then
  echo "  [FAIL] tests/ directory does not exist"
  echo "__HEXA_MATTER_PARITY_GATES__ FAIL  (tests/ missing)"
  exit 1
fi

pass=0
fail=0
total=0

for f in "$GATE_DIR"/*_parity.py; do
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
  if echo "$out" | grep -qE '^__[A-Z0-9_]+__ PASS$'; then
    sentinel="$(echo "$out" | grep -oE '^__[A-Z0-9_]+__ PASS$' | head -1)"
    echo "  [PASS] $name  ($sentinel)"
    pass=$((pass + 1))
    continue
  fi
  echo "  [FAIL] $name (exit 0 but no __<GROUP>_<GATE>__ PASS sentinel)"
  echo "$out" | sed 's/^/         /'
  fail=$((fail + 1))
done

echo ""
echo "  summary: $pass PASS / $fail FAIL of $total gates"

if [[ "$total" -eq 0 ]]; then
  echo "  [FAIL] no tests/*_parity.py files found"
  echo "__HEXA_MATTER_PARITY_GATES__ FAIL  (no gates discovered)"
  exit 1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "__HEXA_MATTER_PARITY_GATES__ PASS  ($pass/$total gates, 0 skipped)"
  exit 0
fi
echo "__HEXA_MATTER_PARITY_GATES__ FAIL  ($fail of $total gates failed)"
exit 1
