#!/usr/bin/env python3
"""
cmt_extended_admet_v7.py — Phase γ closure push #1 (v7.1 2026-05-11).

CMT 5 small-mol (hd6/clc1/sar1/mfn2 orig + gjb1-A) + 4 IP-회피 alt
→ 확장 ADMET audit (rdkit-native):
  • PAINS_A/B/C alert (rdkit FilterCatalog)
  • brenk filter (toxicophore)
  • Lilly RotB / chiral count
  • QED (Quantitative Estimate of Drug-likeness)
  • Ghose, Egan, Muegge rule
  • SwissADME-style derived metrics (분자 부피, fraction Csp3, aromatic ring count)
  • ⚠️ ADMET predictor (PAMPA-BBB, P-gp efflux, CYP inhibition) = wet-lab/external

본 audit = 정량 drug-likeness 확장 (rdkit-native). real ADMET 측정 = wet-lab.
"""
from __future__ import annotations

import json
import sys

from rdkit import Chem
from rdkit.Chem import (
    AllChem, Crippen, Descriptors, Lipinski,
    rdMolDescriptors, QED, FilterCatalog,
)


CANDIDATES = [
    # CMT 5 small-mol (orig)
    ("hxq-cmt-hd6-001-orig",  "OC(=O)c1ccc(NC(=O)CN2C(=S)NN=C2c2ccccc2)cc1"),
    ("hxq-cmt-clc1-001-orig", "OC(=O)c1ccccc1Nc1ccc(C(F)(F)F)nc1F"),
    ("hxq-cmt-sar1-001-orig", "Nc1nc2cc(F)c(F)cc2c(=O)n1Cc1ccncc1"),
    ("hxq-cmt-mfn2-001-orig", "O=C(NC1CCCCC1NC(=O)c1cccnc1)c1cccnc1"),
    ("hxq-cmt-gjb1-001-A",    "O=C(NC1CCN(CC2CC2)CC1)c1ccc(C(F)(F)F)cc1"),
    # IP-회피 alt 4 (v7 권장)
    ("hxq-cmt-hd6-alt",       "OC(=O)c1ccc(NC(=O)CN2C(=O)ON=C2c2ccccc2)cc1"),
    ("hxq-cmt-clc1-alt",      "OC(=O)c1cccnc1Nc1ccc(C(F)(F)F)nc1F"),
    ("hxq-cmt-sar1-alt-B",    "Nc1nc2nc(F)ccc2c(=O)n1Cc1ccncc1"),
    ("hxq-cmt-mfn2-alt",      "O=C(NC1CCCN1C(=O)c1cnccn1)c1cnccn1"),
]


def pains_check(mol) -> dict:
    params = FilterCatalog.FilterCatalogParams()
    params.AddCatalog(FilterCatalog.FilterCatalogParams.FilterCatalogs.PAINS_A)
    params.AddCatalog(FilterCatalog.FilterCatalogParams.FilterCatalogs.PAINS_B)
    params.AddCatalog(FilterCatalog.FilterCatalogParams.FilterCatalogs.PAINS_C)
    cat = FilterCatalog.FilterCatalog(params)
    entries = cat.GetMatches(mol)
    return {
        "PAINS_hits": len(entries),
        "PAINS_alerts": [e.GetDescription() for e in entries] if entries else [],
    }


def brenk_check(mol) -> dict:
    params = FilterCatalog.FilterCatalogParams()
    params.AddCatalog(FilterCatalog.FilterCatalogParams.FilterCatalogs.BRENK)
    cat = FilterCatalog.FilterCatalog(params)
    entries = cat.GetMatches(mol)
    return {
        "BRENK_hits": len(entries),
        "BRENK_alerts": [e.GetDescription() for e in entries] if entries else [],
    }


def ghose(mol) -> bool:
    """Ghose drug-likeness: 160<MW<480, -0.4<logP<5.6, 40<MR<130, 20<atoms<70."""
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    mr = Crippen.MolMR(mol)
    natoms = mol.GetNumAtoms()
    return (160 < mw < 480) and (-0.4 < logp < 5.6) and (40 < mr < 130) and (20 < natoms < 70)


def egan(mol) -> bool:
    """Egan: logP<5.88, TPSA<131.6."""
    return Crippen.MolLogP(mol) < 5.88 and rdMolDescriptors.CalcTPSA(mol) < 131.6


