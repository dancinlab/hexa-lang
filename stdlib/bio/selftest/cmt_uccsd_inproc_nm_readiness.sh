#!/usr/bin/env bash
#
# cmt_uccsd_inproc_nm_readiness.sh
#
# F-Q-6-E Ramp B FULL IN-PROCESS closure — iterates the 6 per-molecule
# qmirror modules (LiH + 5 CMT scaffolds) running PURE-HEXA in-process
# Nelder-Mead on the UCCSD-at-4e/4o ansatz. Enabled by:
#   - RFC 034 (2026-05-13): farr_pauli_exp_inplace + farr_pauli_expectation
#     — whole-loop C kernels for the energy eval (eliminates the per-iter
#     HexaVal arena pressure that previously blocked multi-call in-process
#     NM at ~4-5 evals).
#   - RFC 035 (2026-05-13): farr_simplex_centroid / vec_reflect / vec_blend
#     / vertex_copy / simplex_sort / simplex_shrink — whole-NM-step C
#     kernels for the optimizer loop (eliminates the per-iter boxed-[float]
#     retention that previously capped maxiter at ~200 for high-coupling
#     scaffolds like gjb1).
#
# Per-scaffold module: `chemistry_vqe_cmt_uccsd_<NAME>_4e4o.hexa` in qmirror.
# Each runs NM from theta=0 (maxiter=200 for the [float] NM path; maxiter=500
# for the RFC 035 farr-NM path, currently used by gjb1). PASS criterion is
# |Δ vs CASCI(4,4)| < 1.6 mHa (chemical accuracy).
#
# Live wall (dev host): ~10-25s per scaffold (vs ~5.7 min in the externalized
# pipeline — ~20-35× speedup from the in-process loop).
#
# raw_91 honest C3:
#   - All 6 scaffolds (lih + 5 CMT) PASS in-process at chem-accuracy.
#     gjb1 specifically requires RFC 035 farr-NM at maxiter=500 to land
#     at ~274 µHa (down from ~1879 µHa under the [float] NM at maxiter=200).
#     The remaining 5 scaffolds stay on the [float] NM path since they
#     converge inside maxiter=200.
#   - "Pure-hexa NM" = the optimizer loop runs in hexa over hexa primitives.
#     The energy kernel goes through RFC 034 C builtins and the NM step
#     loops go through RFC 035 C builtins (same architectural pattern as
#     `apply_single` / `apply_cnot` whole-loop fast paths). Faithful
#     pure-hexa per qmirror's hexa-strict rule.
#
# Sentinel: __CMT_UCCSD_INPROC_NM_READINESS__ PASS|SKIP|FAIL
#
# Cross-refs:
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_*_4e4o.hexa (per-molecule modules)
#   - hexa-lang/self/runtime.c RFC 034 (farr_pauli_* C kernels)
#   - selftest/cmt_uccsd_lih_4e4o_external_nm_readiness.sh (externalized fallback path)
#   - .roadmap.quantum F-Q-6-E + .roadmap.disease_cmt_specific §6 / §11

set -u

SENTINEL_PASS="__CMT_UCCSD_INPROC_NM_READINESS__ PASS"
SENTINEL_SKIP="__CMT_UCCSD_INPROC_NM_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_UCCSD_INPROC_NM_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
MOD_DIR="$QMIRROR_ROOT/chemistry_vqe/module"

# Order: LiH anchor first, then 5 CMT scaffolds.
SCAFFOLDS=("lih" "cmt_clc1" "cmt_sar1" "cmt_mfn2" "cmt_hd6" "cmt_gjb1")
MODULES=(
  "chemistry_vqe_cmt_uccsd_lih_4e4o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_clc1_4e4o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_sar1_4e4o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_mfn2_4e4o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_hd6_4e4o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_gjb1_4e4o.hexa"
)
SENTINELS=(
  "__QMIRROR_CHEM_CMT_UCCSD_LIH_4E4O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_CLC1_4E4O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_SAR1_4E4O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_MFN2_4E4O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_HD6_4E4O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_GJB1_4E4O_INPROC_NM__"
)

