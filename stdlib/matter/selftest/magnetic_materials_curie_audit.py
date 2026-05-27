#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/magnetic_materials_curie_audit.py — magnetic-materials Curie + BHmax.

For the magnetic-materials verb spec, verify:

  (a) Curie temperature T_c (or "Curie") is cited for ≥ 1 hard magnet (NdFeB,
      SmCo) with numerical anchor (°C or K)
  (b) BHmax / (BH)_max with MGOe or kJ/m³ unit cited for NdFeB / SmCo / ferrite
  (c) References: Hitachi Metals, TDK, Arnold, Vacuumschmelze, Coey, or similar

Per LATTICE_POLICY §1.2: magnetic parameters are physics, vendor-anchored. No lattice fit.

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

SPEC = os.path.join(REPO_ROOT, "magnetic-materials", "magnetic-materials.md")

CURIE_PATTERN = re.compile(
    r"Curie.{0,120}?(\d{2,4})\s*°?\s*(K|C|°C)",
    re.IGNORECASE | re.DOTALL,
)

BHMAX_PATTERN = re.compile(
    r"\(?BH\)?[_·]*\s*max.{0,200}?(\d+(?:\.\d+)?)\s*(MGOe|kJ/m³|kJ/m\^3|kJ/m3)",
    re.IGNORECASE | re.DOTALL,
)

ANCHORS = ["Hitachi Metals", "TDK", "Arnold", "Vacuumschmelze", "Coey", "datasheet", "Stoner-Wohlfarth"]


def main() -> int:
    print("hexa-matter/selftest/magnetic_materials_curie_audit — NdFeB/SmCo Curie + BHmax")
    print(f"  spec: {SPEC}\n")

    if not os.path.exists(SPEC):
        print("  [FAIL] magnetic-materials.md missing")
        print("__HEXA_MATTER_MAGNETIC_CURIE__ FAIL")
        return 1

    with open(SPEC, "r", encoding="utf-8", errors="ignore") as fh:
        text = fh.read()

    fail = 0
    curie_m = CURIE_PATTERN.search(text)
    if curie_m:
        print(f"  [PASS] Curie anchor: {curie_m.group(0)[:80].strip()}")
    else:
        print("  [FAIL] no Curie temperature anchor (need '<N> K' or '<N> °C')")
        fail += 1

    bh_m = BHMAX_PATTERN.search(text)
    if bh_m:
        print(f"  [PASS] (BH)_max anchor: {bh_m.group(0)[:80].strip()}")
    else:
        print("  [FAIL] no (BH)_max numeric anchor with MGOe / kJ/m³ unit")
        fail += 1

    # Material-name presence
    materials = ["NdFeB", "Nd₂Fe₁₄B", "Nd2Fe14B", "SmCo", "SmCo₅", "SmCo5", "Sm₂Co₁₇", "Sm2Co17"]
    mat_found = [m for m in materials if m in text]
    if mat_found:
        print(f"  [PASS] hard-magnet families named: {mat_found}")
    else:
        print(f"  [FAIL] no NdFeB / SmCo family name in spec")
        fail += 1

    anchors_found = [a for a in ANCHORS if a in text]
    if len(anchors_found) >= 1:
        print(f"  [PASS] reference anchors: {anchors_found[:4]}")
    else:
        print(f"  [FAIL] no vendor / canonical-text reference anchor")
        fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_MAGNETIC_CURIE__ FAIL  ({fail} missing)")
        return 1
    print("__HEXA_MATTER_MAGNETIC_CURIE__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
