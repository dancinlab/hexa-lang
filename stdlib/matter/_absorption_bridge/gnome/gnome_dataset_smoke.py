#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gnome_dataset_smoke.py — DeepMind GNoME dataset adapter (offline schema replay).

Status: PARTIAL (offline fixture replay PASS; live Zenodo download OUT-OF-SCOPE).

GNoME = Graph Networks for Materials Exploration (Merchant et al. 2023 Nature).
2.2M PREDICTED stable inorganic crystals — NOT synthesized. This adapter
validates the per-record schema against the bundled fixture.

UNPROVEN preservation (per INIT.md Phase G hard rule 4):
  Every GNoME record carries `is_synthesized: false` and a `synthesis_status`
  field. The adapter enforces these markers are present.

predictions. They carry their OWN published error bars (formation-energy
MAE ~20 meV/atom per Merchant et al. 2023 supplementary).

License: MIT (hexa-matter Phase G).
"""

from __future__ import annotations
import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CACHE_DIR = HERE / "cache"
SAMPLE_FIXTURE = CACHE_DIR / "sample_record.json"


def load_fixture(path: Path = SAMPLE_FIXTURE) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_gnome_record(rec: dict) -> tuple[bool, str]:
    """Schema-validate a GNoME record.

    Required: gnome_id, composition, predicted_formation_energy_per_atom_eV,
    predicted_energy_above_hull_eV_per_atom, structure, is_synthesized.
    """
    required = [
        "gnome_id",
        "composition",
        "predicted_formation_energy_per_atom_eV",
        "predicted_energy_above_hull_eV_per_atom",
        "structure",
        "is_synthesized",
    ]
    for k in required:
        if k not in rec:
            return False, f"missing required field: {k}"

    # Hard-rule check: GNoME records must explicitly mark NOT synthesized.
    if rec["is_synthesized"] is True:
        return False, "is_synthesized=True for GNoME record (should be False — predictions only)"
    if "synthesis_status" not in rec:
        return False, "missing synthesis_status (UNPROVEN preservation)"
    if "UNPROVEN" not in rec["synthesis_status"] and "predict" not in rec["synthesis_status"].lower():
        return False, f"synthesis_status missing UNPROVEN / prediction marker: {rec['synthesis_status']!r}"

    if "lattice" not in rec["structure"] or "a" not in rec["structure"]["lattice"]:
        return False, "structure.lattice.a missing"
    return True, "ok"


def md5_stamp(payload: Any) -> str:
    blob = json.dumps(payload, sort_keys=True).encode("utf-8")
    return hashlib.md5(blob).hexdigest()[:12]


def _selftest() -> int:
    if not SAMPLE_FIXTURE.exists():
        print(f"  FAIL: fixture not found at {SAMPLE_FIXTURE}")
        print("__HEXA_MATTER_GNOME_DATASET_SMOKE__ FAIL")
        return 1

    try:
        rec = load_fixture()
    except Exception as e:
        print(f"  FAIL: fixture load raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_GNOME_DATASET_SMOKE__ FAIL")
        return 1

    ok, reason = validate_gnome_record(rec)
    if not ok:
        print(f"  FAIL: schema check: {reason}")
        print("__HEXA_MATTER_GNOME_DATASET_SMOKE__ FAIL")
        return 1
    print(f"  PASS: fixture schema OK (gnome_id={rec['gnome_id']}, comp={rec['composition']})")
    print(f"  PASS: synthesis_status UNPROVEN marker preserved")

    stamp = md5_stamp(rec)
    print(f"  PASS: md5 cache stamp = {stamp}")
    print("  NOTE: live Zenodo (DOI 10.5281/zenodo.10371563) download is a runtime concern, not selftest")
    print("__HEXA_MATTER_GNOME_DATASET_SMOKE__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
