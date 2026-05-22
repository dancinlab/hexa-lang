#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/prc_b2_recycling_gibbs_parity.py — Phase I.2 gate B-PRC-2.

Anchor: ISO 14040 LCA + Gibbs 1876 + Atkins Phys. Chem. 11th — recycling
energy floor >= T * R * sum(x_i * ln(x_i)); PET/PE 50:50 ideal-mixing
ΔG_min ~ 1.72 kJ/mol at 298 K.

SPEC_FIRST: this gate verifies the ideal-mixing LOWER BOUND only; real
recycling energies are vastly higher (non-ideal + enthalpy + kinetics).

stdlib only; --selftest exits 0 with __PRC_B2_RECYCLING_GIBBS__ PASS.
"""
from __future__ import annotations

import json
import math
import os
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "prc_b2_recycling_gibbs.json")
SENTINEL = "__PRC_B2_RECYCLING_GIBBS__ PASS"

R_GAS = 8.314  # J/(mol·K)


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    ex = snap["claim"]["example_pet_pe_50_50"]
    T = float(ex["T_K"])
    claimed_dS = float(ex["delta_S_mix_J_per_mol_K"])
    claimed_dG = float(ex["delta_G_min_kJ_per_mol"])
    # ideal-mixing entropy: -R * sum(x_i * ln(x_i)) for x_i = 0.5, 0.5
    derived_dS = -R_GAS * (0.5 * math.log(0.5) + 0.5 * math.log(0.5))
    derived_dG_kJ = T * derived_dS / 1000.0  # = -T·ΔS_mix; floor for DE-mixing is +T·ΔS_mix
    tol = float(snap["tolerance"]["rel"])
    if abs(claimed_dS - derived_dS) / derived_dS > tol:
        print(f"FAIL: ΔS_mix {claimed_dS} J/(mol·K) ≠ derived {derived_dS:.3f} within {tol}")
        return 1
    if abs(claimed_dG - derived_dG_kJ) / derived_dG_kJ > tol:
        print(f"FAIL: ΔG_min {claimed_dG} kJ/mol ≠ derived {derived_dG_kJ:.3f} within {tol}")
        return 1
    if "ISO 14040" not in snap["source"]["citation"]:
        print("FAIL: source must cite ISO 14040 verbatim")
        return 1
    print(f"  source {snap['source']['citation']}")
    print(f"  derived  ΔS_mix = {derived_dS:.3f} J/(mol·K), ΔG_min = {derived_dG_kJ:.3f} kJ/mol")
    print(f"  claimed  ΔS_mix = {claimed_dS}  J/(mol·K), ΔG_min = {claimed_dG}  kJ/mol")
    print(f"PASS: ideal-mixing thermodynamic floor matches ISO 14040 + Gibbs derivation")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: prc_b2_recycling_gibbs_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
