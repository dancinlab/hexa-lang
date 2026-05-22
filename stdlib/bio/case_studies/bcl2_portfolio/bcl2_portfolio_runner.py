#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bcl2_portfolio_runner.py — BCL-2 / hematologic malignancies portfolio
case study (one-disease pilot).

Deterministic, stdlib-only composition of one existing sub-axis sim
(PPI :> QUANTUM) against the two clinical BH3-mimetic small-molecule
protein-protein-interaction inhibitors of the BCL-2 family:

  - venetoclax (Venclexta, AbbVie / Genentech, FDA 2016) — landmark
    FDA-approved BH3-mimetic disrupting the BCL-2 / pro-apoptotic-BH3
    PPI; the parent PPI sim's `bcl2_bh3_groove` row cites venetoclax
    directly.
  - navitoclax / ABT-263 (AbbVie) — dual BCL-2 / BCL-xL BH3-mimetic
    PPI inhibitor; CLINICAL-STAGE, NOT FDA-approved (BCL-xL-driven
    thrombocytopenia has limited its single-agent window). Included
    as in-scope because the parent PPI sim's `bclxl_bh3_groove` row
    names navitoclax / ABT-263 directly as its drug precedent.

Per f3 (no-fork) the parent sim is IMPORTED via `importlib`, not
re-implemented. Per g1 each row inherits the parent sim's real-limit
citations (Bogan & Thorn 1998 binding-hotspot theory; Wells &
McClendon 2007 flat-PPI druggability). Per g8/f2 every PASS =
in-silico simulator+metadata consistency ONLY, never a clinical /
oncology / regulatory / efficacy / portfolio-recommendation claim.

Each in-scope row carries an explicit `fda_approval_status`
("approved" or "clinical_stage") so the honest distinction between
the one FDA-approved drug and the one clinical-stage drug is
STRUCTURAL, not a comment.

Honest scope (see README.md §0/§3): this is ONE disease (BCL-2-family
hematologic malignancy), two BH3-mimetic small molecules. The
research-stage negatives (BCL-2 PROTACs, macrocyclic / stapled-peptide
BH3-mimetics, CAR-T cell-therapy) are recorded explicitly. NOT the
deferred 200-disease re-mapping.

Determinism: no random/network/wall-clock. Fixed timestamp string. The
witness JSON is byte-identical across re-runs.

Sentinel: __BCL2_PORTFOLIO__ PASS (acceptance) on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "bcl2_portfolio_v1"
CASE_STUDY_ID = "bcl2_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism
SENTINEL_PASS = "__BCL2_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__BCL2_PORTFOLIO__ FAIL"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_sims():
    """Import the parent PPI sim (no fork — f3)."""
    ppi = _load(
        "ppi_sim",
        os.path.join(BRIDGE_MOD, "ppi_sim.py"),
    )
    return ppi


def _ppi_subrun(row: dict) -> dict:
    return {
        "sim_module": "ppi_sim",
        "interface": row["interface"],
        "interface_class": row["interface_class"],
        "n_interface_residues": row["n_interface_residues"],
        "n_hotspot_residues": row["n_hotspot_residues"],
        "hotspot_ddg_threshold_kcal_per_mol":
            row["hotspot_ddg_threshold_kcal_per_mol"],
        "sum_ddg_kcal_per_mol": row["sum_ddg_kcal_per_mol"],
        "sum_hotspot_ddg_kcal_per_mol":
            row["sum_hotspot_ddg_kcal_per_mol"],
        "hotspot_energy_fraction": row["hotspot_energy_fraction"],
        "dg_interface_kcal_per_mol": row["dg_interface_kcal_per_mol"],
        "dg_hotspot_cluster_kcal_per_mol":
            row["dg_hotspot_cluster_kcal_per_mol"],
        "mimicry_fraction": row["mimicry_fraction"],
        "dg_mimic_kcal_per_mol": row["dg_mimic_kcal_per_mol"],
        "small_molecule_disruption_viable":
            row["small_molecule_disruption_viable"],
        "hotspot_driven": row["hotspot_driven"],
        "ledger_residual_kcal_per_mol":
            row["ledger_residual_kcal_per_mol"],
        "mimic_within_ledger": row["mimic_within_ledger"],
    }


