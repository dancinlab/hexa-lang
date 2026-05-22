#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sources_audit.py — validates every <system>/SOURCES.md is present, non-empty,
and contains required honesty markers (citation, license).

Emits sentinel: __HEXA_MATTER_ABSORPTION_SOURCES_AUDIT__ PASS / FAIL.

Required SOURCES.md files (Phase G + Phase G+1 + Phase G+2 + Phase J.3):
  - materials_project/SOURCES.md
  - gnome/SOURCES.md
  - matlantis/SOURCES.md
  - omat24/SOURCES.md
  - universal_ff/SOURCES.md
  - cod/SOURCES.md            (Phase G+1: Crystallography Open Database)
  - oqmd/SOURCES.md           (Phase G+2: Open Quantum Materials Database)
  - aflow/SOURCES.md          (Phase G+2: AFLOW — Automatic-FLOW for Materials Discovery)
  - nomad/SOURCES.md          (Phase G+2: NOMAD — NOvel MAterials Discovery)
  - nims_mats/SOURCES.md      (Phase J.3: NIMS Materials Database / MatNavi, Japan)
  - catalysis_hub/SOURCES.md  (Phase J.3: Catalysis-Hub, NTNU + Stanford SUNCAT)

Each must contain (case-insensitive substring match):
  - "license"     — license statement present
  - "citation" OR DOI marker — provenance present
"""

from __future__ import annotations
import argparse
import os
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = Path(os.environ.get("HEXA_MATTER_ROOT", HERE.parent.parent))
ABSORPTION_BRIDGE = ROOT / "_absorption_bridge"

REQUIRED_SOURCES = [
    ABSORPTION_BRIDGE / "materials_project" / "SOURCES.md",
    ABSORPTION_BRIDGE / "gnome" / "SOURCES.md",
    ABSORPTION_BRIDGE / "matlantis" / "SOURCES.md",
    ABSORPTION_BRIDGE / "omat24" / "SOURCES.md",
    ABSORPTION_BRIDGE / "universal_ff" / "SOURCES.md",
    ABSORPTION_BRIDGE / "cod" / "SOURCES.md",
    ABSORPTION_BRIDGE / "oqmd" / "SOURCES.md",
    ABSORPTION_BRIDGE / "aflow" / "SOURCES.md",
    ABSORPTION_BRIDGE / "nomad" / "SOURCES.md",
    ABSORPTION_BRIDGE / "nims_mats" / "SOURCES.md",
    ABSORPTION_BRIDGE / "catalysis_hub" / "SOURCES.md",
]
SENTINEL = "__HEXA_MATTER_ABSORPTION_SOURCES_AUDIT__"
MIN_SIZE_BYTES = 200


def audit_one(p: Path) -> tuple[bool, str]:
    if not p.exists():
        return False, f"missing: {p}"
    sz = p.stat().st_size
    if sz < MIN_SIZE_BYTES:
        return False, f"too small ({sz} bytes): {p}"
    text = p.read_text(encoding="utf-8").lower()
    if "license" not in text:
        return False, f"missing 'license' marker: {p}"
    if "citation" not in text and "doi" not in text and "arxiv" not in text and "nature" not in text and "phys." not in text:
        return False, f"missing citation/DOI/arxiv/journal marker: {p}"
    return True, "ok"


def _selftest() -> int:
    fails = 0
    for p in REQUIRED_SOURCES:
        ok, reason = audit_one(p)
        if ok:
            print(f"  PASS: {p.relative_to(ROOT)}")
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
