#!/usr/bin/env python3
# handoff.py - `chip + handoff` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · sscb cert-dossier mirror).
#
# Emits chip_v1.meta.json + chip_v1.cert_checklist.md +
# chip_v1.verification_report.md + chip_v1.gds_handoff.placeholder +
# chip_v1.bundle_manifest.json + chip_handoff_<stamp>.json (5 artifacts).
#
# Aggregates the upstream 6-cell record outputs (spec target_freq · BOM
# node count · design constraint · analyze cell count · synth area ·
# verify equiv result) into a single tapeout-handoff cert checklist
# anchored to chip §D cert paths (IEEE 1450 STIL · IEC 62474 · SkyWater
# MPW Shuttle / Efabless OpenMPW honest-gap).
#
# argv:
#   chip/handoff.py <output_dir> [--rtl <path>]
#
# This producer does NOT spawn yosys / external tools. It is a pure
# template / aggregation emit. Upstream records (chip_specify_<stamp>.json
# etc.) are read opportunistically from `<output_dir>/..` if present —
# absence is honest-gap, not a crash.

from __future__ import annotations

import json
import platform
import re
import sys
import time
from pathlib import Path
from typing import Optional

GEOMETRY_ID = "chip_v1"

DEFAULT_RTL = "/Users/ghost/core/demiurge/archive/comb/rtl/counter4.v"

# Cert path roster (chip §D honest-gap) — placeholder lab partner candidates.
CERT_PATHS = [
    {
        "standard": "IEEE 1450 (STIL · Standard Test Interface Language)",
        "scope": "Pattern-based functional / structural test patterns.",
        "absorbed": False,
        "blocking": True,
        "lab_partners": ["independent test-vendor TBD"],
        "notes": "STIL pattern generation = downstream (post-tapeout) tool.",
    },
    {
        "standard": "IEC 62474 (substance compliance / material declaration)",
        "scope": "Material composition disclosure for fab-grade IC.",
        "absorbed": False,
        "blocking": False,
        "lab_partners": ["SkyWater fab partner declaration"],
        "notes": "fab-mediated · NOT chip-design-tool responsibility.",
    },
    {
        "standard": "SkyWater MPW Shuttle (OpenMPW)",
        "scope": "Multi-project wafer shuttle (130 nm · open-source friendly).",
        "absorbed": False,
        "blocking": True,
        "lab_partners": ["Efabless", "SkyWater Technology"],
        "notes": "Tapeout submission path · GDS + DRC clean + LVS match required.",
    },
    {
        "standard": "Magic DRC (chip §D honest-gap)",
        "scope": "Design rule check (post-P&R · pre-tapeout).",
        "absorbed": False,
        "blocking": True,
        "lab_partners": ["self-hosted Magic tool"],
        "notes": "Magic DRC integration is honest-gap (chip §D roster).",
    },
    {
        "standard": "OpenSTA signoff (chip §D honest-gap)",
        "scope": "Static timing analysis · timing closure signoff.",
        "absorbed": False,
        "blocking": True,
        "lab_partners": ["self-hosted OpenSTA"],
        "notes": "Post-P&R STA signoff is honest-gap (chip §D roster).",
    },
]


def _parse_argv(argv: list[str]) -> tuple[str, Optional[str]]:
    out_dir = "/tmp/chip_handoff"
    rtl_path: Optional[str] = None
    i = 1
    positional: list[str] = []
    while i < len(argv):
        tok = argv[i]
        if tok == "--rtl" and i + 1 < len(argv):
            rtl_path = argv[i + 1]
            i += 2
            continue
        positional.append(tok)
        i += 1
    if positional:
        out_dir = positional[0]
    return out_dir, rtl_path


def _detect_top(rtl_path: str) -> str:
    p = Path(rtl_path)
    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        return p.stem
    m = re.search(r"\bmodule\s+([A-Za-z_]\w*)\s*[\(;]", text)
    return m.group(1) if m else p.stem


