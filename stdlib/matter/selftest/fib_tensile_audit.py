#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/fib_tensile_audit.py — FIB group tensile-strength anchor.

For the GROUP_FIB verbs (fabric, paper, wood-cellulose, and carbon when read
as fiber: CNT, CF), tensile strength σ is the canonical identifier. This
gate confirms each FIB spec references σ (or "tensile strength" or "MPa" /
"GPa" with a number) — anchored, not lattice-derived.

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

# For each verb, list candidate spec paths — accept anchor presence in ANY of
# the named paths. paper/paper.md is a legacy n=6-fit canon doc; root PAPER.md
# is the deeper expansion absorbed from canon-mk1 and carries the real anchors.
FIB_SPECS = [
    ("fabric", ["fabric/hexa-fabric.md", "HEXA-FABRIC.md"]),
    ("paper", ["paper/paper.md", "PAPER.md"]),
    ("wood-cellulose", ["wood-cellulose/wood-cellulose.md", "WOOD-CELLULOSE.md"]),
    ("aramid", ["aramid/aramid.md", "ARAMID.md"]),
    ("carbon", ["carbon/carbon.md", "GRAPHENE-CARBON.md"]),
]

# Tensile-anchor: number followed by MPa/GPa/kN-per-m/N-per-mm.
# Paper-specific: kN/m (TAPPI T 494 tensile / breaking length) or "tensile index"
# in N·m/g — these are the canonical paper-fiber units.
TENSILE_PATTERN = re.compile(
    r"(\d+(?:\.\d+)?)\s*[-–~]?\s*(\d+(?:\.\d+)?)?\s*"
    r"(MPa|GPa|kN\s*/\s*m|N\s*/\s*mm|N·m\s*/\s*g|TAPPI)",
    re.IGNORECASE,
)


def main() -> int:
    print("hexa-matter/selftest/fib_tensile_audit — FIB group tensile-strength anchor")
    print(f"  root: {REPO_ROOT}\n")

    fail = 0
    for verb, candidates in FIB_SPECS:
        found = None
        match = None
        for rel in candidates:
            path = os.path.join(REPO_ROOT, rel)
            if not os.path.exists(path):
                continue
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
            m = TENSILE_PATTERN.search(text)
            if m:
                found = rel
                match = m
                break
        if match:
            print(f"  [PASS] {verb}: tensile anchor {match.group(0)} (in {found})")
        else:
            print(f"  [FAIL] {verb}: no MPa/GPa/kN-per-m anchor in any of {candidates}")
            fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_FIB_TENSILE__ FAIL  ({fail} missing tensile anchor)")
        return 1
    print("__HEXA_MATTER_FIB_TENSILE__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
