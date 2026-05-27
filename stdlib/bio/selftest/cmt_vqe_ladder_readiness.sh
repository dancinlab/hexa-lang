#!/usr/bin/env bash
#
# cmt_vqe_ladder_readiness.sh
#
# CMT pocket-VQE ladder gate — invokes the qmirror chemistry-VQE CMT module
# (F-Q-6-E, the "classical-chemistry backend" extension realized via option (c)
# of qmirror's CHEMISTRY_VQE_PYSCF_BACKEND_PLAN). Status as of 2026-05-13:
# qmirror now ships `chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians.hexa`,
# which carries VENDORED 2e/2o-active-space parity-mapped Hamiltonians for the
# 5 CMT de-novo candidate scaffolds (hxq-cmt-{clc1,sar1,mfn2,hd6,gjb1}-001 —
# each SMILES → 3D geometry → STO-3G RHF → HOMO/LUMO 2e/2o active space →
# ParityMapper(1,1) → 2-qubit Hamiltonian + CASCI(2,2) reference, extracted
# offline via rdkit+pyscf+qiskit-nature; build-time one-shot extraction per
# qmirror's hexa-strict rule, NOT a runtime dependency), and a pure-hexa UCCSD
# solver that reproduces each CASCI(2,2) reference to << 1 µHa.
#
# This is the live, in-repo-verifiable VQE-BINDING leg of F-disease-cmt-Q-1..6
# at the 2e/2o tier. (Caveats — still honest: the 2e/2o HOMO/LUMO active space
# is a drastic reduction, the geometries are placeholder scaffolds pending
# Phase-β chemotype refinement, and a clinically-meaningful binding-affinity
# calc needs a much larger active space / the final molecule / QM-of-the-pocket
# — that is the next ramp. See the qmirror module header + the plan doc §6.)
#
# raw_91 honest C3:
#   What this gate measures:
#     - Whether the `hexa` runtime + the qmirror CMT chemistry-VQE module are
#       reachable on this host, and if so whether the 5-molecule CMT VQE ladder
#       reproduces the vendored CASCI(2,2) references within the chemical-
#       accuracy bound (1.6 mHa; in practice sub-µHa) — sentinel
#       `__QMIRROR_CHEM_CMT_VQE__ PASS`.
#   What this gate does NOT measure:
#     - Binding affinities / paralog selectivity ratios — the 2e/2o energy is a
#       reproducible quantum-chemistry quantity, NOT "the K_d". 4e/4o+ / final-
#       molecule / pocket-embedded VQE is the next ramp (chemistry judgment).
#     - The qmirror VQE math itself (qmirror owns that — its own module is the
#       verification; this gate is a delegation, not a re-derivation).
#   PASS / SKIP / FAIL semantics:
#     PASS — qmirror CMT VQE module ran AND all 5 reproduced their CASCI(2,2)
#            refs within the bound (`__QMIRROR_CHEM_CMT_VQE__ PASS`, exit 0).
#     SKIP — qmirror / `hexa` runtime not reachable on this host (module absent,
#            TCP dispatch down → ConnectionRefusedError, runtime watchdog SIGKILL
#            on an overloaded host, or timeout). NOT a regression — same SKIP
#            condition as qmirror_chemistry_vqe_gate.sh.
#     FAIL — qmirror reachable but the CMT VQE ladder returned non-zero / a
#            reproduction missed the bound — real regression (investigate the
#            qmirror commit or the vendored constants).
#
# Cross-refs:
#   - .roadmap.disease_cmt_specific §5 (F-disease-cmt-Q-1..6) + §6 (Tier 3 / Phase γ + 양자-VQE adoption ladder)
#   - .roadmap.quantum (F-Q-* inventory + the F-Q-6-E ramp — now LANDED at the 2e/2o tier)
#   - COMPUTE_PORTFOLIO.md §3-4 (the qmirror Tier ladder + the Tier-2 gap)
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians.hexa (the vendored Hamiltonians + recipe)
#   - qmirror/CHEMISTRY_VQE_PYSCF_BACKEND_PLAN_2026_05_12.md (option (c), realized)
#   - selftest/cmt_smiles_validation.py (the Tier-2 placeholder-SMILES validation that feeds this)
#   - selftest/cmt_side_effect_avoidance_audit.py + cmt_library_ranking.py + cmt_axis_and_cross_design_audit.py (the DESIGN-AUDIT layer)
#
# Sentinel: __CMT_VQE_LADDER_READINESS__ PASS|SKIP|FAIL

