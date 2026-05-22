#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/prc_b3_solgel_teos_parity.py — Phase I.2 gate B-PRC-3.

Anchor: Hench & West 1990 Chem. Rev. 90, 33 + Brinker & Scherer 1990
'Sol-Gel Science' — TEOS hydrolysis k_h ~ 1e-3 s^-1 at pH 2, 25 C,
acid-catalyzed first-order pseudo regime.

SPEC_FIRST: parity gate.

stdlib only; --selftest exits 0 with __PRC_B3_SOLGEL_TEOS__ PASS.
"""
from __future__ import annotations

import json
import math
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "prc_b3_solgel_teos.json")
SENTINEL = "__PRC_B3_SOLGEL_TEOS__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    val = float(snap["claim"]["value"])
    tol_log = float(snap["tolerance"]["log10_abs"])
    if val <= 0:
        print(f"FAIL: rate constant {val} must be positive")
        return 1
    log_target = math.log10(1.0e-3)
    if abs(math.log10(val) - log_target) > tol_log:
        print(f"FAIL: k_h {val} outside log tolerance ± {tol_log} of 1e-3 s^-1")
        return 1
    if "Hench" not in snap["source"]["citation"]:
        print("FAIL: source must cite Hench & West verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  claim  TEOS k_h = {val:.2e} s^-1 at pH 2, 25 C")
    print(f"PASS: TEOS sol-gel hydrolysis rate matches Hench-West + Brinker-Scherer")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: prc_b3_solgel_teos_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
