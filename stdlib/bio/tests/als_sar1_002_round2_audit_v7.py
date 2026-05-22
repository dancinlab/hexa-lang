#!/usr/bin/env python3
"""
als_sar1_002_round2_audit_v7.py — Phase β #5 round 2 (v7 2026-05-11).

round 1 (sar1-002-A/B/C/D) 모두 BBB FAIL — pyridylmethyl 의 N 가 TPSA +12, logP -0.5
영향. round 2 = pyridyl→phenyl 또는 naphthyl + 6-CF3 다중치환.
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors


CANDIDATES = [
    ("hxq-als-sar1-002-E",
     "Nc1nc2nc(F)c(C(F)(F)F)cc2c(=O)n1Cc1ccc(C(F)(F)F)cc1",
     "alt-B + 6-CF3 + p-CF3-benzyl (pyridyl→benzyl, bisCF3 lipophilic)"),
    ("hxq-als-sar1-002-F",
     "Nc1nc2nc(F)c(C(F)(F)F)cc2c(=O)n1Cc1ccc2ccccc2c1",
     "alt-B + 6-CF3 + naphthyl-1-methyl (rigid lipophile cap)"),
    ("hxq-als-sar1-002-G",
     "Nc1nc2nc(F)c(C(F)(F)F)cc2c(=O)n1Cc1ccccc1",
     "alt-B + 6-CF3 + benzyl (single lipophilic substituent, IP novel)"),
    ("hxq-als-sar1-002-H",
     "Nc1nc2nc(F)ccc2c(=O)n1Cc1cc(C(F)(F)F)cc(C(F)(F)F)c1",
     "alt-B + 3,5-bis-CF3-benzyl (TIR pocket lipophilic groove)"),
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
    bbb_logp_ok = 2.5 <= logp <= 3.5
    bbb_tpsa_ok = tpsa < 90
    bbb_hbd_ok = hbd < 3
    bbb_mw_ok = mw < 450
    bbb_pass = bbb_logp_ok and bbb_tpsa_ok and bbb_hbd_ok and bbb_mw_ok
    return {
        "id": name, "smiles": smiles, "heavy": mol.GetNumHeavyAtoms(),
        "MW": round(mw, 2), "logP": round(logp, 2),
        "HBD": hbd, "HBA": hba, "TPSA": round(tpsa, 2), "RotB": rotb,
        "Ro5_pass": ro5 == 0, "Veber_pass": veber,
        "BBB_pass": bbb_pass,
        "BBB_logP_ok": bbb_logp_ok, "BBB_TPSA_ok": bbb_tpsa_ok,
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
    print("# §12.2.f.ii als-sar1-002 round 2 (benzyl 변환 + CF3 다중치환)\n")
    cols = ["id", "heavy", "formula", "MW", "logP", "HBD", "HBA", "TPSA", "Ro5", "Veber", "BBB"]
    print("| " + " | ".join(cols) + " |")
    print("| " + " | ".join(["---"] * len(cols)) + " |")
    audited = []
    geoms = {}
    for name, smiles, desc in CANDIDATES:
        r = audit(name, smiles)
        if "error" in r:
            print(f"| {name} | PARSE FAIL | | | | | | | | | |")
            audited.append({**r, "desc": desc})
            continue
        cells = [r["id"], str(r["heavy"]), r["formula"], str(r["MW"]), str(r["logP"]),
                 str(r["HBD"]), str(r["HBA"]), str(r["TPSA"]),
                 "PASS" if r["Ro5_pass"] else "FAIL",
                 "PASS" if r["Veber_pass"] else "FAIL",
                 "PASS" if r["BBB_pass"] else "FAIL"]
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

    with open("tests/als_sar1_002_round2_geoms.json", "w") as f:
        json.dump(geoms, f, indent=2)
    print(f"\n\nSaved {len(geoms)} geometries to tests/als_sar1_002_round2_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
