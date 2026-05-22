#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/mof_dac_economics_honesty_audit.py — MOF DAC $100/t UNPROVEN preservation.

The "magic-MOF $100/t CO₂" DAC claim is UNPROVEN. Climeworks' deployed
solid-amine DAC operates at $600-1000/t. Per raw#10 C3 + UNPROVEN-stamp
preservation, the MOF spec MUST carry this caveat.

This gate scans mof/mof.md and confirms:

  (a) "$100/t" (or "100 /t" or "100 USD/t" or "100/t") is FLAGGED as UNPROVEN, AND
  (b) Climeworks $600-1000/t (or equivalent solid-amine reference value) is named
      as the empirical baseline

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

SPEC = os.path.join(REPO_ROOT, "mof", "mof.md")


def main() -> int:
    print("hexa-matter/selftest/mof_dac_economics_honesty_audit — MOF $100/t UNPROVEN preservation")
    print(f"  spec: {SPEC}\n")

    if not os.path.exists(SPEC):
        print("  [FAIL] mof/mof.md missing")
        print("__HEXA_MATTER_MOF_DAC_HONESTY__ FAIL")
        return 1

    with open(SPEC, "r", encoding="utf-8", errors="ignore") as fh:
        text = fh.read()

    fail = 0

    # (a) $100/t mentioned + UNPROVEN tag
    has_100 = bool(re.search(r"\$?100[/\s]*[/]?\s*t", text)) or bool(
        re.search(r"100\s*USD\s*/?\s*t", text)
    )
    has_unproven = "UNPROVEN" in text
    if has_100 and has_unproven:
        print("  [PASS] $100/t MOF DAC claim + UNPROVEN tag both present")
    else:
        print(f"  [FAIL] $100/t present={has_100}  UNPROVEN tag present={has_unproven}")
        fail += 1

    # (b) Climeworks + 600-1000/t baseline
    has_climeworks = "Climeworks" in text
    has_baseline = (
        bool(re.search(r"\$?600[\s\-–]+1000\s*/?\s*t", text))
        or bool(re.search(r"600[-–]1000", text))
    )
    if has_climeworks and has_baseline:
        print("  [PASS] Climeworks empirical baseline ($600-1000/t) named")
    else:
        print(f"  [FAIL] Climeworks named={has_climeworks}  $600-1000/t baseline={has_baseline}")
        fail += 1

    # (c) explicit policy-anchor reference — LIMIT_BREAKTHROUGH §4 or "amine sorbent"
    has_policy = "LIMIT_BREAKTHROUGH" in text or "amine sorbent" in text or "amine" in text
    if has_policy:
        print("  [PASS] policy / amine-sorbent reference present")
    else:
        print("  [FAIL] no LIMIT_BREAKTHROUGH or amine-sorbent reference")
        fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_MOF_DAC_HONESTY__ FAIL  ({fail} missing honesty anchors)")
        return 1
    print("__HEXA_MATTER_MOF_DAC_HONESTY__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
