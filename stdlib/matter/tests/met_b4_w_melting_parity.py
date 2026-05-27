#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/met_b4_w_melting_parity.py — Phase H gate B-MET-4.

Anchor: CRC Handbook 105th ed. + NIST WebBook — W (tungsten) melting
point T_m = 3422 C (3695 K). Highest among elemental metals.

Parity: LIMIT_BREAKTHROUGH.md refractory melting table 'W | 3695' row ↔
tests/snapshots/met_b4_w_melting.json. Tolerance: abs 1 C (NIST cites
3422 +/- 1 C).

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __MET_B4_W_MELTING__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "met_b4_w_melting.json")
SPEC_DOC = os.path.join(ROOT, "LIMIT_BREAKTHROUGH.md")
SENTINEL = "__MET_B4_W_MELTING__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_K = float(snap["claim"]["value_K"])
    tol_C = float(snap["tolerance"]["abs_C"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"\|\s*W\s*\|\s*([0-9]{4})\s*\|", text)
    if not m:
        print("FAIL: could not locate W melting-point row in LIMIT_BREAKTHROUGH.md")
        return 1
    spec_K = float(m.group(1))
    delta_K = abs(spec_K - src_K)
    print(f"  spec   LIMIT_BREAKTHROUGH.md W = {spec_K} K")
    print(f"  source CRC 105th / NIST       = {src_K} K  (= {src_K - 273.15:.2f} C)")
    print(f"  delta  = {delta_K} K  (tolerance abs {tol_C} C ≈ {tol_C} K)")
    if delta_K > tol_C:
        print(f"FAIL: |spec - CRC/NIST| = {delta_K} K > tolerance {tol_C}")
        return 1
    print(f"PASS: spec W melting point within CRC/NIST tolerance {tol_C} K")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: met_b4_w_melting_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
