#!/usr/bin/env python3
"""
schematic_3_scaffold_audit_v7.py — Phase β #6 (v7 2026-05-11).

3 schematic small-mol 후보 scaffold class 해소 (c9orf72 paradigm 적용):

(a) hxq-cmt-gjb1-001 — Cx32 mutant fold-rescue chaperone (CMT1X, IT delivery)
    BBB irrelevant (IT only) + Schwann selectivity
    paradigm: 4-PBA chemical chaperone class / aryl-piperidinyl-amide

(b) hxq-als-kif5a-001 — KIF5A motor ATPase stabilizer (ALS, BBB-penetrant)
    BBB target logP 2.5-3.5
    paradigm: 4-aryl-pyrimidin-2-amine + 5-CF3 lipophilic
    paralog KIF1A/KIF3A selectivity ≥500x (wet-lab, 본 audit 범위 외)

(c) hxq-als-tbk1-001 — TBK1 LoF rescue chaperone (ALS, BBB-penetrant)
    BBB target logP 2.5-3.5
    paradigm: indazole-3-carboxamide + amine tail (BX-795 paradigm 변형)
    paralog IKKε selectivity ≥500x (wet-lab)

각 후보 2 variant 씩 — rdkit precise + UFF 3D geom.
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors


CANDIDATES = [
    # gjb1 cohort — Cx32 mutant fold-rescue (IT, BBB 무관, Schwann selectivity)
    ("hxq-cmt-gjb1-001-A",
     "O=C(NC1CCN(CC2CC2)CC1)c1ccc(C(F)(F)F)cc1",
     "4-CF3-aryl + (4-cyclopropylmethyl-piperidin-1-yl)-carboxamide (chemical chaperone, IT)"),
    ("hxq-cmt-gjb1-001-B",
     "O=C(O)CCCc1ccc(C(F)(F)F)cc1",
     "4-(4-trifluoromethylphenyl)butyric acid (4-PBA + CF3 = Schwann selective)"),
    # kif5a cohort — motor ATPase stabilizer (BBB-penetrant)
    ("hxq-als-kif5a-001-A",
     "Nc1ncc(C(F)(F)F)c(-c2ccc(F)cc2)n1",
     "2-amino-5-CF3-4-(p-F-phenyl)pyrimidine (BBB + ATPase pocket lipophilic)"),
    ("hxq-als-kif5a-001-B",
     "Nc1nccc(-c2cccc(C(C)C)c2)n1",
     "2-amino-4-(m-isopropyl-phenyl)pyrimidine (BBB + 입체 안정성)"),
    # tbk1 cohort — kinase LoF rescue chaperone (BBB-penetrant)
    ("hxq-als-tbk1-001-A",
     "Nc1ccc2[nH]nc(C(=O)NCCN(C)C)c2c1",
     "5-amino-indazole-3-carboxamide + 디메틸아미노에틸 (BX-795 simplified, LoF chaperone heuristic)"),
    ("hxq-als-tbk1-001-B",
     "O=C(Nc1ccc(C2CC2)cc1)c1n[nH]c2ccccc12",
     "indazole-3-carboxamide + 4-cyclopropyl-aryl (lipophilic kinase chaperone)"),
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
        "Ro5_pass": ro5 == 0, "Veber_pass": veber, "BBB_pass": bbb_pass,
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
    print("# §12.2.g schematic 3 scaffold class 해소 (gjb1/kif5a/tbk1)\n")
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

    with open("tests/schematic_3_scaffold_geoms.json", "w") as f:
        json.dump(geoms, f, indent=2)
    print(f"\n\nSaved {len(geoms)} geometries to tests/schematic_3_scaffold_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
