#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b6_cnt_yarn_parity.py — Phase I.2 gate B-POL-6.

Anchor: Bai et al. 2018 Nat. Nanotechnol. 13, 589 (Tsinghua) — CNT
macroscopic yarn sigma_t ~ 80 GPa at lab-mm gauge.

no n=6 lattice-fit applied.

UNPROVEN PRESERVATION (carbon/carbon.md, AGENTS.md hard constraints):
This gate verifies the snapshot↔Tsinghua-paper parity at the lab-mm
gauge published value. It does NOT claim the 80 GPa value is reproduced
at commodity-yarn (km-scale) — commercial CNT yarn remains 1-3 GPa
(40-80x gap). The snapshot mandates `unproven: true` and
`unproven_reason` fields; the gate rejects any snapshot lacking these.

SPEC_FIRST: parity gate, not measurement, not endorsement of commodity
reproducibility.

stdlib only; --selftest exits 0 with __POL_B6_CNT_YARN__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b6_cnt_yarn.json")
SENTINEL = "__POL_B6_CNT_YARN__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    if snap.get("unproven") is not True:
        print("FAIL: CNT yarn snapshot MUST carry unproven: true (lab-mm only)")
        return 1
    if not snap.get("unproven_reason"):
        print("FAIL: unproven_reason field required for CNT yarn gate")
        return 1
    val = float(snap["claim"]["value"])
    tol = float(snap["tolerance"]["rel"])
    if abs(val - 80.0) / 80.0 > tol:
        print(f"FAIL: claim value {val} GPa outside ± {tol*100:.0f}% of 80")
        return 1
    if "Tsinghua" not in snap["source"]["citation"]:
        print("FAIL: source must cite Tsinghua / Bai 2018 verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  claim  CNT yarn sigma_t = {val} GPa at lab-mm gauge")
    print(f"  status UNPROVEN at commodity scale: {snap['unproven_reason']}")
    print(f"PASS: spec↔Tsinghua-paper parity at lab-mm gauge; UNPROVEN markers preserved")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b6_cnt_yarn_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
