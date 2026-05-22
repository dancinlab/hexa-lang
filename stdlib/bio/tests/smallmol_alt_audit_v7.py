#!/usr/bin/env python3
"""
smallmol_alt_audit_v7.py — Phase β #3 (v7 follow-up 2026-05-11).

3 small-mol (hd6/clc1/mfn2) IP-회피 대안 SMILES land — §10 heuristic 직접 land.
rdkit precise Ro5+Veber audit + UFF 3D geom → JSON.

orig | hd6  | OC(=O)c1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1   [1,3,4-thiadiazol-2(3H)-thione, Eikonizo territory]
orig | clc1 | OC(=O)c1ccccc1Nc1ccc(C(F)(F)F)nc1F            [anthranilic + halopyridine, Sanofi ClC-K 인접]
orig | mfn2 | O=C(NC1CCCCC1NC(=O)c1cccnc1)c1cccnc1          [cyclohexanediamine + bis-nicotinamide]

alt:
  hd6-alt  | 1,3,4-oxadiazol-2(3H)-one ZBG + p-COOH-aryl    [Forma class 인접, but 별도 ZBG]
  clc1-alt | 2-aminonicotinic acid + halopyridyl-amino       [anthranilic 제거 → 2-aminonicotinic]
  mfn2-alt | pyrrolidin-2-yl + bis-pyrazinamide              [cyclohexyl→pyrrolidine, nicotin→pyrazin]
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors


CANDIDATES = [
    # hd6 cohort
    ("hxq-cmt-hd6-001-orig",
     "OC(=O)c1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1",
     "1,3,4-thiadiazol-2(3H)-thione ZBG (CURRENT, Eikonizo HIGH)"),
    ("hxq-cmt-hd6-alt",
     "OC(=O)c1ccc(NC(=O)CN2C(=O)ON=C2c2ccccc2)cc1",
     "1,3,4-oxadiazol-2(3H)-one ZBG (S→O ZBG swap, IP novel)"),
    ("hxq-als-hd6-alt",
     "Cc1ccc(NC(=O)CN2C(=O)ON=C2c2ccccc2)cc1",
     "1,3,4-oxadiazol-2(3H)-one ZBG + methyl aryl (BBB-penetrant, IP novel)"),
    # clc1 cohort
    ("hxq-cmt-clc1-001-orig",
     "OC(=O)c1ccccc1Nc1ccc(C(F)(F)F)nc1F",
     "2-anilinobenzoic acid (anthranilic, Sanofi 인접) (CURRENT, MED-HIGH)"),
    ("hxq-cmt-clc1-alt",
     "OC(=O)c1cccnc1Nc1ccc(C(F)(F)F)nc1F",
     "2-aminonicotinic acid + halopyridyl-amino (anthranilic 제거, IP novel)"),
    # mfn2 cohort
    ("hxq-cmt-mfn2-001-orig",
     "O=C(NC1CCCCC1NC(=O)c1cccnc1)c1cccnc1",
     "trans-1,2-cyclohexanediamine + bis-nicotinamide (CURRENT, LOW-MED)"),
    ("hxq-cmt-mfn2-alt",
     "O=C(NC1CCCN1C(=O)c1cnccn1)c1cnccn1",
     "pyrrolidin-2-yl + bis-pyrazin-2-yl-carboxamide (smaller ring, polar)"),
]


def audit(name: str, smiles: str) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return {"id": name, "smiles": smiles, "error": "rdkit parse FAIL"}
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    hbd = Lipinski.NumHDonors(mol)
    hba = Lipinski.NumHAcceptors(mol)
    tpsa = rdMolDescriptors.CalcTPSA(mol)
    rotb = Lipinski.NumRotatableBonds(mol)
    ro5 = sum([mw > 500, logp > 5, hbd > 5, hba > 10])
    veber = (tpsa < 140) and (rotb < 10)
    return {
        "id": name, "smiles": smiles,
        "heavy": mol.GetNumHeavyAtoms(),
        "MW": round(mw, 2), "logP": round(logp, 2),
        "HBD": hbd, "HBA": hba,
        "TPSA": round(tpsa, 2), "RotB": rotb,
        "FC": Chem.GetFormalCharge(mol),
        "Ro5_violations": ro5, "Ro5_pass": ro5 == 0, "Veber_pass": veber,
        "formula": rdMolDescriptors.CalcMolFormula(mol),
    }


def embed_3d(smiles: str, seed: int = 7) -> dict | None:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return None
    mol = Chem.AddHs(mol)
    rc = AllChem.EmbedMolecule(mol, randomSeed=seed)
    if rc != 0:
        rc = AllChem.EmbedMolecule(mol, randomSeed=seed, useRandomCoords=True)
        if rc != 0:
            return None
    AllChem.UFFOptimizeMolecule(mol, maxIters=400)
    conf = mol.GetConformer()
    parts = []
    for atom in mol.GetAtoms():
        pos = conf.GetAtomPosition(atom.GetIdx())
        parts.append(f"{atom.GetSymbol()} {pos.x:.6f} {pos.y:.6f} {pos.z:.6f}")
    return {"n_atoms_with_h": mol.GetNumAtoms(), "pyscf_atom": "; ".join(parts)}


def main() -> int:
    print("# 3 small-mol IP-회피 alt SMILES audit\n")
    cols = ["id", "heavy", "formula", "MW", "logP", "HBD", "HBA", "TPSA", "RotB", "Ro5", "Veber"]
    print("| " + " | ".join(cols) + " |")
    print("| " + " | ".join(["---"] * len(cols)) + " |")
    audited = []
    geoms = {}
    for name, smiles, desc in CANDIDATES:
        r = audit(name, smiles)
        if "error" in r:
            print(f"| {name} | PARSE FAIL | {smiles} | | | | | | | | |")
            audited.append({**r, "desc": desc})
            continue
        cells = [r["id"], str(r["heavy"]), r["formula"], str(r["MW"]), str(r["logP"]),
                 str(r["HBD"]), str(r["HBA"]), str(r["TPSA"]), str(r["RotB"]),
                 "PASS" if r["Ro5_pass"] else "FAIL",
                 "PASS" if r["Veber_pass"] else "FAIL"]
        print("| " + " | ".join(cells) + " |")
        audited.append({**r, "desc": desc})
        g = embed_3d(smiles)
        if g:
            geoms[name] = {**g, "smiles": smiles, "formula": r["formula"], "n_heavy": r["heavy"]}

    print("\n## Detail")
    for r in audited:
        print(f"\n### {r['id']} — {r['desc']}")
        print(f"SMILES: `{r['smiles']}`")
        if "error" in r:
            print(f"- ERROR: {r['error']}")
            continue
        for k, v in r.items():
            if k in ("id", "smiles", "desc"):
                continue
            print(f"- {k}: {v}")

    with open("tests/smallmol_alt_geoms.json", "w") as f:
        json.dump(geoms, f, indent=2)
    print(f"\n\nSaved {len(geoms)} geometries to tests/smallmol_alt_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
