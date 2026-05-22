#!/usr/bin/env python3
# design.py — `matter + design` producer (thin in-silico shim ·
# D17 consumer-pointer · D72 adapter-only · D111 cellrun-compatible ·
# D106 illustrative-physics).
#
# Emits a TEMPLATE alloy / composite / heterostructure design-space
# scaffold (per matter.demi [cell.design] scope_caveats). NO inverse-
# design (ALDS) is performed, NO active-learning loop driven; the
# output is a placeholder design-space surface a downstream (future)
# hexa-matter / hexa-mlff backed design cell would fill.
#
# Honesty (g3 · D106 · project.tape @D d1):
#   - measurement_gate = GATE_OPEN permanently
#   - absorbed = false permanently (illustrative · D106 · RFC 013 §6.12)
#   - producer = "matter_design@template"
#
# Pattern: mirrors stdlib/firmware/design.py.

from __future__ import annotations

import json
import platform
import sys
import time
from pathlib import Path

GEOMETRY_ID = "matter_design_v1"


def _build_design_space_template() -> dict:
    """Materials design-space scaffold — alloy / composite / hetero-
    structure parameter axes a real inverse-design (ALDS · diffusion-
    model · BO) loop would explore.
    """
    return {
        "design_class": None,           # alloy | composite | heterostructure
        "search_axes": [
            # {"name": ..., "range": [...], "units": ..., "type": ...}
        ],
        "objective": {
            "kind": None,               # multi-objective | scalarized
            "targets": [],              # [{property, direction, weight}]
            "constraints": [],
        },
        "method": {
            "engine": None,             # ALDS | BO | DiffusionModel | GA
            "budget_evals": None,
            "seed_dataset": None,       # OQMD | MaterialsProject | custom
        },
        "candidates": [],               # populated by downstream run
        "notes": (
            "Design-space scaffold — inverse-design engine binding "
            "(ALDS / BO / diffusion model) is downstream substrate "
            "territory (hexa-matter sibling 의 design surface 후보 · "
            "NOT this shim)."
        ),
    }


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    produced_at_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    design_space = _build_design_space_template()
    measurements: dict = {}

    citations = [
        "domains/matter.md — material-family matrix narrative.",
        "domains/matter/README.md — D17 hexa-matter absorbed into "
        "hexa-lang stdlib/mol + stdlib/crystal + stdlib/mlff.",
        "ALDS (Active Learning for Drug / materials Discovery) — "
        "general inverse-design pattern.",
        "Bayesian Optimization for materials — standard reference.",
    ]
    scope_caveats = [
        "matter + design is an illustrative TEMPLATE emit "
        "(D106 illustrative-physics · RFC 013 §6.12) — alloy / "
        "composite / heterostructure design-space scaffold with NO "
        "inverse-design engine bound.",
        "absorbed = false PERMANENTLY (g3 · D106) — a generated "
        "candidate set is computed-projection; bench synthesis + "
        "measurement of any candidate = wet-lab boundary "
        "(@D d1 legitimate not-yet).",
        "producer = matter_design@template — adapter-only emit (D72) "
        "· forwarding to hexa-matter sibling's design surface (or to "
        "stdlib/mlff active-learning) is the next step, not this shim.",
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
        "design_space": design_space,
        "artifacts": {
            "design_space": f"{GEOMETRY_ID}.design_space.json",
        },
    }
    meta_path = out / f"{GEOMETRY_ID}.meta.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
        f.write("\n")

    ds_path = out / f"{GEOMETRY_ID}.design_space.json"
    with open(ds_path, "w", encoding="utf-8") as f:
        json.dump(design_space, f, indent=2, sort_keys=True)
        f.write("\n")

    record = {
        "domain": "matter",
        "verb": "design",
        "kind": "matter_design_record",
        "stamp": stamp,
        "producer": "matter_design@template",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "skipped_reason": None,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "design_space": design_space,
        "artifacts": {
            "meta": meta_path.name,
            "design_space": ds_path.name,
        },
    }
    rec_path = out / f"matter_design_{stamp}.json"
    with open(rec_path, "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2, sort_keys=True)
        f.write("\n")

    summary = {
        "ok": True,
        "geometry_id": GEOMETRY_ID,
        "gate_type": "hexa-native-absent",
        "provisional": True,
        "design_space_fields": list(design_space.keys()),
        "artifacts": {
            "record": rec_path.name,
            "meta": meta_path.name,
            "design_space": ds_path.name,
        },
    }
    sys.stderr.write("MATTER_DESIGN_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/matter_design"))
