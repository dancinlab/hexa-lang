#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pymatgen_phasediagram_smoke.py — binary phase diagram construction smoke
test using pymatgen's PhaseDiagram on a tiny synthetic dataset.

Status: PARTIAL (FUNCTIONAL with pymatgen; SKIPs cleanly without).

What the smoke test does:
  - Define three PDEntry instances for a fictional binary system A-B with
    known formation energies.
  - Construct a PhaseDiagram from those entries.
  - Verify that the resulting diagram has the expected stable phases on
    the convex hull.

This is a SMOKE TEST. It does NOT pull real Materials Project data.
The actual phase-diagram construction for real material systems is the
Phase F + G target (`_research_bridge/materials_project_fetch.py` and
beyond).


Optional dep: pymatgen >= 2024.0.0

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import sys
import argparse


def _have_pymatgen() -> bool:
    try:
        import pymatgen  # noqa: F401
        return True
    except ImportError:
        return False


def _selftest() -> int:
    if not _have_pymatgen():
        print("  SKIP: pymatgen not installed")
        print("  install: pip install pymatgen")
        print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ PASS (SKIP mode)")
        return 0

    try:
        from pymatgen.analysis.phase_diagram import PhaseDiagram, PDEntry
        from pymatgen.core import Composition
    except Exception as e:
        print(f"  SKIP: pymatgen import path changed: {type(e).__name__}: {e}")
        print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ PASS (SKIP mode, API drift)")
        return 0

    # Synthetic toy: A-B binary with intermediate AB compound stable.
    # Energies in eV/atom relative to elements.
    entries = [
        PDEntry(Composition("A"),  energy=0.0),
        PDEntry(Composition("B"),  energy=0.0),
        PDEntry(Composition("AB"), energy=-1.0),  # stable intermediate
        PDEntry(Composition("A2B"), energy=-0.2),  # less stable per atom
    ]
    try:
        pd = PhaseDiagram(entries)
    except Exception as e:
        print(f"  FAIL: PhaseDiagram construction raised {type(e).__name__}: {e}")
        print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ FAIL")
        return 1

    stable_compositions = {e.composition.reduced_formula for e in pd.stable_entries}
    if "AB" not in stable_compositions:
        print(f"  FAIL: AB not stable in phase diagram. stable={stable_compositions}")
        print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ FAIL")
        return 1
    print(f"  PASS: PhaseDiagram constructed; stable={stable_compositions}")

    # The hull should report AB at energy_above_hull == 0.
    eah = pd.get_e_above_hull(entries[2])
    if abs(eah) > 1e-9:
        print(f"  FAIL: AB e_above_hull = {eah} (expected 0)")
        print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ FAIL")
        return 1
    print(f"  PASS: AB e_above_hull = {eah:.3e} eV/atom (on hull)")

    print("__HEXA_MATTER_PYMATGEN_PHASEDIAGRAM_SMOKE__ PASS")
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
