#!/usr/bin/env bash
#
# akida_workload_readiness.sh
#
# AKIDA workload readiness probe — checks whether the 4 identified hexa-bio
# AKIDA (BrainChip AKD1000 neuromorphic) workloads can (yet) run, via the
# xeno CLI (the exotic-compute orchestrator that multiplexes AKIDA).
#
# CRITICAL fallback principle (per user 2026-05-12): **AKIDA is optional**.
# A user without xeno, without AKIDA hardware, without AKIDA Cloud access —
# must NEVER see a FAIL. The pattern is always: `use xeno CLI || none(fallback)`.
#   - xeno CLI not installed         → SKIP (use the CPU fallback path)
#   - xeno installed, AKIDA not wired → SKIP (xeno Phase 1.5 `falsifier` pending)
#   - xeno reachable, returns 91      → SKIP (xeno raw_91 honest C3 fail-loud — a
#                                       sister-bridge issue, not a hexa-bio regression)
#   - xeno reachable, AKIDA workloads runnable → PASS (would only happen post
#                                       AKD1000 arrival + xeno Phase 1.5)
#   - xeno reachable, xeno status returns non-zero (≠91) → FAIL (real xeno regression)
#
# The 4 AKIDA workloads (all currently SKIP — accelerators, not dependencies):
#   1. ribozyme G26-RB-3 — off-target Hamming scan (GENCODE v47, ~106k transcripts ×
#      28nt). Fallback: RIsearch2 brute-force on commodity CPU (already the live path).
#   2. medical-device — EEG seizure / EMG / ECG arrhythmia / glucose pattern recognition
#      (1W continuous wear, AKIDA flagship use case). Fallback: standard ML inference.
#   3. nanobot — in-vivo actuation 4-state pose inference (sub-mW implant, AKIDA niche).
#      Fallback: standard pose estimation.
#   4. crispr-cas13-poc-diagnostic — lateral-flow Au-NP capture-line signal classification
#      (on-device edge AI, AKIDA designed niche). Fallback: standard image classification.
#
# raw_91 honest C3:
#   What this gate measures:
#     - Whether the `xeno` CLI is present + `xeno roadmap akida` is queryable,
#       and whether xeno's AKIDA roadmap reports a state where the AKIDA
#       workloads could be wired (AKD1000 arrived + Phase 1.5 `falsifier`).
#   What this gate explicitly does NOT measure:
#     - Whether any AKIDA workload actually produces correct results (no AKIDA
#       hardware on this dev host; AKIDA Cloud session is a separate ephemeral
#       cycle). This is a *readiness* probe, not a *correctness* probe.
#   PASS / SKIP / FAIL semantics: see CRITICAL fallback principle above.
#     The expected normal state is SKIP — AKIDA workloads are not yet wired
#     anywhere, and that's fine; the hexa-bio core needs none of them.
#
# Cross-refs:
#   - COMPUTE_PORTFOLIO.md §2 (xeno → AKIDA row) + §5 (routing logic)
#   - XENO.md §4 (potential hexa-bio workloads)
#   - selftest/compute_substrate_routing.py (edge_ai → xeno_akida routing)
#   - xeno repo: ~/core/xeno  (https://github.com/dancinlab/xeno)
#   - xeno AKIDA roadmap: ~/core/xeno/roadmaps/.roadmap.akida
#
# Sentinel: __AKIDA_WORKLOAD_READINESS__ PASS|SKIP|FAIL

set -u

SENTINEL_PASS="__AKIDA_WORKLOAD_READINESS__ PASS"
SENTINEL_SKIP="__AKIDA_WORKLOAD_READINESS__ SKIP"
SENTINEL_FAIL="__AKIDA_WORKLOAD_READINESS__ FAIL"

XENO_ROOT="${XENO_ROOT:-$HOME/core/xeno}"
XENO_BIN="${XENO_BIN:-$XENO_ROOT/bin/xeno}"
AKIDA_ROADMAP="$XENO_ROOT/roadmaps/.roadmap.akida"

echo "akida_workload_readiness — 4 hexa-bio AKIDA workloads × xeno-CLI readiness probe"
echo "  pattern: use xeno CLI || none(fallback) — AKIDA is an accelerator, never a dependency"
echo "  xeno bin: $XENO_BIN"
echo

# (1) xeno CLI present? (|| none(fallback))
if [ ! -x "$XENO_BIN" ]; then
  echo "  SKIP: xeno CLI not found / not executable at $XENO_BIN"
  echo "        → AKIDA workloads route to their CPU fallbacks:"
  echo "          1. ribozyme G26-RB-3 off-target → RIsearch2 brute-force (already the live path)"
  echo "          2. medical-device pattern recog → standard ML inference"
  echo "          3. nanobot pose inference       → standard pose estimation"
  echo "          4. crispr-cas13 lateral-flow    → standard image classification"
  echo "        This is NOT a regression — the exotic-compute layer simply isn't installed here."
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (2) xeno status reachable? (|| none(fallback))
echo "  invoking: $XENO_BIN status"
SOUT="$(timeout 30 "$XENO_BIN" status 2>&1)"
SRC=$?
case "$SRC" in
  0)  echo "  xeno status: exit 0 (reachable + sister bridges healthy)" ;;
  91) echo "  SKIP: xeno status returned 91 (raw_91 honest C3 fail-loud — a sister-bridge issue, not a hexa-bio regression)"
      echo "        → AKIDA workloads use their CPU fallbacks. NOT a regression."
      echo "$SENTINEL_SKIP"; exit 0 ;;
  124) echo "  SKIP: xeno status timed out at 30s → use CPU fallbacks"
       echo "$SENTINEL_SKIP"; exit 0 ;;
  *)  echo "$SOUT" | tail -10
      echo
      echo "  xeno status: exit $SRC (real xeno regression — investigate xeno commit)"
      echo "$SENTINEL_FAIL"; exit 1 ;;
