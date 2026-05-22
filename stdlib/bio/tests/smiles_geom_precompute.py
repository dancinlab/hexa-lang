#!/usr/bin/env python3
"""
smiles_geom_precompute.py — v7 land 2026-05-11.

5 placeholder SMILES → rdkit UFF-optimized 3D xyz → pyscf_atom string.
Output JSON saved to tests/smiles_geoms.json. Run before quantum experiments
to bypass sshfs shared-library load issue when rdkit + qiskit_nature live
in the same process.
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem

CANDIDATES = [
    ("hxq-cmt-hd6-001",  "OC(=O)c1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1"),
    ("hxq-cmt-clc1-001", "OC(=O)c1ccccc1Nc1ccc(C(F)(F)F)nc1F"),
    ("hxq-cmt-sar1-001", "Nc1nc2cc(F)c(F)cc2c(=O)n1Cc1ccncc1"),
    ("hxq-cmt-mfn2-001", "O=C(NC1CCCCC1NC(=O)c1cccnc1)c1cccnc1"),
    ("hxq-als-hd6-001",  "Cc1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1"),
]


def smiles_to_pyscf_atom(smiles: str, seed: int = 7) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError(f"rdkit parse fail: {smiles!r}")
    mol = Chem.AddHs(mol)
    rc = AllChem.EmbedMolecule(mol, randomSeed=seed)
    if rc != 0:
        rc = AllChem.EmbedMolecule(mol, randomSeed=seed, useRandomCoords=True)
        if rc != 0:
            raise RuntimeError(f"rdkit embed fail: {smiles!r}")
    AllChem.UFFOptimizeMolecule(mol, maxIters=400)

    conf = mol.GetConformer()
    atoms = []
    parts = []
    for atom in mol.GetAtoms():
        pos = conf.GetAtomPosition(atom.GetIdx())
        sym = atom.GetSymbol()
        atoms.append({"sym": sym, "x": pos.x, "y": pos.y, "z": pos.z})
        parts.append(f"{sym} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f}")
    return {
        "smiles": smiles,
        "canonical_smiles": Chem.MolToSmiles(Chem.MolFromSmiles(smiles)),
        "n_atoms": mol.GetNumAtoms(),
        "n_heavy": Chem.MolFromSmiles(smiles).GetNumHeavyAtoms(),
        "formula": Chem.rdMolDescriptors.CalcMolFormula(mol),
        "pyscf_atom": "; ".join(parts),
        "atoms": atoms,
    }


def main() -> int:
    out = {}
    for name, smiles in CANDIDATES:
        try:
            geom = smiles_to_pyscf_atom(smiles)
            out[name] = geom
            print(f"  {name}: n_atoms={geom['n_atoms']} heavy={geom['n_heavy']} formula={geom['formula']}")
        except Exception as exc:
            out[name] = {"error": str(exc)}
            print(f"  {name}: FAIL {exc}")
    with open("tests/smiles_geoms.json", "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved 5 geometries to tests/smiles_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
