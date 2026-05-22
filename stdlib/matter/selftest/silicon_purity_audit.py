#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/silicon_purity_audit.py — silicon-specific Si-L1..Si-L12 verifier.

The silicon spec is the gold-standard template for hexa-matter (real-limits-
first). This gate verifies that `silicon/silicon.md`:

  - Declares all 12 Si limit-IDs (Si-L1 through Si-L12)
  - Names the 9N purity ceiling with SOFT_WALL classification
  - States CZ crucible ≈ 600 mm and FZ rod ≈ 200 mm
  - Cites SEMI / ASTM / vendor anchors

Per LATTICE_POLICY §1.2: silicon's REAL limits are anchored — no lattice fit.

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

SI_SPEC = os.path.join(REPO_ROOT, "silicon", "silicon.md")


def main() -> int:
    print("hexa-matter/selftest/silicon_purity_audit — Si-L1..Si-L12 + 9N + CZ/FZ limits")
    print(f"  spec: {SI_SPEC}\n")

    if not os.path.exists(SI_SPEC):
        print("  [FAIL] silicon/silicon.md missing")
        print("__HEXA_MATTER_SILICON_PURITY__ FAIL")
        return 1

    with open(SI_SPEC, "r", encoding="utf-8", errors="ignore") as fh:
        text = fh.read()

    fail = 0
    # (1) Si-L1..Si-L12 all present
    for i in range(1, 13):
        tag = f"Si-L{i}"
        if tag in text:
            print(f"  [PASS] {tag} declared")
        else:
            print(f"  [FAIL] {tag} missing from silicon/silicon.md")
            fail += 1

    # (2) 9N + SOFT_WALL
    if re.search(r"9N", text) and "SOFT_WALL" in text:
        print("  [PASS] 9N purity ceiling + SOFT_WALL classification")
    else:
        print(f"  [FAIL] 9N + SOFT_WALL: 9N={'9N' in text}  SOFT_WALL={'SOFT_WALL' in text}")
        fail += 1

    # (3) CZ ~600 mm
    if re.search(r"600\s*mm", text):
        print("  [PASS] CZ crucible 600 mm anchor")
    else:
        print("  [FAIL] no 600 mm CZ crucible anchor")
        fail += 1

    # (4) FZ ~200 mm
    if re.search(r"200\s*mm", text):
        print("  [PASS] FZ rod 200 mm anchor")
    else:
        print("  [FAIL] no 200 mm FZ rod anchor")
        fail += 1

    # (5) SEMI / ASTM / vendor cite
    anchors = ["SEMI", "ASTM", "Wacker", "Hemlock", "Topsil", "Siltronic", "Wolfspeed", "Ferrotec", "Heraeus"]
    found_anchors = [a for a in anchors if a in text]
    if len(found_anchors) >= 3:
        print(f"  [PASS] ≥3 SEMI/ASTM/vendor anchors: {found_anchors[:5]}")
    else:
        print(f"  [FAIL] insufficient SEMI/ASTM/vendor anchors: {found_anchors}")
        fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_SILICON_PURITY__ FAIL  ({fail} missing)")
        return 1
    print("__HEXA_MATTER_SILICON_PURITY__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
