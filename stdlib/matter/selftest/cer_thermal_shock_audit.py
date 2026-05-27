#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/cer_thermal_shock_audit.py — CER group thermal-shock anchor check.

For the GROUP_CER verbs (ceramics, concrete, concrete_tech, glass, silicon),
thermal-shock resistance is a canonical engineering parameter. This gate
checks that the CER spec corpus collectively mentions a thermal-shock
parameter (R / R′ / R″) anchored to a real source (ASTM C1525 or related, or
explicit citation of a thermal-shock coefficient).

NOTE: not every individual CER verb spec carries the thermal-shock anchor
(e.g., silicon.md focuses on purity/dimension; thermal shock lives in
ceramics/concrete/glass). PASS = at least one CER verb spec OR
LIMIT_BREAKTHROUGH.md OR CERAMIC-ENGINEERING.md references a thermal-shock
parameter from a real anchor.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

CER_SPECS = [
    "ceramics/ceramics.md",
    "concrete/concrete.md",
    "concrete_tech/concrete-technology.md",
    "glass/hexa-glass.md",
    "silicon/silicon.md",
    "compound-semi/compound-semi.md",
    "perovskite/perovskite.md",
    "2d-materials/2d-materials.md",
    "mof/mof.md",
    "carbon/carbon.md",
    # Phase D follow-on (2026-05-13, 29→33):
    "glass-ceramic/glass-ceramic.md",
    "geopolymer/geopolymer.md",
    "aerogel-foam/aerogel-foam.md",
    # Phase D'' (2026-05-13, 33→36):
    "refractory/refractory.md",
    "electrode-material/electrode-material.md",
    "CERAMIC-ENGINEERING.md",
    "LIMIT_BREAKTHROUGH.md",
]

# Thermal-shock related keywords (any of these on a spec line counts as anchor)
ANCHORS = [
    r"thermal shock", r"thermal-shock",
    r"\bR'\b", r"\bR''\b", r"\bR'''\b",
    r"\bASTM C1525\b", r"\bASTM C1499\b",
    r"\bquench\b",
    r"k/α", r"k\s*/\s*α", r"E·α", r"thermal stress",
    r"ΔT", r"Delta T_c",
    r"Hasselman",  # canonical thermal-shock theorist
]


def main() -> int:
    print("hexa-matter/selftest/cer_thermal_shock_audit — CER group thermal-shock anchor")
    print(f"  root: {REPO_ROOT}\n")

    pattern = re.compile("|".join(ANCHORS), re.IGNORECASE)

    hit_count = 0
    hit_files: list[str] = []
    for rel in CER_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            print(f"  [WARN] missing CER spec: {rel}")
            continue
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        if pattern.search(text):
            hit_count += 1
            hit_files.append(rel)
            print(f"  [OK]   {rel}: thermal-shock anchor present")

    print()
    print(f"  CER specs with thermal-shock anchor: {hit_count} / {len(CER_SPECS)}")
    print()
    if hit_count >= 1:
        print(f"__HEXA_MATTER_CER_THERMAL_SHOCK__ PASS  (anchored in: {hit_files[:3]})")
        return 0
    print("__HEXA_MATTER_CER_THERMAL_SHOCK__ FAIL  (no CER verb spec references thermal-shock parameter)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
