#!/usr/bin/env python3
# specify.py - `sscb + specify` producer (D72 adapter-only · firmware-stub
# pattern · D111 cellrun-compatible).
#
# Emits an `sscb_v1.meta.json` (sibling meta with `measurements` block for
# D113 cellrun payload flattening / roll-up) plus a plain-text spec dossier
# transcribed from `~/core/demiurge/domains/sscb.md` §1 "Design blueprint
# deliverable" (SSOT — domain-meta-domain principle).
#
# This is a TEMPLATE-emit specify (no measurement, no SPICE/FEM/TCAD
# instrument invoked) — `absorbed = false` permanently per g3. The
# ≤ 600 ns target is HEXA-SSCB mk1 aspiration, NOT a bench-verified
# measurement.
#
# Citations (domains/sscb.md §5):
#   - UL 489I 1st ed. Oct 2025 — webstore.ansi.org/standards/ul/ul489ied2025
#   - IEC 60947-2 — sinobreaker.com/iec-60947-2-vs-ul-489/
#   - IEEE C37.x switchgear family
#
# D61: substrate SSOT here under hexa-lang/stdlib/sscb/.
# D116: hexa-lang stdlib is the single producer SSOT (sibling repos = docs only).
# g3:  honest. Pure template emit, no external tool required. Record
#      always GATE_OPEN / absorbed=false (spec without measurement is
#      illustrative, not absorption).

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "sscb_v1"


