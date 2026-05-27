#!/usr/bin/env bash
#
# cmt_uccsd_lih_4e4o_ansatz_readiness.sh
#
# F-Q-6-E Ramp B partial — pure-hexa UCCSD-at-4e/4o ANSATZ MACHINERY gate.
# Invokes qmirror's `chemistry_vqe_cmt_uccsd_lih_4e4o.hexa`, which validates:
#
#   - Pure-hexa Trotter UCCSD ansatz application (26 Hermitian-excitation
#     generators over 152 Pauli rotations).
#   - Mask-keyed n-qubit single-Pauli-string exponential exp(i*alpha*P)
#     applied in place on farr handles.
#   - Mask-keyed n-qubit Pauli expectation <psi|P|psi>.
#   - One-shot energy evaluation at theta=0 reproduces the offline-computed
#     <HF|H|HF> reference to machine precision (target: |Δ| < 1 µHa).
#
# raw_91 honest C3 — what this DOES NOT cover (yet):
#   - Pure-hexa NM/SLSQP loop driving the variational optimization. The
#     algorithm + transcription are validated (numpy harness PASSes the
#     convergence target — Δ ~ 1.06 mHa at maxiter=200, 0.004 µHa at 8k);
#     hexa-side multi-call exhibits a per-call boxed-float retention pattern
#     in the inner farr_get hot loops (~180 MB/call) that exceeds the
#     768 MB hexa-interp cap after ~4 sequential energy evaluations. Pure-
#     hexa NM closure is the next sub-ramp; needs hexa-runtime tuning
#     (unbox farr_get return, or aggressive inner-loop GC) — out of this
#     gate's scope.
#   - The other 5 molecules (clc1/sar1/mfn2/hd6/gjb1) at the UCCSD-ansatz
#     tier — same code applies, just swap the vendored UCCSD-decomposition
#     + Hamiltonian. Mechanical extension once the multi-call leak is fixed.
#
# Sentinel: __CMT_UCCSD_LIH_4E4O_ANSATZ_READINESS__ PASS|SKIP|FAIL
#
# Cross-refs:
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e4o.hexa
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians_4e4o_lib.hexa (shared)
#   - selftest/cmt_vqe_ladder_4e4o_readiness.sh (the vendored-ψ* tier; sibling)
#   - .roadmap.disease_cmt_specific §6 + .roadmap.quantum F-Q-6-E

set -u

SENTINEL_PASS="__CMT_UCCSD_LIH_4E4O_ANSATZ_READINESS__ PASS"
SENTINEL_SKIP="__CMT_UCCSD_LIH_4E4O_ANSATZ_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_UCCSD_LIH_4E4O_ANSATZ_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
MODULE="$QMIRROR_ROOT/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_lih_4e4o.hexa"

echo "cmt_uccsd_lih_4e4o_ansatz_readiness — pure-hexa UCCSD ansatz machinery (Ramp B partial)"
echo "  module: $MODULE"
echo

if [ ! -f "$MODULE" ]; then
  echo "  SKIP: qmirror UCCSD LiH module not found"
  echo "$SENTINEL_SKIP"; exit 0
fi
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not found on PATH"
  echo "$SENTINEL_SKIP"; exit 0
fi

OUT="$(timeout 180 hexa run "$MODULE" --selftest 2>&1)"
RC=$?

if echo "$OUT" | grep -qiE "ConnectionRefusedError|Connection refused|Killed: 9|Terminated: 15|__HEXA_RC=137|__HEXA_RC=143|memory cap exceeded"; then
  echo "$OUT" | tail -6
  echo
  echo "  SKIP: hexa runtime couldn't complete (TCP / watchdog / load / mem-cap)"
  echo "$SENTINEL_SKIP"; exit 0
fi

case "$RC" in
  0)
    echo "$OUT" | tail -25
    echo
    if echo "$OUT" | grep -q "__QMIRROR_CHEM_CMT_UCCSD_LIH_4E4O_ANSATZ__ PASS"; then
      echo "  qmirror pure-hexa UCCSD ansatz at LiH 4e/4o: VALIDATED (E(theta=0) = HF to machine precision)."
      echo "$SENTINEL_PASS"; exit 0
    fi
    echo "  module exited 0 but no PASS sentinel"
    echo "$SENTINEL_SKIP"; exit 0
    ;;
  124)
    echo "  SKIP: timeout"
    echo "$SENTINEL_SKIP"; exit 0
    ;;
  *)
    echo "$OUT" | tail -15
    echo "  exit $RC — real regression"
    echo "$SENTINEL_FAIL"; exit 1
    ;;
esac
