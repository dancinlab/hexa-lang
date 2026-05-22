#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/prc_b1_hales_packing_parity.py — Phase I.1 gate B-PRC-1.

Anchor: Hales 2005 (Annals of Math. 162, 1065-1185) + Hales et al. 2017
(Forum Math. Pi 5, e2) — formal (machine-verified) proof of the Kepler
conjecture: FCC/HCP packing density of identical hard spheres in R^3 is
exactly pi / (3 * sqrt(2)) ≈ 0.7405.

This gate is a numerical-check parity gate (per CLOSURE_RESIDUAL_BACKLOG
§B B-PRC-1 'Hales packing simulation parity (FCC/HCP 0.7405)'): the
snapshot value is checked against the closed-form pi/(3*sqrt(2)).

Parity: LIMIT_BREAKTHROUGH.md L11 row ↔
tests/snapshots/prc_b1_hales_packing.json. Tolerance: abs 0.0005.

(packing pi/(3 sqrt2) is the Kepler invariant, not an n=6 invariant).
SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __PRC_B1_HALES_PACKING__ PASS sentinel.
"""
from __future__ import annotations

import json
import math
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "prc_b1_hales_packing.json")
SPEC_DOC = os.path.join(ROOT, "LIMIT_BREAKTHROUGH.md")
SENTINEL = "__PRC_B1_HALES_PACKING__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    snap_val = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["abs"])
    closed_form = math.pi / (3.0 * math.sqrt(2.0))
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"L11\s*\|.*?FCC/HCP:\s*([0-9]+\.[0-9]+)", text)
    if not m:
        print("FAIL: could not locate L11 Kepler/Hales packing claim in LIMIT_BREAKTHROUGH.md")
        return 1
    spec_val = float(m.group(1))
    d_snap = abs(spec_val - snap_val)
    d_exact = abs(spec_val - closed_form)
    print(f"  spec       LIMIT_BREAKTHROUGH.md L11 = {spec_val}")
    print(f"  source     Hales 2005+2017 snapshot   = {snap_val}")
    print(f"  closed     pi / (3*sqrt(2))           = {closed_form:.6f}")
    print(f"  delta_snap = {d_snap:.6f}  (tolerance abs {tol})")
    print(f"  delta_form = {d_exact:.6f}  (tolerance abs {tol})")
    if d_snap > tol or d_exact > tol:
        print(f"FAIL: packing density delta > tolerance {tol}")
        return 1
    print(f"PASS: spec FCC/HCP packing matches Hales formal proof within {tol}")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: prc_b1_hales_packing_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