def _build_spec() -> dict:
    """Transcribed from domains/sscb.md §1 — the SSOT for HEXA-SSCB mk1.

    Keys are snake_case (matches Codable `SscbSpecifyRecord` mirror on the
    cockpit side). All values are aspirational / template — no measured
    figures here.
    """
    return {
        "target": (
            "<= 1 us DC fault interruption "
            "(HEXA-SSCB mk1 spec target = 600 ns)"
        ),
        "voltage": "1500 Vdc max (IEC 60947-2 SSHCB envelope)",
        "current": (
            "TBD per family — Icu / Ics breaking capacity per IEC 60947-2 "
            "type-test"
        ),
        "standards": [
            "UL 489I 1st ed. 2025 (SSCB / SSHCB <= 1000 Vac / 1500 Vdc)",
            "IEC 60947-2",
            "IEEE C37.x",
        ],
        "semiconductor_family": "SiC | GaN power switches with paralleling",
        "topology": (
            "pure-SS vs hybrid SSHCB "
            "(sscb.md §2 ARCHITECT shelf option)"
        ),
        "protections": [
            "snubber for transient suppression",
            "magnetic limiter / commutation circuit",
            "galvanic disconnect mechanical",
        ],
        "thermal_management": (
            "active cooling — liquid cold plate option "
            "(OpenFOAM analyze cell per sscb.md §2)"
        ),
        "cert_dossier_required": True,
        "notes": (
            "Spec scaffold (template) — downstream verbs (structure / "
            "design / synthesize / analyze / verify / handoff) fill the "
            "TBD slots with measured / vendor-validated values. UL 489I "
            "type-test = accredited-lab gate, NOT a SPICE simulation."
        ),
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    spec = _build_spec()

    # D113 measurements block — empty for template specify, but present
    # so the cellrun envelope's payload.measurements roll-up has a valid
    # (empty) container instead of a missing key.
    measurements: dict = {}

    citations = [
        "UL 489I 1st ed. (Oct 2025) — "
        "webstore.ansi.org/standards/ul/ul489ied2025.",
        "IEC 60947-2 vs UL 489 — sinobreaker.com/iec-60947-2-vs-ul-489/.",
        "IEEE C37.x switchgear family.",
        "domains/sscb.md §1 (HEXA-SSCB mk1 spec) — demiurge repo SSOT.",
    ]
    scope_caveats = [
        "specify is a doc-TEMPLATE emit (no measurement, no instrument) "
        "— <= 600 ns target = HEXA-SSCB mk1 aspiration, NOT bench-verified.",
        "current rating + die selection + UL 489I lab booking = "
        "downstream verb territory (structure / design / verify) — "
        "this cell does NOT bind to a part number or a fault current.",
        "absorbed = false permanently (g3) — a spec without measurement "
        "is illustrative, not an absorption claim (mirrors firmware "
        "specify.py template emit pattern).",
        "domains/sscb.md §1 is the SSOT — this script transcribes it "
        "into a record JSON envelope (domain-meta-domain principle).",
    ]

    # Sibling meta.json — D113 cellrun payload flattening source.
    # cellrun looks for `<geometry_id>.meta.json` (or any *.meta.json)
    # in the run_dir and rolls `measurements` up into the envelope's
    # `payload.measurements`. Spec fields are stashed at the top level
    # so they survive the roll-up.
    meta = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "produced_at_utc": produced_at_utc,
        "python_version": platform.python_version(),
        # G7 typed gate_type — template emit succeeded; no hexa-native
        # sscb-specify kernel exists yet (and never will — spec is a
        # doc template, not a kernel) → D80 hexa-native-absent +
        # provisional.
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # D113 — empty measurements block (template emit, no figures).
        "measurements": measurements,
        # Spec content (transcribed from sscb.md §1).
        "spec": spec,
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
        "# HEXA-SSCB mk1 — spec dossier (specify cell template emit)",
        "",
        f"Stamp: {stamp}",
        f"Source SSOT: domains/sscb.md §1 (demiurge repo)",
        "",
        "## Headline target",
        "",
        f"- {spec['target']}",
        f"- Voltage: {spec['voltage']}",
        f"- Current: {spec['current']}",
        "",
        "## Standards",
        "",
    ]
    dossier_lines.extend(f"- {s}" for s in spec["standards"])
    dossier_lines.extend([
        "",
        "## Topology + semiconductor",
        "",
        f"- Family: {spec['semiconductor_family']}",
        f"- Topology: {spec['topology']}",
        "",
        "## Protections",
        "",
    ])
    dossier_lines.extend(f"- {p}" for p in spec["protections"])
    dossier_lines.extend([
        "",
        "## Thermal management",
        "",
        f"- {spec['thermal_management']}",
        "",
        "## Certification",
        "",
        (
            "- cert_dossier_required: "
            f"{'YES' if spec['cert_dossier_required'] else 'no'}"
        ),
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

    # Top-level record — the `sscb_specify_record` shape declared in
    # sscb.demi `[cell.specify].record_kind`. Mirrors the firmware
    # specify.py top-level shape (domain · verb · kind · stamp · producer
    # · measurement_gate · absorbed · scope_caveats · citations).
    record = {
        "domain": "sscb",
        "verb": "specify",
        "kind": "sscb_specify_record",
        "stamp": stamp,
        "producer": "sscb_specify@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        # Spec fields surfaced at top level (Codable mirror on cockpit).
        "target": spec["target"],
        "voltage": spec["voltage"],
        "current": spec["current"],
        "standards": spec["standards"],
        "semiconductor_family": spec["semiconductor_family"],
        "topology": spec["topology"],
        "protections": spec["protections"],
        "thermal_management": spec["thermal_management"],
        "cert_dossier_required": spec["cert_dossier_required"],
        "notes": spec["notes"],
        "artifacts": {
            "meta": meta_path.name,
            "spec_dossier": dossier_path.name,
        },
    }
    rec_path = out / f"sscb_specify_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    sys.stderr.write(
        f"sscb_specify: wrote {rec_path} "
        f"(ok=True, target='{spec['target'][:40]}...', "
        f"standards={len(spec['standards'])})\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "target": spec["target"],
        "voltage": spec["voltage"],
        "standards_count": len(spec["standards"]),
        "cert_dossier_required": spec["cert_dossier_required"],
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "spec_dossier": dossier_path.name,
        },
    }
    # SSCB_SPECIFY_RESULT marker on stderr — matches ngspice_breaking.py
    # pattern; cellrun and Swift CellrunDispatch consume the merged
    # stdout+stderr stream so either is fine.
    sys.stderr.write("SSCB_SPECIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sscb_specify"))
