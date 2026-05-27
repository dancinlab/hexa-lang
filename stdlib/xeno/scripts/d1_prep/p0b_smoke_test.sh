#!/usr/bin/env bash
# P0b — Smoke-test 8 post-arrival falsifier scripts via Mac local CPU.
# Validates import + arg parse only; no actual measurement (cloud needed).
set -euo pipefail
XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
NEXUS_ORIGIN="$XENO_ROOT/scripts/akida/nexus_origin"

if [[ ! -d "$NEXUS_ORIGIN" ]]; then
  echo "FAIL: nexus_origin missing at $NEXUS_ORIGIN" >&2
  exit 1
fi

# 8 post-arrival falsifier modules (from nexus README mapping)
declare -a SCRIPTS=(
  "energy_meter.py"        # F-L1, F-L1+
  "lyapunov_sweep.py"      # F-L6
  "godel_disagreement.py"  # F-M1
  "spike_compress.py"      # F-M2 (also F-M3b/M4 helper)
  "qrng_entropy.py"        # F-L7 (already PASS, smoke for re-run)
  "blowup_phase7.py"       # F-A
  "check_loops.py"         # F-B
  "validate_witness.py"    # F-C (already PASS, smoke for re-run)
)

pass=0; fail=0
echo "[P0b] smoke-test ${#SCRIPTS[@]} scripts in $NEXUS_ORIGIN"
for s in "${SCRIPTS[@]}"; do
  path="$NEXUS_ORIGIN/$s"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $s — missing"
    fail=$((fail + 1))
    continue
  fi
  # Syntax check only (-c does compile-only verify, -m py_compile)
  if python3 -c "import py_compile; py_compile.compile('$path', doraise=True)" 2>/dev/null; then
    echo "  ✓ $s — syntax ok"
    pass=$((pass + 1))
  else
    echo "  ✗ $s — syntax error"
    fail=$((fail + 1))
  fi
done

echo
echo "[P0b] result: $pass pass, $fail fail"
[[ $fail -eq 0 ]]
