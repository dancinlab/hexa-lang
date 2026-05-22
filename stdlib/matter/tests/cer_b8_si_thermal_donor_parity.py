#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b8_si_thermal_donor_parity.py — Phase I.2 gate B-CER-8.

Anchor: Kaiser & Frisch 1958 Phys. Rev. 112, 1546 + SEMI MF1188 (Bullis
1995) — CZ Si thermal-donor [TD] = 10^15 to 10^16 cm^-3 after 450 C / 1 h.

SPEC_FIRST: parity gate, not measurement.

stdlib only; --selftest exits 0 with __CER_B8_SI_THERMAL_DONOR__ PASS.
"""
from __future__ import annotations

import json
import math
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b8_si_thermal_donor.json")
SENTINEL = "__CER_B8_SI_THERMAL_DONOR__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    lo, hi = snap["claim"]["value_range"]
    tol_log = float(snap["tolerance"]["log10_abs"])
    if not (0 < lo < hi):
        print(f"FAIL: invalid range ({lo}, {hi})")
        return 1
    span = math.log10(hi) - math.log10(lo)
    if span > 2 * tol_log + 1.5:
        print(f"FAIL: range spans {span:.2f} log decades > 2*tol+1.5")
        return 1
    if not (1e14 <= lo <= 1e16 and 1e15 <= hi <= 1e17):
        print(f"FAIL: range out of Kaiser-Frisch bracket")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  range  [TD] = {lo:.1e} to {hi:.1e} cm^-3 (span {span:.2f} decades)")
    print(f"PASS: CZ Si thermal-donor range matches Kaiser-Frisch 1958 + SEMI MF1188")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b8_si_thermal_donor_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
