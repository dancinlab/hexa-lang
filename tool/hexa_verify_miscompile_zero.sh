#!/usr/bin/env bash
# tool/hexa_verify_miscompile_zero.sh — MISCOMPILE-ZERO verify-axis driver.
#
# @D h_audit_axis_form — domain audits land on ONE CLI surface as
# `hexa verify --<axis> <domain>`. The hexa-native axis is wired in
# tool/verify_cli.hexa::cmd_miscompile_zero (dispatched by `hexa verify
# --miscompile-zero`). That native path activates once the verify_cli build
# floor is repaired (the JIT/standalone build currently fails to LINK the
# cross-directory `use compiler/atlas/calc_dispatch` + calculator namespace —
# `_calc_eps`/`_sigma_k`/`_static_atlas` undefined; the SAME wall hits every
# existing axis, e.g. `--blue-max`, not just this one).
#
# Until then, this wrapper is the runnable surface the axis delegates to: it is
# byte-for-byte the same engine (tool/miscompile_zero_gate.sh) + the SAME tier
# matrix cmd_miscompile_zero prints, with the gate exit code captured
# SEPARATELY (no pipe-mask) so the tier rides the real rc.
#
# Both the standalone gate AND `hexa verify --miscompile-zero` consume this
# logic — single source of the tier mapping.
#
# Tier mapping (gate-rc-driven):
#   gate rc 0 → 🟢 SUPPORTED-NUMERICAL  (floor held — 0 ENCODE-MISS, 0 udf)
#   gate rc 1 → 🔴 FALSIFIED            (regression — dirty object emitted)
#   gate rc 2 → 🟠 INSUFFICIENT         (SETUP/INFRA — no graduated emitter)
#
# Exit code = gate exit code (faithful passthrough).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "verify --miscompile-zero  (MISCOMPILE-ZERO native-codegen floor audit · @D h_audit_axis_form)"

# Run the gate; capture stdout AND the real exit code separately (no pipe-mask).
gate_out="$(bash "$REPO/tool/miscompile_zero_gate.sh" 2>&1)"
rc=$?
printf '%s\n' "$gate_out"

echo "── tier matrix ───────────────────────────────────────────────"
echo "  axis              : MISCOMPILE-ZERO (native --emit=obj codegen floor)"
echo "  corpus            : self/test/miscompile_zero/c1..c10 (+ class m1..m7)"
echo "  gate              : tool/miscompile_zero_gate.sh"
echo "  gate rc           : $rc"
case "$rc" in
  0) echo "  tier              : 🟢 SUPPORTED-NUMERICAL  (floor held — 0 ENCODE-MISS, 0 udf across corpus)" ;;
  1) echo "  tier              : 🔴 FALSIFIED  (native-codegen regression — object produced but dirty; floor BROKE)" ;;
  *) echo "  tier              : 🟠 INSUFFICIENT  (SETUP/INFRA — env lacks graduated native emitter; floor NOT broken, gate rc=$rc)" ;;
esac
exit "$rc"
