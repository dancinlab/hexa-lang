#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b3_microplastic_kd_parity.py — Phase I.2 gate B-POL-3.

Anchor: NOAA Marine Debris Program + Mato 2001 + Rochman 2013 —
microplastic-sorbed hydrophobic organic (PCB/PAH) log K_d 4-6.

SPEC_FIRST: parity gate.

stdlib only; --selftest exits 0 with __POL_B3_MICROPLASTIC_KD__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b3_microplastic_kd.json")
SENTINEL = "__POL_B3_MICROPLASTIC_KD__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    lo, hi = snap["claim"]["value_range_log10"]
    if not (lo < hi):
        print(f"FAIL: invalid range ({lo}, {hi})")
        return 1
    if not (3.5 <= lo <= 4.5 and 5.5 <= hi <= 6.5):
        print(f"FAIL: log Kd range out of NOAA aggregate bracket (4-6)")
        return 1
    if "NOAA" not in snap["source"]["citation"]:
        print("FAIL: source must cite NOAA verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  range  log Kd {lo} to {hi}")
    print(f"PASS: microplastic-PCB/PAH log Kd matches NOAA aggregate")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b3_microplastic_kd_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
