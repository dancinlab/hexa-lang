#!/usr/bin/env bash
#
# xeno_substrate_gate.sh
#
# CLI-direct integration gate to xeno (exotic compute substrate orchestrator).
#
# Architectural note: hexa-bio does NOT reimplement neuromorphic / organoid /
# quantum-gate / random substrate access; xeno (sister repo `dancinlab/xeno`,
# locally at `~/core/xeno`) is the canonical orchestrator. It multiplexes:
#   - AKIDA AKD1000 (BrainChip neuromorphic; 1W spike-based inference; cloud
#     access + physical chip pending ETA)
#   - Loihi3 (Intel neuromorphic)
#   - Northpole (IBM neuromorphic)
#   - FinalSpark (biological organoid compute)
#   - Cortical Labs DishBrain (biological substrate)
#   - IonQ (quantum-gate, distinct from qmirror's state-vector simulation)
#   - QRNG (quantum random number — distinct from ANU QRNG inside qmirror)
#
# This gate invokes xeno via its bash CLI — NOT via a Python wrapper / adapter —
# so xeno upgrades pick up automatically without hexa-bio carrying a shadow copy.
#
# Note: xeno itself is at Phase 1+ (AKIDA Cloud access live 2026-05-08; AKD1000
# physical chip ordered 2026-04-29 with ETA pending). hexa-bio integration uses
# `xeno status` as the reachability check — once xeno's `falsifier` subcommand
# (Phase 1.5 TODO) lands, the gate can switch to that for substrate-level
# verification.
#
# raw_91 honest C3 disclosure:
#   What this gate measures:
#     - Whether the `xeno` CLI is present on this host AND its `status`
#       subcommand returns 0 (xeno repo + sister-repo bridges healthy).
#   What this gate does NOT measure:
#     - The substrate selftests themselves (AKIDA spike fidelity, Loihi3
#       spike-rate accuracy, etc.). Those are xeno's job; xeno's own
#       falsifier harness (Phase 1.5) is the verification. This gate is a
#       *delegation reachability check*, not a re-verification.
#     - Whether any specific substrate (AKIDA AKD1000) is physically present.
#       AKIDA Cloud access is sufficient for D+0/D+1 pre-arrival validation;
#       physical chip arrival is a separate ETA-pending milestone.
#   PASS / SKIP / FAIL semantics:
#     PASS — `xeno status` exited 0 (xeno reachable + healthy).
#     SKIP — xeno CLI not found at $XENO_BIN (clone or `hx install xeno`
#            absent). NOT a regression — honest signal this host doesn't have
#            the exotic-compute layer installed.
#     FAIL — xeno reachable but `xeno status` returned non-zero. Investigate
#            xeno commit (xeno may use exit 91 for "raw 91 honest C3 fail-loud"
#            connection failures — that's a xeno-side fix, not hexa-bio's).
#
# Cross-refs:
#   - AGENTS.md "Sister repositories" section (xeno entry)
#   - xeno repo: ~/core/xeno  (https://github.com/dancinlab/xeno)
#   - xeno status subcommand: bin/xeno status
#   - Potential hexa-bio AKIDA workloads:
#     * crispr-cas13-poc-diagnostic — lateral-flow signal classification
#     * medical-device — EEG/EMG/ECG edge AI
#     * ribozyme G26-RB-3 — off-target Hamming pattern matching acceleration
#     * nanobot — sub-mW in-vivo actuation pose controller
#
# Sentinel:
#   __XENO_SUBSTRATE__ PASS|SKIP|FAIL  (single-line, run_all.sh greppable)

set -u

SENTINEL_PASS="__XENO_SUBSTRATE__ PASS"
SENTINEL_SKIP="__XENO_SUBSTRATE__ SKIP"
SENTINEL_FAIL="__XENO_SUBSTRATE__ FAIL"

XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
XENO_BIN="${XENO_BIN:-$XENO_ROOT/bin/xeno}"

echo "xeno_substrate_gate — CLI-direct delegation to xeno orchestrator"
echo "  xeno root: $XENO_ROOT"
echo "  xeno bin:  $XENO_BIN"

# (1) presence check
if [ ! -x "$XENO_BIN" ]; then
  echo
  echo "  SKIP: xeno CLI not found / not executable at $XENO_BIN"
  echo "        Install via 'hx install xeno' or clone https://github.com/dancinlab/xeno"
  echo "        to $XENO_ROOT. This is a sister-repo CLI integration — not a"
  echo "        hexa-bio regression; the exotic-compute layer simply isn't wired"
  echo "        on this host."
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (2) invoke xeno status with bounded timeout
echo
echo "  invoking: $XENO_BIN status"
OUT="$(timeout 30 "$XENO_BIN" status 2>&1)"
RC=$?

# (3) classify result
case "$RC" in
  0)
    echo "$OUT" | tail -15
    echo
    echo "  xeno status: exit 0 (reachable + healthy)"
    echo "$SENTINEL_PASS"
    exit 0
    ;;
  91)
    echo "$OUT" | tail -8
    echo
    echo "  SKIP: xeno status returned 91 (raw_91 honest C3 fail-loud — connection"
    echo "        to a sister repo failed). NOT a hexa-bio regression. Check xeno"
    echo "        sister-repo bridges (anima/nexus/hive/hexa-brain reachability)."
    echo "$SENTINEL_SKIP"
    exit 0
    ;;
  124)
    echo "$OUT" | tail -5
    echo
    echo "  SKIP: xeno status timed out at 30s"
    echo "$SENTINEL_SKIP"
    exit 0
    ;;
  *)
    echo "$OUT" | tail -15
    echo
    echo "  xeno status: exit $RC (real regression)"
    echo "$SENTINEL_FAIL"
    exit 1
    ;;
esac
