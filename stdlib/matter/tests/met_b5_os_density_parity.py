#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/met_b5_os_density_parity.py — Phase H gate B-MET-5.

Anchor: CRC Handbook 105th ed. + NIST WebBook — Os (osmium) density
rho = 22.59 g/cm^3 at 293 K. Highest-density stable element
(Ir 22.56 within combined uncertainty).

Parity: LIMIT_BREAKTHROUGH.md L6 row '22.59 g/cm^3' ↔
tests/snapshots/met_b5_os_density.json. Tolerance: abs 0.02 g/cm^3.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __MET_B5_OS_DENSITY__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "met_b5_os_density.json")
SPEC_DOC = os.path.join(ROOT, "LIMIT_BREAKTHROUGH.md")
SENTINEL = "__MET_B5_OS_DENSITY__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    expected = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"Osmium\s*[ρρ]?\s*=\s*([0-9]+\.[0-9]+)\s*g/cm", text)
    if not m:
        # Try alt: "ρ of Os = 22.59 g/cm³"
        m = re.search(r"ρ\s*of\s*Os\s*=\s*([0-9]+\.[0-9]+)\s*g/cm", text)
    if not m:
        print("FAIL: could not locate Os density claim in LIMIT_BREAKTHROUGH.md")
        return 1
    spec_val = float(m.group(1))
    delta = abs(spec_val - expected)
    print(f"  spec   LIMIT_BREAKTHROUGH.md L6 = {spec_val} g/cm^3")
    print(f"  source CRC 105th / NIST WebBook = {expected} g/cm^3")
    print(f"  delta  = {delta:.4f} g/cm^3 (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - CRC/NIST| = {delta:.4f} > tolerance {tol}")
        return 1
    print(f"PASS: spec Os density within CRC/NIST tolerance {tol} g/cm^3")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: met_b5_os_density_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
