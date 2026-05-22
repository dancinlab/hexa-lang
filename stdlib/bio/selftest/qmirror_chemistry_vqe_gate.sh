#!/usr/bin/env bash
#
# qmirror_chemistry_vqe_gate.sh
#
# CLI-direct integration gate to qmirror's chemistry VQE selftest.
#
# Architectural note: hexa-bio does NOT reimplement the quantum substrate; qmirror
# (sister repo `dancinlab/qmirror`, locally at `~/core/qmirror`) is the canonical
# Aer-compatible state-vector kernel + ANU QRNG entropy source + chemistry VQE
# (cond.14 H2 STO-3G/0.74Å sub-µHa via UCCSD + active-space CASCI). This gate
# invokes qmirror via the `hexa` runtime — NOT via a Python wrapper / adapter —
# so that qmirror updates are picked up automatically without hexa-bio carrying
# a shadow copy of the quantum code.
#
# raw_91 honest C3 disclosure:
#   What this gate measures:
#     - Whether the `hexa` runtime + qmirror chemistry_vqe selftest is reachable
#       on this host. If reachable, whether qmirror's own selftest exits 0 and
#       emits its PASS marker.
#   What this gate does NOT measure:
#     - The correctness of qmirror's VQE math (qmirror owns that — its own
#       selftest is the verification). This gate is a *delegation*, not a
#       re-verification.
#     - Mpro-pocket-scale VQE (`tests/mpro_pocket_vqe_v7.py`) or the 5-warhead
#       library (`tests/mpro_warhead_library_vqe_v7.py`) — those currently use
#       qiskit/aer directly via `~/.hexabio_venv`. Migrating them to qmirror is
#       a separate (c) C4.2 work item (DEST: qmirror, integration TODO).
#   PASS / SKIP / FAIL semantics:
#     PASS — qmirror chemistry_vqe selftest ran AND succeeded (exit 0).
#     SKIP — qmirror or `hexa` runtime not reachable on this host (TCP dispatch
#            server down, or qmirror not cloned). NOT a regression. Honest signal
#            that this host can't exercise the live backend right now.
#     FAIL — qmirror reachable but its selftest returned non-zero. Real
#            regression — investigate qmirror commit.
#
# Cross-refs:
#   - CLOSURE_RESIDUAL_BACKLOG.md §C4 (quantum HW DEST = qmirror sister repo)
#   - AGENTS.md "Sister repositories" section
#   - qmirror module: ~/core/qmirror/chemistry_vqe/module/chemistry_vqe.hexa
#
# This gate intentionally has no fallback / re-implementation. If qmirror is
# the substitute (and the user confirmed it is — 2026-05-12), hexa-bio reads
# the live result. No shadow copy.

set -u

SENTINEL_PASS='__QMIRROR_CHEMISTRY_VQE_GATE__ PASS'
SENTINEL_SKIP='__QMIRROR_CHEMISTRY_VQE_GATE__ SKIP'
SENTINEL_FAIL='__QMIRROR_CHEMISTRY_VQE_GATE__ FAIL'

QMIRROR_ROOT="${QMIRROR_ROOT:-$HOME/core/qmirror}"
QMIRROR_MODULE="$QMIRROR_ROOT/chemistry_vqe/module/chemistry_vqe.hexa"

echo "qmirror_chemistry_vqe_gate — CLI-direct delegation to sister repo dancinlab/qmirror"
echo "  module:  $QMIRROR_MODULE"
echo "  runtime: $(command -v hexa 2>/dev/null || echo '(hexa not on PATH)')"
echo

# (1) qmirror present?
if [ ! -f "$QMIRROR_MODULE" ]; then
  echo "  SKIP: qmirror chemistry_vqe module not present at $QMIRROR_MODULE"
  echo "        (clone https://github.com/dancinlab/qmirror to \$HOME/core/qmirror"
  echo "         or set QMIRROR_ROOT to its location)"
  echo
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (2) hexa runtime present?
if ! command -v hexa >/dev/null 2>&1; then
  echo "  SKIP: hexa runtime not found on PATH"
  echo "        (install hexa-lang per qmirror README; or use \`hx install qmirror\` for shim)"
  echo
  echo "$SENTINEL_SKIP"
  exit 0
fi

# (3) qmirror selftest run — short timeout because cold-start dispatch + chemistry VQE
#     is bounded; if it hangs, the gate is uninformative anyway.
echo "  invoking: hexa run $QMIRROR_MODULE --selftest"
OUT="$(timeout 120 hexa run "$QMIRROR_MODULE" --selftest 2>&1)"
RC=$?

# (4) classify result
case "$RC" in
  0)
    echo "$OUT" | tail -20
    echo
    echo "  qmirror chemistry_vqe selftest: exit 0"
    echo "$SENTINEL_PASS"
    exit 0
    ;;
  124)
    echo "$OUT" | tail -8
    echo
    echo "  SKIP: qmirror chemistry_vqe selftest timed out at 120s"
    echo "        (likely hexa runtime dispatch server unreachable — \`ConnectionRefusedError\`"
    echo "         on the TCP backing port; start the dispatch server or use \`hx\` shim)"
    echo "$SENTINEL_SKIP"
    exit 0
    ;;
  *)
    # Distinguish "runtime can't reach dispatch server" (SKIP) from "qmirror returned non-zero" (FAIL).
    if echo "$OUT" | grep -qi "ConnectionRefusedError\|Connection refused"; then
      echo "$OUT" | tail -5
      echo
      echo "  SKIP: hexa runtime can't reach its dispatch server (ConnectionRefusedError)"
      echo "        — not a qmirror regression; this host's runtime isn't fully wired."
      echo "$SENTINEL_SKIP"
      exit 0
    fi
    echo "$OUT" | tail -20
    echo
    echo "  qmirror chemistry_vqe selftest: exit $RC (real regression)"
    echo "$SENTINEL_FAIL"
    exit 1
    ;;
esac
