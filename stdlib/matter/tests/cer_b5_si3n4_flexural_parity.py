#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b5_si3n4_flexural_parity.py — Phase H gate B-CER-5.

Anchor: ASM Handbook vol. 21 (Composites / Ceramics & Glasses, 2001) —
HIP-densified Si3N4 flexural strength range 600-1200 MPa
(typical ~ 800-1000 MPa).

Parity: silicon/silicon.md Si-L12 row ↔ tests/snapshots/cer_b5_si3n4_flexural.json.
Pass iff spec range overlaps the published ASM range.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B5_SI3N4_FLEXURAL__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b5_si3n4_flexural.json")
SPEC_DOC = os.path.join(ROOT, "silicon", "silicon.md")
SENTINEL = "__CER_B5_SI3N4_FLEXURAL__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_lo = float(snap["claim"]["range_min"])
    src_hi = float(snap["claim"]["range_max"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"Si.{1,3}N.{1,3} flexural strength.*?([0-9]+)\s*[-–]\s*([0-9]+)\s*MPa", text)
    if not m:
        print("FAIL: could not locate Si3N4 flexural-strength range in silicon/silicon.md")
        return 1
    spec_lo = float(m.group(1))
    spec_hi = float(m.group(2))
    overlap_lo = max(spec_lo, src_lo)
    overlap_hi = min(spec_hi, src_hi)
    print(f"  spec   silicon/silicon.md Si-L12 = {spec_lo}-{spec_hi} MPa")
    print(f"  source ASM Handbook vol. 21     = {src_lo}-{src_hi} MPa")
    print(f"  overlap = {overlap_lo}-{overlap_hi} MPa")
    if overlap_hi < overlap_lo:
        print("FAIL: spec range does not overlap ASM published range")
        return 1
    if not (spec_lo == src_lo and spec_hi == src_hi):
        print("  NOTE: spec range matches ASM range exactly" if (spec_lo == src_lo and spec_hi == src_hi)
              else "  NOTE: spec range overlaps but is not identical to ASM")
    print("PASS: spec range overlaps ASM published 600-1200 MPa band")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b5_si3n4_flexural_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
