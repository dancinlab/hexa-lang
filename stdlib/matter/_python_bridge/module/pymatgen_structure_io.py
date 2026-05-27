#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pymatgen_structure_io.py — pymatgen Structure parse / write smoke test
+ Materials Project ID format resolution (offline, no API call).

Status: PARTIAL (FUNCTIONAL with pymatgen; SKIPs cleanly without).

Two paths:
  1. Build a tiny in-memory Structure (Si diamond cubic), write CIF to a
     string buffer, re-parse the CIF, verify round-trip.
  2. Validate Materials Project ID strings (`mp-149` for Si, `mp-1062`,
     `mp-30` etc.) match the canonical regex `^mp-\\d+$`.

NO external API calls in --selftest. The actual MP API fetch is Phase F
(`_research_bridge/materials_project_fetch.py`).

DFT data. CIF round-trip is structural identity only.

Optional dep: pymatgen >= 2024.0.0

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import re
import sys
import argparse
from typing import Optional


MP_ID_RE = re.compile(r"^mp-\d+$")


def is_valid_mp_id(s: str) -> bool:
    """Validate Materials Project ID format. Pure regex, no network."""
    return bool(MP_ID_RE.match(s))


def _have_pymatgen() -> bool:
    try:
        import pymatgen  # noqa: F401
        return True
    except ImportError:
        return False


def _selftest() -> int:
    # MP ID validation always runs (stdlib only).
    cases = [
        ("mp-149",   True,   "Si (canonical)"),
        ("mp-1062",  True,   "Cu (canonical)"),
        ("mp-30",    True,   "small mp-id"),
        ("MP-149",   False,  "wrong case"),
        ("mp149",    False,  "missing dash"),
        ("mp-",      False,  "empty number"),
        ("",         False,  "empty string"),
    ]
    for mp_id, expected, label in cases:
        got = is_valid_mp_id(mp_id)
        if got != expected:
            print(f"  FAIL: {label}: mp_id={mp_id!r}  expected={expected}  got={got}")
            print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ FAIL")
            return 1
        print(f"  PASS: MP-ID regex  {mp_id!r:<14}  →  {got}")

    # Pymatgen Structure round-trip (CIF).
    if not _have_pymatgen():
        print("  SKIP: pymatgen not installed (Structure round-trip)")
        print("  install: pip install pymatgen")
        print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ PASS (MP-ID regex passed; pymatgen path SKIPPED)")
        return 0

    from pymatgen.core import Structure, Lattice

    # Build Si diamond-cubic structure programmatically.
    a = 5.4307
    lattice = Lattice.cubic(a)
    coords = [
        (0.0, 0.0, 0.0),
        (0.25, 0.25, 0.25),
    ]
    s1 = Structure(lattice, ["Si", "Si"], coords)

    cif_str = s1.to(fmt="cif")
    if not cif_str or "Si" not in cif_str:
        print(f"  FAIL: CIF serialization produced no Si entry")
        print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ FAIL")
        return 1
    print(f"  PASS: Si Structure → CIF ({len(cif_str)} chars)")

    # Round-trip parse.
    try:
        s2 = Structure.from_str(cif_str, fmt="cif")
    except Exception as e:
        print(f"  FAIL: CIF re-parse raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ FAIL")
        return 1

    if len(s2) != len(s1):
        print(f"  FAIL: round-trip atom count mismatch: {len(s1)} → {len(s2)}")
        print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ FAIL")
        return 1
    # Lattice parameter preservation within 1e-3 Å.
    if abs(s2.lattice.a - s1.lattice.a) > 1e-3:
        print(f"  FAIL: lattice a mismatch: {s1.lattice.a} → {s2.lattice.a}")
        print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ FAIL")
        return 1
    print(f"  PASS: CIF round-trip preserved structure (a={s2.lattice.a:.4f} Å, {len(s2)} atoms)")

    print("__HEXA_MATTER_PYMATGEN_STRUCTURE_IO__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--validate-mp-id", default=None, help="validate an mp-id string")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    if args.validate_mp_id:
        print("valid" if is_valid_mp_id(args.validate_mp_id) else "invalid")
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
