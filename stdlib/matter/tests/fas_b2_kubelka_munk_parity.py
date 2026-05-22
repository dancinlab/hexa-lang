#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/fas_b2_kubelka_munk_parity.py — Phase I.2 gate B-FAS-2.

Anchor: AATCC Test Method 6 (1993) + Kubelka & Munk 1931 Z. Tech. Phys.
12, 593 — K/S = (1 - R_inf)^2 / (2 * R_inf); identity check.

SPEC_FIRST: parity gate verifies the closed-form K/S identity at R_inf = 0.5
(K/S = 0.25 exactly) and reflectance bounds [0, 1].

stdlib only; --selftest exits 0 with __FAS_B2_KUBELKA_MUNK__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "fas_b2_kubelka_munk.json")
SENTINEL = "__FAS_B2_KUBELKA_MUNK__ PASS"


def k_over_s(r_inf: float) -> float:
    return (1.0 - r_inf) ** 2 / (2.0 * r_inf)


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    bounds = snap["claim"]["bounds"]
    r_lo, r_hi = bounds["R_inf_range"]
    expected_at_half = float(bounds["KoverS_at_R_inf_0p5"])
    tol = float(snap["tolerance"]["abs"])
    derived = k_over_s(0.5)
    if abs(derived - expected_at_half) > tol:
        print(f"FAIL: K/S(0.5) derived {derived} ≠ expected {expected_at_half} within {tol}")
        return 1
    if not (r_lo == 0.0 and r_hi == 1.0):
        print(f"FAIL: R_inf bounds {r_lo}-{r_hi} ≠ [0, 1]")
        return 1
    # spot-check monotonic K/S decreasing in R_inf on (0, 1]
    if not (k_over_s(0.25) > k_over_s(0.5) > k_over_s(0.75)):
        print("FAIL: K/S not monotonic in R_inf as Kubelka-Munk predicts")
        return 1
    if "AATCC" not in snap["source"]["citation"] or "Kubelka" not in snap["source"]["citation"]:
        print("FAIL: source must cite AATCC + Kubelka-Munk verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  derived K/S(R_inf=0.5) = {derived} (expected {expected_at_half})")
    print(f"PASS: K/S formula identity matches AATCC TM6 + Kubelka-Munk 1931")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: fas_b2_kubelka_munk_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
