#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b3_si_bandgap_parity.py — Phase H gate B-CER-3.

Anchor: NIST WebBook + Sze 3rd ed. (2007) — Si indirect bandgap
E_g = 1.12 eV at 300 K.

Parity: silicon/silicon.md Si-L7 row ↔ tests/snapshots/cer_b3_si_bandgap.json.
Tolerance: abs 0.02 eV (Varshni T-dependent spread).

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B3_SI_BANDGAP__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b3_si_bandgap.json")
SPEC_DOC = os.path.join(ROOT, "silicon", "silicon.md")
SENTINEL = "__CER_B3_SI_BANDGAP__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    expected = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"Si bandgap.*?\*\*([0-9]+\.[0-9]+)\s*eV", text)
    if not m:
        print("FAIL: could not locate Si bandgap claim in silicon/silicon.md")
        return 1
    spec_val = float(m.group(1))
    delta = abs(spec_val - expected)
    print(f"  spec   silicon/silicon.md Si-L7 = {spec_val} eV")
    print(f"  source NIST WebBook + Sze 3rd  = {expected} eV (300 K)")
    print(f"  delta  = {delta:.4f} eV (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - NIST| = {delta:.4f} > tolerance {tol}")
        return 1
    print(f"PASS: spec value within NIST/Sze tolerance {tol} eV")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b3_si_bandgap_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
