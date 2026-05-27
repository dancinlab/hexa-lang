#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b1_aramid_tensile_parity.py — Phase H gate B-POL-1.

Anchor: ASTM D885 + DuPont Kevlar 49 technical datasheet + ASM Handbook
vol. 21 — Kevlar 49 single-fiber tensile strength sigma_f >= 3.0 GPa.

Parity: aramid/aramid.md F-AR-Q1 falsifier row ↔
tests/snapshots/pol_b1_aramid_tensile.json. Pass iff spec threshold meets
or exceeds the standard's published minimum.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __POL_B1_ARAMID_TENSILE__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b1_aramid_tensile.json")
SPEC_DOC = os.path.join(ROOT, "aramid", "aramid.md")
SENTINEL = "__POL_B1_ARAMID_TENSILE__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_min = float(snap["claim"]["min_value"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"Kevlar 49 tensile.{0,40}[σs]_?f\s*[>≥]=?\s*([0-9]+\.[0-9]+)\s*GPa", text
    )
    if not m:
        print("FAIL: could not locate Kevlar 49 tensile threshold in aramid/aramid.md F-AR-Q1")
        return 1
    spec_val = float(m.group(1))
    print(f"  spec   aramid/aramid.md F-AR-Q1 sigma_f >= {spec_val} GPa")
    print(f"  source ASTM D885 / DuPont Kevlar 49 baseline >= {src_min} GPa")
    if spec_val < src_min:
        print(f"FAIL: spec threshold {spec_val} < ASTM D885 baseline {src_min} GPa")
        return 1
    print(f"PASS: spec threshold >= ASTM D885 / DuPont Kevlar 49 baseline {src_min} GPa")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b1_aramid_tensile_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
