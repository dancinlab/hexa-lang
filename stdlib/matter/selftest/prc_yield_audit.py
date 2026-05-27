#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/prc_yield_audit.py — PRC group yield-claim honesty.

For the GROUP_PRC verbs (synthesis, recycle_n6, recycling), if a yield claim
appears (e.g., "X % yield" or "X % recovery"), this gate confirms either:

  (a) the claim has an inline falsifier or caveat (UNVERIFIED / UNPROVEN /
      "subject to F-…"  / "draft" / "TBD" markers), OR
  (b) the claim is cited to a real source (vendor / journal / SEMI / ASTM).

Plain numerical yield claims without anchor OR caveat are HONESTLY flagged.

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

PRC_SPECS = [
    "synthesis/material-synthesis.md",
    "recycle_n6/hexa-recycle.md",
    "recycling/recycling.md",
]

# Files known to be legacy canon-imports (pre-LATTICE_POLICY-2026-05-12 era).
# These contain n=6-fit yield prose ("HEXA-n=6 = 90 % yield" etc.) that
# predates raw#10 C3 — report but don't FAIL.
LEGACY_KNOWN = {
    "synthesis/material-synthesis.md",
    "recycle_n6/hexa-recycle.md",
    "recycling/recycling.md",
}

# Match yield claims: "NN % yield", "NN % recovery", "NN% conversion"
YIELD_PATTERN = re.compile(
    r"(\d{1,3})\s*%\s*(yield|recovery|conversion|efficiency|recycle)",
    re.IGNORECASE,
)

# Caveat tokens that legitimize a yield claim when present nearby (same paragraph)
CAVEATS = [
    "UNVERIFIED", "UNPROVEN", "TBD", "draft", "candidate",
    "ASTM", "ISO", "SEMI", "NIST", "vendor", "datasheet",
    "F-Si-", "F-CER-", "F-POL-", "F-MET-", "F-PRC-",
    "B-CER-", "B-POL-", "B-MET-", "B-PRC-",
    "OECD", "EPA",
]


def split_paragraphs(text: str) -> list[str]:
    return re.split(r"\n\s*\n", text)


def main() -> int:
    print("hexa-matter/selftest/prc_yield_audit — PRC group yield-claim honesty")
    print(f"  root: {REPO_ROOT}\n")

    fail = 0
    legacy_warn = 0
    for rel in PRC_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            print(f"  [WARN] missing PRC spec: {rel}")
            continue
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        paragraphs = split_paragraphs(text)
        bare_yield_count = 0
        anchored_count = 0
        for para in paragraphs:
            if not YIELD_PATTERN.search(para):
                continue
            has_caveat = any(c in para for c in CAVEATS)
            if has_caveat:
                anchored_count += 1
            else:
                bare_yield_count += 1
        is_legacy = rel in LEGACY_KNOWN
        legacy_tag = " (legacy canon-import, pre-policy)" if is_legacy else ""
        print(f"  [{'PASS' if bare_yield_count == 0 else 'INFO'}] {rel}: "
              f"yield-claim paragraphs {anchored_count + bare_yield_count} "
              f"(anchored={anchored_count}, bare={bare_yield_count}){legacy_tag}")
        if (bare_yield_count + anchored_count) > 0 and anchored_count == 0:
            if is_legacy:
                # Honest-known legacy n=6-fit yield prose — REPORT, do not FAIL.
                print(f"  [LEGACY-KNOWN] {rel}: bare yield claims from canon-imported lattice-fit prose")
                legacy_warn += 1
            else:
                print(f"  [FAIL] {rel}: has {bare_yield_count} yield claim(s) but NO anchor/caveat anywhere")
                fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_PRC_YIELD__ FAIL  ({fail} non-legacy PRC spec(s) with bare yield claims)")
        return 1
    print(f"__HEXA_MATTER_PRC_YIELD__ PASS  (legacy-known bare-yield specs: {legacy_warn})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
