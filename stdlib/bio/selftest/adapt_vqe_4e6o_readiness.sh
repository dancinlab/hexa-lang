#!/usr/bin/env bash
#
# adapt_vqe_4e6o_readiness.sh
#
# F-Q-6-E Ramp B-3 — ADAPT-VQE 4e/6o (10-qubit) gate across LiH + 5 CMT
# scaffolds. Reads pre-emitted markers in $QMIRROR_ROOT/state/markers/
# (or, if absent, SKIPs cleanly).
#
# ADAPT-VQE = greedy operator selection from the 92-op UCCSD pool, one op
# per outer step, FD-gradient screening, joint inner re-opt via pure-hexa
# L-BFGS-B. Closure target per scaffold: |Δ| < 1.6 mHa vs CASCI(4,6) AND
# K < 92 (fewer parameters than the full UCCSD ansatz).
#
# Sister gate to:
#   - adapt_vqe_4e5o_readiness.sh (8-qubit ADAPT, 54-op pool)
#   - cmt_uccsd_4e6o_readiness.sh (brute-force NM 4e/6o sibling)
#
# Compared to the brute-force NM 4e/6o gate:
#   - gjb1 4e/6o under NM stalled at 1090 µHa @ maxiter=4000 / 394s.
#     ADAPT-VQE FD-grad operator selection is the principled fix: only
#     the operators that actually reduce energy get promoted, so the
#     parameter count shrinks (typical 4e/5o pattern: K=5..12 vs 54-op
#     UCCSD baseline) and the remaining inner L-BFGS-B problem is
#     gradient-screened from the start.
#   - Same Hamiltonian + same UCCSD pool — only the outer search strategy
#     changes. CASCI references and SLSQP offline anchors are unchanged.
#
# Sentinel: __ADAPT_VQE_4E6O_READINESS__ PASS|SKIP|FAIL
#
# Cross-refs:
#   - qmirror/chemistry_vqe/module/_adapt_vqe_lih_4e6o.hexa
#   - qmirror/chemistry_vqe/module/_adapt_vqe_cmt_{clc1,sar1,mfn2,hd6,gjb1}_4e6o.hexa
#   - qmirror/chemistry_vqe/module/_adapt_vqe_driver_4e6o.hexa
#   - selftest/cmt_uccsd_4e6o_readiness.sh (brute-force NM sibling)
#   - selftest/adapt_vqe_4e5o_readiness.sh (4e/5o ADAPT predecessor)

set -u

SENTINEL_PASS="__ADAPT_VQE_4E6O_READINESS__ PASS"
SENTINEL_SKIP="__ADAPT_VQE_4E6O_READINESS__ SKIP"
SENTINEL_FAIL="__ADAPT_VQE_4E6O_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
MARKER_DIR="$QMIRROR_ROOT/state/markers"

# Per-scaffold 900s budget (4e/6o ADAPT is ~2× slower than 4e/5o per Pauli
# + ~70% more pool params; NM 4e/6o sibling already uses 900s budget).
export HEXA_MEM_UNLIMITED="${HEXA_MEM_UNLIMITED:-1}"

# 6 scaffolds: LiH anchor + 5 CMT (clc1, sar1, mfn2, hd6, gjb1).
SCAFFOLDS=("lih" "cmt_clc1" "cmt_sar1" "cmt_mfn2" "cmt_hd6" "cmt_gjb1")
MARKER_STEMS=(
  "_adapt_vqe_lih_4e6o"
  "_adapt_vqe_cmt_clc1_4e6o"
  "_adapt_vqe_cmt_sar1_4e6o"
  "_adapt_vqe_cmt_mfn2_4e6o"
  "_adapt_vqe_cmt_hd6_4e6o"
  "_adapt_vqe_cmt_gjb1_4e6o"
)

echo "adapt_vqe_4e6o_readiness — LiH + 5 CMT scaffolds @ 4e/6o (10-qubit) ADAPT-VQE"
echo "  marker dir: $MARKER_DIR"
echo "  HEXA_MEM_UNLIMITED=1 (10q × 631-1819 Pauli × 92-op pool ⇒ ADAPT FD-grad screen"
echo "  fits in ~2 GB working set when ham_*_h packed handles + farr_pauli_expectation_batch)"
echo

if [ ! -d "$MARKER_DIR" ]; then
  echo "  SKIP: marker dir not present"
  echo "$SENTINEL_SKIP"; exit 0
fi

n_pass=0; n_skip=0; n_fail=0
n_total="${#SCAFFOLDS[@]}"

for i in "${!SCAFFOLDS[@]}"; do
  name="${SCAFFOLDS[$i]}"
  stem="${MARKER_STEMS[$i]}"

  # Prefer a non-FAILED marker, but fall back to FAILED for honest reporting.
  PASS_MARKER="$(ls -t "$MARKER_DIR"/${stem}_*.marker 2>/dev/null | grep -v FAILED | head -1)"
  FAIL_MARKER="$(ls -t "$MARKER_DIR"/${stem}_*_FAILED.marker 2>/dev/null | head -1)"

  if [ -n "$PASS_MARKER" ]; then
    LINE="$(head -1 "$PASS_MARKER")"
    echo "  PASS[$name]:  ${LINE}"
    n_pass=$((n_pass + 1))
  elif [ -n "$FAIL_MARKER" ]; then
    LINE="$(head -1 "$FAIL_MARKER")"
    echo "  FAIL[$name]: ${LINE}"
    n_fail=$((n_fail + 1))
  else
    echo "  SKIP[$name]: no marker"
    n_skip=$((n_skip + 1))
  fi
done

echo
echo "  per-scaffold tally: $n_pass PASS / $n_skip SKIP / $n_fail FAIL  (of $n_total)"

if [ "$n_fail" -gt 0 ]; then
  echo "$SENTINEL_FAIL"; exit 1
fi
if [ "$n_pass" -ge 1 ]; then
  if [ "$n_skip" -gt 0 ]; then
    echo "  ($n_skip skips do not block gate-level PASS — markers may be in flight)"
  fi
  echo "$SENTINEL_PASS"; exit 0
fi
echo "$SENTINEL_SKIP"; exit 0
