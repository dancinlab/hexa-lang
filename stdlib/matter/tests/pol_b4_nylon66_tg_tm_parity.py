#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b4_nylon66_tg_tm_parity.py — Phase H gate B-POL-4.

Anchor: ASM Engineered Materials Handbook vol. 2 (Engineering Plastics,
1988) + CRC Handbook 105th ed. — Nylon-6,6 (PA66) Tg ~ 50 C, Tm ~ 265 C.

Parity: POLYMER-CHEMISTRY.md §3.2 'Nylon-6,6 | 50-65 | 265' row ↔
tests/snapshots/pol_b4_nylon66_tg_tm.json. Tolerance: Tg +/- 5 C, Tm +/- 3 C.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __POL_B4_NYLON66_TG_TM__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b4_nylon66_tg_tm.json")
SPEC_DOC = os.path.join(ROOT, "POLYMER-CHEMISTRY.md")
SENTINEL = "__POL_B4_NYLON66_TG_TM__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_tg_lo = float(snap["claim"]["Tg_C_range_min"])
    src_tg_hi = float(snap["claim"]["Tg_C_range_max"])
    src_tm = float(snap["claim"]["Tm_C"])
    tg_tol = float(snap["tolerance"]["Tg_abs_C"])
    tm_tol = float(snap["tolerance"]["Tm_abs_C"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"Nylon-6,6\s*\|\s*([0-9]+)\s*-\s*([0-9]+)\s*\|\s*([0-9]+)", text)
    if not m:
        print("FAIL: could not locate Nylon-6,6 row in POLYMER-CHEMISTRY.md §3.2")
        return 1
    spec_tg_lo = float(m.group(1))
    spec_tg_hi = float(m.group(2))
    spec_tm = float(m.group(3))
    tg_lo_delta = abs(spec_tg_lo - src_tg_lo)
    tg_hi_delta = abs(spec_tg_hi - src_tg_hi)
    tm_delta = abs(spec_tm - src_tm)
    print(f"  spec   POLYMER-CHEMISTRY.md §3.2 Nylon-6,6 Tg={spec_tg_lo}-{spec_tg_hi} C, Tm={spec_tm} C")
    print(f"  source ASM vol.2 + CRC 105th         Tg={src_tg_lo}-{src_tg_hi} C, Tm={src_tm} C")
    if tg_lo_delta > tg_tol or tg_hi_delta > tg_tol:
        print(f"FAIL: Tg range delta > tolerance {tg_tol} C")
        return 1
    if tm_delta > tm_tol:
        print(f"FAIL: Tm delta {tm_delta} > tolerance {tm_tol} C")
        return 1
    print(f"PASS: Tg + Tm within ASM/CRC tolerance (Tg+-{tg_tol}, Tm+-{tm_tol} C)")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b4_nylon66_tg_tm_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
