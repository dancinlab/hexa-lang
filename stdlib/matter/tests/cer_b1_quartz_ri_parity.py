#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b1_quartz_ri_parity.py — Phase I.1 gate B-CER-1.

Anchor: NIST SRM 1960 quartz standard — alpha-quartz n_o (= n_d) = 1.5443
at lambda = 589.3 nm Na-D line, 25 C, ordinary ray. Sosman 1927 / Frondel
1962 secondary references.

Parity: glass/hexa-glass.md F-GL-Q4 row ↔
tests/snapshots/cer_b1_quartz_ri.json. Tolerance: abs 0.003.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B1_QUARTZ_RI__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b1_quartz_ri.json")
SPEC_DOC = os.path.join(ROOT, "glass", "hexa-glass.md")
SENTINEL = "__CER_B1_QUARTZ_RI__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    expected = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"F-GL-Q4.*?n_d\s*=\s*\*\*([0-9]+\.[0-9]+)\*\*", text)
    if not m:
        print("FAIL: could not locate alpha-quartz n_d in glass/hexa-glass.md F-GL-Q4")
        return 1
    spec_val = float(m.group(1))
    delta = abs(spec_val - expected)
    print(f"  spec   glass/hexa-glass.md F-GL-Q4 n_d = {spec_val}")
    print(f"  source NIST SRM 1960 quartz         n_d = {expected}")
    print(f"  delta  = {delta:.4f} (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - NIST| = {delta:.4f} > tolerance {tol}")
        return 1
    print(f"PASS: spec quartz n_d within NIST SRM 1960 tolerance {tol}")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b1_quartz_ri_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
