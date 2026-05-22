#!/usr/bin/env python3
"""
als_sar1_002_c9orf72_audit_v7.py — Phase β #5 (v7 follow-up 2026-05-11).

(a) hxq-als-sar1-002 land — alt-B core (pyrido[2,3-d]pyrimidin-4-one) +
    lipophilic 강화 (6-CF3 / 6-Cl / 6-Me / 7-cyclopropyl) → logP 2.5-3.5
    BBB target 도달 검증.

(b) hxq-als-c9orf72-001 scaffold class 해소 — G4C2 secondary structure
    binder paradigm (acridine + carbazole class heuristic) 3 variant.

rdkit precise audit + UFF 3D geom → JSON for 후속 VQE pipeline.
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors


CANDIDATES = [
    # als-sar1-002 cohort (alt-B core + lipophilic substituent)
    ("hxq-als-sar1-001-alt-B-ref",
     "Nc1nc2nc(F)ccc2c(=O)n1Cc1ccncc1",
     "[ref] alt-B core (CMT 권장, logP 0.96 — ALS BBB 부적합)"),
    ("hxq-als-sar1-002-A",
     "Nc1nc2nc(F)c(C(F)(F)F)cc2c(=O)n1Cc1ccncc1",
     "alt-B + 6-CF3 (lipophilic 강화 + electron-withdrawing TIR pocket)"),
    ("hxq-als-sar1-002-B",
     "Nc1nc2nc(F)c(Cl)cc2c(=O)n1Cc1ccncc1",
     "alt-B + 6-Cl (lipophilic 강화 mild + TIR pocket H-bond accept)"),
    ("hxq-als-sar1-002-C",
     "Nc1nc2nc(F)c(C)cc2c(=O)n1Cc1ccncc1",
     "alt-B + 6-Me (mild logP 강화, minimal perturbation)"),
    ("hxq-als-sar1-002-D",
     "Nc1nc2nc(F)cc(C3CC3)c2c(=O)n1Cc1ccncc1",
     "alt-B + 7-cyclopropyl (rigid lipophile + 평면 TIR pocket 적합)"),
    # c9orf72-001 cohort (G4C2 secondary structure binder)
    ("hxq-als-c9orf72-001-A",
     "CN(C)CCNc1c2ccccc2nc2ccccc12",
     "9-amino-N-(dimethylamino-ethyl)acridine (G4 stabilizer, BRACO-19 simplified)"),
    ("hxq-als-c9orf72-001-B",
     "Nc1ccc2nc3ccccc3c(NCCN4CCCCC4)c2c1",
     "3-amino-9-(piperidin-1-yl-ethylamino)acridine (G4 bisamino)"),
    ("hxq-als-c9orf72-001-C",
     "O=C(NCCCN1CCCCC1)c1cc2ccccc2[nH]1",
     "indole-2-carboxamide + piperidine-propyl (DC-34 class G4 RNA binder)"),
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
    # BBB target: logP 2.5-3.5, TPSA <90, HBD<3, MW <450
    bbb_logp_ok = 2.5 <= logp <= 3.5
    bbb_tpsa_ok = tpsa < 90
    bbb_hbd_ok = hbd < 3
    bbb_mw_ok = mw < 450
    bbb_pass = bbb_logp_ok and bbb_tpsa_ok and bbb_hbd_ok and bbb_mw_ok
    return {
        "id": name, "smiles": smiles,
        "heavy": mol.GetNumHeavyAtoms(),
        "MW": round(mw, 2), "logP": round(logp, 2),
        "HBD": hbd, "HBA": hba,
        "TPSA": round(tpsa, 2), "RotB": rotb,
        "FC": Chem.GetFormalCharge(mol),
        "Ro5_violations": ro5, "Ro5_pass": ro5 == 0, "Veber_pass": veber,
        "BBB_pass": bbb_pass,
        "BBB_detail": {
            "logP_2.5_3.5": bbb_logp_ok,
            "TPSA_lt_90": bbb_tpsa_ok,
            "HBD_lt_3": bbb_hbd_ok,
            "MW_lt_450": bbb_mw_ok,
        },
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
    print("# §12.2.f als-sar1-002 + c9orf72-001 scaffold audit\n")
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

    with open("tests/als_sar1_002_c9orf72_geoms.json", "w") as f:
        json.dump(geoms, f, indent=2)
    print(f"\n\nSaved {len(geoms)} geometries to tests/als_sar1_002_c9orf72_geoms.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
