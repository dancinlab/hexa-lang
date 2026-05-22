#!/usr/bin/env python3
# structure.py — `matter + structure` producer (thin in-silico shim ·
# D17 consumer-pointer · D72 adapter-only · D111 cellrun-compatible ·
# D106 illustrative-physics).
#
# Emits a TEMPLATE crystal-structure / phase-composition / microstructure
# topology scaffold (per matter.demi [cell.structure] scope_caveats).
# NO Materials Project / OQMD query is performed; NO pymatgen Structure
# parsed; the output is a placeholder topology surface a downstream
# (future) hexa-mol/crystal-backed structure cell would fill.
#
# Honesty (g3 · D106 · project.tape @D d1):
#   - measurement_gate = GATE_OPEN permanently
#   - absorbed = false permanently (illustrative · D106 · RFC 013 §6.12)
#   - producer = "matter_structure@template" (NOT a hexa-mol pin)
#
# Pattern: mirrors stdlib/firmware/structure.py.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "matter_structure_v1"


def _build_topology_template() -> dict:
    """Crystal-structure / microstructure topology scaffold —
    placeholder fields a real Materials Project / OQMD-backed
    structure cell fills with a queried Structure object.
    """
    return {
        "crystal_system": None,    # cubic / hexagonal / tetragonal / etc.
        "space_group": None,        # IT number 1-230
        "lattice_parameters": {
            "a_angstrom": None, "b_angstrom": None, "c_angstrom": None,
            "alpha_deg": None, "beta_deg": None, "gamma_deg": None,
        },
        "composition": {
            "formula_unit": None,
            "elements": [],
        },
        "phases": [],               # [{name, fraction, structure_ref}]
        "microstructure": {
            "grain_size_um": None,
            "porosity_pct": None,
            "anisotropy_axis": None,
        },
        "notes": (
            "Topology scaffold — Materials Project / OQMD query + "
            "pymatgen Structure parser = downstream substrate "
            "territory (NOT this shim)."
        ),
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    topology = _build_topology_template()
    measurements: dict = {}

    citations = [
        "domains/matter.md — material-family matrix narrative.",
        "domains/matter/README.md — D17 hexa-matter absorbed into "
        "hexa-lang stdlib/mol + stdlib/crystal + stdlib/mlff.",
        "Materials Project (materialsproject.org) — open database.",
        "OQMD (oqmd.org) — open quantum materials database.",
        "pymatgen (BSD) — Structure parser candidate.",
    ]
    scope_caveats = [
        "matter + structure is an illustrative TEMPLATE emit "
        "(D106 illustrative-physics · RFC 013 §6.12) — crystal / "
        "phase / microstructure topology scaffold with NO Materials "
        "Project / OQMD query bound.",
        "absorbed = false PERMANENTLY (g3 · D106) — a queried or "
        "predicted Structure is computed-projection; bench validation "
        "(XRD lattice refinement · SEM micrograph) = wet-lab boundary "
        "(@D d1 legitimate not-yet).",
        "producer = matter_structure@template — adapter-only emit "
        "(D72) · forwarding to stdlib/mol + stdlib/crystal (the D17 "
        "absorbed substrate) is the next step, not this shim.",
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
        "topology": topology,
        "artifacts": {
            "topology": f"{GEOMETRY_ID}.topology.json",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    topo_path = out / f"{GEOMETRY_ID}.topology.json"
    with open(topo_path, "w", encoding="utf-8") as f:
        json.dump(topology, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "matter",
        "verb": "structure",
        "kind": "matter_structure_record",
        "stamp": stamp,
        "producer": "matter_structure@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "topology": topology,
        "artifacts": {
            "meta": meta_path.name,
            "topology": topo_path.name,
        },
    }
    rec_path = out / f"matter_structure_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "topology_fields": list(topology.keys()),
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "topology": topo_path.name,
        },
    }
    sys.stderr.write("MATTER_STRUCTURE_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/matter_structure"))
