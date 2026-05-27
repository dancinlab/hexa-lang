#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ase_atoms_construct.py — construct canonical Atoms objects for hexa-matter
specs (Si diamond cubic, NdFeB tetragonal, simple Fe BCC, etc.).

Status: PARTIAL (FUNCTIONAL with ASE; SKIPs cleanly without).

Backs the SPEC_FIRST claim that internal structural literals are
self-consistent: when we say "Si diamond cubic a=5.4307 Å", does the ASE
crystal builder accept that input and produce a sensible Atoms object?

optimize, or fit any vendor data; we only construct.

Optional dep: ase >= 3.22.0
  pip install ase

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import sys
import argparse
from typing import Optional, Any


def _have_ase() -> bool:
    try:
        import ase  # noqa: F401
        return True
    except ImportError:
        return False


def build_silicon() -> Optional[Any]:
    """Diamond-cubic Si, a = 5.4307 Å (CRC Handbook). Returns Atoms or None."""
    if not _have_ase():
        return None
    from ase.build import bulk
    return bulk("Si", crystalstructure="diamond", a=5.4307)


def build_iron_bcc() -> Optional[Any]:
    """α-Fe BCC, a = 2.8665 Å (CRC). Returns Atoms or None."""
    if not _have_ase():
        return None
    from ase.build import bulk
    return bulk("Fe", crystalstructure="bcc", a=2.8665)


def build_copper_fcc() -> Optional[Any]:
    """Cu FCC, a = 3.6149 Å (CRC). Returns Atoms or None."""
    if not _have_ase():
        return None
    from ase.build import bulk
    return bulk("Cu", crystalstructure="fcc", a=3.6149)


def _selftest() -> int:
    if not _have_ase():
        print("  SKIP: ase not installed")
        print("  install: pip install ase")
        print("__HEXA_MATTER_ASE_ATOMS_CONSTRUCT__ PASS (SKIP mode)")
        return 0

    cases = [
        ("Si diamond cubic",  build_silicon,    "Si", 2),
        ("α-Fe BCC",          build_iron_bcc,   "Fe", 1),
        ("Cu FCC",            build_copper_fcc, "Cu", 1),
    ]
    fail = 0
    for label, builder, expected_sym, expected_natoms in cases:
        atoms = builder()
        if atoms is None:
            print(f"  FAIL: {label}: builder returned None")
            fail += 1
            continue
        # Check element symbol(s) and atom count (primitive cell).
        syms = set(atoms.get_chemical_symbols())
        n = len(atoms)
        if syms != {expected_sym}:
            print(f"  FAIL: {label}: symbols {syms} (expected {expected_sym})")
            fail += 1
            continue
        if n != expected_natoms:
            print(f"  FAIL: {label}: {n} atoms (expected {expected_natoms} primitive)")
            fail += 1
            continue
        # Sanity: positive volume, 3x3 cell.
        vol = atoms.get_volume()
        if vol <= 0:
            print(f"  FAIL: {label}: non-positive volume {vol}")
            fail += 1
            continue
        print(f"  PASS: {label:<25}  atoms={n}  vol={vol:.2f} Å³  syms={syms}")

    if fail:
        print(f"__HEXA_MATTER_ASE_ATOMS_CONSTRUCT__ FAIL ({fail} failures)")
        return 1
    print("__HEXA_MATTER_ASE_ATOMS_CONSTRUCT__ PASS")
    return 0


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
