#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kras_g12c_portfolio_runner.py — KRAS-G12C portfolio case study
(one-disease pilot).

Deterministic, stdlib-only composition of two existing axis sims against
two FDA-approved KRAS-G12C inhibitors that map cleanly onto axes:

  - sotorasib (Lumakras, Amgen, FDA 2021) — irreversible covalent
    acrylamide warhead, KRAS-G12C switch-II Cys12.
  - adagrasib (Krazati, Mirati/BMS, FDA 2022) — irreversible covalent
    acrylamide warhead, KRAS-G12C switch-II Cys12.

Both drugs:
  → COVALENT (expansion-main) — covalent_inhibition_sim two-step kinetics
  → cryptic-site touch-point: CRYPTIC-POCKET (:> QUANTUM core) — the
    switch-II pocket is the canonical cryptic site (Ostrem 2013;
    Canon 2019).

Per f3 (no-fork) both parent sims are IMPORTED via `importlib`, not
re-implemented. Per g1 each row inherits its parent sim's real-limit
citation. Per g8/f2 every PASS = in-silico simulator+metadata
consistency ONLY, never a clinical / oncology / regulatory / efficacy /
portfolio-recommendation claim.

Honest scope (see README.md §0/§3): this is ONE disease, two real
drugs. The research-stage negatives (pan-KRAS PROTACs, anti-KRAS
ASOs, pan-RAS / non-G12C KRAS inhibitors) are recorded explicitly
as honest negatives. NOT the deferred 200-disease re-mapping.

Determinism: no random/network/wall-clock. Fixed timestamp string. The
witness JSON is byte-identical across re-runs.

Sentinel: __KRAS_G12C_PORTFOLIO__ PASS (acceptance) on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "kras_g12c_portfolio_v1"
CASE_STUDY_ID = "kras_g12c_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism
SENTINEL_PASS = "__KRAS_G12C_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__KRAS_G12C_PORTFOLIO__ FAIL"

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
    ci = _load(
        "covalent_inhibition_sim",
        os.path.join(BRIDGE_MOD, "covalent_inhibition_sim.py"),
    )
    cp = _load(
        "cryptic_pocket_sim",
        os.path.join(BRIDGE_MOD, "cryptic_pocket_sim.py"),
    )
    return ci, cp


