#!/usr/bin/env python3
# specify.py - `chip + specify` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible · sscb pattern mirror).
#
# Emits a `chip_v1.meta.json` (sibling meta with `measurements` block for
# D113 cellrun payload flattening / roll-up) plus a plain-text spec dossier
# and the top-level chip_specify_record JSON envelope.
#
# This is a TEMPLATE-emit specify (no synthesis, no tapeout binding) —
# `absorbed = false` permanently per g3. The targets below are
# clean-room-phase-a aspirations (SKY130 / yosys 0.65 / ABC), NOT
# tapeout-validated figures.
#
# argv:
#   chip/specify.py <output_dir> [--rtl <path>]
#
# `--rtl <path>` is parsed off argv when present and recorded into the
# spec/record under `rtl_path` + `rtl_top` (derived from filename stem).
# When absent, the producer defaults to `counter4.v` for the smoke-test
# walkthrough — NOT a hardcode for the 5-chip set; the dispatcher passes
# the explicit `--rtl <path>` per chip iteration (chip.demi §5-chip
# walkthrough roster).
#
# Citations (domains/chip.md + chip.demi):
#   - chip.demi [cell.specify] — record_kind=chip_specify_record
#   - Yosys 0.65 (YosysHQ, ISC) — open-source RTL synthesis (κ-43 substrate).
#   - ABC (Berkeley · UC Regents) — logic optimization + tech mapping.
#   - SKY130 PDK (Google + SkyWater · Apache-2.0) — open-source 130 nm node.
#   - IEEE Std 1364-2005 — Verilog synthesizable subset reference.
#
# g3: honest. Pure template emit, no external tool required. Record
#     always GATE_OPEN / absorbed=false (a spec without synthesis +
#     tapeout signoff is illustrative, not absorption).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path
from typing import Optional

GEOMETRY_ID = "chip_v1"

# Per-chip metadata table — minimal didactic facts (LOC / family / brief).
# Generic dispatch: keyed by RTL filename stem. If a stem is not in this
# table the producer still emits a record (with rtl_top=stem, brief=None)
# — supports any future Verilog file dropped under archive/comb/rtl/.
KNOWN_CHIPS = {
    "counter4":   {"family": "counter",  "brief": "4-bit synchronous up-counter (4 DFF · ~25 LOC)."},
    "pwm8":       {"family": "pwm",      "brief": "8-bit PWM controller (8 DFF + comparator · ~35 LOC)."},
    "uart_tx":    {"family": "fsm",      "brief": "UART TX 8N1, 5-state FSM (~95 LOC)."},
    "crc8":       {"family": "datapath", "brief": "CRC-8 CCITT poly 0x07 (8 DFF + XOR tree · ~50 LOC)."},
    "spi_master": {"family": "fsm",      "brief": "SPI master 4-pin 8-bit MSB-first, 3-state FSM (~120 LOC)."},
}

DEFAULT_RTL = "/Users/ghost/core/demiurge/archive/comb/rtl/counter4.v"


def _parse_argv(argv: list[str]) -> tuple[str, Optional[str]]:
    """Pull `<out_dir>` (positional) + `--rtl <path>` (optional) off argv.

    Generic shape — argv parse is intentionally tiny (no argparse) so
    cellrun.hexa can spawn this with `[out_dir, '--rtl', rtl_path]` and
    the 7 producers share the parse contract.
    """
    out_dir = "/tmp/chip_specify"
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


def _build_spec(rtl_path: Optional[str]) -> dict:
    """Chip spec template — SKY130 + yosys 0.65 + ABC envelope.

    All values are aspirational / clean-room-phase-a — no measured
    figures here (synth area / freq / power come from analyze +
    synthesize cells downstream).
    """
    rtl = rtl_path or DEFAULT_RTL
    stem = Path(rtl).stem
    chip_meta = KNOWN_CHIPS.get(stem, {"family": "unknown", "brief": None})
    return {
        "rtl_path": rtl,
        "rtl_top": stem,
        "chip_family": chip_meta["family"],
        "chip_brief": chip_meta["brief"],
        "tech_node": "SKY130 (130 nm · SkyWater open PDK · Apache-2.0)",
        "cell_library": "sky130_fd_sc_hd (high-density · 9-track)",
        "synth_tool": "yosys 0.65 + ABC (Berkeley · UC Regents)",
        "target_freq_mhz": 100,
        "area_budget_um2": 10_000,
        "power_budget_mw": "TBD per family — propagated by analyze cell.",
        "cert_pattern": [
            "IEEE 1450 (STIL test patterns) — pattern-based verification.",
            "IEC 62474 (substance compliance) — material declaration.",
            "post-tapeout: SkyWater MPW Shuttle / Efabless OpenMPW (honest-gap).",
        ],
        "verification_flow": [
            "RTL lint (chip.analyze) — yosys check + proc/opt/check.",
            "Synthesis (chip.synthesize) — yosys synth + dfflibmap + ABC -liberty.",
            "Equivalence (chip.verify) — yosys equiv_make + equiv_simple.",
            "Handoff (chip.handoff) — cert checklist + GDS placeholder.",
        ],
        "notes": (
            "Spec scaffold (template) — downstream verbs (structure / "
            "design / analyze / synthesize / verify / handoff) fill the "
            "TBD slots with measured / yosys-validated values. Tapeout "
            "signoff (OpenROAD P&R · Magic DRC · OpenSTA · LVS) "
            "= honest-gap, NOT scope of this cell."
        ),
    }