def muegge(mol) -> bool:
    """Muegge: 200<MW<600, -2<logP<5, TPSA<150, RotB<15, ring count>0, atom variety."""
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    tpsa = rdMolDescriptors.CalcTPSA(mol)
    rotb = Lipinski.NumRotatableBonds(mol)
    rings = rdMolDescriptors.CalcNumRings(mol)
    hbd = Lipinski.NumHDonors(mol)
    hba = Lipinski.NumHAcceptors(mol)
    return (
        200 < mw < 600 and -2 < logp < 5 and tpsa < 150 and
        rotb < 15 and rings > 0 and hbd <= 5 and hba <= 10
    )


def audit_extended(name: str, smiles: str) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return {"id": name, "error": "parse FAIL"}
    mw = Descriptors.ExactMolWt(mol)
    logp = Crippen.MolLogP(mol)
    hbd = Lipinski.NumHDonors(mol)
    hba = Lipinski.NumHAcceptors(mol)
    tpsa = rdMolDescriptors.CalcTPSA(mol)
    rotb = Lipinski.NumRotatableBonds(mol)
    natoms = mol.GetNumAtoms()
    nheavy = mol.GetNumHeavyAtoms()
    nrings = rdMolDescriptors.CalcNumRings(mol)
    naromatic = rdMolDescriptors.CalcNumAromaticRings(mol)
    fcsp3 = rdMolDescriptors.CalcFractionCSP3(mol)
    nchiral = len(Chem.FindMolChiralCenters(mol, includeUnassigned=True))
    qed_score = QED.qed(mol)
    pains = pains_check(mol)
    brenk = brenk_check(mol)
    return {
        "id": name, "smiles": smiles,
        "heavy": nheavy, "MW": round(mw, 2), "logP": round(logp, 2),
        "HBD": hbd, "HBA": hba, "TPSA": round(tpsa, 2), "RotB": rotb,
        "nrings": nrings, "naromatic": naromatic,
        "fCsp3": round(fcsp3, 3), "nchiral": nchiral,
        "QED": round(qed_score, 3),
        "Lipinski_pass": (mw <= 500 and logp <= 5 and hbd <= 5 and hba <= 10),
        "Veber_pass": (tpsa < 140 and rotb < 10),
        "Ghose_pass": ghose(mol),
        "Egan_pass": egan(mol),
        "Muegge_pass": muegge(mol),
        "PAINS_hits": pains["PAINS_hits"],
        "PAINS_alerts": pains["PAINS_alerts"],
        "BRENK_hits": brenk["BRENK_hits"],
        "BRENK_alerts": brenk["BRENK_alerts"][:3],  # first 3
        "formula": rdMolDescriptors.CalcMolFormula(mol),
    }


def main() -> int:
    print("# §15.1 CMT extended ADMET audit (rdkit-native)\n")
    rows = []
    for name, smi in CANDIDATES:
        r = audit_extended(name, smi)
        rows.append(r)
        print(f"\n### {name}")
        print(f"SMILES: `{smi}`")
        if "error" in r:
            print(f"ERROR: {r['error']}"); continue
        for k, v in r.items():
            if k in ("id", "smiles"):
                continue
            print(f"  {k}: {v}")
    print("\n## Summary table")
    cols = ["id", "QED", "Lipinski", "Veber", "Ghose", "Egan", "Muegge", "PAINS", "BRENK", "fCsp3"]
    print("| " + " | ".join(cols) + " |")
    print("| " + " | ".join(["---"] * len(cols)) + " |")
    for r in rows:
        if "error" in r:
            continue
        cells = [
            r["id"], str(r["QED"]),
            "PASS" if r["Lipinski_pass"] else "FAIL",
            "PASS" if r["Veber_pass"] else "FAIL",
            "PASS" if r["Ghose_pass"] else "FAIL",
            "PASS" if r["Egan_pass"] else "FAIL",
            "PASS" if r["Muegge_pass"] else "FAIL",
            f"{r['PAINS_hits']} alert" if r['PAINS_hits'] else "clean",
            f"{r['BRENK_hits']} alert" if r['BRENK_hits'] else "clean",
            str(r["fCsp3"]),
        ]
        print("| " + " | ".join(cells) + " |")
    print("\n## JSON")
    print(json.dumps(rows, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
