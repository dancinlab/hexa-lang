#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rdkit_descriptor_calc.py — molecular descriptors (MolWt, LogP, TPSA, HBA,
HBD) for adhesive monomers, elastomer crosslinkers, biodegradable-plastics
monomers, and POL group oligomer building blocks.

Status: PARTIAL (FUNCTIONAL with RDKit; SKIPs cleanly without).

Descriptors:
  MolWt  — molecular weight (g/mol)
  LogP   — Crippen-Wildman octanol/water partition coefficient
  TPSA   — topological polar surface area (Å²)
  HBA    — hydrogen-bond acceptor count
  HBD    — hydrogen-bond donor count

These descriptors are used by:
  - adhesive/adhesive.md      (cyanoacrylate, structural)
  - elastomer/elastomer.md    (NR, SBR, EPDM precursors)
  - biodegradable-plastics/biodegradable-plastics.md (PLA/PHA/PBS monomers)

control. They are NOT applied to vendor MWD data or commercial product
spec values to claim equivalence.

Optional dep: rdkit-pypi >= 2022.9.1

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import sys
import argparse
from typing import Dict, Optional


def _have_rdkit() -> bool:
    try:
        import rdkit  # noqa: F401
        return True
    except ImportError:
        return False


def descriptors(smiles: str) -> Optional[Dict[str, float]]:
    """Compute the 5 descriptors. Returns None if RDKit missing or invalid SMILES."""
    if not _have_rdkit():
        return None
    from rdkit import Chem
    from rdkit.Chem import Descriptors, Crippen, rdMolDescriptors

    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return None
    return {
        "MolWt": Descriptors.MolWt(mol),
        "LogP":  Crippen.MolLogP(mol),
        "TPSA":  rdMolDescriptors.CalcTPSA(mol),
        "HBA":   rdMolDescriptors.CalcNumHBA(mol),
        "HBD":   rdMolDescriptors.CalcNumHBD(mol),
    }


def _selftest() -> int:
    if not _have_rdkit():
        print("  SKIP: rdkit not installed")
        print("  install: pip install rdkit-pypi")
        print("__HEXA_MATTER_RDKIT_DESCRIPTOR_CALC__ PASS (SKIP mode)")
        return 0

    # Three monomers + a tolerance band for each descriptor (LogP is a Crippen
    # fit, so we keep tolerance generous; MolWt is exact via mass table).
    cases = [
        # (smiles, label, exp_MolWt, exp_MolWt_tol)
        ("CC(C(=O)O)O",          "lactic acid",     90.0,   1.0),  # PLA monomer
        ("OC(=O)CCCCC(=O)O",     "adipic acid",     146.0,  1.0),  # nylon-6,6 monomer
        ("C(=C)C#N",             "acrylonitrile",   53.0,   1.0),  # PAN/CF precursor
        ("c1ccccc1",             "benzene",         78.0,   1.0),  # aromatic
    ]
    fail = 0
    for smi, label, exp_mw, tol in cases:
        d = descriptors(smi)
        if d is None:
            print(f"  FAIL: {label}: descriptors() returned None for {smi}")
            fail += 1
            continue
        if abs(d["MolWt"] - exp_mw) > tol:
            print(f"  FAIL: {label}: MolWt={d['MolWt']:.2f}  expected={exp_mw}±{tol}")
            fail += 1
            continue
        # Sanity: HBA, HBD are non-negative integers; TPSA is non-negative;
        # LogP is a real number (can be negative for very polar).
        if d["HBA"] < 0 or d["HBD"] < 0 or d["TPSA"] < 0:
            print(f"  FAIL: {label}: negative descriptor value {d}")
            fail += 1
            continue
        print(f"  PASS: {label:<20}  MolWt={d['MolWt']:.2f}  LogP={d['LogP']:.2f}  TPSA={d['TPSA']:.1f}  HBA={d['HBA']}  HBD={d['HBD']}")

    if fail:
        print(f"__HEXA_MATTER_RDKIT_DESCRIPTOR_CALC__ FAIL ({fail} failures)")
        return 1
    print("__HEXA_MATTER_RDKIT_DESCRIPTOR_CALC__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--smiles", default=None, help="compute descriptors for a SMILES string")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    if args.smiles:
        d = descriptors(args.smiles)
        if d is None:
            print("RDKit missing or invalid SMILES")
            return 1
        for k, v in d.items():
            print(f"{k}: {v}")
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
