#!/usr/bin/env python3
"""
sar1_alt_audit_v7.py — Phase β #2 (v7 follow-up 2026-05-11).

§10 의 hxq-cmt-sar1-001 / hxq-als-sar1-001 IP-회피 대안 SMILES land +
rdkit 정밀 audit (Ro5 + Veber + TPSA + RotB + formal charge) + UFF 3D
geometry 산출 → tests/sar1_alt_geoms.json.

(qiskit_nature build + VQE 는 별도 process — sshfs nested .so 우회.)

원본:  `hxq-cmt-sar1-001` SMILES = `Nc1nc2cc(F)c(F)cc2c(=O)n1Cc1ccncc1`
                                     ↑ 2-amino-quinazolin-4(1H)-one (Disarm/Lilly territory)

대안:
  - alt-A: 7-aza-quinazolin-4-one (ring N relocate, di-F 보존)
  - alt-B: pyrido[2,3-d]pyrimidin-4-one (fused pyrido-pyrimidinone, 5-F)
  - alt-C: pteridin-4-one (di-aza, 6-F)
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors


CANDIDATES = [
    ("hxq-cmt-sar1-001-orig",
     "Nc1nc2cc(F)c(F)cc2c(=O)n1Cc1ccncc1",
     "2-amino-quinazolin-4(1H)-one + 6,7-diF + N-pyridyl-4-methyl (CURRENT, Disarm/Lilly territory)"),
    ("hxq-cmt-sar1-alt-A",
     "Nc1nc2cc(F)c(F)nc2c(=O)n1Cc1ccncc1",
     "8-aza-quinazolin-4(1H)-one (ring N at position 8, di-F 보존)"),
    ("hxq-cmt-sar1-alt-B",
     "Nc1nc2nc(F)ccc2c(=O)n1Cc1ccncc1",
     "pyrido[2,3-d]pyrimidin-4(3H)-one (fused pyrido-pyrimidinone, 5-F)"),
    ("hxq-cmt-sar1-alt-C",
     "Nc1nc2cnc(F)cc2c(=O)n1Cc1ccncc1",
     "pyrido[3,4-d]pyrimidin-4(3H)-one (fused pyrido-pyrimidinone alt regio, 6-F)"),
]


def audit_props(name: str, smiles: str) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return {"id": name, "smiles": smiles, "error": "rdkit parse FAIL"}
    heavy = mol.GetNumHeavyAtoms()
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    hbd = Lipinski.NumHDonors(mol)
    hba = Lipinski.NumHAcceptors(mol)
    tpsa = rdMolDescriptors.CalcTPSA(mol)
    rotb = Lipinski.NumRotatableBonds(mol)
    fcharge = Chem.GetFormalCharge(mol)
    ro5v = sum([mw > 500, logp > 5, hbd > 5, hba > 10])
    veber = (tpsa < 140) and (rotb < 10)
    return {
        "id": name, "smiles": smiles, "heavy": heavy,
        "MW": round(mw, 2), "logP": round(logp, 2),
        "HBD": hbd, "HBA": hba, "TPSA": round(tpsa, 2),
        "RotB": rotb, "FC": fcharge,
        "Ro5_violations": ro5v, "Ro5_pass": ro5v == 0,
        "Veber_pass": veber,
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
    return {
        "n_atoms_with_h": mol.GetNumAtoms(),
        "pyscf_atom": "; ".join(parts),
    }


def main() -> int:
    print("# §10/§11 sar1-001 IP-회피 대안 SMILES audit\n")

    audited = []
    geoms = {}
    cols = ["id", "heavy", "formula", "MW", "logP", "HBD", "HBA", "TPSA", "RotB", "Ro5", "Veber"]
    print("| " + " | ".join(cols) + " |")
    print("| " + " | ".join(["---"] * len(cols)) + " |")
    for name, smiles, desc in CANDIDATES:
        r = audit_props(name, smiles)
        if "error" in r:
            print(f"| {name} | PARSE FAIL | {smiles} | | | | | | | | |")
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
        for k, v in r.items():
            if k in ("id", "smiles", "desc"):
                continue
            print(f"- {k}: {v}")

    with open("tests/sar1_alt_geoms.json", "w") as f:
        json.dump(geoms, f, indent=2)
    print(f"\n\nSaved {len(geoms)} geometries to tests/sar1_alt_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
