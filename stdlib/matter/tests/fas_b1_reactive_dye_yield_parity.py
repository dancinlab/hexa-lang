#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/fas_b1_reactive_dye_yield_parity.py — Phase I.1 gate B-FAS-1.

Anchor: ISO 105-X12 + ICI Procion-H technical manual + Aspland 1997
'Textile Dyeing and Coloration' (AATCC) — reactive dye covalent yield
>= 60 % on cellulose at 60 C, pH 11 (Na2CO3 alkali fixation).

Parity: hexa-fashion/fashion-architecture.md §3.1 Reactive dye F-FAS-Q1
falsifier ↔ tests/snapshots/fas_b1_reactive_dye_yield.json. Threshold:
spec must claim >= 60 %.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __FAS_B1_REACTIVE_DYE_YIELD__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "fas_b1_reactive_dye_yield.json")
SPEC_DOC = os.path.join(ROOT, "hexa-fashion", "fashion-architecture.md")
SENTINEL = "__FAS_B1_REACTIVE_DYE_YIELD__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    thr = float(snap["tolerance"]["min_threshold_pct"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"F-FAS-Q1.*?covalent yield\s*≥\s*\*\*([0-9]+)\s*%\*\*\s*on cellulose.*?60\s*°C.*?pH\s*11",
        text,
        re.S,
    )
    if not m:
        print("FAIL: could not locate F-FAS-Q1 reactive-dye yield claim in fashion-architecture.md §3.1")
        return 1
    spec_val = float(m.group(1))
    print(f"  spec   fashion-architecture.md §3.1 F-FAS-Q1 = >= {spec_val} % at 60 C, pH 11")
    print(f"  source ISO 105-X12 + ICI Procion-H + Aspland = >= {thr} % at 60 C, pH 11")
    if spec_val < thr:
        print(f"FAIL: spec covalent yield {spec_val} % < threshold {thr} %")
        return 1
    print(f"PASS: spec reactive-dye covalent yield meets ISO 105-X12 threshold >= {thr} %")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: fas_b1_reactive_dye_yield_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
