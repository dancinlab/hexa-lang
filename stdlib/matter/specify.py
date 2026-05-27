#!/usr/bin/env python3
# specify.py — `matter + specify` producer (thin in-silico shim ·
# D17 consumer-pointer · D72 adapter-only · D111 cellrun-compatible ·
# D106 illustrative-physics).
#
# UNUSUAL CASE: matter has NO substrate of its own under stdlib/matter/.
# The materials substrate was absorbed into hexa-lang as
# `stdlib/mol/` + `stdlib/crystal/` + `stdlib/mlff/` (D17 ·
# domains/matter/README.md). The legacy hexa-matter sibling repo
# (~/core/hexa-matter/) still exists for closure-aggregator history but
# is no longer authoritative for substrate dispatch (the matter analyze
# legacy κ-30/D53 path was sibling-repo dispatch · D111 Phase C migrated
# this to CellrunDispatch).
#
# This shim is a TEMPLATE emit: a materials-requirements template
# scaffold derived from matter.md § material-family matrix narrative
# (mechanical · thermal · chemical · electronic target axes). NO
# simulation is invoked, NO measured property is claimed. The output
# survives the cellrun envelope's D113 measurements roll-up with an
# empty measurements block (illustrative spec, not figures).
#
# Honesty (g3 · D106 · project.tape @D d1):
#   - measurement_gate = GATE_OPEN permanently
#   - absorbed = false permanently (illustrative-physics, NOT a wet-lab
#     materials measurement · D106 carve-out · RFC 013 §6.12)
#   - producer = "matter_specify@template" (NOT a hexa-matter pin —
#     this shim does NOT spawn the sibling aggregator)
#   - scope_caveats explicitly cite the D106 illustrative boundary;
#     wet-lab synthesize/verify/handoff stay honest-skip per @D d1
#
# Pattern: mirrors stdlib/firmware/specify.py (firmware-adapter-only)
# + sscb specify.py D113 sibling-meta convention.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "matter_specify_v1"


def _build_requirements_template() -> dict:
    """Materials-requirements template — four canonical target axes
    from matter.md material-family matrix narrative (mechanical /
    thermal / chemical / electronic). Values are TEMPLATE placeholders
    a real materials project fills with vendor-validated / measured
    figures via the (future) hexa-matter analyze cell.
    """
    return {
        "mechanical": {
            "tensile_strength_mpa": None,
            "youngs_modulus_gpa": None,
            "density_g_cm3": None,
            "notes": "Spec scaffold — bench measurement = wet-lab boundary.",
        },
        "thermal": {
            "operating_temp_c": [None, None],
            "thermal_conductivity_w_mk": None,
            "cte_ppm_k": None,
            "notes": "DSC / TGA / laser-flash measurement = wet-lab boundary.",
        },
        "chemical": {
            "ph_window": None,
            "corrosion_resistance_class": None,
            "notes": "Salt-spray / immersion test = wet-lab boundary.",
        },
        "electronic": {
            "bandgap_ev": None,
            "carrier_mobility_cm2_vs": None,
            "dielectric_constant": None,
            "notes": "Hall / IV / impedance measurement = wet-lab boundary.",
        },
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    requirements = _build_requirements_template()

    # D113 — empty measurements block (illustrative spec, no figures).
    measurements: dict = {}

    citations = [
        "domains/matter.md material-family matrix narrative — demiurge SSOT.",
        "domains/matter/README.md — D17 hexa-matter absorbed into "
        "hexa-lang stdlib/mol/ + stdlib/crystal/ + stdlib/mlff/.",
        "Materials Project (materialsproject.org) — open materials database.",
        "OQMD (oqmd.org) — open quantum materials database.",
        "Materials Genome Initiative — mgi.gov.",
    ]
    scope_caveats = [
        "matter + specify is an illustrative TEMPLATE emit "
        "(D106 illustrative-physics · RFC 013 §6.12) — material-"
        "requirements scaffold (mechanical · thermal · chemical · "
        "electronic axes) with NO measured property bound.",
        "absorbed = false PERMANENTLY (g3 · D106) — a requirements "
        "template is aspiration, never a wet-lab measurement. "
        "absorbed=true requires accredited bench measurement (XRD · "
        "SEM · DSC · tensile · Hall) which lives past project.tape "
        "@D d1's legitimate not-yet wet-lab boundary.",
        "producer = matter_specify@template — this shim does NOT "
        "spawn ~/core/hexa-matter/verify/run_all.hexa (legacy κ-30/"
        "D53 sibling-repo dispatcher) · adapter-only emit (D72).",
        "wet-lab cells (synthesize · verify · handoff) stay honest-"
        "skip per project.tape @D d1 — bench reagent / measurement "
        "/ qualification = the legitimate not-yet boundary.",
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
        "requirements": requirements,
        "artifacts": {
            "requirements": f"{GEOMETRY_ID}.requirements.json",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    # Sibling requirements.json (the template scaffold).
    req_path = out / f"{GEOMETRY_ID}.requirements.json"
    with open(req_path, "w", encoding="utf-8") as f:
        json.dump(requirements, f, indent=2, sort_keys=True)
        f.write("\n")

    # Top-level record — `matter_specify_record` shape per matter.demi.
    record = {
        "domain": "matter",
        "verb": "specify",
        "kind": "matter_specify_record",
        "stamp": stamp,
        "producer": "matter_specify@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "requirements": requirements,
        "artifacts": {
            "meta": meta_path.name,
            "requirements": req_path.name,
        },
    }
    rec_path = out / f"matter_specify_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "axes": list(requirements.keys()),
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "requirements": req_path.name,
        },
    }
    sys.stderr.write("MATTER_SPECIFY_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/matter_specify"))
