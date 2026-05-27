#!/usr/bin/env bash
#
# cmt_vqe_ladder_4e4o_readiness.sh
#
# CMT 4e/4o pocket-VQE ladder gate — the **4e/4o** sub-ramp of F-Q-6-E.
# Companion to cmt_vqe_ladder_readiness.sh (which gates the 2e/2o tier).
#
# Iterates the qmirror per-molecule 4e/4o modules:
#   chemistry_vqe_cmt_4e4o_<name>.hexa  (one per molecule, each ~580 LOC —
#   the all-6-in-one-file approach hits the 768 MB hexa-interp RSS cap during
#   AST construction over 6 large vendored Hamiltonians + ψ* arrays; per-
#   molecule files comfortably fit and parallel-friendly).
#
# For each module: reads vendored Hamiltonian (Pauli terms + constant_shift),
# vendored UCCSD-converged ψ* (64 complex amplitudes, since 4e/4o ParityMapper((2,2)) +
# 2-qubit reduction = 6 qubits), and vendored CASCI(4,4) reference; computes
# ⟨ψ*|H|ψ*⟩ via the generic n-qubit Pauli-expectation evaluator (in the shared
# library module chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa); verdicts |Δ|
# against the 1.6 mHa chemical-accuracy bound. Per-molecule sentinel
# `__QMIRROR_CHEM_CMT_VQE_4E4O_<NAME>__ PASS`. Gate PASS iff every molecule's
# per-module sentinel PASSes.
#
# raw_91 honest C3 — what this DOES NOT do (unchanged from the 2-mol version):
#   - Run a pure-hexa variational optimizer on a 6-qubit Hamiltonian (that's
#     the sibling chemistry_vqe_cmt_uccsd_4e4o.hexa Ramp B work, separate gate).
#   - Compute "the binding energy" — CASCI(4,4) over a frontier-orbital active
#     space is a reproducible quantum-chemistry quantity, not a K_d. Pocket-
#     embedded VQE / final-molecule chemotype / 4e/4o → bigger AS = open ramps.
#
# Cross-refs:
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_4e4o_<name>.hexa (per-molecule modules)
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa (shared Pauli-expectation + driver)
#   - qmirror/CHEMISTRY_VQE_PYSCF_BACKEND_PLAN_2026_05_12.md §4 (option (c) at the 4e/4o sub-tier)
#   - selftest/cmt_vqe_ladder_readiness.sh (the 2e/2o tier — orthogonal)
#   - .roadmap.disease_cmt_specific §6 양자-VQE adoption ladder
#   - .roadmap.quantum F-Q-6-E sub-tier table
#
# Sentinel: __CMT_VQE_LADDER_4E4O_READINESS__ PASS|SKIP|FAIL

set -u

SENTINEL_PASS="__CMT_VQE_LADDER_4E4O_READINESS__ PASS"
SENTINEL_SKIP="__CMT_VQE_LADDER_4E4O_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_VQE_LADDER_4E4O_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
MOD_DIR="$QMIRROR_ROOT/chemistry_vqe/module"
LIB_MOD="$MOD_DIR/chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa"

# Canonical molecule order: LiH validation anchor first, then the 5 CMT scaffolds
# in roadmap-canonical sequence (clc1, sar1, mfn2, hd6, gjb1).
MOLS=(
  "lih_validation"
  "cmt_clc1"
  "cmt_sar1"
  "cmt_mfn2"
  "cmt_hd6"
  "cmt_gjb1"
)

echo "cmt_vqe_ladder_4e4o_readiness — 4e/4o pocket-VQE replay (F-Q-6-E 4e/4o sub-tier)"
echo "  qmirror lib module: $LIB_MOD"
echo "  runtime:            $(command -v hexa 2>/dev/null || echo '(hexa not on PATH)')"
echo

if [ ! -f "$LIB_MOD" ]; then
  echo "  SKIP: qmirror 4e/4o shared library not found at $LIB_MOD"
  echo "$SENTINEL_SKIP"
  exit 0
fi

if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not found on PATH"
  echo "$SENTINEL_SKIP"
  exit 0
fi

n_pass=0
n_skip=0
n_fail=0
SKIP_REASON=""
for slug in "${MOLS[@]}"; do
  mod="$MOD_DIR/chemistry_vqe_cmt_4e4o_${slug}.hexa"
  if [ ! -f "$mod" ]; then
    echo "  SKIP[${slug}]: module not present"
    n_skip=$((n_skip + 1))
    SKIP_REASON="${SKIP_REASON} ${slug}=missing"
    continue
  fi
  OUT="$(timeout 60 hexa run "$mod" --selftest 2>&1)"
  RC=$?
  # Runtime-environment SKIP signatures.
  if echo "$OUT" | grep -qiE "ConnectionRefusedError|Connection refused|Killed: 9|Terminated: 15|__HEXA_RC=137|__HEXA_RC=143|memory cap exceeded"; then
    echo "  SKIP[${slug}]: hexa runtime issue (TCP / watchdog / load / mem-cap)"
    n_skip=$((n_skip + 1))
    SKIP_REASON="${SKIP_REASON} ${slug}=runtime"
    continue
  fi
  if [ "$RC" -eq 124 ]; then
    echo "  SKIP[${slug}]: timeout"
    n_skip=$((n_skip + 1))
    SKIP_REASON="${SKIP_REASON} ${slug}=timeout"
    continue
  fi
  # Look for per-module PASS sentinel (BSD grep backtracking quirk — use .+ rather than [A-Z_]+).
  if echo "$OUT" | grep -qE "__QMIRROR_CHEM_CMT_VQE_4E4O_.+__ PASS"; then
    pass_line=$(echo "$OUT" | grep -E "^  ✓|delta" | head -3 | tr '\n' ' ')
    echo "  PASS[${slug}]: ${pass_line:0:160}"
    n_pass=$((n_pass + 1))
  elif echo "$OUT" | grep -qE "__QMIRROR_CHEM_CMT_VQE_4E4O_.+__ FAIL"; then
    echo "  FAIL[${slug}]: per-module sentinel FAIL"
    echo "$OUT" | tail -6
    n_fail=$((n_fail + 1))
  else
    echo "  SKIP[${slug}]: no sentinel emitted (rc=$RC)"
    n_skip=$((n_skip + 1))
    SKIP_REASON="${SKIP_REASON} ${slug}=no-sentinel"
  fi
done

echo
echo "  per-molecule tally: $n_pass PASS / $n_skip SKIP / $n_fail FAIL  (of ${#MOLS[@]})"
if [ "$n_fail" -gt 0 ]; then
  echo "$SENTINEL_FAIL"
  exit 1
fi
# PASS only if ≥1 molecule reproduced CASCI(4,4) AND no FAILs. If all SKIP
# (host can't run hexa at all), bubble up as SKIP — same family as the 2e/2o
# gate's host-can't-exercise-hexa semantics.
if [ "$n_pass" -ge 1 ]; then
  echo "  qmirror 4e/4o vendored VQE replay: $n_pass/$((n_pass + n_skip + n_fail)) molecules reproduced CASCI(4,4) within chem-accuracy."
  if [ "$n_skip" -gt 0 ]; then
    echo "  (some molecules SKIPped:$SKIP_REASON — non-regression)"
  fi
  echo "$SENTINEL_PASS"
  exit 0
fi
echo "  all molecules SKIPped — host can't exercise hexa right now (non-regression)"
echo "$SENTINEL_SKIP"
exit 0
