#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b6_uhpc_compressive_parity.py — Phase I.2 gate B-CER-6.

Anchor: Ductal (Lafarge-Holcim) + Cor-Tuf (USACE ERDC) datasheet — UHPC
sigma_c 150-200 MPa typical, 800 MPa upper headroom with steel-fiber +
autoclave per ASTM C39.

SPEC_FIRST: gate verifies snapshot↔vendor parity; reproducibility of the
800 MPa upper headroom remains UNVERIFIED at commodity scale.

stdlib only; --selftest exits 0 with __CER_B6_UHPC_COMPRESSIVE__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b6_uhpc_compressive.json")
SENTINEL = "__CER_B6_UHPC_COMPRESSIVE__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    if not snap.get("source", {}).get("citation"):
        print("FAIL: missing source citation")
        return 1
    lo, hi = snap["claim"]["value_range"]
    typ_lo, typ_hi = snap["claim"]["value_typical"]
    if not (0 < typ_lo < typ_hi <= hi and lo <= typ_lo):
        print(f"FAIL: invalid range structure ({lo}-{hi}, typ {typ_lo}-{typ_hi})")
        return 1
    if hi != 800.0 or typ_lo != 150.0:
        print(f"FAIL: vendor headroom drift (expected typical 150-200, upper 800 MPa)")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  range  typical {typ_lo}-{typ_hi} MPa, upper {hi} MPa")
    print(f"PASS: UHPC sigma_c range matches Ductal+Cor-Tuf vendor datasheets")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b6_uhpc_compressive_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
