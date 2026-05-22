#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b9_si_oxygen_interstitial_parity.py — Phase I.2 gate B-CER-9.

Anchor: ASTM F121 / F1188 — FTIR 1107 cm^-1 interstitial oxygen in CZ Si
wafer; [O_i] typical 10-30 ppma (5-15 x 10^17 cm^-3).

SPEC_FIRST: parity gate.

stdlib only; --selftest exits 0 with __CER_B9_SI_OXYGEN_INTERSTITIAL__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b9_si_oxygen_interstitial.json")
SENTINEL = "__CER_B9_SI_OXYGEN_INTERSTITIAL__ PASS"

# ppma to cm^-3 for Si: 1 ppma ~ 4.98 x 10^16 cm^-3 (5.0e16 rounded)
PPMA_TO_CM3 = 5.0e16


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    lo_p, hi_p = snap["claim"]["value_range_ppma"]
    lo_c, hi_c = snap["claim"]["value_range_cm3"]
    tol = float(snap["tolerance"]["rel"])
    derived_lo = lo_p * PPMA_TO_CM3
    derived_hi = hi_p * PPMA_TO_CM3
    if abs(derived_lo - lo_c) / lo_c > tol or abs(derived_hi - hi_c) / hi_c > tol:
        print(f"FAIL: ppma↔cm^-3 unit conversion outside tolerance {tol}")
        return 1
    if not (5 <= lo_p <= 15 and 20 <= hi_p <= 40):
        print(f"FAIL: ppma range out of ASTM F121 typical bracket")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  range  [O_i] = {lo_p}-{hi_p} ppma ({lo_c:.1e} to {hi_c:.1e} cm^-3)")
    print(f"PASS: CZ Si [O_i] range matches ASTM F121 / F1188")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b9_si_oxygen_interstitial_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
