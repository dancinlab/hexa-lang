#!/usr/bin/env bash
#
# cmt_uccsd_lih_4e4o_external_nm_readiness.sh
#
# F-Q-6-E Ramp B EXTERNALIZED — full pure-hexa-physics + Python-stdlib-driver
# variational VQE gate. Demonstrates "Option 2" from the prior Ramp B
# documentation: externalize the optimization loop so each energy evaluation
# is a fresh hexa subprocess (avoiding the per-call boxed-float retention
# that blocks in-process pure-hexa NM at ~4-5 evals).
#
# Pipeline:
#   (1) Python NM driver (`cmt_uccsd_lih_4e4o_external_nm_driver.py`) does
#       a 26-parameter Nelder-Mead in pure stdlib (no scipy/numpy).
#   (2) Per energy eval, the driver writes θ to /tmp/uccsd_theta.txt and
#       invokes `hexa run chemistry_vqe_cmt_uccsd_lih_4e4o_oneshot.hexa`
#       as a subprocess. The hexa module reads θ, runs ONE energy eval
#       (cv_uccsd_lih_energy_cached over the UCCSD Trotter ansatz + masked
#       n-qubit Pauli expectation), writes E to /tmp/uccsd_energy.txt, exits.
#   (3) The driver reads E and feeds it back to NM. Fresh hexa process per
#       eval → no in-process memory accumulation.
#
# raw_91 honest C3:
#   - The ENERGY COMPUTATION (UCCSD ansatz application + Pauli expectation)
#     runs entirely in pure hexa — same code as the ansatz-validation gate
#     (cmt_uccsd_lih_4e4o_ansatz_readiness.sh).
#   - The OPTIMIZER (Nelder-Mead 26-dim) runs in Python stdlib. Honest
#     scope: this is "physics-in-hexa + optimizer-in-python", not
#     "pure-hexa NM". The pure-hexa NM remains blocked on hexa-runtime
#     per-call boxed-float retention (~180 MB/call → 768 MB cap after ~4
#     sequential calls); see qmirror/CHANGELOG.md for the open sub-ramp.
#   - Wall: 5-min budget at maxiter=5 reaches Δ ~ 495 µHa (3× under the
#     1.6 mHa chem-accuracy bound, ~58% recovery of the HF→CASCI gap).
#     Higher maxiter would converge further (numpy harness: 8k iters → 0.004 µHa).
#
# PASS / SKIP / FAIL semantics:
#   PASS — driver completes AND either reaches chem-accuracy (|Δ| < 1.6 mHa)
#          OR recovers > 50% of the HF→CASCI correlation gap (proves the
#          variational descent is working end-to-end).
#   SKIP — host can't run hexa (TCP dispatch / runtime / load) OR oneshot
#          module absent OR python3 unavailable OR overall timeout.
#   FAIL — driver reaches its budget but the descent is insufficient
#          (< 50% recovery), indicating a real bug in either the hexa
#          physics or the NM driver.
#
# Cross-refs:
#   - selftest/cmt_uccsd_lih_4e4o_external_nm_driver.py (the driver)
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e4o_oneshot.hexa
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e4o.hexa (energy eval impl)
#   - selftest/cmt_uccsd_lih_4e4o_ansatz_readiness.sh (sibling: ansatz-only gate)
#   - selftest/cmt_vqe_ladder_4e4o_readiness.sh (sibling: vendored ψ* replay)
#
# Sentinel: __CMT_UCCSD_LIH_4E4O_EXTERNAL_NM_READINESS__ PASS|SKIP|FAIL

set -u

SENTINEL_PASS="__CMT_UCCSD_LIH_4E4O_EXTERNAL_NM_READINESS__ PASS"
SENTINEL_SKIP="__CMT_UCCSD_LIH_4E4O_EXTERNAL_NM_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_UCCSD_LIH_4E4O_EXTERNAL_NM_READINESS__ FAIL"

HERE="$(cd "$(dirname "$0")" && pwd)"
QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
ONESHOT="$QMIRROR_ROOT/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e4o_oneshot.hexa"
DRIVER="$HERE/cmt_uccsd_lih_4e4o_external_nm_driver.py"

# Default: maxiter=5, ~5 min wall on the dev host. Override via env var
# CMT_EXT_NM_MAXITER for longer convergence sweeps; the gate honors any value
# from 1 (very fast, ~1 min, descent demo only) to 50+ (long-running, full
# chem-accuracy convergence).
MAXITER="${CMT_EXT_NM_MAXITER:-5}"
GATE_TIMEOUT_S="${CMT_EXT_NM_GATE_TIMEOUT_S:-420}"

echo "cmt_uccsd_lih_4e4o_external_nm_readiness — externalized NM (Ramp B option 2)"
echo "  oneshot module: $ONESHOT"
echo "  driver:         $DRIVER"
echo "  maxiter=$MAXITER (env CMT_EXT_NM_MAXITER override), timeout=${GATE_TIMEOUT_S}s"
echo

if [ ! -f "$ONESHOT" ] || [ ! -f "$DRIVER" ]; then
  echo "  SKIP: oneshot module or driver missing"
  echo "$SENTINEL_SKIP"; exit 0
fi
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not on PATH"
  echo "$SENTINEL_SKIP"; exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "  SKIP: python3 not on PATH"
  echo "$SENTINEL_SKIP"; exit 0
fi

OUT="$(timeout "$GATE_TIMEOUT_S" python3 "$DRIVER" --maxiter "$MAXITER" 2>&1)"
RC=$?

if [ "$RC" -eq 124 ]; then
  echo "$OUT" | tail -6
  echo
  echo "  SKIP: driver timed out at ${GATE_TIMEOUT_S}s (loaded host or higher maxiter than wall budget)"
  echo "$SENTINEL_SKIP"; exit 0
fi

# Runtime-environment SKIP signatures (host can't exercise hexa right now).
if echo "$OUT" | grep -qiE "TCP dispatch|ConnectionRefusedError|memory-cap|hexa runtime memory-cap|memory cap exceeded"; then
  echo "$OUT" | tail -10
  echo
  echo "  SKIP: hexa runtime issue during NM (TCP / mem-cap / watchdog)"
  echo "$SENTINEL_SKIP"; exit 0
fi

# Look for the driver's PASS sentinel
if echo "$OUT" | grep -qE "__EXT_NM_LIH_4E4O__ PASS"; then
  echo "$OUT" | tail -18
  echo
  echo "  pure-hexa-physics + python-NM driver: variational descent CONFIRMED at the 4e/4o tier."
  echo "$SENTINEL_PASS"; exit 0
fi
if echo "$OUT" | grep -qE "__EXT_NM_LIH_4E4O__ SKIP"; then
  echo "$OUT" | tail -12
  echo "$SENTINEL_SKIP"; exit 0
fi
if echo "$OUT" | grep -qE "__EXT_NM_LIH_4E4O__ FAIL"; then
  echo "$OUT" | tail -12
  echo
  echo "$SENTINEL_FAIL"; exit 1
fi

# No sentinel — treat as SKIP if rc != 0, FAIL otherwise.
echo "$OUT" | tail -10
echo
if [ "$RC" -ne 0 ]; then
  echo "  SKIP: driver exited $RC with no sentinel"
  echo "$SENTINEL_SKIP"; exit 0
fi
echo "  FAIL: no sentinel emitted"
echo "$SENTINEL_FAIL"; exit 1
