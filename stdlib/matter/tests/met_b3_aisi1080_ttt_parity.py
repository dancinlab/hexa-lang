#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/met_b3_aisi1080_ttt_parity.py — Phase I.1 gate B-MET-3.

Anchor: ASM Handbook vol. 4 (1991) — AISI 1080 plain-carbon eutectoid
steel TTT diagram: C-curve nose ~ 550 C, bainite onset ~ 540 C, martensite
start Ms ~ 250 C (literature spread 215-260 C). Bain & Davenport 1930
foundational reference.

Parity: METALLURGY-DEEP.md §5.1 ASCII TTT + §5.2 phase descriptions ↔
tests/snapshots/met_b3_aisi1080_ttt.json. Tolerances: nose +/- 25 C,
bainite +/- 25 C, Ms +/- 35 C.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __MET_B3_AISI1080_TTT__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "met_b3_aisi1080_ttt.json")
SPEC_DOC = os.path.join(ROOT, "METALLURGY-DEEP.md")
SENTINEL = "__MET_B3_AISI1080_TTT__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    src_nose = float(snap["claim"]["nose_C"])
    src_bainite = float(snap["claim"]["bainite_onset_C"])
    src_Ms = float(snap["claim"]["Ms_C"])
    tol_nose = float(snap["tolerance"]["nose_abs_C"])
    tol_bainite = float(snap["tolerance"]["bainite_onset_abs_C"])
    tol_Ms = float(snap["tolerance"]["Ms_abs_C"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m_nose = re.search(r'"C-curve" nose at\s*~\s*([0-9]+)\s*°C', text)
    m_bain = re.search(r"Bainite.*?forms at\s*([0-9]+)\s*-\s*([0-9]+)\s*°C", text)
    m_ms = re.search(r"Ms\s*=\s*([0-9]+)\s*°C\s*martensite start", text)
    if not (m_nose and m_bain and m_ms):
        print("FAIL: could not locate TTT landmarks in METALLURGY-DEEP.md")
        return 1
    spec_nose = float(m_nose.group(1))
    spec_bainite_hi = float(m_bain.group(2))  # bainite onset = upper bound (e.g., 540)
    spec_Ms = float(m_ms.group(1))
    d_nose = abs(spec_nose - src_nose)
    d_bainite = abs(spec_bainite_hi - src_bainite)
    d_Ms = abs(spec_Ms - src_Ms)
    print(f"  spec   METALLURGY-DEEP.md §5 = nose {spec_nose} C, bainite onset {spec_bainite_hi} C, Ms {spec_Ms} C")
    print(f"  source ASM vol. 4 + Bain 1930 = nose {src_nose} C, bainite onset {src_bainite} C, Ms {src_Ms} C")
    print(f"  delta  nose={d_nose}, bainite={d_bainite}, Ms={d_Ms}")
    if d_nose > tol_nose or d_bainite > tol_bainite or d_Ms > tol_Ms:
        print(f"FAIL: TTT landmark delta exceeds tolerance (nose<=±{tol_nose}, bain<=±{tol_bainite}, Ms<=±{tol_Ms})")
        return 1
    print(f"PASS: TTT landmarks within ASM vol.4 tolerance")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: met_b3_aisi1080_ttt_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
