#!/usr/bin/env python3
# analyze.py — `matter + analyze` producer (thin in-silico shim ·
# D17 consumer-pointer · D72 adapter-only · D111 cellrun-compatible ·
# D106 illustrative-physics).
#
# LEGACY CONTEXT: κ-30 / D53 era MatterAnalyzer.swift was a sibling-
# repo dispatcher that spawned `~/core/hexa-matter/verify/run_all.hexa`
# (the 4-subscript closure aggregator: spec_presence · lattice_
# arithmetic · real_limits_anchor · closure_consistency) and emitted a
# MatterRecord with per-subscript PASS/FAIL. D111 Phase C migrated the
# (.analyze, "matter") route off the legacy bridge onto CellrunDispatch.
#
# This shim emits a TEMPLATE matter-analyze envelope (NOT a sibling-
# repo spawn — that integration is a separate cycle, optionally via
# either (a) teaching cellrun.hexa a sibling-repo substrate kind, or
# (b) extending this shim to subprocess the run_all.hexa aggregator
# and parse PASS/FAIL). For now: honest illustrative emit, GATE_OPEN
# / absorbed=false, scope_caveats explicit about the gap.
#
# Honesty (g3 · D106 · project.tape @D d1):
#   - measurement_gate = GATE_OPEN permanently
#   - absorbed = false permanently (illustrative · D106 · RFC 013 §6.12)
#   - producer = "matter_analyze@template" (NOT "hexa_matter@<sha>" —
#     no aggregator was spawned)
#   - scope_caveats cite the κ-30/D53 legacy + the path-forward options
#
# Pattern: mirrors stdlib/firmware/analyze.py.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "matter_analyze_v1"


def _build_analysis_template() -> dict:
    """Materials-analysis envelope template — the per-subscript shape
    a real hexa-matter run_all.hexa spawn would fill (mirrors
    MatterRecord.SubscriptResult in cockpit).
    """
    return {
        "entry_script": "~/core/hexa-matter/verify/run_all.hexa",
        "total_scripts": 0,
        "passed_scripts": 0,
        "per_script": [],   # [{script, passed}]
        "exit_code": None,
        "notes": (
            "Analysis envelope scaffold — actual sibling-repo "
            "aggregator spawn (κ-30/D53 legacy MatterAnalyzer pattern) "
            "is downstream substrate territory · NOT this shim."
        ),
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    analysis = _build_analysis_template()
    measurements: dict = {}

    citations = [
        "domains/matter.md — material-family matrix narrative.",
        "domains/matter/README.md — D17 hexa-matter absorbed.",
        "MatterRecord.swift κ-30/D53 — typed sidecar JSON (cockpit "
        "Models/MatterRecord.swift preserved for the day the adapter "
        "lands · R3 compliance).",
        "hexa-matter/verify/run_all.hexa — 4-subscript closure "
        "aggregator (spec_presence · lattice_arithmetic · real_"
        "limits_anchor · closure_consistency).",
    ]
    scope_caveats = [
        "matter + analyze is an illustrative TEMPLATE emit "
        "(D106 illustrative-physics · RFC 013 §6.12) — analysis "
        "envelope scaffold with NO ~/core/hexa-matter/verify/"
        "run_all.hexa spawn performed.",
        "absorbed = false PERMANENTLY (g3 · D106) — a real "
        "MatterRecord with absorbed=true requires (a) the sibling "
        "aggregator run end-to-end AND (b) a pinned hexa-matter "
        "commit hash · neither is captured by this template shim.",
        "producer = matter_analyze@template (NOT hexa_matter@<sha>) "
        "— adapter-only emit (D72). Path forward: (a) teach "
        "cellrun.hexa a sibling-repo substrate kind, or (b) extend "
        "this shim to subprocess run_all.hexa and parse PASS/FAIL.",
        "Stage 4 absorbed=true gating belongs to hexa-matter's own "
        "aggregator + closure-invariants · demiurge witnesses, never "
        "upgrades the claim (D17 g_stdlib_ownership).",
        "wet-lab cells (synthesize · verify · handoff) stay honest-"
        "skip per project.tape @D d1.",
    ]

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "analysis": analysis,
        "artifacts": {
            "analysis": f"{GEOMETRY_ID}.analysis.json",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    ana_path = out / f"{GEOMETRY_ID}.analysis.json"
    with open(ana_path, "w", encoding="utf-8") as f:
        json.dump(analysis, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "matter",
        "verb": "analyze",
        "kind": "matter_analyze_record",
        "stamp": stamp,
        "producer": "matter_analyze@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "analysis": analysis,
        "artifacts": {
            "meta": meta_path.name,
            "analysis": ana_path.name,
        },
    }
    rec_path = out / f"matter_analyze_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "analysis_fields": list(analysis.keys()),
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "analysis": ana_path.name,
        },
    }
    sys.stderr.write("MATTER_ANALYZE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/matter_analyze"))