esac
echo

# (3) AKIDA roadmap present + queryable?
if [ ! -f "$AKIDA_ROADMAP" ]; then
  echo "  SKIP: xeno present but AKIDA roadmap not found at $AKIDA_ROADMAP"
  echo "        → AKIDA workloads use CPU fallbacks. xeno may be an older build without the AKIDA substrate."
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (4) Probe xeno's AKIDA roadmap state. We look for two readiness signals:
#     (a) the AKD1000 chip blocker is resolved (not "blocked")
#     (b) xeno exposes a `falsifier` subcommand (Phase 1.5) — checked via `xeno --help` or `xeno falsifier`
CHIP_BLOCKED=1
if grep -q '"akida.blk.1"' "$AKIDA_ROADMAP" 2>/dev/null; then
  # the chip blocker line exists; check if it still says "blocked"
  if grep -q '"status":"blocked".*akida.blk.1\|"akida.blk.1".*"status":"blocked"\|"akida.blk.1","desc":"칩 도착' "$AKIDA_ROADMAP" 2>/dev/null; then
    CHIP_BLOCKED=1
  else
    # blocker line exists but not marked "blocked" — could be partial-resolved or resolved
    if grep -q '"akida.blk.1".*"new_status":"partial-resolved"\|"prior_status":"blocked.*new_status":"partial-resolved"' "$AKIDA_ROADMAP" 2>/dev/null; then
      CHIP_BLOCKED=2  # partial — AKIDA Cloud access enables pre-arrival validation, but physical chip still pending
    else
      CHIP_BLOCKED=0  # fully resolved (chip arrived)
    fi
  fi
fi

FALSIFIER_READY=0
# Actually invoke `xeno falsifier` — a Phase 1.5 TODO stub will either error,
# print a "TODO"/"not implemented"/"Phase 1.5" message, or exit non-zero.
FOUT="$(timeout 15 "$XENO_BIN" falsifier 2>&1)"
FRC=$?
if [ "$FRC" -eq 0 ] && ! echo "$FOUT" | grep -qi "TODO\|not implemented\|not yet\|Phase 1.5\|unknown topic\|unknown subcommand"; then
  FALSIFIER_READY=1
fi

echo "  AKIDA roadmap probe:"
case "$CHIP_BLOCKED" in
  1) echo "    - AKD1000 physical chip: BLOCKED (ordered 2026-04-29, ETA pending)" ;;
  2) echo "    - AKD1000 physical chip: PARTIAL — AKIDA Cloud access live 2026-05-08 (pre-arrival validation enabled); physical chip ETA still pending" ;;
  0) echo "    - AKD1000 physical chip: RESOLVED (chip arrived)" ;;
esac
if [ "$FALSIFIER_READY" -eq 1 ]; then
  echo "    - xeno \`falsifier\` subcommand: AVAILABLE (Phase 1.5 landed)"
else
  echo "    - xeno \`falsifier\` subcommand: NOT YET (Phase 1.5 TODO — substrate-level verification not exposed)"
fi
echo

# (5) Verdict: PASS only if BOTH chip resolved AND falsifier ready. Otherwise SKIP (with fallback note).
if [ "$CHIP_BLOCKED" -eq 0 ] && [ "$FALSIFIER_READY" -eq 1 ]; then
  echo "  ✅ AKIDA workloads are wireable: AKD1000 present + xeno Phase 1.5 falsifier available."
  echo "     The 4 hexa-bio AKIDA workloads (ribozyme off-target / medical-device pattern recog /"
  echo "     nanobot pose / crispr-cas13 lateral-flow) can now be wired as xeno falsifier calls."
  echo "     (Actual wiring is a follow-up task — this gate just confirms readiness.)"
  echo "$SENTINEL_PASS"
  exit 0
fi

echo "  SKIP: AKIDA workloads not yet wireable on this host."
echo "        Gating: $([ "$CHIP_BLOCKED" -ne 0 ] && echo 'AKD1000 chip arrival pending; ')$([ "$FALSIFIER_READY" -ne 1 ] && echo 'xeno Phase 1.5 falsifier subcommand pending')"
echo "        → All 4 AKIDA workloads route to CPU fallbacks (RIsearch2 brute-force / standard ML"
echo "          inference / standard pose estimation / standard image classification). The AKIDA"
echo "          path is a 1W-edge-AI accelerator, not a dependency — hexa-bio core needs none of it."
echo "$SENTINEL_SKIP"
exit 0
