#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b2_si_density_parity.py — Phase H gate B-CER-2.

Anchor: CRC Handbook of Chemistry and Physics, 105th ed. (2024) —
Si density rho = 2.329 g/cm^3 at 293 K.

Parity check: silicon/silicon.md Si-L6 row claim ↔ vendored snapshot
tests/snapshots/cer_b2_si_density.json. Tolerance: abs 0.002 g/cm^3.

Per Rule 4 SPEC_FIRST: this gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B2_SI_DENSITY__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b2_si_density.json")
SPEC_DOC = os.path.join(ROOT, "silicon", "silicon.md")
SENTINEL = "__CER_B2_SI_DENSITY__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    expected = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"Si density.*?\*\*([0-9]+\.[0-9]+)\s*g/cm", text)
    if not m:
        print("FAIL: could not locate Si density claim in silicon/silicon.md")
        return 1
    spec_val = float(m.group(1))
    delta = abs(spec_val - expected)
    print(f"  spec   silicon/silicon.md Si-L6 = {spec_val} g/cm^3")
    print(f"  source CRC 105th (2024) p.4-87 = {expected} g/cm^3")
    print(f"  delta  = {delta:.4f} g/cm^3 (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - CRC| = {delta:.4f} > tolerance {tol}")
        return 1
    print(f"PASS: spec value within CRC tolerance {tol} g/cm^3")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b2_si_density_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