# ── Drug → sim mapping (BH3-mimetic small-molecule PPI inhibitors) ────
def build_in_scope_rows() -> list:
    ppi = _import_sims()
    rows = ppi.build_rows()
    bcl2_row = next(r for r in rows
                    if r["interface"] == "bcl2_bh3_groove")
    bclxl_row = next(r for r in rows
                     if r["interface"] == "bclxl_bh3_groove")

    venetoclax = {
        "drug": "venetoclax",
        "brand": "Venclexta",
        "sponsor": "AbbVie / Genentech",
        "fda_approval_status": "approved",
        "fda_year": 2016,
        "fda_center": "CDER",
        "fda_application": ("NDA 208573 — Venclexta first approval "
                            "2016-04-11 (CLL with 17p deletion); "
                            "subsequent expansions for SLL and AML"),
        "modality": ("BH3-mimetic small-molecule PPI inhibitor — "
                     "disrupts the BCL-2 / pro-apoptotic-BH3 "
                     "protein-protein interaction by mimicking the "
                     "BH3 helix's hotspot residues in the BCL-2 groove"),
        "axis_mapping": {
            "axis": "PPI",
            "parent_axis": "QUANTUM (core-5)",
            "axis_layer": "expansion-sub",
        },
        "real_limit_anchor": (
            "Bogan & Thorn 1998 binding-hotspot theory (J. Mol. Biol. "
            "280:1) — interface binding free energy concentrated in a "
            "few hotspot residues (ΔΔG ≥ 2 kcal/mol by alanine "
            "scanning), bounded by the alanine-scanning ledger; "
            "druggability of flat hotspot-driven PPIs follows Wells & "
            "McClendon, Nature 450:1001 (2007)"
        ),
        "drug_precedent_refs": [
            "Souers et al., Nat. Med. 19:202 (2013)",
            "Stilgenbauer et al., Lancet Oncol. 17:768 (2016)",
            "FDA NDA 208573 (Venclexta first approval, 2016-04-11)",
        ],
        "sim_run": _ppi_subrun(bcl2_row),
        "in_silico_only": True,
    }
    navitoclax = {
        "drug": "navitoclax",
        "brand": "ABT-263 (no marketed brand — clinical-stage)",
        "sponsor": "AbbVie",
        "fda_approval_status": "clinical_stage",
        "fda_year": None,
        "fda_center": None,
        "fda_application": None,
        "modality": ("BH3-mimetic small-molecule PPI inhibitor — dual "
                     "BCL-2 / BCL-xL inhibitor; BCL-xL-driven "
                     "thrombocytopenia has limited its single-agent "
                     "clinical window"),
        "axis_mapping": {
            "axis": "PPI",
            "parent_axis": "QUANTUM (core-5)",
            "axis_layer": "expansion-sub",
        },
        "real_limit_anchor": (
            "Bogan & Thorn 1998 binding-hotspot theory (J. Mol. Biol. "
            "280:1) — interface binding free energy concentrated in a "
            "few hotspot residues (ΔΔG ≥ 2 kcal/mol by alanine "
            "scanning), bounded by the alanine-scanning ledger; "
            "druggability of flat hotspot-driven PPIs follows Wells & "
            "McClendon, Nature 450:1001 (2007)"
        ),
        "drug_precedent_refs": [
            "Tse et al., Cancer Res. 68:3421 (2008)",
            "Roberts et al., J. Clin. Oncol. 30:488 (2012) — "
            "navitoclax phase I in CLL/SLL",
        ],
        "sim_run": _ppi_subrun(bclxl_row),
        "in_silico_only": True,
    }
    return [venetoclax, navitoclax]


