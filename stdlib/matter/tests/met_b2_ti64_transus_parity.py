#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/met_b2_ti64_transus_parity.py — Phase I.1 gate B-MET-2.

Anchor: ASM Handbook vol. 2 (1990) — Ti-6Al-4V (Grade 5) alpha-beta
transformation temperature (beta-transus) = 995 +/- 15 C (1268 K).

Parity: METALLURGY-DEEP.md §4.3 'β-transus (°C) | 995 ± 15' row ↔
tests/snapshots/met_b2_ti64_transus.json. Tolerance: abs 15 C.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __MET_B2_TI64_TRANSUS__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "met_b2_ti64_transus.json")
SPEC_DOC = os.path.join(ROOT, "METALLURGY-DEEP.md")
SENTINEL = "__MET_B2_TI64_TRANSUS__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_T = float(snap["claim"]["T_C"])
    tol = float(snap["tolerance"]["abs_C"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"β-transus.*?\|\s*([0-9]+)\s*±\s*([0-9]+)",
        text,
    )
    if not m:
        print("FAIL: could not locate β-transus row in METALLURGY-DEEP.md §4.3")
        return 1
    spec_val = float(m.group(1))
    spec_tol = float(m.group(2))
    delta = abs(spec_val - src_T)
    print(f"  spec   METALLURGY-DEEP.md §4.3 β-transus = {spec_val} ± {spec_tol} C")
    print(f"  source ASM Handbook vol. 2 Ti-6Al-4V    = {src_T} ± {tol} C ({snap['claim']['T_K']} K)")
    print(f"  delta  = {delta} C (tolerance abs {tol})")
    if delta > tol:
        print(f"FAIL: |spec - ASM| = {delta} > tolerance {tol} C")
        return 1
    if spec_tol != tol:
        print(f"FAIL: spec tolerance ± {spec_tol} != source tolerance ± {tol}")
        return 1
    print(f"PASS: spec Ti-6Al-4V β-transus within ASM tolerance {tol} C")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: met_b2_ti64_transus_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
