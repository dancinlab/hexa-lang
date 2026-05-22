#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b2_pet_hydrolysis_ea_parity.py — Phase I.1 gate B-POL-2.

Anchor: Marshall et al. 1988 + Toray PET film datasheet — PET ester-bond
hydrolysis activation energy Ea = 75-100 kJ/mol under acidic conditions,
85 C; first-order kinetics on ester bond cleavage.

Parity: POLYMER-CHEMISTRY.md §4.1 ester block 'E_a ≈ 80-100 kJ/mol
(Marshall et al. 1988)' ↔ tests/snapshots/pol_b2_pet_hydrolysis_ea.json.
Tolerance: ± 10 kJ/mol on each endpoint of the 75-100 band.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __POL_B2_PET_HYDROLYSIS_EA__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b2_pet_hydrolysis_ea.json")
SPEC_DOC = os.path.join(ROOT, "POLYMER-CHEMISTRY.md")
SENTINEL = "__POL_B2_PET_HYDROLYSIS_EA__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_lo = float(snap["claim"]["Ea_kJ_per_mol_min"])
    src_hi = float(snap["claim"]["Ea_kJ_per_mol_max"])
    tol = float(snap["tolerance"]["Ea_band_abs_kJ_per_mol"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"PET hydrolysis kinetics.*?E_a\s*[≈~]\s*([0-9]+)\s*-\s*([0-9]+)\s*kJ/mol",
        text,
    )
    if not m:
        print("FAIL: could not locate PET hydrolysis E_a range in POLYMER-CHEMISTRY.md §4.1")
        return 1
    spec_lo = float(m.group(1))
    spec_hi = float(m.group(2))
    lo_delta = abs(spec_lo - src_lo)
    hi_delta = abs(spec_hi - src_hi)
    print(f"  spec   POLYMER-CHEMISTRY.md §4.1 E_a = {spec_lo}-{spec_hi} kJ/mol")
    print(f"  source Marshall 1988 + Toray         = {src_lo}-{src_hi} kJ/mol")
    print(f"  delta  lo={lo_delta} hi={hi_delta} (tolerance abs {tol})")
    if lo_delta > tol or hi_delta > tol:
        print(f"FAIL: PET E_a range delta > tolerance {tol} kJ/mol")
        return 1
    print(f"PASS: spec PET E_a range within Marshall/Toray tolerance ± {tol} kJ/mol")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b2_pet_hydrolysis_ea_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