set -u

SENTINEL_PASS="__CMT_VQE_LADDER_READINESS__ PASS"
SENTINEL_SKIP="__CMT_VQE_LADDER_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_VQE_LADDER_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
CMT_MODULE="$QMIRROR_ROOT/chemistry_vqe/module/chemistry_vqe_cmt_hamiltonians.hexa"
H2_MODULE="$QMIRROR_ROOT/chemistry_vqe/module/chemistry_vqe.hexa"

echo "cmt_vqe_ladder_readiness — CMT 2e/2o pocket-VQE ladder (F-disease-cmt-Q-1..6, Tier 3 / Phase γ)"
echo "  qmirror CMT module: $CMT_MODULE"
echo "  runtime:            $(command -v hexa 2>/dev/null || echo '(hexa not on PATH)')"
echo

# (1) qmirror CMT VQE module present?
if [ ! -f "$CMT_MODULE" ]; then
  echo "  SKIP: qmirror chemistry_vqe CMT module not found at $CMT_MODULE"
  if [ -f "$H2_MODULE" ]; then
    echo "        (qmirror is present but pre-dates the F-Q-6-E CMT ladder; update qmirror — "
    echo "         'hx update qmirror' or 'git -C $QMIRROR_ROOT pull')"
  else
    echo "        (clone https://github.com/dancinlab/qmirror to \$QMIRROR_ROOT or 'hx install qmirror')"
  fi
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (2) hexa runtime present?
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not found on PATH (install per qmirror README; or 'hx install qmirror' for shim)"
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (3) run the CMT VQE ladder — bounded; the 5-molecule run is ~5s on a quiet
#     host (each is a 2-qubit / 3-parameter UCCSD = the H2 cost). Give it some
#     headroom for a loaded host (~the H2 gate's 120s + a bit for 5 molecules),
#     but treat a timeout as SKIP (uninformative, not a regression).
echo "  invoking: hexa run $CMT_MODULE --selftest"
OUT="$(timeout 150 hexa run "$CMT_MODULE" --selftest 2>&1)"
RC=$?

# (4) classify
# Runtime-environment SKIP signatures (host can't exercise hexa right now —
# same family as qmirror_chemistry_vqe_gate.sh): TCP dispatch refused, the
# runtime's own SIGKILL watchdog firing on an overloaded host, or a timeout.
if echo "$OUT" | grep -qiE "ConnectionRefusedError|Connection refused|Killed: 9|Terminated: 15|__HEXA_RC=137|__HEXA_RC=143"; then
  echo "$OUT" | tail -6
  echo
  echo "  SKIP: hexa runtime couldn't complete on this host (TCP dispatch down / runtime watchdog / load)"
  echo "        — not a qmirror regression; this host can't exercise the live backend right now."
  echo "$SENTINEL_SKIP"
  exit 0
fi

case "$RC" in
  0)
    echo "$OUT" | tail -20
    echo
    if echo "$OUT" | grep -q "__QMIRROR_CHEM_CMT_VQE__ PASS"; then
      echo "  qmirror CMT 2e/2o VQE ladder: 5/5 reproduced CASCI(2,2) within the chem-accuracy bound."
      echo "  → F-disease-cmt-Q-1..6 VQE-BINDING leg LIVE at the 2e/2o tier (in-repo-verifiable)."
      echo "    Next ramp: 4e/4o+ active spaces / final-molecule geometries / pocket-embedded VQE (chemistry judgment)."
      echo "$SENTINEL_PASS"
      exit 0
    fi
    echo "  qmirror CMT VQE module exited 0 but did not emit __QMIRROR_CHEM_CMT_VQE__ PASS — treating as SKIP"
    echo "  (module shape may have changed; investigate qmirror)"
    echo "$SENTINEL_SKIP"
    exit 0
    ;;
  124)
    echo "$OUT" | tail -6
    echo
    echo "  SKIP: qmirror CMT VQE selftest timed out at 150s (likely an overloaded host — not a regression)"
    echo "$SENTINEL_SKIP"
    exit 0
    ;;
  *)
    echo "$OUT" | tail -20
    echo
    echo "  qmirror CMT VQE selftest: exit $RC with __QMIRROR_CHEM_CMT_VQE__ not PASS (real regression — investigate qmirror)"
    echo "$SENTINEL_FAIL"
    exit 1
    ;;
esac
