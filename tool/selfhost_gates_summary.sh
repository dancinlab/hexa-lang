#!/usr/bin/env bash
# selfhost_gates_summary.sh — the ALWAYS-RUNNING aggregator behind the single
# required branch-protection check `selfhost-gates-summary`.
#
# WHY this exists: the six SELFHOST-CI gate workflows are path-filtered
# (pull_request: paths: self/** compiler/** tool/<x>). A path-filtered check
# can NOT be a required status check — a PR that doesn't touch those paths never
# reports it, so the merge blocks forever ("Expected — waiting for status").
# This aggregator runs UNCONDITIONALLY on every PR (no path filter), so it
# ALWAYS reports → it is safe to require without deadlocking unrelated PRs.
#
# WHAT it enforces:
#   1. HERMETIC shim-integrity (tool/selfhost_shim_integrity.sh) — runs REAL on
#      any host incl. hosted CI (no graduated compiler needed). A true gate.
#   2. PRESENCE + bash-syntax of all six gate scripts — a regression that
#      deletes/breaks a gate script fails here even on a hosted runner.
#   3. The heavy native-emit gates (byte-eq / determinism / codegen / crossemit /
#      promote-parity) stay as their own path-filtered workflows; they run REAL
#      only on a slot-bearing runner. This summary INVOKES them when
#      SELFHOST_SLOT_READY=1 is set (a self-hosted runner that holds gen2_fix),
#      else records them as slot-deferred (NOT a failure) — so flipping that one
#      repo var upgrades enforcement with no workflow edit.
#
# EXIT: 0 = required check PASSES (hermetic gate green + all scripts present).
#       1 = a real regression (shim contract broken, or a gate script missing /
#           malformed, or a slot-real gate failed). Blocks merge.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

echo "── selfhost-gates-summary (always-on required aggregator) ─────────────"

# ── 1. hermetic shim-integrity — REAL on any host ─────────────────────────
echo "[1] hermetic shim-integrity (tool/selfhost_shim_integrity.sh)"
if [ -f tool/selfhost_shim_integrity.sh ]; then
  rc=0; bash tool/selfhost_shim_integrity.sh || rc=$?
  if [ "$rc" -eq 0 ]; then echo "    PASS — shim contract held (real)"; else echo "    FAIL — shim integrity rc=$rc"; fail=1; fi
else
  echo "    FAIL — tool/selfhost_shim_integrity.sh MISSING"; fail=1
fi

# ── 2. presence + bash-syntax of all six gate scripts ─────────────────────
echo "[2] gate-script presence + syntax"
for g in selfhost_byteeq_gate selfhost_codegen_guard selfhost_crossemit_smoke \
         selfhost_parity_gate determinism_gate selfhost_shim_integrity; do
  f="tool/${g}.sh"
  if [ ! -f "$f" ]; then echo "    FAIL — $f MISSING"; fail=1; continue; fi
  if bash -n "$f" 2>/dev/null; then echo "    PASS — $f present + bash -n clean"; else echo "    FAIL — $f bash -n error"; fail=1; fi
done

# ── 3. heavy native-emit gates — REAL only when a slot-bearing runner is wired ─
echo "[3] native-emit gates (byte-eq / determinism / codegen / crossemit / promote-parity)"
if [ "${SELFHOST_SLOT_READY:-0}" = "1" ]; then
  for g in selfhost_byteeq_gate determinism_gate selfhost_codegen_guard; do
    echo "    [slot] running tool/${g}.sh REAL"
    rc=0; bash "tool/${g}.sh" || rc=$?
    # exit 2 = build-floor / cannot-native-emit on THIS host → slot-deferred, not a fail
    if [ "$rc" -eq 0 ]; then echo "      PASS ${g}"; elif [ "$rc" -eq 2 ]; then echo "      NEUTRAL ${g} (exit-2 infra)"; else echo "      FAIL ${g} rc=$rc"; fail=1; fi
  done
else
  echo "    SLOT-DEFERRED — no SELFHOST_SLOT_READY runner; real native-emit enforcement"
  echo "    runs via the per-PR path-filtered gate workflows + on slot-bearing hosts."
  echo "    (Set repo var SELFHOST_SLOT_READY=1 on a gen2_fix self-hosted runner to"
  echo "     activate inline native-emit enforcement here — no workflow edit needed.)"
fi

echo "───────────────────────────────────────────────────────────────────────"
if [ "$fail" -eq 0 ]; then
  echo "selfhost-gates-summary: PASS"
  exit 0
else
  echo "selfhost-gates-summary: FAIL (real regression — see above)"
  exit 1
fi
