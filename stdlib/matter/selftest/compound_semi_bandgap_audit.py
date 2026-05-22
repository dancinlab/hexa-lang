#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/compound_semi_bandgap_audit.py — compound-semi bandgap citation check.

For the compound-semi verb spec, verify each of GaN / SiC / GaAs / InP has its
bandgap cited (eV value) with a real reference (Sze, NIST, Saddow & Agarwal,
or similar).

Bandgap canonical values (300 K, room temperature):
  GaN  : 3.4 eV
  4H-SiC: 3.26 eV
  GaAs : 1.42 eV
  InP  : 1.34 eV

Per LATTICE_POLICY §1.2: bandgap is real physics, NIST/Sze-anchored. No lattice fit.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

SPEC = os.path.join(REPO_ROOT, "compound-semi", "compound-semi.md")

# Expected bandgap claims — (material, expected_eV, tolerance_eV)
EXPECTED = [
    ("GaN", 3.4, 0.2),
    ("SiC", 3.26, 0.3),
    ("GaAs", 1.42, 0.1),
    ("InP", 1.34, 0.1),
]

# Anchor references that must appear somewhere in the spec
ANCHORS = ["Sze", "NIST", "Saddow", "Slack", "Wolfspeed", "datasheet"]


def main() -> int:
    print("hexa-matter/selftest/compound_semi_bandgap_audit — GaN/SiC/GaAs/InP bandgap")
    print(f"  spec: {SPEC}\n")

    if not os.path.exists(SPEC):
        print("  [FAIL] compound-semi.md missing")
        print("__HEXA_MATTER_COMPOUND_SEMI_BANDGAP__ FAIL")
        return 1

    with open(SPEC, "r", encoding="utf-8", errors="ignore") as fh:
        text = fh.read()

    fail = 0
    for mat, exp_ev, tol in EXPECTED:
        # Look for the material name + a number followed by "eV" within 80 chars
        pattern = re.compile(
            rf"{re.escape(mat)}.{{0,80}}?(\d+(?:\.\d+)?)\s*eV",
            re.IGNORECASE | re.DOTALL,
        )
        m = pattern.search(text)
        if not m:
            print(f"  [FAIL] {mat}: no bandgap eV number found near material name")
            fail += 1
            continue
        try:
            got = float(m.group(1))
        except ValueError:
            print(f"  [FAIL] {mat}: bandgap value unparseable: {m.group(1)}")
            fail += 1
            continue
        if abs(got - exp_ev) <= tol:
            print(f"  [PASS] {mat}: {got} eV  (expected {exp_ev} ± {tol})")
        else:
            print(f"  [FAIL] {mat}: {got} eV outside expected {exp_ev} ± {tol}")
            fail += 1

    # Anchor presence
    anchors_found = [a for a in ANCHORS if a in text]
    if len(anchors_found) >= 2:
        print(f"  [PASS] ≥2 reference anchors present: {anchors_found[:4]}")
    else:
        print(f"  [FAIL] insufficient reference anchors: {anchors_found}")
        fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_COMPOUND_SEMI_BANDGAP__ FAIL  ({fail} missing)")
        return 1
    print("__HEXA_MATTER_COMPOUND_SEMI_BANDGAP__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
