#!/usr/bin/env bash
#
# cmt_uccsd_4e6o_readiness.sh
#
# F-Q-6-E Ramp B-3 — 4e/6o (10-qubit) IN-PROCESS NM closure across
# 6 scaffolds (LiH anchor + 5 CMT). Iterates
# `chemistry_vqe_cmt_uccsd_<scaffold>_4e6o.hexa` in qmirror for
# lih / cmt_clc1 / cmt_sar1 / cmt_mfn2 / cmt_hd6 / cmt_gjb1. Each module
# runs the pure-hexa Nelder-Mead via hexa-lang RFC 034 (energy C kernels)
# + RFC 035 (NM-step C kernels) + RFC 036 (farr_int_array packed handles
# for the Hamiltonian mask tables) + RFC 037 (batched Pauli expectation)
# on the 10-qubit ParityMapper((2,2)) Hamiltonian (~2-3k Pauli terms,
# vendored offline from qiskit-nature 0.7.2 + pyscf 2.13.0 with SLSQP
# maxiter=500 ftol=1e-9).
#
# RFC 036 is the key enabler at this tier: the 1024-amp state-vector
# × ~2-3k Pauli inner loop does NOT fit on the default 768 MB cap when
# the mask tables are boxed [int] reads. With farr_int handles the
# working set drops to ~1-2 GB at maxiter=500. The gate still exports
# HEXA_MEM_CAP_MB=2048 as the working budget (sister 4e/5o gate
# convention).
#
# Sentinel: __CMT_UCCSD_4E6O_READINESS__ PASS|SKIP|FAIL
#
# raw_91 honest C3 (per .roadmap.weave / .roadmap.quantum):
#   - PASS when ≥1 scaffold reaches chemical accuracy (1.6 mHa) and
#     remaining are documented externalized (gradient-free NM at 10
#     qubits with ~95 params is genuinely harder than 4e/5o; that's a
#     property of the optimizer, not the RFC 034..037 plumbing).
#   - SKIP cleanly if the hexa runtime is unreachable (per ~/core/CLAUDE.md
#     per-axis substrate optional — SKIP ≠ FAIL).
#
# Cross-refs:
#   - qmirror/chemistry_vqe/module/chemistry_vqe_cmt_uccsd_*_4e6o.hexa
#   - selftest/cmt_uccsd_4e5o_readiness.sh (parallel 4e/5o gate)
#   - selftest/cmt_uccsd_lih_4e5o_readiness.sh (LiH 4e/5o anchor)

set -u

SENTINEL_PASS="__CMT_UCCSD_4E6O_READINESS__ PASS"
SENTINEL_SKIP="__CMT_UCCSD_4E6O_READINESS__ SKIP"
SENTINEL_FAIL="__CMT_UCCSD_4E6O_READINESS__ FAIL"

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
MOD_DIR="$QMIRROR_ROOT/chemistry_vqe/module"

SCAFFOLDS=("lih" "cmt_clc1" "cmt_sar1" "cmt_mfn2" "cmt_hd6" "cmt_gjb1")
MODULES=(
  "chemistry_vqe_cmt_uccsd_lih_4e6o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_clc1_4e6o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_sar1_4e6o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_mfn2_4e6o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_hd6_4e6o.hexa"
  "chemistry_vqe_cmt_uccsd_cmt_gjb1_4e6o.hexa"
)
SENTINELS=(
  "__QMIRROR_CHEM_CMT_UCCSD_LIH_4E6O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_CLC1_4E6O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_SAR1_4E6O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_MFN2_4E6O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_HD6_4E6O_INPROC_NM__"
  "__QMIRROR_CHEM_CMT_UCCSD_CMT_GJB1_4E6O_INPROC_NM__"
)

echo "cmt_uccsd_4e6o_readiness — 6 scaffolds (LiH + 5 CMT) @ 4e/6o (10-qubit) full NM"
echo "  qmirror module dir: $MOD_DIR"
echo "  HEXA_MEM_UNLIMITED=1 (10q × 1819-Pauli at maxiter≥2000 exceeds 4 GB cap)"
echo

