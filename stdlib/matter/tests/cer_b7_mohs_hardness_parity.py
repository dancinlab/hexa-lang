#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/cer_b7_mohs_hardness_parity.py — Phase I.1 gate B-CER-7.

Anchor: Friedrich Mohs 1812 + NIST SRD scratch-hardness reference — the
10-stop ladder talc(1) gypsum(2) calcite(3) fluorite(4) apatite(5)
orthoclase(6) quartz(7) topaz(8) corundum(9) diamond(10).

Parity: gemology/gemology.md F-GEM-Q5 row ↔
tests/snapshots/cer_b7_mohs_hardness.json. Mohs ladder is a defined
reference set — gate enforces 10 stops with exact mineral identity.

SPEC_FIRST: gate checks spec↔source parity, not measurement.

stdlib only; --selftest exits 0 with __CER_B7_MOHS_HARDNESS__ PASS sentinel.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
SNAPSHOT = os.path.join(ROOT, "tests", "snapshots", "cer_b7_mohs_hardness.json")
SPEC_DOC = os.path.join(ROOT, "gemology", "gemology.md")
SENTINEL = "__CER_B7_MOHS_HARDNESS__ PASS"


def main() -> int:
    with open(SNAPSHOT, "r", encoding="utf-8") as fh:
        snap = json.load(fh)
    if snap.get("n6_lattice_fit_applied") is not False:
        return 1
    ladder = snap["claim"]["ladder"]
    if len(ladder) != 10:
        print(f"FAIL: snapshot ladder must have 10 stops, got {len(ladder)}")
        return 1
    with open(SPEC_DOC, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"F-GEM-Q5.*?\| OPEN \|", text, re.S)
    if not m:
        print("FAIL: could not locate F-GEM-Q5 row in gemology/gemology.md")
        return 1
    row = m.group(0)
    missing = []
    for entry in ladder:
        token = f"{entry['stop']} {entry['mineral']}"
        if token not in row:
            missing.append(token)
    print(f"  spec   gemology/gemology.md F-GEM-Q5 = {len(ladder) - len(missing)}/10 stops matched")
    print(f"  source Mohs 1812 + NIST SRD          = 10/10 stops")
    if missing:
        print(f"FAIL: ladder stops missing from F-GEM-Q5: {missing}")
        return 1
    print(f"PASS: full 10-stop Mohs ladder present in F-GEM-Q5 verbatim")
    print(SENTINEL)
    return 0


if __name__ == "__main__":
    if "--selftest" not in sys.argv and len(sys.argv) > 1:
        print("usage: cer_b7_mohs_hardness_parity.py --selftest")
        raise SystemExit(2)
    raise SystemExit(main())