def main(argv: list[str]) -> int:
    out_dir, rtl_path = _parse_argv(argv)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    spec = _build_spec(rtl_path)

    # D113 measurements block — empty for template specify, but present
    # so the cellrun envelope's payload.measurements roll-up has a valid
    # (empty) container instead of a missing key.
    measurements: dict = {
        "target_freq_mhz": spec["target_freq_mhz"],
        "area_budget_um2": spec["area_budget_um2"],
        "cert_pattern_count": len(spec["cert_pattern"]),
        "verification_flow_step_count": len(spec["verification_flow"]),
    }

    citations = [
        "domains/chip.md + chip.demi [cell.specify] — chip 7-verb manifest SSOT.",
        "Yosys 0.65 (YosysHQ, ISC) — open-source RTL synthesis (chip §B "
        "absorbed κ-43 substrate).",
        "ABC (Berkeley · UC Regents) — logic optimization + tech mapping.",
        "SKY130 PDK (Google + SkyWater · Apache-2.0) — open 130 nm node.",
        "IEEE Std 1364-2005 — Verilog synthesizable subset reference.",
    ]
    scope_caveats = [
        "specify is a doc-TEMPLATE emit (no synthesis, no tapeout) — "
        "target_freq_mhz / area_budget_um2 are clean-room-phase-a "
        "aspirations, NOT tapeout-validated.",
        "RTL top-module is derived from filename stem — no Verilog "
        "parse here (structure cell does the parse).",
        "absorbed = false PERMANENTLY (g3) — a spec without synthesis + "
        "tapeout signoff is illustrative, not an absorption claim.",
        "Tapeout signoff (OpenROAD P&R · Magic DRC · OpenSTA · LVS · "
        "IR-drop) = honest-gap roster (chip §D), NOT this cell's scope.",
    ]

    # Sibling meta.json — D113 cellrun payload flattening source.
    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "measurements": measurements,
        "spec": spec,
        "rtl_path": spec["rtl_path"],
        "rtl_top": spec["rtl_top"],
        "artifacts": {
            "spec_dossier": f"{GEOMETRY_ID}.spec_dossier.md",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # Plain-text dossier for human review (one-shot snapshot of the spec).
    dossier_path = out / f"{GEOMETRY_ID}.spec_dossier.md"
    dossier_lines = [
        f"# chip spec dossier — {spec['rtl_top']} (specify cell template emit)",
        "",
        f"Stamp: {stamp}",
        f"Source SSOT: chip.demi [cell.specify] (demiurge repo)",
        f"RTL: {spec['rtl_path']}",
        f"Top module: {spec['rtl_top']}",
        f"Family: {spec['chip_family']}",
        "",
        "## Technology envelope",
        "",
        f"- Tech node: {spec['tech_node']}",
        f"- Cell library: {spec['cell_library']}",
        f"- Synth tool: {spec['synth_tool']}",
        "",
        "## Targets (aspirational · NOT measured)",
        "",
        f"- Clock frequency: {spec['target_freq_mhz']} MHz",
        f"- Area budget: {spec['area_budget_um2']} µm²",
        f"- Power budget: {spec['power_budget_mw']}",
        "",
        "## Certification pattern",
        "",
    ]
    dossier_lines.extend(f"- {c}" for c in spec["cert_pattern"])
    dossier_lines.extend([
        "",
        "## Verification flow",
        "",
    ])
    dossier_lines.extend(f"- {v}" for v in spec["verification_flow"])
    dossier_lines.extend([
        "",
        "## Notes",
        "",
        spec["notes"],
        "",
        "## Honest-skip caveats (g3)",
        "",
    ])
    dossier_lines.extend(f"- {c}" for c in scope_caveats)
    dossier_lines.append("")
    dossier_path.write_text("\n".join(dossier_lines), encoding="utf-8")

    # Top-level record — the `chip_specify_record` shape declared in
    # chip.demi [cell.specify].record_kind. Mirrors sscb_specify_record
    # envelope (domain · verb · kind · stamp · producer · measurement_gate
    # · absorbed · scope_caveats · citations).
    record = {
        "domain": "chip",
        "verb": "specify",
        "kind": "chip_specify_record",
        "stamp": stamp,
        "producer": "chip_specify@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # Spec fields surfaced at top level (Codable mirror on cockpit).
        "rtl_path": spec["rtl_path"],
        "rtl_top": spec["rtl_top"],
        "chip_family": spec["chip_family"],
        "chip_brief": spec["chip_brief"],
        "tech_node": spec["tech_node"],
        "cell_library": spec["cell_library"],
        "synth_tool": spec["synth_tool"],
        "target_freq_mhz": spec["target_freq_mhz"],
        "area_budget_um2": spec["area_budget_um2"],
        "power_budget_mw": spec["power_budget_mw"],
        "cert_pattern": spec["cert_pattern"],
        "verification_flow": spec["verification_flow"],
        "notes": spec["notes"],
        "artifacts": {
            "meta": meta_path.name,
            "spec_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"chip_specify_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"chip_specify: wrote {rec_path} "
        f"(ok=True, top='{spec['rtl_top']}', "
        f"family='{spec['chip_family']}', "
        f"freq_mhz={spec['target_freq_mhz']})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "rtl_top": spec["rtl_top"],
        "chip_family": spec["chip_family"],
        "target_freq_mhz": spec["target_freq_mhz"],
        "area_budget_um2": spec["area_budget_um2"],
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "spec_dossier": dossier_path.name,
        },
    }
    sys.stderr.write("CHIP_SPECIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
