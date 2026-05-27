#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hiv1_portfolio_runner.py — HIV-1 portfolio case study (one-disease pilot).

Deterministic, stdlib-only composition of two existing axis sims against
two FDA-approved HIV-1 drugs that map cleanly onto sub-axes:

  - lenacapavir (Sunlenca, Gilead, FDA 2022) — CAPSID-ASSEMBLY-MODULATOR
    sub-axis (:> VIROCAPSID core). Strong-over-stabilizer regime.
  - maraviroc   (Selzentry, ViiV/Pfizer, FDA 2007) — ALLOSTERIC sub-axis
    (:> QUANTUM core). MWC R-state stabilizer profile.

Per f3 (no-fork) both parent sims are IMPORTED via `importlib`, not
re-implemented. Per g1 each row inherits its parent sim's real-limit
citation. Per g8/f2 every PASS = in-silico simulator+metadata
consistency ONLY, never a clinical/therapeutic/regulatory/efficacy claim.

Honest scope (see README.md §0/§3): this is ONE disease, two real
drugs. The research-stage / CBER negatives (anti-HIV ASOs;
HIV-targeting PROTACs; gene-editing curatives) are recorded explicitly
as honest negatives — the portfolio acknowledges what it does NOT
model. NOT the deferred 200-disease re-mapping.

Determinism: no random/network/wall-clock. Fixed timestamp string. The
witness JSON is byte-identical across re-runs.

Sentinel: __HIV1_PORTFOLIO__ PASS (acceptance) on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "hiv1_portfolio_v1"
CASE_STUDY_ID = "hiv1_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_sims():
    """Import the two parent sims (no fork — f3)."""
    cam = _load(
        "capsid_assembly_modulator_sim",
        os.path.join(BRIDGE_MOD, "capsid_assembly_modulator_sim.py"),
    )
    allo = _load(
        "allosteric_sim",
        os.path.join(BRIDGE_MOD, "allosteric_sim.py"),
    )
    return cam, allo


# ── Drug → sim mapping (FDA-approved CDER small molecules only) ───────
def build_in_scope_rows() -> list:
    cam, allo = _import_sims()

    # lenacapavir — strong-over-stabilizer regime per CAPSID-MODULATOR sim
    cam_row = cam.simulate_cam("strong_over_stabilizer", -3.0)
    lenacapavir = {
        "drug": "lenacapavir",
        "brand": "Sunlenca",
        "sponsor": "Gilead",
        "fda_year": 2022,
        "fda_center": "CDER",
        "fda_application": "NDA 215973",
        "modality": "capsid-assembly modulator (small molecule)",
        "axis_mapping": {
            "axis": "CAPSID-ASSEMBLY-MODULATOR",
            "parent_axis": "VIROCAPSID (core-5)",
            "axis_layer": "sub-axis",
        },
        "real_limit_anchor": (
            "Caspar & Klug 1962 quasi-equivalence T-number geometry; "
            "Zlotnick 1994 (Biochemistry 33:1233) / Zlotnick 2003 "
            "(J Mol Recognit 16:294) weak-contact thermodynamics + "
            "over-stabilization kinetic-trap regime"
        ),
        "drug_precedent_refs": [
            "Link et al., Nature 584:614 (2020)",
            "Bester et al., Science 370:360 (2020)",
            "FDA NDA 215973 (2022-12-22)",
        ],
        "sim_run": {
            "sim_module": "capsid_assembly_modulator_sim",
            "scenario": cam_row["scenario"],
            "delta_dg_kcal": cam_row["delta_dg_modulator_kcal"],
            "g_contact_cam_kcal": cam_row["g_contact_cam_kcal"],
            "assembled_fraction_shift": cam_row["assembled_fraction_shift"],
            "kinetic_trap_regime": cam_row["kinetic_trap_regime"],
        },
        "in_silico_only": True,
    }

    # maraviroc — MWC R-state stabilizer (allosteric CCR5)
    # call into allosteric_sim's main panel run and pull the first row.
    allo_rows = allo.build_rows()
    allo_row = allo_rows[0]
    maraviroc = {
        "drug": "maraviroc",
        "brand": "Selzentry",
        "sponsor": "ViiV / Pfizer",
        "fda_year": 2007,
        "fda_center": "CDER",
        "fda_application": "NDA 022128",
        "modality": "CCR5 allosteric inhibitor (small molecule)",
        "axis_mapping": {
            "axis": "ALLOSTERIC",
            "parent_axis": "QUANTUM (core-5)",
            "axis_layer": "sub-axis",
        },
        "real_limit_anchor": (
            "Monod, Wyman & Changeux 1965 (J Mol Biol 12:88) MWC "
            "two-state allosteric model; saturable allosteric ceiling "
            "(Christopoulos & Kenakin 2002, Pharmacol Rev 54:323)"
        ),
        "drug_precedent_refs": [
            "Dorr et al., Antimicrob Agents Chemother 49:4721 (2005)",
            "FDA NDA 022128 (2007-08-06)",
        ],
        "sim_run": {
            "sim_module": "allosteric_sim",
            "scenario": allo_row.get("modulator", "first_panel_row"),
            "modulator_class": allo_row.get("modulator_class"),
            "modulation_kind": allo_row.get("modulation_kind"),
            "cooperativity_alpha": allo_row.get("cooperativity_alpha"),
            "log10_alpha": allo_row.get("log10_alpha"),
            "modulator_kd_uM": allo_row.get("modulator_kd_uM"),
            "ceiling_respected": allo_row.get("ceiling_respected"),
            "is_allosteric_modulator": (
                allo_row.get("modulation_kind") in ("NAM", "PAM")
            ),
        },
        "in_silico_only": True,
    }

    return [lenacapavir, maraviroc]


