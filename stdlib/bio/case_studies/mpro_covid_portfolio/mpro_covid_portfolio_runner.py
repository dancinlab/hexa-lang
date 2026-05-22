#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mpro_covid_portfolio_runner.py — Mpro / COVID-19 portfolio case study
(one-disease pilot).

Deterministic, stdlib-only composition of one existing sub-axis sim
against one FDA-approved Mpro inhibitor that maps cleanly onto an
expansion-layer axis:

  - nirmatrelvir (Paxlovid, Pfizer, FDA EUA 2022 / full approval 2023)
    — REVERSIBLE-COVALENT sub-axis (:> COVALENT expansion-main). The
    nitrile→thioimidate adduct with Mpro Cys145 is a *reversible*
    covalent linkage — measurable koff, finite residence time.

Per f3 (no-fork) the parent sim is IMPORTED via `importlib`, not
re-implemented. Per g1 the row inherits the parent sim's real-limit
citation (Eyring transition-state theory). Per g8/f2 every PASS =
in-silico simulator+metadata consistency ONLY, never a clinical /
antiviral / regulatory / efficacy / portfolio-recommendation claim.

Honest scope (see README.md §0/§3): this is ONE disease, ONE real
drug. The non-US-FDA / research-stage / CBER negatives (ensitrelvir
PMDA-only; non-covalent Mpro chemotypes; anti-SARS-CoV-2 mAbs) are
recorded explicitly as honest negatives — the portfolio acknowledges
what it does NOT model. NOT the deferred 200-disease re-mapping.

Determinism: no random/network/wall-clock. Fixed timestamp string. The
witness JSON is byte-identical across re-runs.

Sentinel: __MPRO_COVID_PORTFOLIO__ PASS (acceptance) on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "mpro_covid_portfolio_v1"
CASE_STUDY_ID = "mpro_covid_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism
SENTINEL_PASS = "__MPRO_COVID_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__MPRO_COVID_PORTFOLIO__ FAIL"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_sims():
    """Import the parent sim (no fork — f3)."""
    rc = _load(
        "reversible_covalent_sim",
        os.path.join(BRIDGE_MOD, "reversible_covalent_sim.py"),
    )
    return rc


# ── Drug → sim mapping (FDA-approved CDER small molecules only) ───────
def build_in_scope_rows() -> list:
    rc = _import_sims()

    # nirmatrelvir — nitrile-warhead reversible covalent Mpro inhibitor.
    rc_rows = rc.build_rows()
    nitrile_row = next(r for r in rc_rows
                       if r["warhead"] == "nitrile_nirmatrelvir")

    nirmatrelvir = {
        "drug": "nirmatrelvir",
        "brand": "Paxlovid (nirmatrelvir + ritonavir)",
        "sponsor": "Pfizer",
        "fda_year": 2022,
        "fda_center": "CDER",
        "fda_application": "EUA 091 (2022); NDA 217188 (full approval "
                           "2023-05-25)",
        "modality": ("reversible covalent nitrile warhead — forms a "
                     "thioimidate adduct with the SARS-CoV-2 Mpro "
                     "catalytic-dyad Cys145 thiolate"),
        "axis_mapping": {
            "axis": "REVERSIBLE-COVALENT",
            "parent_axis": "COVALENT (expansion-main)",
            "axis_layer": "expansion-sub",
        },
        "real_limit_anchor": (
            "Eyring transition-state theory (Eyring, J. Chem. Phys. "
            "3:107, 1935): the universal frequency prefactor kB·T/h "
            "≈ 6.46e12 /s at T = 310 K bounds every modelled "
            "unimolecular rate"
        ),
        "drug_precedent_refs": [
            "Owen et al., Science 374:1586 (2021)",
            "Boras et al., Nat. Commun. 12:6055 (2021)",
            "FDA NDA 217188 (Paxlovid full approval, 2023-05-25)",
        ],
        "sim_run": {
            "sim_module": "reversible_covalent_sim",
            "warhead": nitrile_row["warhead"],
            "warhead_class": nitrile_row["warhead_class"],
            "dg_on_kcal_per_mol": nitrile_row["dg_on_kcal_per_mol"],
            "dg_rxn_kcal_per_mol": nitrile_row["dg_rxn_kcal_per_mol"],
            "kon_per_s": nitrile_row["kon_per_s"],
            "koff_per_s": nitrile_row["koff_per_s"],
            "K_eq": nitrile_row["K_eq"],
            "residence_time_s": nitrile_row["residence_time_s"],
            "residence_time_human": nitrile_row["residence_time_human"],
            "reversibility": nitrile_row["reversibility"],
            "kon_below_eyring_ceiling":
                nitrile_row["kon_below_eyring_ceiling"],
            "koff_below_eyring_ceiling":
                nitrile_row["koff_below_eyring_ceiling"],
            "K_eq_consistency_rel_err":
                nitrile_row["K_eq_consistency_rel_err"],
        },
        "in_silico_only": True,
    }

    return [nirmatrelvir]