# ── Drug → sim mapping (FDA-approved CDER small molecules only) ───────
def build_in_scope_rows() -> list:
    ci, cp = _import_sims()
    ci_rows = ci.build_rows()
    cp_rows = cp.build_rows()
    sotorasib_cov = next(r for r in ci_rows
                         if r["inhibitor"] == "sotorasib_KRAS_Cys12")
    adagrasib_cov = next(r for r in ci_rows
                         if r["inhibitor"] == "adagrasib_KRAS_Cys12")
    switch_ii = next(r for r in cp_rows
                     if r["pocket"] == "kras_g12c_switch_II")

    def _cov_subrun(row: dict) -> dict:
        return {
            "sim_module": "covalent_inhibition_sim",
            "inhibitor": row["inhibitor"],
            "warhead_class": row["warhead_class"],
            "Ki_molar": row["Ki_molar"],
            "kinact_per_s": row["kinact_per_s"],
            "kinact_over_Ki_M_per_s": row["kinact_over_Ki_M_per_s"],
            "dg_covalent_step_kcal_per_mol":
                row["dg_covalent_step_kcal_per_mol"],
            "kinact_eyring_tst_per_s": row["kinact_eyring_tst_per_s"],
            "free_enzyme_half_life_s": row["free_enzyme_half_life_s"],
            "free_enzyme_half_life_human":
                row["free_enzyme_half_life_human"],
            "kinact_below_eyring_ceiling":
                row["kinact_below_eyring_ceiling"],
            "kinact_tst_below_eyring_ceiling":
                row["kinact_tst_below_eyring_ceiling"],
            "metric_consistency_rel_err":
                row["metric_consistency_rel_err"],
        }

    def _crypt_subrun(row: dict) -> dict:
        return {
            "sim_module": "cryptic_pocket_sim",
            "pocket": row["pocket"],
            "pocket_class": row["pocket_class"],
            "dg_open_kcal_per_mol": row["dg_open_kcal_per_mol"],
            "dg_bind_open_kcal_per_mol":
                row["dg_bind_open_kcal_per_mol"],
            "dg_bind_obs_kcal_per_mol":
                row["dg_bind_obs_kcal_per_mol"],
            "apo_open_state_population":
                row["apo_open_state_population"],
            "is_cryptic": row["is_cryptic"],
            "cryptic_binder_viable": row["cryptic_binder_viable"],
            "opening_cost_outpaid": row["opening_cost_outpaid"],
            "pocket_state": row["pocket_state"],
            "ledger_consistency_rel_err":
                row["ledger_consistency_rel_err"],
        }

    sotorasib = {
        "drug": "sotorasib",
        "brand": "Lumakras",
        "sponsor": "Amgen",
        "fda_year": 2021,
        "fda_center": "CDER",
        "fda_application": ("NDA 214665 — accelerated approval "
                            "2021-05-28; full approval 2025"),
        "modality": ("irreversible covalent acrylamide Michael "
                     "acceptor — reacts with KRAS-G12C mutant-specific "
                     "Cys12 thiol in the switch-II pocket"),
        "axis_mapping": {
            "axis": "COVALENT",
            "parent_axis": "COVALENT (expansion-main)",
            "axis_layer": "expansion-main",
            "cryptic_touch_axis": "CRYPTIC-POCKET",
            "cryptic_touch_parent_axis": "QUANTUM (core-5)",
            "cryptic_touch_axis_layer": "expansion-sub",
        },
        "real_limit_anchor": (
            "Strelow 2017 kinact/Ki framework for covalent-inhibitor "
            "efficiency + Eyring transition-state theory (kB·T/h "
            "≈ 6.46e12 /s @ 310 K hard unimolecular ceiling); switch-II "
            "cryptic-pocket conformational-selection thermodynamic "
            "cycle (Hammes, Chang & Oas, PNAS 106:13737, 2009) — "
            "ΔG_bind_obs = ΔG_bind_open + ΔG_open"
        ),
        "drug_precedent_refs": [
            "Canon et al., Nature 575:217 (2019)",
            "Hong et al., N. Engl. J. Med. 383:1207 (2020)",
            "FDA NDA 214665 (Lumakras accelerated approval, "
            "2021-05-28)",
            "Ostrem et al., Nature 503:548 (2013) — switch-II cryptic "
            "pocket discovery",
        ],
        "sim_run": {
            "covalent_step": _cov_subrun(sotorasib_cov),
            "cryptic_pocket": _crypt_subrun(switch_ii),
        },
        "in_silico_only": True,
    }
    adagrasib = {
        "drug": "adagrasib",
        "brand": "Krazati",
        "sponsor": "Mirati Therapeutics / Bristol-Myers Squibb",
        "fda_year": 2022,
        "fda_center": "CDER",
        "fda_application": ("NDA 216340 — accelerated approval "
                            "2022-12-12"),
        "modality": ("irreversible covalent acrylamide Michael "
                     "acceptor — reacts with KRAS-G12C mutant-specific "
                     "Cys12 thiol in the switch-II pocket"),
        "axis_mapping": {
            "axis": "COVALENT",
            "parent_axis": "COVALENT (expansion-main)",
            "axis_layer": "expansion-main",
            "cryptic_touch_axis": "CRYPTIC-POCKET",
            "cryptic_touch_parent_axis": "QUANTUM (core-5)",
            "cryptic_touch_axis_layer": "expansion-sub",
        },
        "real_limit_anchor": (
            "Strelow 2017 kinact/Ki framework for covalent-inhibitor "
            "efficiency + Eyring transition-state theory (kB·T/h "
            "≈ 6.46e12 /s @ 310 K hard unimolecular ceiling); switch-II "
            "cryptic-pocket conformational-selection thermodynamic "
            "cycle (Hammes, Chang & Oas, PNAS 106:13737, 2009) — "
            "ΔG_bind_obs = ΔG_bind_open + ΔG_open"
        ),
        "drug_precedent_refs": [
            "Jänne et al., N. Engl. J. Med. 387:120 (2022)",
            "FDA NDA 216340 (Krazati accelerated approval, 2022-12-12)",
            "Ostrem et al., Nature 503:548 (2013) — switch-II cryptic "
            "pocket discovery",
        ],
        "sim_run": {
            "covalent_step": _cov_subrun(adagrasib_cov),
            "cryptic_pocket": _crypt_subrun(switch_ii),
        },
        "in_silico_only": True,
    }
    return [sotorasib, adagrasib]