# ── Honest research-stage negatives (recorded, not modeled) ──────────
RESEARCH_STAGE_NEGATIVES = [
    {
        "candidate_class": "BCL-2- / BCL-xL-targeting PROTAC "
                           "bifunctional degrader (e.g. DT2216 against "
                           "BCL-xL)",
        "axis_in_repo": "BIFUNCTIONAL (expansion-main)",
        "fda_approved": False,
        "status": "research-stage / preclinical / early clinical",
        "reason": (
            "no FDA-approved BCL-2- or BCL-xL-targeting bifunctional "
            "degrader exists; several preclinical CRBN- and VHL-"
            "recruiting BCL-family PROTACs are reported (including "
            "DT2216 designed to limit BCL-xL-driven thrombocytopenia "
            "by tissue-selective degradation), but none have advanced "
            "to FDA approval"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "macrocyclic BH3-mimetic / stapled BH3-"
                           "peptide BCL-2 inhibitor",
        "axis_in_repo": "PPI (:> QUANTUM) — macrocyclic/peptide "
                        "specialization, no FDA precedent",
        "fda_approved": False,
        "status": "research-stage / early clinical",
        "reason": (
            "no FDA-approved macrocyclic or stapled-peptide BCL-2 "
            "inhibitor exists; several stapled-BH3-peptide and "
            "cyclopeptide leads are in preclinical / early clinical "
            "development"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "anti-apoptotic-pathway-engaging CAR-T / "
                           "cell-therapy approaches to BCL-2-driven "
                           "malignancies",
        "axis_in_repo": None,
        "fda_approved": False,
        "fda_center_if_filed": "CBER",
        "status": "CBER-regulated cell therapy",
        "reason": (
            "CBER-regulated biologic; out of repo CDER scope per "
            "criterion #4 drug-only/CDER discipline. Honest UNPLACED, "
            "same pattern as Zolgensma in "
            "case_studies/sma_portfolio/."
        ),
        "in_scope": False,
        "reported_not_run": True,
        "unplaced_precedent_in_repo": (
            "AXIS/HIERARCHY.tape @N genetic_medicine_status"
        ),
    },
]


# ── Acceptance ────────────────────────────────────────────────────────
def acceptance(in_scope: list, negatives: list) -> dict:
    crit = {
        "X1_two_in_scope_drugs": len(in_scope) == 2,
        "X2_first_in_scope_is_fda_approved_cder": (
            in_scope[0]["fda_approval_status"] == "approved"
            and in_scope[0]["fda_center"] == "CDER"
        ),
        "X3_second_in_scope_is_clinical_stage_honest": (
            in_scope[1]["fda_approval_status"] == "clinical_stage"
            and in_scope[1]["fda_center"] is None
            and in_scope[1]["fda_year"] is None
        ),
        "X4_each_in_scope_has_real_limit_anchor": all(
            d.get("real_limit_anchor") for d in in_scope
        ),
        "X5_each_in_scope_has_axis_mapping_PPI": all(
            d["axis_mapping"]["axis"] == "PPI" for d in in_scope
        ),
        "X6_in_scope_in_silico_only_flag_set": all(
            d.get("in_silico_only") is True for d in in_scope
        ),
        "X7_research_stage_negatives_recorded": len(negatives) >= 3,
        "X8_negatives_marked_not_run": all(
            n.get("reported_not_run") is True and n["in_scope"] is False
            for n in negatives
        ),
        "X9_both_interfaces_are_bh3_helix_groove": all(
            d["sim_run"]["interface_class"] == "bh3_helix_groove"
            for d in in_scope
        ),
        "X10_both_interfaces_hotspot_driven": all(
            d["sim_run"]["hotspot_driven"] is True for d in in_scope
        ),
        "X11_both_disruptions_viable": all(
            d["sim_run"]["small_molecule_disruption_viable"] is True
            for d in in_scope
        ),
        "X12_ledger_within_bounds": all(
            d["sim_run"]["mimic_within_ledger"] is True
            and d["sim_run"]["ledger_residual_kcal_per_mol"] < 1e-9
            for d in in_scope
        ),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def build_witness() -> dict:
    in_scope = build_in_scope_rows()
    acc = acceptance(in_scope, RESEARCH_STAGE_NEGATIVES)
    return {
        "schema_version": SCHEMA_VERSION,
        "case_study_id": CASE_STUDY_ID,
        "ts": TS_FIXED,
        "disease": {
            "name": ("BCL-2-family-driven hematologic malignancy "
                     "(e.g. chronic lymphocytic leukemia, small "
                     "lymphocytic lymphoma, acute myeloid leukemia)"),
            "abbreviation": "BCL2",
            "target_family": ("BCL-2 family anti-apoptotic proteins "
                              "(BCL-2, BCL-xL, MCL-1) and their "
                              "pro-apoptotic BH3-only binding partners "
                              "(BIM, BID, BAD, NOXA, PUMA, etc.)"),
        },
        "in_scope_drugs": in_scope,
        "research_stage_negatives": RESEARCH_STAGE_NEGATIVES,
        "cross_axis_touch_points": [
            {
                "id": "G3",
                "module": ("_python_bridge/module/"
                           "ppi_molecular_glue_cross.py"),
                "note": ("G3 shares the BCL-2 BH3-groove interface as "
                         "its hotspot-rich reference case (BH3 grooves "
                         "clear at α ≈ 10 vs hotspot-poor KIX shallow "
                         "groove failing at α > 5000). Cited for "
                         "completeness — venetoclax is a PPI disruptor, "
                         "NOT a molecular glue; this portfolio does "
                         "NOT claim a molecular-glue modality for the "
                         "BH3-mimetics."),
            },
        ],
        "honesty": {
            "in_silico_only": True,
            "core_5_unchanged": True,
            "no_fork_of_sister_sims": True,
            "one_disease_pilot_not_200_disease_remap": True,
            "research_stage_negatives_listed_honestly": True,
            "clinical_stage_drug_marked_honestly": True,
            "not_a_molecular_glue_claim": True,
            "no_lattice_derivation": True,
            "statement": (
                "Per-disease IN-SILICO composition of one existing "
                "sub-axis sim (PPI :> QUANTUM) for two BH3-mimetic "
                "small-molecule PPI inhibitors of the BCL-2 family: "
                "venetoclax / Venclexta (FDA-approved 2016, CDER) and "
                "navitoclax / ABT-263 (clinical-stage, NOT "
                "FDA-approved — honestly flagged via "
                "fda_approval_status='clinical_stage' and null "
                "fda_year/fda_center). The parent PPI sim's panel "
                "cites BOTH drugs directly by name as the drug "
                "precedents for the bcl2_bh3_groove and "
                "bclxl_bh3_groove rows respectively. Research-stage "
                "negatives (BCL-2 PROTACs, macrocyclic / stapled-"
                "peptide BH3-mimetics, CAR-T cell therapies) are "
                "recorded honestly, not modeled. The G3 cross-axis "
                "touch-point (PPI × MOLECULAR-GLUE) is cited for "
                "completeness — this portfolio does NOT claim a "
                "molecular-glue modality for the BH3-mimetics; "
                "venetoclax is a PPI DISRUPTOR. NEVER a therapeutic / "
                "clinical / oncology / efficacy / regulatory / "
                "portfolio-recommendation claim (g8 / f2). Drugs "
                "described by own published precedent (Souers 2013, "
                "Tse 2008, FDA NDA 208573) — nothing here is derived "
                "from the n=6 lattice (g3 / f1 / f_lattice_fit). The "
                "200-disease re-mapping remains deferred per "
                "AXIS/HIERARCHY.tape Log."
            ),
        },
        "acceptance": acc,
        "sentinel": (SENTINEL_PASS if acc["verdict"] == "PASS"
                     else SENTINEL_FAIL),
    }


def main() -> int:
    print("bcl2_portfolio_runner — BCL-2 / hematologic malignancies "
          "case study (one-disease pilot)\n", flush=True)
    print("  in-scope:    venetoclax (Venclexta, AbbVie/Genentech, "
          "FDA 2016, CDER)")
    print("               → PPI :> QUANTUM (BCL-2 BH3-helix groove)")
    print("               navitoclax / ABT-263 (AbbVie, clinical-stage, "
          "NOT FDA-approved)")
    print("               → PPI :> QUANTUM (BCL-xL BH3-helix groove)")
    print("  not-in-scope (honest negatives):")
    print("    BCL-2 / BCL-xL PROTAC degraders — research-stage")
    print("    macrocyclic / stapled-BH3-peptide BCL-2 mimetics — "
          "research-stage")
    print("    anti-apoptotic CAR-T cell therapies — CBER, criterion "
          "#4\n", flush=True)
    witness = build_witness()
    acc = witness["acceptance"]
    print("## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---\n")
    print("  [honesty] in-silico simulator-consistency only — NOT a "
          "clinical / therapeutic / oncology / regulatory / efficacy /")
    print("  portfolio-recommendation claim (g8 / f2). Core-5 axes "
          "UNCHANGED; one-disease pilot only; 200-disease re-mapping")
    print("  remains deferred per AXIS/HIERARCHY.tape Log. "
          "Research-stage negatives listed but not modeled; the")
    print("  clinical-stage drug (navitoclax) is honestly flagged "
          "fda_approval_status='clinical_stage'.\n")
    print("## witness JSON")
    print(json.dumps(witness, indent=2, sort_keys=True, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