# ── Honest research-stage / non-US-FDA negatives (recorded, not run) ──
RESEARCH_STAGE_NEGATIVES = [
    {
        "candidate_class": "ensitrelvir (Xocova, Shionogi) — non-covalent "
                           "Mpro inhibitor, Japan PMDA-only",
        "axis_in_repo": "REVERSIBLE-COVALENT (general covalent-axis "
                        "non-covalent contrast)",
        "fda_approved": False,
        "status": "non-US-FDA (Japan PMDA emergency approval 2022-11; "
                  "conditional full approval 2024)",
        "reason": (
            "ensitrelvir is approved by Japan PMDA only; criterion #4 "
            "keeps US-FDA discipline for in-scope drugs. Recorded "
            "honestly, not modeled."
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "non-covalent Mpro inhibitor chemotypes "
                           "(e.g. PF-00835231 piperidinone, HTS leads)",
        "axis_in_repo": None,
        "fda_approved": False,
        "status": "research-stage",
        "reason": (
            "no FDA-approved non-covalent Mpro inhibitor exists; "
            "various non-covalent chemotypes from the early COVID-19 "
            "response remain research-stage"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "anti-SARS-CoV-2 monoclonal antibody "
                           "(tixagevimab/cilgavimab, bebtelovimab, etc.)",
        "axis_in_repo": None,
        "fda_approved": False,
        "fda_center_if_filed": "CBER",
        "status": "withdrawn / de-authorised against contemporary variants",
        "reason": (
            "CBER-regulated biologic; out of repo CDER scope per "
            "criterion #4 drug-only/CDER discipline. All currently "
            "authorised anti-SARS-CoV-2 mAbs have been withdrawn or "
            "de-authorised against contemporary variants. Honest "
            "UNPLACED, same pattern as Zolgensma in "
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
        "X1_one_in_scope_drug": len(in_scope) == 1,
        "X2_all_in_scope_are_cder": all(
            d["fda_center"] == "CDER" for d in in_scope
        ),
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
        "X8_nirmatrelvir_row_is_reversible": (
            in_scope[0]["sim_run"]["reversibility"] == "reversible"
        ),
        "X9_eyring_ceiling_respected": (
            in_scope[0]["sim_run"]["kon_below_eyring_ceiling"] is True
            and in_scope[0]["sim_run"]["koff_below_eyring_ceiling"] is True
        ),
        "X10_K_eq_self_consistent": (
            in_scope[0]["sim_run"]["K_eq_consistency_rel_err"] < 1e-9
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
            "name": "Coronavirus disease 2019 (SARS-CoV-2 infection)",
            "abbreviation": "COVID-19",
            "target_protein": "SARS-CoV-2 main protease (Mpro / 3CLpro / nsp5)",
            "catalytic_residue": "Cys145 (Mpro Cys145/His41 catalytic dyad)",
        },
        "in_scope_drugs": in_scope,
        "research_stage_negatives": RESEARCH_STAGE_NEGATIVES,
        "cross_axis_touch_points": [
            {
                "id": "A5",
                "module": ("_python_bridge/module/"
                           "reversible_covalent_mpro_vqe_cross.py"),
                "note": ("QUANTUM-axis Mpro warhead ΔE_rxn → "
                         "REVERSIBLE-COVALENT Eyring kinetics → koff "
                         "→ residence time → reversibility class. "
                         "The 5 panel rows are illustrative_only; "
                         "this case study lifts the nitrile_nirmatrelvir "
                         "row as the nirmatrelvir/Paxlovid drug-"
                         "precedent line."),
            },
        ],
        "honesty": {
            "in_silico_only": True,
            "core_5_unchanged": True,
            "no_fork_of_sister_sims": True,
            "one_disease_pilot_not_200_disease_remap": True,
            "research_stage_negatives_listed_honestly": True,
            "no_lattice_derivation": True,
            "statement": (
                "Per-disease IN-SILICO composition of one existing "
                "sub-axis sim (REVERSIBLE-COVALENT :> COVALENT) for "
                "one FDA-approved CDER drug (nirmatrelvir / Paxlovid). "
                "Non-US-FDA (ensitrelvir / PMDA), research-stage "
                "(non-covalent Mpro chemotypes) and CBER (anti-"
                "SARS-CoV-2 mAbs) negatives are recorded honestly, "
                "not modeled. NEVER a therapeutic / clinical / "
                "antiviral / efficacy / regulatory / portfolio-"
                "recommendation claim (g8 / f2). nirmatrelvir is "
                "described via its own published precedent (Owen "
                "et al. 2021; FDA NDA 217188) — nothing here is "
                "derived from the n=6 lattice (g3 / f1 / "
                "f_lattice_fit). The 200-disease re-mapping remains "
                "deferred per AXIS/HIERARCHY.tape Log."
            ),
        },
        "acceptance": acc,
        "sentinel": (SENTINEL_PASS if acc["verdict"] == "PASS"
                     else SENTINEL_FAIL),
    }


def main() -> int:
    print("mpro_covid_portfolio_runner — COVID-19 case study "
          "(one-disease pilot)\n", flush=True)
    print("  in-scope:    nirmatrelvir (Paxlovid, Pfizer, FDA 2022 EUA")
    print("               / 2023 full) → REVERSIBLE-COVALENT :> COVALENT")
    print("  not-in-scope (honest negatives):")
    print("    ensitrelvir (Xocova, Shionogi) — Japan PMDA only, not US-FDA")
    print("    non-covalent Mpro inhibitor chemotypes — research-stage")
    print("    anti-SARS-CoV-2 mAbs — CBER, withdrawn/de-authorised\n",
          flush=True)
    witness = build_witness()
    acc = witness["acceptance"]
    print("## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---\n")
    print("  [honesty] in-silico simulator-consistency only — NOT a "
          "clinical / therapeutic / antiviral / regulatory / efficacy /")
    print("  portfolio-recommendation claim (g8 / f2). Core-5 axes "
          "UNCHANGED; one-disease pilot only; 200-disease re-mapping")
    print("  remains deferred per AXIS/HIERARCHY.tape Log. Non-US-FDA, "
          "research-stage and CBER negatives listed but not modeled.\n")
    print("## witness JSON")
    print(json.dumps(witness, indent=2, sort_keys=True, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
