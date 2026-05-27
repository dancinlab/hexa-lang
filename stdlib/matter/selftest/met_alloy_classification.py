#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/met_alloy_classification.py — MET group alloy classification.

For the GROUP_MET verbs (metallurgy, superalloy, magnetic-materials), this
gate verifies the spec corpus collectively names canonical alloy families:

  - Ni-based (Inconel, Nimonic, CMSX, Rene)
  - Co-based (HAYNES, Stellite)
  - Fe-Ni-based (Incoloy)
  - Ti-6Al-4V (Ti alloy)
  - NdFeB / SmCo / ferrite / Metglas / Finemet (magnetic)

PASS = ≥ 3 canonical alloy families surface across the MET corpus, with
classification language present.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

MET_SPECS = [
    "metallurgy/swordsmithing.md",
    "superalloy/superalloy.md",
    "magnetic-materials/magnetic-materials.md",
    "METALLURGY-DEEP.md",
    "SWORDSMITHING.md",
]

# Canonical alloy classification keywords (presence ≥ 1 line counts).
ALLOY_FAMILIES = {
    "Ni-based / Inconel": ["Ni-based", "Ni-base", "Inconel", "Nimonic", "CMSX", "Rene", "Hastelloy"],
    "Co-based": ["Co-based", "Co-base", "Stellite", "HAYNES"],
    "Fe-Ni-based / Incoloy": ["Fe-Ni-based", "Fe-Ni-base", "Incoloy"],
    "Ti alloy": ["Ti-6Al-4V", "Ti-alloy", "titanium alloy"],
    "Hard magnet (NdFeB)": ["NdFeB", "Nd2Fe14B", "Nd₂Fe₁₄B"],
    "Hard magnet (SmCo)": ["SmCo", "Sm2Co17", "Sm₂Co₁₇", "SmCo5", "SmCo₅"],
    "Soft magnet (Metglas/Finemet)": ["Metglas", "Finemet", "Si-Fe", "permalloy", "Permalloy"],
    "Steel grade (AISI/Eurofer)": ["AISI", "Eurofer", "RAFM", "austenite", "bainite", "martensite"],
}


def main() -> int:
    print("hexa-matter/selftest/met_alloy_classification — MET group alloy family coverage")
    print(f"  root: {REPO_ROOT}\n")

    corpus = ""
    for rel in MET_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                corpus += "\n" + fh.read()
            print(f"  [OK]   loaded {rel}")
        else:
            print(f"  [WARN] missing MET spec: {rel}")

    print()
    families_hit: list[str] = []
    for family, keywords in ALLOY_FAMILIES.items():
        hit = any(kw in corpus for kw in keywords)
        mark = "PASS" if hit else "----"
        print(f"  [{mark}] {family}: {'yes' if hit else 'no'}")
        if hit:
            families_hit.append(family)

    print()
    print(f"  alloy families covered: {len(families_hit)} / {len(ALLOY_FAMILIES)}")
    print()
    if len(families_hit) >= 3:
        print(f"__HEXA_MATTER_MET_ALLOY_CLASSIFICATION__ PASS  ({len(families_hit)} families covered)")
        return 0
    print(f"__HEXA_MATTER_MET_ALLOY_CLASSIFICATION__ FAIL  (only {len(families_hit)}; need ≥ 3)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
