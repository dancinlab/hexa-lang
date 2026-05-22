#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b4_sic_bandgap_parity.py — Phase H gate B-CER-4.

Anchor: Saddow & Agarwal 2004 (Artech House) — 4H-SiC E_g = 3.26 eV;
6H-SiC E_g = 3.02 eV.

Parity: silicon/silicon.md Si-L11 row ↔ tests/snapshots/cer_b4_sic_bandgap.json.
Tolerance: abs 0.05 eV (covers literature spread 3.23-3.28 eV for 4H-SiC).

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B4_SIC_BANDGAP__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b4_sic_bandgap.json")
SPEC_DOC = os.path.join(ROOT, "silicon", "silicon.md")
SENTINEL = "__CER_B4_SIC_BANDGAP__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    expected = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"\*\*([0-9]+\.[0-9]+)\s*eV\s*\(4H-SiC\)\*\*", text)
    if not m:
        print("FAIL: could not locate 4H-SiC bandgap claim in silicon/silicon.md")
        return 1
    spec_val = float(m.group(1))
    delta = abs(spec_val - expected)
    print(f"  spec   silicon/silicon.md Si-L11 = {spec_val} eV (4H-SiC)")
    print(f"  source Saddow & Agarwal 2004    = {expected} eV (4H-SiC)")
    print(f"  delta  = {delta:.4f} eV (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - Saddow| = {delta:.4f} > tolerance {tol}")
        return 1
    print(f"PASS: spec value within Saddow & Agarwal tolerance {tol} eV")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b4_sic_bandgap_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