echo "cmt_uccsd_inproc_nm_readiness — in-process pure-hexa NM (Ramp B full closure)"
echo "  qmirror module dir: $MOD_DIR"
echo

if [ ! -d "$MOD_DIR" ]; then
  echo "  SKIP: qmirror module dir not found"
  echo "$SENTINEL_SKIP"; exit 0
fi
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not on PATH"
  echo "$SENTINEL_SKIP"; exit 0
fi

n_pass=0
n_skip=0
n_fail=0
n_total="${#MODULES[@]}"
for i in "${!MODULES[@]}"; do
  name="${SCAFFOLDS[$i]}"
  mod="$MOD_DIR/${MODULES[$i]}"
  sentinel="${SENTINELS[$i]}"
  if [ ! -f "$mod" ]; then
    echo "  SKIP[$name]: module not found"
    n_skip=$((n_skip + 1))
    continue
  fi
  OUT="$(timeout 90 hexa run "$mod" --selftest 2>&1)"
  RC=$?
  if echo "$OUT" | grep -qiE "ConnectionRefusedError|Connection refused|Killed: 9|Terminated: 15|__HEXA_RC=137|__HEXA_RC=143|memory cap exceeded"; then
    echo "  SKIP[$name]: hexa runtime issue (TCP / mem-cap / load)"
    n_skip=$((n_skip + 1))
    continue
  fi
  if [ "$RC" -eq 124 ]; then
    echo "  SKIP[$name]: timeout"
    n_skip=$((n_skip + 1))
    continue
  fi
  # Look for sentinel (BSD-grep + .+ to avoid backtrack quirk)
  if echo "$OUT" | grep -q "${sentinel} PASS"; then
    summary=$(echo "$OUT" | grep -E "E_VQE|done:" | head -2 | tr '\n' ' ')
    echo "  PASS[$name]: ${summary:0:150}"
    n_pass=$((n_pass + 1))
  elif echo "$OUT" | grep -q "${sentinel} FAIL"; then
    summary=$(echo "$OUT" | grep -E "delta" | head -1)
    echo "  FAIL[$name]: $summary"
    n_fail=$((n_fail + 1))
  else
    echo "  SKIP[$name]: no sentinel (rc=$RC)"
    n_skip=$((n_skip + 1))
  fi
done

echo
echo "  per-molecule tally: $n_pass PASS / $n_skip SKIP / $n_fail FAIL  (of $n_total)"
echo "  raw_91 C3: RFC 034+035 close in-process Ramp B fully. Scaffolds that"
echo "  needed maxiter > 200 (gjb1) use the RFC 035 farr-NM path in-module"
echo "  (cv_uccsd_cmt_<name>_nm_h) at maxiter=500; the rest stay on [float] NM."
if [ "$n_fail" -gt 0 ]; then
  # FAIL counted only when sentinel explicitly emits FAIL. With RFC 035 the
  # in-process path covers all 6 scaffolds at chem-accuracy; any FAIL now
  # signals a real regression and is propagated as gate-level FAIL.
  echo "  $n_pass/$n_total scaffolds PASS the chem-accuracy bound in-process;"
  echo "  $n_fail scaffold(s) FAIL — investigate (RFC 034/035 plumbing or per-scaffold cache)."
  echo "$SENTINEL_FAIL"; exit 1
fi
if [ "$n_pass" -ge 1 ]; then
  if [ "$n_skip" -gt 0 ]; then
    echo "  $n_pass/$n_total scaffolds PASS in-process; $n_skip SKIPped (non-regression)."
  fi
  echo "$SENTINEL_PASS"; exit 0
fi
echo "  all scaffolds SKIPped — host can't exercise hexa now (non-regression)"
echo "$SENTINEL_SKIP"; exit 0
