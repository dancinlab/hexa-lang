#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/met_b1_inconel718_creep_parity.py — Phase I.1 gate B-MET-1.

Anchor: ASM Handbook vol. 1 (1990) + Special Metals Inconel 718 datasheet
(SMC-045, 2007) — IN718 stress-rupture > 690 MPa at 650 C, 100 h (the
engineering envelope corresponding to > 1000 h to 0.2 % creep strain).

Parity: superalloy/superalloy.md SA-L1 row '~ 700 MPa' ↔
tests/snapshots/met_b1_inconel718_creep.json. Threshold: spec >= 690 MPa.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __MET_B1_INCONEL718_CREEP__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "met_b1_inconel718_creep.json")
SPEC_DOC = os.path.join(ROOT, "superalloy", "superalloy.md")
SENTINEL = "__MET_B1_INCONEL718_CREEP__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    thr = float(snap["tolerance"]["min_threshold_MPa"])
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(
        r"SA-L1\s*\|\s*Inconel 718 stress-rupture at 650 .C, 100 h.*?\*\*~\s*([0-9]+)\s*MPa\*\*",
        text,
    )
    if not m:
        print("FAIL: could not locate SA-L1 Inconel 718 stress-rupture claim in superalloy/superalloy.md")
        return 1
    spec_val = float(m.group(1))
    print(f"  spec   superalloy/superalloy.md SA-L1 = ~ {spec_val} MPa")
    print(f"  source ASM vol.1 + Special Metals    = >= {thr} MPa")
    if spec_val < thr:
        print(f"FAIL: spec {spec_val} MPa < threshold {thr} MPa")
        return 1
    print(f"PASS: spec IN718 stress-rupture >= {thr} MPa per ASM/Special Metals envelope")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: met_b1_inconel718_creep_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
