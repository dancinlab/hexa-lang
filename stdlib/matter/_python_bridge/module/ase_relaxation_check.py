#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ase_relaxation_check.py — tiny EMT/LJ relaxation smoke test on a small Cu
cluster. Validates that the ASE optimizer pipeline can run end-to-end on
the in-repo fixture without external DFT calculators.

Status: PARTIAL (FUNCTIONAL with ASE; SKIPs cleanly without).

Cu atoms with the EMT calculator). It does NOT touch vendor data and does
NOT claim DFT-grade material parameters. EMT is a coarse semi-empirical
potential — sufficient for a "the pipeline runs" smoke test, NOT a
property-prediction tool.

Optional dep: ase >= 3.22.0

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import sys
import argparse


def _have_ase() -> bool:
    try:
        import ase  # noqa: F401
        return True
    except ImportError:
        return False


def _selftest() -> int:
    if not _have_ase():
        print("  SKIP: ase not installed")
        print("  install: pip install ase")
        print("__HEXA_MATTER_ASE_RELAXATION_CHECK__ PASS (SKIP mode)")
        return 0

    from ase import Atoms
    from ase.calculators.emt import EMT
    from ase.optimize import BFGS
    import io

    # Toy: 4 Cu atoms slightly displaced from FCC lattice. Relax with EMT.
    # EMT is a coarse semi-empirical potential — sufficient for "pipeline runs"
    # smoke test, NOT a property-prediction tool.
    pos = [
        (0.0, 0.0, 0.0),
        (1.82, 1.82, 0.05),   # slight displacement
        (1.82, 0.0, 1.82),
        (0.0, 1.82, 1.82),
    ]
    atoms = Atoms("Cu4", positions=pos, cell=[3.61, 3.61, 3.61], pbc=True)
    atoms.calc = EMT()

    try:
        e0 = atoms.get_potential_energy()
    except Exception as e:
        print(f"  FAIL: initial energy call raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_ASE_RELAXATION_CHECK__ FAIL")
        return 1
    print(f"  PASS: EMT initial energy   E_0 = {e0:.4f} eV")

    # Run a handful of BFGS steps. Suppress stdout to keep the gate quiet.
    buf = io.StringIO()
    opt = BFGS(atoms, logfile=buf)
    try:
        opt.run(fmax=0.05, steps=20)
    except Exception as e:
        print(f"  FAIL: BFGS.run raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_ASE_RELAXATION_CHECK__ FAIL")
        return 1

    e1 = atoms.get_potential_energy()
    print(f"  PASS: EMT relaxed energy   E_1 = {e1:.4f} eV   (ΔE = {e1 - e0:+.4f} eV)")

    # Sanity: energy went DOWN (or stayed same) — never UP — under relaxation.
    if e1 > e0 + 1e-3:
        print(f"  FAIL: relaxation INCREASED energy ({e0} → {e1})")
        print("__HEXA_MATTER_ASE_RELAXATION_CHECK__ FAIL")
        return 1
    print("  PASS: relaxation did not increase energy (sanity check)")

    print("__HEXA_MATTER_ASE_RELAXATION_CHECK__ PASS")
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