# ── Honest research-stage negatives (recorded, not modeled) ──────────
RESEARCH_STAGE_NEGATIVES = [
    {
        "candidate_class": "pan-KRAS / KRAS-G12C-selective PROTAC "
                           "bifunctional degrader (e.g. LC-2)",
        "axis_in_repo": "BIFUNCTIONAL (expansion-main)",
        "fda_approved": False,
        "status": "research-stage / preclinical",
        "reason": (
            "no FDA-approved KRAS-targeting bifunctional degrader "
            "exists; several preclinical CRBN- and VHL-recruiting "
            "KRAS-G12C-selective PROTACs are reported but none have "
            "advanced to FDA approval"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "antisense oligonucleotide against KRAS",
        "axis_in_repo": "OLIGONUCLEOTIDE (expansion-main)",
        "fda_approved": False,
        "status": "research-stage",
        "reason": (
            "no FDA-approved anti-KRAS ASO exists; the OLIGONUCLEOTIDE "
            "axis exists in the repo but no clinical anti-KRAS drug "
            "maps onto it"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
    {
        "candidate_class": "pan-RAS active-state inhibitor / non-G12C "
                           "KRAS mutant inhibitor (e.g. RMC-6236, "
                           "divarasib)",
        "axis_in_repo": "COVALENT (expansion-main) — for covalent "
                        "pan-RAS chemotypes; CRYPTIC-POCKET (:> "
                        "QUANTUM) for switch-II-related cryptic sites",
        "fda_approved": False,
        "status": "research-stage / clinical-trial-stage",
        "reason": (
            "no FDA-approved pan-RAS or non-G12C KRAS-mutant inhibitor "
            "exists at the time of writing; several candidates are in "
            "late clinical trials but none are FDA-approved"
        ),
        "in_scope": False,
        "reported_not_run": True,
    },
]


# ── Acceptance ────────────────────────────────────────────────────────
def acceptance(in_scope: list, negatives: list) -> dict:
    crit = {
        "X1_two_in_scope_drugs": len(in_scope) == 2,
        "X2_all_in_scope_are_cder": all(
            d["fda_center"] == "CDER" for d in in_scope
        ),
        "X3_each_in_scope_has_real_limit_anchor": all(
            d.get("real_limit_anchor") for d in in_scope
        ),
        "X4_each_in_scope_has_axis_mapping": all(
            d["axis_mapping"]["axis"] == "COVALENT" for d in in_scope
        ),
        "X5_in_scope_in_silico_only_flag_set": all(
            d.get("in_silico_only") is True for d in in_scope
        ),
        "X6_research_stage_negatives_recorded": len(negatives) >= 3,
        "X7_negatives_marked_not_run": all(
            n.get("reported_not_run") is True and n["in_scope"] is False
            for n in negatives
        ),
        "X8_both_rows_target_Cys12": all(
            "Cys12" in d["sim_run"]["covalent_step"]["inhibitor"]
            for d in in_scope
        ),
        "X9_both_rows_acrylamide_thio_michael": all(
            d["sim_run"]["covalent_step"]["warhead_class"]
            == "acrylamide_thio_michael" for d in in_scope
        ),
        "X10_switch_ii_pocket_is_cryptic": all(
            d["sim_run"]["cryptic_pocket"]["is_cryptic"] is True
            for d in in_scope
        ),
        "X11_eyring_ceiling_respected_both": all(
            (d["sim_run"]["covalent_step"]["kinact_below_eyring_ceiling"]
             is True)
            and (d["sim_run"]["covalent_step"]
                 ["kinact_tst_below_eyring_ceiling"] is True)
            for d in in_scope
        ),
        "X12_cryptic_ledger_consistent": all(
            d["sim_run"]["cryptic_pocket"]["ledger_consistency_rel_err"]
            < 1e-9 for d in in_scope
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
            "name": "KRAS-G12C-mutant cancer (e.g. non-small-cell lung "
                    "cancer with KRAS p.G12C)",
            "abbreviation": "KRAS-G12C",
            "target_protein": "KRAS GTPase (G12C mutant)",
            "targeted_residue": "Cys12 (G12C mutant-specific cysteine "
                                "in the switch-II pocket)",
        },
        "in_scope_drugs": in_scope,
        "research_stage_negatives": RESEARCH_STAGE_NEGATIVES,
        "cross_axis_touch_points": [
            {
                "id": "G2",
                "module": ("_python_bridge/module/"
                           "allosteric_cryptic_pocket_cross.py"),
                "note": ("MWC two-state and cryptic-pocket open/closed "
                         "populations coincide under R↔open mapping "
                         "(rel-err < 1e-12). sotorasib / KRAS-G12C is "
                         "the named cryptic-side precedent of that "
                         "cross — model-level unification this case "
                         "study draws on."),
            },
            {
                "id": "A5",
                "module": ("_python_bridge/module/"
                           "reversible_covalent_mpro_vqe_cross.py"),
                "note": ("A5 models the Mpro target, but its "
                         "`acrylamide_sotorasib` contrast row carries "
                         "the same irreversible-covalent warhead "
                         "modality (acrylamide → Cys thio-Michael "
                         "adduct, large |ΔG_rxn|, koff → 0) that the "
                         "two KRAS-G12C drugs in this portfolio "
                         "follow."),
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
                "Per-disease IN-SILICO composition of two existing "
                "axis sims (COVALENT expansion-main; CRYPTIC-POCKET :> "
                "QUANTUM sub-axis) for two FDA-approved CDER drugs "
                "(sotorasib / Lumakras, adagrasib / Krazati). Both "
                "share the acrylamide-warhead / Cys12 / switch-II "
                "cryptic-pocket modality. Research-stage negatives "
                "(pan-KRAS PROTACs, anti-KRAS ASOs, pan-RAS / non-G12C "
                "KRAS inhibitors) are recorded honestly, not modeled. "
                "NEVER a therapeutic / clinical / oncology / efficacy "
                "/ regulatory / portfolio-recommendation claim (g8 / "
                "f2). Drugs described by own published precedent "
                "(Canon 2019, Jänne 2022, FDA NDAs 214665 / 216340) — "
                "nothing here is derived from the n=6 lattice (g3 / "
                "f1 / f_lattice_fit). The 200-disease re-mapping "
                "remains deferred per AXIS/HIERARCHY.tape Log."
            ),
        },
        "acceptance": acc,
        "sentinel": (SENTINEL_PASS if acc["verdict"] == "PASS"
                     else SENTINEL_FAIL),
    }


def main() -> int:
    print("kras_g12c_portfolio_runner — KRAS-G12C case study "
          "(one-disease pilot)\n", flush=True)
    print("  in-scope:    sotorasib (Lumakras, Amgen, FDA 2021)")
    print("               → COVALENT + CRYPTIC-POCKET :> QUANTUM "
          "(switch-II)")
    print("               adagrasib (Krazati, Mirati/BMS, FDA 2022)")
    print("               → COVALENT + CRYPTIC-POCKET :> QUANTUM "
          "(switch-II)")
    print("  not-in-scope (honest negatives):")
    print("    pan-KRAS / KRAS-G12C PROTAC degraders — research-stage")
    print("    anti-KRAS antisense oligonucleotides — research-stage")
    print("    pan-RAS / non-G12C KRAS inhibitors — research-stage\n",
          flush=True)
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
          "Research-stage negatives listed but not modeled.\n")
    print("## witness JSON")
    print(json.dumps(witness, indent=2, sort_keys=True, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
