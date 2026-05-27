#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sources_audit.py — validates every <system>/SOURCES.md is present, non-empty,
and contains required honesty markers (citation, license).

Emits sentinel: __HEXA_BIO_ABSORPTION_SOURCES_AUDIT__ PASS / FAIL.

Required SOURCES.md files (cycle-30++++++++ backport from hexa-matter Phase G):
  - alphafold3/SOURCES.md
  - rosettafold/SOURCES.md
  - esmfold/SOURCES.md
  - openfold/SOURCES.md
  - colabfold/SOURCES.md
  - foldseek/SOURCES.md
  - mmseqs/SOURCES.md
  - uniprot/SOURCES.md
  - pdb/SOURCES.md

Each must contain (case-insensitive substring match):
  - "license"     — license statement present
  - "citation" OR DOI / Nature / Science / journal-shorthand marker — provenance

AlphaFold-3's SOURCES.md gets an EXTRA check: the "non-commercial"
restriction must be loudly flagged (critical license honesty per
SPEC_FIRST / SOURCES discipline).
"""

from __future__ import annotations
import argparse
import os
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = Path(os.environ.get("HEXA_BIO_ROOT", HERE.parent.parent))
ABSORPTION_BRIDGE = ROOT / "_absorption_bridge"

REQUIRED_SOURCES = [
    ABSORPTION_BRIDGE / "alphafold3" / "SOURCES.md",
    ABSORPTION_BRIDGE / "rosettafold" / "SOURCES.md",
    ABSORPTION_BRIDGE / "esmfold" / "SOURCES.md",
    ABSORPTION_BRIDGE / "openfold" / "SOURCES.md",
    ABSORPTION_BRIDGE / "colabfold" / "SOURCES.md",
    ABSORPTION_BRIDGE / "foldseek" / "SOURCES.md",
    ABSORPTION_BRIDGE / "mmseqs" / "SOURCES.md",
    ABSORPTION_BRIDGE / "uniprot" / "SOURCES.md",
    ABSORPTION_BRIDGE / "pdb" / "SOURCES.md",
]
SENTINEL = "__HEXA_BIO_ABSORPTION_SOURCES_AUDIT__"
MIN_SIZE_BYTES = 300


def audit_one(p: Path) -> tuple[bool, str]:
    if not p.exists():
        return False, f"missing: {p}"
    sz = p.stat().st_size
    if sz < MIN_SIZE_BYTES:
        return False, f"too small ({sz} bytes): {p}"
    text = p.read_text(encoding="utf-8").lower()
    if "license" not in text:
        return False, f"missing 'license' marker: {p}"
    if not any(m in text for m in ("citation", "doi", "arxiv", "nature", "science", "nucleic acids res", "phys.")):
        return False, f"missing citation/DOI/journal marker: {p}"

    # AF3 EXTRA: non-commercial restriction MUST be flagged loudly.
    if p.parent.name == "alphafold3":
        if "non-commercial" not in text and "noncommercial" not in text:
            return False, f"AF3 SOURCES.md missing 'non-commercial' restriction marker: {p}"
        if "isomorphic labs" not in text:
            return False, f"AF3 SOURCES.md missing Isomorphic Labs commercial-pathway marker: {p}"

    return True, "ok"


def _selftest() -> int:
    fails = 0
    for p in REQUIRED_SOURCES:
        ok, reason = audit_one(p)
        if ok:
            try:
                rel = p.relative_to(ROOT)
            except ValueError:
                rel = p
            print(f"  PASS: {rel}")
        else:
            print(f"  FAIL: {reason}")
            fails += 1

    if fails == 0:
        print(f"{SENTINEL} PASS ({len(REQUIRED_SOURCES)}/{len(REQUIRED_SOURCES)} SOURCES.md present + honest)")
        return 0
    print(f"{SENTINEL} FAIL ({fails} of {len(REQUIRED_SOURCES)} SOURCES.md invalid)")
    return 1


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
