#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/gem_authenticity_check.py — GEM group certification anchor check.

For the GROUP_GEM verbs (gemology), this gate verifies that the gemology
spec references a canonical gemological certification body (GIA / IGS /
AGS / HRD / Gübelin / SSEF) — the only legitimate identification anchors
for gem material.

Per raw#9 hexa-only: Python stdlib only.

Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import os
import sys

REPO_ROOT = os.environ.get("HEXA_MATTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

GEM_SPECS = [
    "gemology/gemology.md",
    "GEMOLOGY.md",
]

GEM_AUTHORITIES = [
    "GIA",  # Gemological Institute of America
    "IGS",  # International Gem Society
    "AGS",  # American Gem Society
    "HRD",  # HRD Antwerp
    "Gübelin",
    "SSEF",
    "ICA",  # International Colored Gemstone Association
]

# Also accept canonical gemological-property anchors (refractive index,
# birefringence, dispersion, Mohs hardness with vendor/NIST cite).
SECONDARY_ANCHORS = [
    "refractive index",
    "birefringence",
    "dispersion",
    "Mohs",
    "specific gravity",
    "fluorescence",
    "Sugano-Tanabe",
]


def main() -> int:
    print("hexa-matter/selftest/gem_authenticity_check — GEM group certification anchor")
    print(f"  root: {REPO_ROOT}\n")

    corpus = ""
    for rel in GEM_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                corpus += "\n" + fh.read()
            print(f"  [OK]   loaded {rel}")
        else:
            print(f"  [WARN] missing GEM spec: {rel}")

    auth_hits = [k for k in GEM_AUTHORITIES if k in corpus]
    sec_hits = [k for k in SECONDARY_ANCHORS if k.lower() in corpus.lower()]

    print()
    print(f"  certification authority refs: {auth_hits}")
    print(f"  secondary anchors (RI/SG/Mohs/etc.): {sec_hits[:5]}")
    print()
    if auth_hits or len(sec_hits) >= 3:
        if auth_hits:
            print(f"__HEXA_MATTER_GEM_AUTHENTICITY__ PASS  (cert authority: {auth_hits})")
        else:
            print(f"__HEXA_MATTER_GEM_AUTHENTICITY__ PASS  (≥3 gemological anchors: {sec_hits[:3]})")
        return 0
    print("__HEXA_MATTER_GEM_AUTHENTICITY__ FAIL  (no GIA/IGS/AGS reference AND <3 secondary anchors)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
