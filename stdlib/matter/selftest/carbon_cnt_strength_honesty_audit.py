#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/carbon_cnt_strength_honesty_audit.py — CNT 80 GPa lab/commercial honesty.

The CNT yarn 80 GPa figure is a LAB MILLIMETER-SCALE record. Commercial CNT
yarn is 1-3 GPa. Per raw#10 C3 + UNPROVEN/UNVERIFIED preservation rule, the
carbon verb spec MUST carry this caveat.

This gate scans carbon/carbon.md and confirms:

  (a) "80 GPa" appears, AND
  (b) on the same line OR within 5 lines, an honesty marker appears:
      - "UNVERIFIED" / "UNPROVEN" / "lab" / "mm-scale" / "commercial 1-3 GPa"
        / "R&D" / "not at production"

If 80 GPa is mentioned without an honesty caveat, FAIL.

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

SPEC = os.path.join(REPO_ROOT, "carbon", "carbon.md")

HONESTY_MARKERS = [
    "UNVERIFIED", "UNPROVEN", "lab", "mm-scale", "millimeter",
    "commercial 1-3 GPa", "commercial 1–3 GPa", "R&D", "not at production",
    "lab record", "lab mm-scale", "lab-scale",
]


def main() -> int:
    print("hexa-matter/selftest/carbon_cnt_strength_honesty_audit — CNT 80 GPa caveat")
    print(f"  spec: {SPEC}\n")

    if not os.path.exists(SPEC):
        print("  [FAIL] carbon/carbon.md missing")
        print("__HEXA_MATTER_CARBON_CNT_HONESTY__ FAIL")
        return 1

    with open(SPEC, "r", encoding="utf-8", errors="ignore") as fh:
        lines = fh.readlines()

    # Locate the start of the References section, if any — bibliography entries
    # that *quote* a paper title containing "80 GPa" are not claims by us.
    refs_start: int | None = None
    for i, line in enumerate(lines):
        if re.match(r"^##+\s+(§\d+\s+)?References", line, re.IGNORECASE):
            refs_start = i
            break

    # Find lines with "80 GPa" (outside the references section)
    target_lines: list[int] = []
    for i, line in enumerate(lines):
        if refs_start is not None and i >= refs_start:
            continue
        if re.search(r"\b80\s*GPa\b", line):
            target_lines.append(i)

    if not target_lines:
        print("  [FAIL] '80 GPa' not found in spec — CNT lab record citation missing")
        print("__HEXA_MATTER_CARBON_CNT_HONESTY__ FAIL")
        return 1

    print(f"  found '80 GPa' on {len(target_lines)} line(s): {target_lines}\n")

    # For each occurrence, check ±5 lines for honesty marker
    fail = 0
    for ln in target_lines:
        window = "\n".join(lines[max(0, ln - 5):min(len(lines), ln + 6)])
        markers_found = [m for m in HONESTY_MARKERS if m.lower() in window.lower()]
        if markers_found:
            print(f"  [PASS] line {ln + 1}: honesty markers nearby — {markers_found[:3]}")
        else:
            print(f"  [FAIL] line {ln + 1}: '80 GPa' present without UNVERIFIED/lab/mm-scale caveat in ±5 lines")
            fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_CARBON_CNT_HONESTY__ FAIL  ({fail} bare 80 GPa citation)")
        return 1
    print("__HEXA_MATTER_CARBON_CNT_HONESTY__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
