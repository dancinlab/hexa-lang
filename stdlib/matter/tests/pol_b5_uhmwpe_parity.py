#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/pol_b5_uhmwpe_parity.py — Phase I.2 gate B-POL-5.

Anchor: DSM Dyneema SK99 datasheet 2019 — UHMWPE fiber sigma_t 3.9 GPa,
E 132 GPa, rho 0.97 g/cm^3 per ASTM D885.

SPEC_FIRST: parity gate.

stdlib only; --selftest exits 0 with __POL_B5_UHMWPE__ PASS.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "pol_b5_uhmwpe.json")
SENTINEL = "__POL_B5_UHMWPE__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    vals = snap["claim"]["values"]
    sigma_t = float(vals["sigma_t_GPa"])
    E = float(vals["E_GPa"])
    rho = float(vals["rho_g_cm3"])
    tol_s = float(snap["tolerance"]["sigma_t_rel"])
    tol_E = float(snap["tolerance"]["E_rel"])
    tol_r = float(snap["tolerance"]["rho_abs"])
    if abs(sigma_t - 3.9) / 3.9 > tol_s:
        print(f"FAIL: sigma_t {sigma_t} GPa outside ± {tol_s*100:.0f}% of 3.9")
        return 1
    if abs(E - 132.0) / 132.0 > tol_E:
        print(f"FAIL: E {E} GPa outside ± {tol_E*100:.0f}% of 132")
        return 1
    if abs(rho - 0.97) > tol_r:
        print(f"FAIL: rho {rho} g/cm^3 outside ± {tol_r} of 0.97")
        return 1
    if "Dyneema" not in snap["source"]["citation"]:
        print("FAIL: source must cite Dyneema verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  values sigma_t={sigma_t} GPa, E={E} GPa, rho={rho} g/cm^3")
    print(f"PASS: UHMWPE (Dyneema SK99) matches vendor datasheet")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: pol_b5_uhmwpe_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
