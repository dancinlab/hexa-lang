#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/gem_b2_ruby_rline_parity.py — Phase I.1 gate B-GEM-2.

Anchor: NIST gem identification reference + Sugano-Tanabe-Kamimura 1970
('Multiplets of Transition-Metal Ions in Crystals') — natural ruby Cr3+
R1-line fluorescence at 694.3 +/- 0.3 nm at 300 K under 532 nm or 405 nm
laser excitation, calibrated spectrometer (resolution <= 0.2 nm).

Parity: gemology/gemology.md F-GEM-Q3 falsifier row ↔
tests/snapshots/gem_b2_ruby_rline.json. Tolerance: abs 0.3 nm.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __GEM_B2_RUBY_RLINE__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "gem_b2_ruby_rline.json")
SPEC_DOC = os.path.join(ROOT, "gemology", "gemology.md")
SENTINEL = "__GEM_B2_RUBY_RLINE__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_val = float(snap["claim"]["value_nm"])
    tol = float(snap["tolerance"]["abs_nm"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"F-GEM-Q3.*?R₁-line fluorescence at\s*([0-9]+\.[0-9]+)\s*±\s*([0-9]+\.[0-9]+)\s*nm",
        text,
    )
    if not m:
        print("FAIL: could not locate ruby R1 line claim in gemology/gemology.md F-GEM-Q3")
        return 1
    spec_val = float(m.group(1))
    spec_tol = float(m.group(2))
    delta = abs(spec_val - src_val)
    print(f"  spec   gemology/gemology.md F-GEM-Q3 R1 = {spec_val} ± {spec_tol} nm")
    print(f"  source NIST / Sugano-Tanabe-Kamimura    = {src_val} ± {tol} nm")
    print(f"  delta  = {delta:.4f} nm (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - NIST| = {delta:.4f} > tolerance {tol} nm")
        return 1
    if spec_tol > tol:
        print(f"FAIL: spec ± {spec_tol} loosens NIST ± {tol}")
        return 1
    print(f"PASS: spec ruby R1 within NIST/Sugano tolerance {tol} nm")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: gem_b2_ruby_rline_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