def _load_upstream_records(out: Path) -> dict:
    """Best-effort upstream-record load.

    Looks for chip_<verb>_<stamp>.json in `out` + sibling dirs (`out/..`).
    Returns dict keyed by verb with the loaded record (or None when not
    found). This is opportunistic — handoff still emits a usable record
    when upstream cells haven't run.
    """
    verbs = ["specify", "structure", "design", "analyze", "synthesize", "verify"]
    loaded: dict[str, Optional[dict]] = {v: None for v in verbs}
    search_dirs = [out, out.parent]
    # Also look at sibling dirs named chip_<verb>_test (per smoke pattern).
    for sibling in out.parent.iterdir() if out.parent.is_dir() else []:
        if sibling.is_dir() and sibling.name.startswith("chip_"):
            search_dirs.append(sibling)
    for verb in verbs:
        # Newest first.
        candidates: list[Path] = []
        for d in search_dirs:
            if not d.is_dir():
                continue
            for p in d.glob(f"chip_{verb}_*.json"):
                candidates.append(p)
        if not candidates:
            continue
        candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        try:
            loaded[verb] = json.loads(
                candidates[0].read_text(encoding="utf-8"))
        except Exception:
            loaded[verb] = None
    return loaded


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    rtl = rtl_path or DEFAULT_RTL
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    top = _detect_top(rtl)
    upstream = _load_upstream_records(out)
    upstream_present_count = sum(1 for v in upstream.values() if v is not None)

    # Roll-up signals from upstream (best-effort · None when missing).
    def _get(verb: str, key: str, default=None):
        rec = upstream.get(verb)
        if rec is None:
            return default
        return rec.get(key, default)

    summary_signals = {
        "rtl_top": top,
        "specify_freq_mhz": _get("specify", "target_freq_mhz"),
        "structure_node_count": _get("structure", "bom_node_count"),
        "design_target_freq_mhz": _get("design", "target_freq_mhz"),
        "design_sky130_lib_found": _get("design", "sky130_lib_found"),
        "analyze_total_cells": _get("analyze", "total_cells"),
        "analyze_dff_count": _get("analyze", "dff_count"),
        "synthesize_post_synth_cells": _get("synthesize", "post_synth_cells"),
        "synthesize_chip_area_um2": _get("synthesize", "chip_area_um2"),
        "verify_equiv_ran": _get("verify", "equiv_ran"),
        "verify_equiv_cleared": _get("verify", "equiv_cleared"),
    }

    # Cert checklist — per-row pass/fail tally based on upstream evidence.
    cert_rows: list[dict] = []
    cert_rows.append({
        "id": "spec_compliance",
        "title": "Spec compliance",
        "ok": _get("specify", "rtl_top") is not None,
        "evidence": (
            f"specify record present: rtl_top='{_get('specify', 'rtl_top')}' · "
            f"target_freq_mhz={summary_signals['specify_freq_mhz']}."
        ) if upstream.get("specify") else "specify record absent.",
    })
    cert_rows.append({
        "id": "rtl_structure",
        "title": "RTL structure (BOM tree)",
        "ok": _get("structure", "bom_node_count", 0) > 0,
        "evidence": (
            f"structure record present: bom_node_count="
            f"{summary_signals['structure_node_count']}."
        ) if upstream.get("structure") else "structure record absent.",
    })
    cert_rows.append({
        "id": "design_constraints",
        "title": "Design constraints (yosys script + SKY130 lib)",
        "ok": (_get("design", "sky130_lib_found") is True),
        "evidence": (
            f"design record present: sky130_lib_found="
            f"{summary_signals['design_sky130_lib_found']}."
        ) if upstream.get("design") else "design record absent.",
    })
    cert_rows.append({
        "id": "pre_synth_analyze",
        "title": "Pre-synth analyze (yosys stat · sanity floor)",
        "ok": (_get("analyze", "yosys_ok") is True
               and _get("analyze", "floor_ok") is True),
        "evidence": (
            f"analyze record present: total_cells="
            f"{summary_signals['analyze_total_cells']} · "
            f"dff_count={summary_signals['analyze_dff_count']}."
        ) if upstream.get("analyze") else "analyze record absent.",
    })
    cert_rows.append({
        "id": "post_synth",
        "title": "Post-synth tech mapping (SKY130 · ABC)",
        "ok": (_get("synthesize", "yosys_ok") is True
               and (_get("synthesize", "synth_v_exists") is True)),
        "evidence": (
            f"synthesize record present: post_synth_cells="
            f"{summary_signals['synthesize_post_synth_cells']} · "
            f"chip_area_um2="
            f"{summary_signals['synthesize_chip_area_um2']}."
        ) if upstream.get("synthesize") else "synthesize record absent.",
    })
    cert_rows.append({
        "id": "equiv_check",
        "title": "Combinational equivalence (yosys equiv_make)",
        "ok": (_get("verify", "equiv_cleared") is True),
        "evidence": (
            f"verify record present: equiv_ran="
            f"{summary_signals['verify_equiv_ran']} · "
            f"equiv_cleared="
            f"{summary_signals['verify_equiv_cleared']}."
        ) if upstream.get("verify") else "verify record absent.",
    })
    cert_rows.append({
        "id": "tapeout_signoff",
        "title": "Tapeout signoff (DRC + LVS + STA + IR-drop + IO ring + power grid)",
        "ok": False,
        "evidence": (
            "Honest-gap (chip §D): OpenROAD P&R · Magic DRC · OpenSTA · "
            "LVS · IR-drop · IO ring · power grid 7-종 흡수 不在."
        ),
    })

    cert_pass_count = sum(1 for r in cert_rows if r["ok"])
    cert_fail_count = len(cert_rows) - cert_pass_count
    cert_blocking_count = sum(
        1 for r in cert_rows if not r["ok"]
        and r["id"] in ("post_synth", "equiv_check", "tapeout_signoff")
    )

    # Cert checklist artifact.
    cert_path = out / f"{GEOMETRY_ID}.cert_checklist.md"
    cert_lines = [
        f"# chip handoff cert checklist — {top}",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {top}",
        f"Upstream records loaded: {upstream_present_count} of 6",
        f"Cert rows: {len(cert_rows)} · pass={cert_pass_count} · fail={cert_fail_count} · blocking={cert_blocking_count}",
        "",
        "## Per-row checklist",
        "",
    ]
    for r in cert_rows:
        mark = "[x]" if r["ok"] else "[ ]"
        cert_lines.append(f"- {mark} **{r['title']}** — {r['evidence']}")
    cert_lines.extend([
        "",
        "## Cert paths (chip §D roster)",
        "",
    ])
    for cp in CERT_PATHS:
        cert_lines.append(
            f"- **{cp['standard']}** — {cp['scope']} "
            f"(absorbed={cp['absorbed']} · blocking={cp['blocking']})")
        cert_lines.append(f"  - notes: {cp['notes']}")
        cert_lines.append(f"  - lab partners: {', '.join(cp['lab_partners'])}")
    cert_path.write_text("\n".join(cert_lines), encoding="utf-8")

    # Verification report artifact.
    verify_path = out / f"{GEOMETRY_ID}.verification_report.md"
    verify_lines = [
        f"# chip handoff verification report — {top}",
        "",
        f"Stamp: {stamp}",
        f"RTL: {rtl}",
        f"Top module: {top}",
        "",
        "## Upstream cell roll-up",
        "",
        f"- specify present: {upstream.get('specify') is not None}",
        f"  - target_freq_mhz: {summary_signals['specify_freq_mhz']}",
        f"- structure present: {upstream.get('structure') is not None}",
        f"  - bom_node_count: {summary_signals['structure_node_count']}",
        f"- design present: {upstream.get('design') is not None}",
        f"  - design_target_freq_mhz: {summary_signals['design_target_freq_mhz']}",
        f"  - sky130_lib_found: {summary_signals['design_sky130_lib_found']}",
        f"- analyze present: {upstream.get('analyze') is not None}",
        f"  - total_cells: {summary_signals['analyze_total_cells']}",
        f"  - dff_count: {summary_signals['analyze_dff_count']}",
        f"- synthesize present: {upstream.get('synthesize') is not None}",
        f"  - post_synth_cells: {summary_signals['synthesize_post_synth_cells']}",
        f"  - chip_area_um2: {summary_signals['synthesize_chip_area_um2']}",
        f"- verify present: {upstream.get('verify') is not None}",
        f"  - equiv_ran: {summary_signals['verify_equiv_ran']}",
        f"  - equiv_cleared: {summary_signals['verify_equiv_cleared']}",
        "",
        "## Verdict",
        "",
        f"- cert_pass_count: {cert_pass_count}",
        f"- cert_fail_count: {cert_fail_count}",
        f"- cert_blocking_count: {cert_blocking_count}",
        f"- handoff_ready: **False** (tapeout signoff is honest-gap · chip §D)",
        "",
    ]
    verify_path.write_text("\n".join(verify_lines), encoding="utf-8")

    # GDS handoff PLACEHOLDER (text · NOT a real GDSII binary).
    gds_path = out / f"{GEOMETRY_ID}.gds_handoff.placeholder"
    gds_text = (
        f"# chip_v1.gds_handoff.placeholder — {top}\n"
        "#\n"
        "# HONEST: NOT a real GDSII file. Real GDS generation requires\n"
        "# OpenROAD P&R + Magic stream-out (honest-gap roster · chip §D).\n"
        "# This placeholder records the intended tapeout target only.\n"
        "#\n"
        f"chip_top_module: {top}\n"
        f"target_tech: SKY130 (sky130_fd_sc_hd · 130 nm)\n"
        f"target_shuttle: SkyWater MPW Shuttle / Efabless OpenMPW\n"
        f"gdsii_status: NOT_GENERATED\n"
        f"reason: OpenROAD P&R · Magic DRC · LVS · STA signoff 흡수 不在 (chip §D).\n"
    )
    gds_path.write_text(gds_text, encoding="utf-8")

    # Bundle manifest.
    bundle_path = out / f"{GEOMETRY_ID}.bundle_manifest.json"
    bundle = {
        "geometry_id": GEOMETRY_ID,
        "rtl_top": top,
        "rtl_path": rtl,
        "stamp": stamp,
        "artifacts": [
            cert_path.name,
            verify_path.name,
            gds_path.name,
            f"{GEOMETRY_ID}.meta.json",
        ],
        "upstream_records_present": upstream_present_count,
        "cert_rows": cert_rows,
        "cert_paths": CERT_PATHS,
        "summary_signals": summary_signals,
    }
    with open(bundle_path, "w", encoding="utf-8") as f:
        json.dump(bundle, f, indent=2, sort_keys=True)
        f.write("\n")

    citations = [
        "chip.demi [cell.handoff] — chip_handoff_record kind.",
        "chip §D honest-gap roster — OpenROAD P&R · Magic DRC · OpenSTA · "
        "LVS · IR-drop · IO ring · power grid (tapeout signoff 7-종).",
        "IEEE 1450 (STIL) — Standard Test Interface Language for test "
        "patterns.",
        "IEC 62474 — substance compliance / material declaration.",
        "SkyWater MPW Shuttle / Efabless OpenMPW — open-source tapeout "
        "path (130 nm SKY130).",
        "stdlib/sscb/handoff (firmware/handoff.py pattern) — cert dossier "
        "structure mirror.",
    ]
    scope_caveats = [
        "Tapeout signoff (OpenROAD P&R · Magic DRC · OpenSTA · LVS · "
        "IR-drop · IO ring · power grid) is honest-gap (chip §D · 7-종 "
        "동시 needed for absorbed=true).",
        "GDS handoff artifact is a TEXT PLACEHOLDER · NOT a real GDSII · "
        "real GDS generation requires Magic stream-out.",
        "Cert checklist is doc-only — actual lab booking + fab "
        "submission + IEEE 1450 STIL pattern generation = downstream "
        "post-cellrun work.",
        "absorbed=false PERMANENTLY at this cell — handoff is a "
        "cert-readiness dossier · NOT a tapeout-clean GDSII bundle.",
    ]
    if upstream_present_count < 6:
        scope_caveats.append(
            f"Upstream records: only {upstream_present_count} of 6 found "
            "— cert checklist rows degrade to 'absent' for the missing "
            "cells (honest gap, NOT a crash).")

    measurements = {
        "cert_row_count": len(cert_rows),
        "cert_pass_count": cert_pass_count,
        "cert_fail_count": cert_fail_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": 4,
        "upstream_records_present": upstream_present_count,
    }

    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "summary_signals": summary_signals,
        "rtl_path": rtl,
        "rtl_top": top,
        "cert_rows": cert_rows,
        "artifacts": {
            "cert_checklist": cert_path.name,
            "verification_report": verify_path.name,
            "gds_handoff": gds_path.name,
            "bundle_manifest": bundle_path.name,
        },
        "provenance": {
            "measurement_gate": "GATE_OPEN",
            "absorbed": False,
            "scope_caveats": scope_caveats,
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "chip",
        "verb": "handoff",
        "kind": "chip_handoff_record",
        "stamp": stamp,
        "producer": "chip_handoff@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "rtl_path": rtl,
        "rtl_top": top,
        "cert_row_count": len(cert_rows),
        "cert_pass_count": cert_pass_count,
        "cert_fail_count": cert_fail_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": 4,
        "upstream_records_present": upstream_present_count,
        "summary_signals": summary_signals,
        "cert_rows": cert_rows,
        "handoff_ready": False,
        "notes": (
            "Cert-readiness dossier · NOT a tapeout-clean GDSII bundle. "
            "OpenROAD P&R + Magic DRC + OpenSTA signoff + LVS + IR-drop "
            "+ IO ring + power grid 7-종 동시 needed for absorbed=true."
        ),
        "artifacts": {
            "meta": meta_path.name,
            "cert_checklist": cert_path.name,
            "verification_report": verify_path.name,
            "gds_handoff": gds_path.name,
            "bundle_manifest": bundle_path.name,
        },
    }
    rec_path = out / f"chip_handoff_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_handoff: wrote {rec_path} "
        f"(ok=True, top='{top}', "
        f"cert_pass={cert_pass_count}/{len(cert_rows)}, "
        f"upstream_present={upstream_present_count}/6)\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "rtl_top": top,
        "cert_row_count": len(cert_rows),
        "cert_pass_count": cert_pass_count,
        "cert_fail_count": cert_fail_count,
        "cert_blocking_count": cert_blocking_count,
        "bundle_artifact_count": 4,
        "upstream_records_present": upstream_present_count,
        "handoff_ready": False,
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "cert_checklist": cert_path.name,
            "verification_report": verify_path.name,
            "gds_handoff": gds_path.name,
            "bundle_manifest": bundle_path.name,
        },
    }
    sys.stderr.write("CHIP_HANDOFF_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
