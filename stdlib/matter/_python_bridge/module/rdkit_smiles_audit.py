#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rdkit_smiles_audit.py — SMILES validity and canonicalization for organic
material specs (POL group: epoxy DGEBA, nylon-6,6 ε-caprolactam, PET,
adhesive cyanoacrylate, biodegradable PLA lactide, etc.).

Status: PARTIAL (FUNCTIONAL with RDKit; SKIPs cleanly without).

Phase E: this is the chemistry arm of the bridge. It validates that the
SMILES literals embedded in POL/adhesive/biodegradable spec docs parse
correctly and canonicalize stably.

chemical-structure databases. SMILES → canonical SMILES is pure structural
identity.

Optional dep: rdkit-pypi >= 2022.9.1
  pip install rdkit-pypi

License: MIT (hexa-matter Phase E).
"""

from __future__ import annotations
import sys
import argparse
from typing import Optional


def _have_rdkit() -> bool:
    try:
        import rdkit  # noqa: F401
        return True
    except ImportError:
        return False


def canonicalize_smiles(smiles: str) -> Optional[str]:
    """Return canonical SMILES, or None if invalid.

    SKIPs cleanly without RDKit by returning None and the caller is expected
    to honor that. For "validity == None means RDKit-missing" disambiguation
    use `_have_rdkit()` directly.
    """
    if not _have_rdkit():
        return None
    from rdkit import Chem
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return None
    return Chem.MolToSmiles(mol, canonical=True)


def is_valid_smiles(smiles: str) -> Optional[bool]:
    """Return True/False/None where None means "RDKit unavailable, SKIP"."""
    if not _have_rdkit():
        return None
    from rdkit import Chem
    return Chem.MolFromSmiles(smiles) is not None


def _selftest() -> int:
    if not _have_rdkit():
        print("  SKIP: rdkit not installed")
        print("  install: pip install rdkit-pypi")
        print("__HEXA_MATTER_RDKIT_SMILES_AUDIT__ PASS (SKIP mode)")
        return 0

    # Canonical SMILES of materials-relevant organics.
    # All MUST parse and round-trip stably.
    cases = [
        ("CC(=O)O",                              "acetic acid"),                # POL precursor
        ("c1ccccc1",                             "benzene"),                    # aromatic
        ("O=C(O)c1ccc(O)cc1",                    "p-hydroxybenzoic acid"),      # adhesive monomer
        ("CC(C)(c1ccc(OC2CO2)cc1)c1ccc(OC2CO2)cc1", "DGEBA epoxy"),             # epoxy
        ("CC1=CCC(CC1)C(=C)C",                   "limonene"),                   # bio-monomer
        ("OCC1OC(O)C(O)C(O)C1O",                 "glucose"),                    # cellulose monomer
        ("CC(C(=O)O)O",                          "lactic acid"),                # PLA monomer
        ("NCCCCCN.OC(=O)CCCCC(=O)O",             "nylon-6,6 salt (HMDA + AA)"), # nylon
        ("C(=C)C#N",                             "acrylonitrile"),              # PAN/carbon-fiber precursor
        ("[H]/N=C(/N)N",                         "guanidine"),                  # adhesive
    ]
    fail = 0
    for smi, label in cases:
        canon = canonicalize_smiles(smi)
        if canon is None:
            print(f"  FAIL: {label}: SMILES {smi!r} could not be canonicalized")
            fail += 1
            continue
        # Round-trip: canonicalize the canonical form again — must be stable.
        re_canon = canonicalize_smiles(canon)
        if re_canon != canon:
            print(f"  FAIL: {label}: canonicalization not stable. {canon!r} → {re_canon!r}")
            fail += 1
            continue
        print(f"  PASS: {label:<30}  →  {canon}")

    # Negative case: invalid SMILES.
    bad = "this is not a smiles"
    if is_valid_smiles(bad):
        print(f"  FAIL: invalid SMILES {bad!r} reported valid")
        fail += 1
    else:
        print(f"  PASS: invalid SMILES {bad!r} correctly rejected")

    if fail:
        print(f"__HEXA_MATTER_RDKIT_SMILES_AUDIT__ FAIL ({fail} failures)")
        return 1
    print("__HEXA_MATTER_RDKIT_SMILES_AUDIT__ PASS")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--smiles", default=None, help="canonicalize a SMILES string")
    args = p.parse_args()
    if args.selftest:
        return _selftest()
    if args.smiles:
        c = canonicalize_smiles(args.smiles)
        print(c if c is not None else "INVALID (or RDKit missing)")
        return 0
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
