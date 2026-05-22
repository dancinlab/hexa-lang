#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/gem_b1_corundum_ri_parity.py — Phase H gate B-GEM-1.

Anchor: GIA corundum identification chart + NIST gem-RI tables —
corundum (Al2O3, ruby + sapphire) refractive index n_d in 1.762-1.770
at 589.3 nm Na-D line, 25 C.

Parity: gemology/gemology.md F-GEM-Q1 falsifier row ↔
tests/snapshots/gem_b1_corundum_ri.json. Pass iff spec range matches the
GIA-published 1.762-1.770 band.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __GEM_B1_CORUNDUM_RI__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "gem_b1_corundum_ri.json")
SPEC_DOC = os.path.join(ROOT, "gemology", "gemology.md")
SENTINEL = "__GEM_B1_CORUNDUM_RI__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_lo = float(snap["claim"]["range_min"])
    src_hi = float(snap["claim"]["range_max"])
    tol = float(snap["tolerance"]["extension_abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"Corundum.*?n_d\s*in\s*([0-9]+\.[0-9]+)[\s\-–]+([0-9]+\.[0-9]+)", text
    )
    if not m:
        print("FAIL: could not locate corundum n_d range in gemology/gemology.md F-GEM-Q1")
        return 1
    spec_lo = float(m.group(1))
    spec_hi = float(m.group(2))
    lo_delta = abs(spec_lo - src_lo)
    hi_delta = abs(spec_hi - src_hi)
    print(f"  spec   gemology/gemology.md F-GEM-Q1 n_d = {spec_lo}-{spec_hi}")
    print(f"  source GIA / NIST gem-RI            n_d = {src_lo}-{src_hi}")
    print(f"  delta lo={lo_delta:.4f}  hi={hi_delta:.4f}  (tolerance {tol})")
    if lo_delta > tol or hi_delta > tol:
        print(f"FAIL: corundum n_d range delta > tolerance {tol}")
        return 1
    print(f"PASS: spec corundum n_d range within GIA/NIST tolerance {tol}")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: gem_b1_corundum_ri_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
