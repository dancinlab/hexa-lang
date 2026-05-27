#!/usr/bin/env python3
"""
rdkit_precise_audit.py — v7 land 2026-05-11.

§8 v6 hand-heuristic Ro5 audit (5 placeholder SMILES) 를 rdkit 정밀
audit 으로 승격: MW + logP (Crippen) + HBD + HBA + TPSA + RotB + formal
charge + Lipinski violations + Veber pass.

5 placeholder SMILES = `hxq-{cmt-hd6,cmt-clc1,cmt-sar1,cmt-mfn2,als-hd6}-001`.

Output: stdout markdown table — `.roadmap.novel_drugs §11` 직접 paste.
"""

from rdkit import Chem
from rdkit.Chem import AllChem, Crippen, Descriptors, Lipinski, rdMolDescriptors

CANDIDATES = [
    ("hxq-cmt-hd6-001",  "OC(=O)c1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1"),
    ("hxq-cmt-clc1-001", "OC(=O)c1ccccc1Nc1ccc(C(F)(F)F)nc1F"),
    ("hxq-cmt-sar1-001", "Nc1nc2cc(F)c(F)cc2c(=O)n1Cc1ccncc1"),
    ("hxq-cmt-mfn2-001", "O=C(NC1CCCCC1NC(=O)c1cccnc1)c1cccnc1"),
    ("hxq-als-hd6-001",  "Cc1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1"),
]


def audit(name: str, smiles: str) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return {"id": name, "error": "rdkit parse fail"}
    AllChem.Compute2DCoords(mol)
    heavy = mol.GetNumHeavyAtoms()
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    hbd = Lipinski.NumHDonors(mol)
    hba = Lipinski.NumHAcceptors(mol)
    tpsa = rdMolDescriptors.CalcTPSA(mol)
    rotb = Lipinski.NumRotatableBonds(mol)
    fcharge = Chem.GetFormalCharge(mol)
    ro5 = sum([mw > 500, logp > 5, hbd > 5, hba > 10])
    veber_pass = (tpsa < 140) and (rotb < 10)
    return {
        "id": name,
        "smiles": smiles,
        "heavy": heavy,
        "MW": round(mw, 2),
        "logP": round(logp, 2),
        "HBD": hbd,
        "HBA": hba,
        "TPSA": round(tpsa, 2),
        "RotB": rotb,
        "formal_charge": fcharge,
        "Ro5_violations": ro5,
        "Ro5_pass": ro5 == 0,
        "Veber_pass": veber_pass,
    }


def main() -> None:
    rows = [audit(n, s) for n, s in CANDIDATES]
    print("# §11 — rdkit 정밀 Ro5 + Veber audit (v7 land 2026-05-11)\n")
    print(f"rdkit version: {Chem.__version__ if hasattr(Chem, '__version__') else 'n/a'}\n")
    cols = ["id", "heavy", "MW", "logP", "HBD", "HBA", "TPSA", "RotB", "FC", "Ro5v", "Ro5", "Veber"]
    hdr = "| " + " | ".join(cols) + " |"
    sep = "| " + " | ".join(["---"] * len(cols)) + " |"
    print(hdr)
    print(sep)
    for r in rows:
        cells = [
            r["id"], str(r["heavy"]), str(r["MW"]), str(r["logP"]),
            str(r["HBD"]), str(r["HBA"]), str(r["TPSA"]), str(r["RotB"]),
            str(r["formal_charge"]),
            str(r["Ro5_violations"]),
            "PASS" if r["Ro5_pass"] else "FAIL",
            "PASS" if r["Veber_pass"] else "FAIL",
        ]
        print("| " + " | ".join(cells) + " |")
    print("\n## Detail")
    for r in rows:
        print(f"\n### {r['id']}")
        print(f"SMILES: `{r['smiles']}`")
        for k, v in r.items():
            if k in ("id", "smiles"):
                continue
            print(f"- {k}: {v}")


if __name__ == "__main__":
    main()