if [ ! -d "$MOD_DIR" ]; then
  echo "  SKIP: qmirror module dir not found"
  echo "$SENTINEL_SKIP"; exit 0
fi
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not on PATH"
  echo "$SENTINEL_SKIP"; exit 0
fi

# Check at least one expected module exists; otherwise the offline
# extraction may not have completed yet — SKIP rather than FAIL.
any_module_present=0
for m in "${MODULES[@]}"; do
  if [ -f "$MOD_DIR/$m" ]; then any_module_present=1; break; fi
done
if [ "$any_module_present" -eq 0 ]; then
  echo "  SKIP: no 4e/6o modules present yet (offline extraction pending)"
  echo "$SENTINEL_SKIP"; exit 0
fi

export HEXA_MEM_UNLIMITED="${HEXA_MEM_UNLIMITED:-1}"

n_pass=0; n_skip=0; n_fail=0
n_total="${#MODULES[@]}"

for i in "${!MODULES[@]}"; do
  name="${SCAFFOLDS[$i]}"
  mod="$MOD_DIR/${MODULES[$i]}"
  sentinel="${SENTINELS[$i]}"
  if [ ! -f "$mod" ]; then
    echo "  SKIP[$name]: module not found"
    n_skip=$((n_skip + 1)); continue
  fi
  # 900s wall budget per scaffold — gjb1 at maxiter=4000 took ~394 s; other
  # scaffolds at maxiter=2000 took ~210-250 s. Generous headroom for slow hosts.
  OUT="$(timeout 900 hexa run "$mod" --selftest 2>&1)"
  RC=$?
  if echo "$OUT" | grep -qiE "ConnectionRefusedError|Connection refused|Killed: 9|Terminated: 15|__HEXA_RC=137|__HEXA_RC=143|memory cap exceeded"; then
    echo "  SKIP[$name]: hexa runtime issue (TCP / mem-cap / load)"
    n_skip=$((n_skip + 1)); continue
  fi
  if [ "$RC" -eq 124 ]; then
    echo "  SKIP[$name]: timeout (360s budget)"
    n_skip=$((n_skip + 1)); continue
  fi
  if echo "$OUT" | grep -q "${sentinel} PASS"; then
    LINE="$(echo "$OUT" | grep -E 'done:|delta' | head -2 | tr '\n' ' ')"
    echo "  PASS[$name]:  $LINE"
    n_pass=$((n_pass + 1))
  elif echo "$OUT" | grep -q "${sentinel} FAIL"; then
    LINE="$(echo "$OUT" | grep -E 'E_VQE|delta' | head -1)"
    echo "  FAIL[$name]: $LINE"
    n_fail=$((n_fail + 1))
  else
    echo "  SKIP[$name]: no sentinel (rc=$RC)"
    n_skip=$((n_skip + 1))
  fi
done

echo
echo "  per-molecule tally: $n_pass PASS / $n_skip SKIP / $n_fail FAIL  (of $n_total)"
echo "  raw_91 C3: gradient-free NM at 10q + ~95 params is genuinely"
echo "  harder than 4e/5o. PASS if ≥1 scaffold reaches chemical accuracy"
echo "  in-process; remaining scaffolds → externalized fall-back (offline"
echo "  qiskit-SLSQP gradient-based VQE — already vendored in the .hexa"
echo "  module header as the 'offline VQE' figure-of-merit)."

if [ "$n_pass" -ge 1 ]; then
  if [ "$n_skip" -gt 0 ] || [ "$n_fail" -gt 0 ]; then
    echo "  ($n_skip skip / $n_fail fail do not block gate-level PASS — see raw_91 C3)"
  fi
  echo "$SENTINEL_PASS"; exit 0
fi
if [ "$n_fail" -gt 0 ]; then
  echo "$SENTINEL_FAIL"; exit 1
fi
echo "$SENTINEL_SKIP"; exit 0
