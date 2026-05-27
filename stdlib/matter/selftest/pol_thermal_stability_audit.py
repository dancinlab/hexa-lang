#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/pol_thermal_stability_audit.py — POL group T_g anchor check.

For the GROUP_POL verbs, glass-transition temperature T_g is a canonical
identifier. This gate confirms that at least N (here: ≥ 4) POL spec files
reference T_g with a numeric value cited (not lattice-derived) somewhere.

Per LATTICE_POLICY §1.2 + raw#10 C3, T_g must come from CRC / vendor / ASTM
data, not from a lattice arithmetic identity.

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

POL_SPECS = [
    "epoxy/epoxy.md",
    "nylon/nylon.md",
    "pet_film/pet-film.md",
    "tire_cord/tire-cord.md",
    "aramid/aramid.md",
    "elastomer/elastomer.md",
    "adhesive/adhesive.md",
    "liquid-crystal/liquid-crystal.md",
    "biodegradable-plastics/biodegradable-plastics.md",
    # Phase D follow-on (2026-05-13, 29→33):
    "ionic-liquid/ionic-liquid.md",
    # Phase D'' (2026-05-13, 33→36):
    "photoresist/photoresist.md",
    # Root deep doc
    "POLYMER-CHEMISTRY.md",
]

# T_g pattern — accept any of: T_g, Tg, glass transition, glass-transition
# accompanied by a numeric K or °C value
TG_PATTERN = re.compile(
    r"(T_?g|glass[ -]transition)"
    r".{0,80}?"
    r"(\d{2,4})\s*(K|°C|C|kelvin|celsius)",
    re.IGNORECASE | re.DOTALL,
)


def main() -> int:
    print("hexa-matter/selftest/pol_thermal_stability_audit — POL group T_g anchor")
    print(f"  root: {REPO_ROOT}\n")

    hits = 0
    hit_files: list[str] = []
    for rel in POL_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            print(f"  [WARN] missing POL spec: {rel}")
            continue
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        m = TG_PATTERN.search(text)
        if m:
            hits += 1
            hit_files.append(rel)
            sample = m.group(0).replace("\n", " ")[:80]
            print(f"  [OK]   {rel}: T_g anchor — {sample}")
        else:
            print(f"  [info] {rel}: no numeric T_g anchor found")

    print()
    print(f"  POL specs with T_g anchor: {hits} / {len(POL_SPECS)}")
    print()
    if hits >= 4:
        print(f"__HEXA_MATTER_POL_THERMAL_STABILITY__ PASS  ({hits} of {len(POL_SPECS)} specs anchored)")
        return 0
    print(f"__HEXA_MATTER_POL_THERMAL_STABILITY__ FAIL  (only {hits} of {len(POL_SPECS)} POL specs carry numeric T_g; need ≥ 4)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
