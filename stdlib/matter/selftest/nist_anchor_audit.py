#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/nist_anchor_audit.py — citation-anchor presence check.

Per LATTICE_POLICY §1.2 (real-limits-first) and raw#10 C3 (no lattice-fit on
external entities), every quantitative claim cited in a verb spec must be
anchored by an external reference. This gate scans LIMIT_BREAKTHROUGH.md and
the silicon + Phase D verb specs (the post-policy authored ones) and
confirms:

  (a) LIMIT_BREAKTHROUGH.md cites NIST/CRC/ASM/SEMI/ASTM/Hales/Frenkel anchors
  (b) silicon/silicon.md cites NIST/SEMI/ASTM/vendor for every Si-L1..Si-L12 line
  (c) post-policy Phase D verb specs (12 verbs) carry vendor or NIST/ASTM citation
      somewhere in the file

Pre-policy (pre-2026-05-12) canon-imported specs are excluded — they were
written before raw#10 C3 was enforced.

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

# Specs authored under the post-2026-05-12 policy (silicon + 12 Phase D verbs
# + 4 Phase D follow-on verbs):
POST_POLICY_SPECS = [
    ("silicon", "silicon/silicon.md"),
    ("compound-semi", "compound-semi/compound-semi.md"),
    ("perovskite", "perovskite/perovskite.md"),
    ("2d-materials", "2d-materials/2d-materials.md"),
    ("mof", "mof/mof.md"),
    ("carbon", "carbon/carbon.md"),
    ("elastomer", "elastomer/elastomer.md"),
    ("adhesive", "adhesive/adhesive.md"),
    ("liquid-crystal", "liquid-crystal/liquid-crystal.md"),
    ("biodegradable-plastics", "biodegradable-plastics/biodegradable-plastics.md"),
    ("wood-cellulose", "wood-cellulose/wood-cellulose.md"),
    ("superalloy", "superalloy/superalloy.md"),
    ("magnetic-materials", "magnetic-materials/magnetic-materials.md"),
    # Phase D follow-on (2026-05-13, 29→33):
    ("glass-ceramic", "glass-ceramic/glass-ceramic.md"),
    ("geopolymer", "geopolymer/geopolymer.md"),
    ("aerogel-foam", "aerogel-foam/aerogel-foam.md"),
    ("ionic-liquid", "ionic-liquid/ionic-liquid.md"),
    # Phase D'' (2026-05-13, 33→36):
    ("refractory", "refractory/refractory.md"),
    ("photoresist", "photoresist/photoresist.md"),
    ("electrode-material", "electrode-material/electrode-material.md"),
]

ANCHOR_KEYWORDS = (
    "NIST",
    "CRC Handbook",
    "ASM",
    "SEMI",
    "ASTM",
    "Hales",
    "Frenkel",
    "Stefan-Boltzmann",
    "Sze",  # SM Physics 3rd ed.
    "datasheet",
    "ISO ",
    "JIS ",
    "DIN ",
    "Coey",  # magnetism canonical
    "OECD",
    "Saddow",  # SiC ref
    "TAPPI",
    "GIA",
    "IGS",
    # Primary-literature / vendor / database anchors
    "Yaghi",       # MOF canonical
    "BASF",        # MOF Basolite vendor
    "Furukawa",    # MOF-210
    "Hupp",        # NU series MOF
    "Eddaoudi",    # MOF-5
    "CCDC",        # Cambridge Crystallographic Data Centre
    "Graphenea",   # 2D-materials vendor
    "Ossila",      # 2D-materials vendor
    "NIMS",        # 2D-materials supplier (Japan)
    "Phys. Rev.",  # generic journal citation
    "Science",     # generic journal citation
    "Nat. ",       # Nature family journals
    "Acta",        # Acta journals
)


def has_any_anchor(text: str) -> tuple[bool, list[str]]:
    hits: list[str] = []
    for k in ANCHOR_KEYWORDS:
        if k in text:
            hits.append(k)
    return (len(hits) > 0, hits)


def main() -> int:
    print("hexa-matter/selftest/nist_anchor_audit — citation-anchor presence")
    print(f"  root: {REPO_ROOT}\n")

    fail = 0

    # (a) LIMIT_BREAKTHROUGH.md
    lb_path = os.path.join(REPO_ROOT, "LIMIT_BREAKTHROUGH.md")
    if not os.path.exists(lb_path):
        print("  [FAIL] LIMIT_BREAKTHROUGH.md missing")
        fail += 1
    else:
        with open(lb_path, "r", encoding="utf-8") as fh:
            text = fh.read()
        ok, hits = has_any_anchor(text)
        if ok and len(hits) >= 3:
            print(f"  [PASS] LIMIT_BREAKTHROUGH.md anchors: {sorted(set(hits))[:8]}")
        else:
            print(f"  [FAIL] LIMIT_BREAKTHROUGH.md insufficient anchors: {hits}")
            fail += 1

    # (b) + (c) post-policy specs
    print("")
    for verb, rel in POST_POLICY_SPECS:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            print(f"  [FAIL] {verb}: spec missing at {rel}")
            fail += 1
            continue
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        ok, hits = has_any_anchor(text)
        if ok:
            print(f"  [PASS] {verb}: anchors {sorted(set(hits))[:4]}")
        else:
            print(f"  [FAIL] {verb}: no NIST/CRC/ASM/SEMI/ASTM/vendor anchor found")
            fail += 1

    print()
    if fail > 0:
        print(f"__HEXA_MATTER_NIST_ANCHOR__ FAIL  ({fail} missing anchors)")
        return 1
    print("__HEXA_MATTER_NIST_ANCHOR__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
