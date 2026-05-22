#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/fib_b2_paper_tensile_parity.py — Phase H gate B-FIB-2.

Anchor: TAPPI T494 (2021) — tensile properties of paper / paperboard.
Bleached softwood kraft, 80 g/m^2 handsheet, baseline tensile index
>= 70 N*m/g per TAPPI T494 with TAPPI T402 conditioning.

Parity: paper/paper.md F-PA-Q1 falsifier row ↔
tests/snapshots/fib_b2_paper_tensile.json. Pass iff spec threshold meets
or exceeds the TAPPI-published minimum.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __FIB_B2_PAPER_TENSILE__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "fib_b2_paper_tensile.json")
SPEC_DOC = os.path.join(ROOT, "paper", "paper.md")
SENTINEL = "__FIB_B2_PAPER_TENSILE__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_min = float(snap["claim"]["min_value"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"Bleached softwood kraft.*?tensile index\s*[>≥]=?\s*([0-9]+)\s*N", text
    )
    if not m:
        print("FAIL: could not locate kraft tensile-index threshold in paper/paper.md F-PA-Q1")
        return 1
    spec_val = float(m.group(1))
    print(f"  spec   paper/paper.md F-PA-Q1 tensile index >= {spec_val} N*m/g")
    print(f"  source TAPPI T494 (2021) baseline           >= {src_min} N*m/g")
    if spec_val < src_min:
        print(f"FAIL: spec threshold {spec_val} < TAPPI T494 baseline {src_min} N*m/g")
        return 1
    print(f"PASS: spec threshold >= TAPPI T494 published baseline {src_min} N*m/g")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: fib_b2_paper_tensile_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