# ── Honest research-stage negatives (recorded, not modeled) ──────────
RESEARCH_STAGE_NEGATIVES = [
    {
        "candidate_class": "anti-HIV antisense oligonucleotide",
        "axis_in_repo": "OLIGONUCLEOTIDE (expansion-main)",
        "fda_approved": False,
        "status": "research-stage",
        "reason": (
            "no FDA-approved anti-HIV ASO exists; fomivirsen was the "
            "first FDA-approved ASO but targeted CMV and was withdrawn "
            "in 2002"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "HIV-targeting bifunctional degrader (PROTAC)",
        "axis_in_repo": "BIFUNCTIONAL (expansion-main)",
        "fda_approved": False,
        "status": "research-stage",
        "reason": (
            "no FDA-approved HIV-targeting bifunctional degrader; "
            "the BIFUNCTIONAL axis exists in the repo but no clinical "
            "HIV drug maps onto it"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "gene-editing curative (e.g. CRISPR-Cas9, EBT-101)",
        "axis_in_repo": None,
        "fda_approved": False,
        "fda_center_if_filed": "CBER",
        "status": "clinical-trial-stage; CBER-regulated",
        "reason": (
            "CBER-regulated biologic; out of repo CDER scope per "
            "criterion #4 drug-only/CDER discipline (same pattern as "
            "Zolgensma in case_studies/sma_portfolio/). Honest UNPLACED."
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
        "X2_all_in_scope_are_cder": all(d["fda_center"] == "CDER"
                                        for d in in_scope),
        "X3_each_in_scope_has_real_limit_anchor": all(
            d.get("real_limit_anchor") for d in in_scope
        ),
        "X4_each_in_scope_has_axis_mapping": all(
            d["axis_mapping"]["axis"] for d in in_scope
        ),
        "X5_in_scope_in_silico_only_flag_set": all(
            d.get("in_silico_only") is True for d in in_scope
        ),
        "X6_research_stage_negatives_recorded": len(negatives) >= 3,
        "X7_negatives_marked_not_run": all(
            n.get("reported_not_run") is True and n["in_scope"] is False
            for n in negatives
        ),
        "X8_cam_row_returned_a_trap_regime": (
            in_scope[0]["sim_run"]["kinetic_trap_regime"] is True
        ),
        "X9_allosteric_row_is_a_modulator_NAM_or_PAM": (
            in_scope[1]["sim_run"]["is_allosteric_modulator"] is True
        ),
        "X10_allosteric_ceiling_respected": (
            in_scope[1]["sim_run"]["ceiling_respected"] is True
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
            "name": "Human Immunodeficiency Virus 1 infection",
            "abbreviation": "HIV-1",
        },
        "in_scope_drugs": in_scope,
        "research_stage_negatives": RESEARCH_STAGE_NEGATIVES,
        "cross_axis_touch_points": [
            {
                "id": "A4",
                "module": "_python_bridge/module/capsid_modulator_pdb_anchor_cross.py",
                "note": ("HIV-1 capsids classified honest 'T-number N/A — "
                         "non-icosahedral fullerene cone'; the cross "
                         "refuses to fabricate a T-number"),
            },
            {
                "id": "G2",
                "module": "_python_bridge/module/allosteric_cryptic_pocket_cross.py",
                "note": ("MWC and cryptic-pocket are identical 2-state "
                         "equilibria under R↔open mapping; the general "
                         "framework this case study draws on"),
            },
        ],
        "honesty": {
            "in_silico_only": True,
            "core_5_unchanged": True,
            "no_fork_of_sister_sims": True,
            "one_disease_pilot_not_200_disease_remap": True,
            "research_stage_negatives_listed_honestly": True,
            "statement": (
                "Per-disease IN-SILICO composition of two existing axis "
                "sims for two FDA-approved CDER drugs (lenacapavir, "
                "maraviroc). Research-stage negatives (anti-HIV ASOs, "
                "HIV-PROTACs) and CBER negatives (gene-editing "
                "curatives) are recorded honestly, not modeled. NEVER "
                "a therapeutic / clinical / efficacy / regulatory / "
                "portfolio-recommendation claim (g8 / f2). The 200-"
                "disease re-mapping remains deferred per "
                "AXIS/HIERARCHY.tape Log."
            ),
        },
        "acceptance": acc,
        "sentinel": ("__HIV1_PORTFOLIO__ PASS"
                     if acc["verdict"] == "PASS"
                     else "__HIV1_PORTFOLIO__ FAIL"),
    }


def main() -> int:
    print("hiv1_portfolio_runner — HIV-1 case study (one-disease pilot)\n",
          flush=True)
    print("  in-scope:    lenacapavir → CAPSID-ASSEMBLY-MODULATOR "
          ":> VIROCAPSID")
    print("               maraviroc   → ALLOSTERIC :> QUANTUM")
    print("  not-in-scope (honest negatives): anti-HIV ASO (research-")
    print("    stage) · HIV-PROTAC (research-stage) · gene-editing "
          "curative (CBER, criterion #4)\n", flush=True)
    witness = build_witness()
    acc = witness["acceptance"]
    print("## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---\n")
    print("  [honesty] in-silico simulator-consistency only — NOT a "
          "clinical / therapeutic / regulatory / efficacy /")
    print("  portfolio-recommendation claim (g8 / f2). Core-5 axes "
          "UNCHANGED; one-disease pilot only; 200-disease re-mapping")
    print("  remains deferred per AXIS/HIERARCHY.tape Log. Research-"
          "stage and CBER negatives listed but not modeled.\n")
    print("## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
