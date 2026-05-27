#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
drug_redesign_runner.py — drug-redesign SANDBOX (one target).

Deterministic, stdlib-only modality-space exploration around ONE FDA-
approved drug. The target is SARS-CoV-2 Mpro and the real drug is
nirmatrelvir (Paxlovid, Pfizer; FDA EUA 2022 / full approval 2023) — a
reversible-covalent nitrile-warhead inhibitor of the Mpro catalytic
Cys145.

The sandbox runs FOUR axis sims against the SAME target and reports the
in-silico model SIGNATURES side by side as a modality-space MAP:

  L1 (status quo) — REVERSIBLE-COVALENT :> COVALENT
                    reversible_covalent_sim.py — nitrile_nirmatrelvir row.
                    Eyring TST real-limit anchor.
  L2 (irreversible) — COVALENT (expansion-main, irreversible regime)
                    covalent_inhibition_sim.py — acrylamide warhead row
                    (illustrative re-engineering at Mpro Cys145).
                    Strelow kinact/Ki + Eyring TST real-limit anchors.
  L3 (degradation) — PROTAC :> BIFUNCTIONAL
                    protac_sim.py — strong-cooperativity PROTAC row
                    (illustrative Mpro-PROTAC ternary signature).
                    Douglass three-body equilibrium + Gadd cooperativity α
                    real-limit anchors.
  L4 (PPI disruption) — PPI :> QUANTUM (core)
                    ppi_sim.py — hotspot-driven interface row
                    (illustrative Mpro dimerization PPI signature).
                    Bogan-Thorn binding-hotspot theory real-limit anchor.

HONESTY (echoes A5 cross's `illustrative_only` caveat pattern):

  - Every alternative-lens row carries `illustrative_only = true` AND
    `not_a_redesign_recommendation = true`. These are model SIGNATURES
    for the modality CLASS, NOT fits to a re-engineered nirmatrelvir.
  - The original drug nirmatrelvir is the clinically-validated truth.
    The three alternative lenses (L2/L3/L4) are RESEARCH/ILLUSTRATIVE
    projections; they are NOT actual redesign proposals.
  - A PASS verifies IN-SILICO simulator + metadata internal consistency
    ONLY (g8 / f2). NEVER a redesign claim, NEVER a clinical claim,
    NEVER an efficacy or potency or selectivity prediction.
  - Per f3 (no-fork) all four parent sims are IMPORTED via importlib;
    none of their logic is re-implemented here.
  - Per g3 / f1 / f_lattice_fit each lens is described by its OWN
    modality precedent (nirmatrelvir for L1; the acrylamide-warhead
    KRAS-G12C/BTK class for L2; the ARV-471/ARV-110/BRD4-VHL PROTAC
    class for L3; the BH3-mimetic / venetoclax PPI class for L4). No
    quantity is derived from the n=6 lattice.
  - One-TARGET sandbox; NOT the deferred 200-disease re-mapping that
    AXIS/HIERARCHY.tape Log keeps explicitly out of scope.

Determinism: no random / no network / no wall-clock dependence; the
witness JSON is byte-identical across re-runs.

Sentinel: __DRUG_REDESIGN_SANDBOX__ PASS (acceptance) on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ───────────────────────────────────────────
SCHEMA_VERSION = "drug_redesign_sandbox_v1"
CASE_STUDY_ID = "drug_redesign_sandbox.v1"
TS_FIXED = "2026-05-16T00:00:00Z"     # determinism

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")


# ── f3 no-fork: import the four parent sims via importlib ────────────
def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_sims():
    """Import the four parent sims (no fork — governance f3)."""
    rcs = _load(
        "reversible_covalent_sim",
        os.path.join(BRIDGE_MOD, "reversible_covalent_sim.py"),
    )
    cis = _load(
        "covalent_inhibition_sim",
        os.path.join(BRIDGE_MOD, "covalent_inhibition_sim.py"),
    )
    prot = _load(
        "protac_sim",
        os.path.join(BRIDGE_MOD, "protac_sim.py"),
    )
    ppi = _load(
        "ppi_sim",
        os.path.join(BRIDGE_MOD, "ppi_sim.py"),
    )
    return rcs, cis, prot, ppi


# ── Target + original drug ────────────────────────────────────────────
TARGET = {
    "name": "SARS-CoV-2 Mpro",
    "aliases": ["3CLpro", "nsp5", "main protease"],
    "uniprot_class": "viral cysteine protease (catalytic dyad Cys145 / His41)",
    "organism": "Severe acute respiratory syndrome coronavirus 2",
    "function": (
        "cleaves the viral polyprotein at ~11 conserved sites to "
        "release functional non-structural proteins (Nsp4-Nsp16); the "
        "enzyme is functionally obligate-dimeric (N-finger interface)"
    ),
}

ORIGINAL_DRUG = {
    "drug": "nirmatrelvir",
    "brand": "Paxlovid (nirmatrelvir + ritonavir)",
    "sponsor": "Pfizer",
    "fda_year": 2023,
    "fda_center": "CDER",
    "fda_application": "EUA 2022; NDA 217188 full approval 2023-05-25",
    "modality": (
        "reversible-covalent nitrile-warhead small-molecule inhibitor "
        "of SARS-CoV-2 Mpro (Cys145 thioimidate adduct)"
    ),
    "is_clinically_validated": True,
    "drug_precedent_refs": [
        "Owen et al., Science 374:1586 (2021) — PF-07321332 discovery",
        "Boras et al., Nat. Commun. 12:6055 (2021) — Cys145 thioimidate",
        "FDA EUA (2022-12-22); NDA 217188 full approval (2023-05-25)",
    ],
}


# ── Lens builders (one per axis lens) ────────────────────────────────
def build_lens_L1_reversible_covalent(rcs) -> dict:
    """L1 status quo: REVERSIBLE-COVALENT :> COVALENT — nirmatrelvir-style."""
    rows = rcs.build_rows()
    # the panel's nitrile_nirmatrelvir row (status-quo modality)
    row = next(r for r in rows if r["warhead"] == "nitrile_nirmatrelvir")
    return {
        "lens_id": "L1",
        "lens_name": "status quo — reversible covalent (nitrile)",
        "axis_mapping": {
            "axis": "REVERSIBLE-COVALENT",
            "parent_axis": "COVALENT (expansion-main)",
            "axis_layer": "sub-axis",
        },
        "is_status_quo": True,
        "sim_module": "_python_bridge/module/reversible_covalent_sim.py",
        "real_limit_anchor": (
            "Eyring transition-state theory: a unimolecular elementary "
            "rate is bounded by the universal frequency prefactor "
            "kB*T/h (~6.46e12 /s @ T=310 K). koff is bounded; "
            "reversibility classification koff >= 1e-4 /s anchored by "
            "warhead-class koff regimes (Singh 2011; Boike 2022)."
        ),
        "real_limit_citations": [
            "Eyring H, J. Chem. Phys. 3:107-115 (1935) — transition-state theory",
            "Singh et al., Nat. Rev. Drug Discov. 10:307 (2011) — covalent kinetics",
            "Boike, Bhattacharya & Cravatt, Nat. Rev. Drug Discov. 21:881 (2022)",
        ],
        "modality_precedent_citations": [
            "Owen et al., Science 374:1586 (2021) — nirmatrelvir/PF-07321332",
            "Boras et al., Nat. Commun. 12:6055 (2021) — nitrile->thioimidate at Cys145",
        ],
        "model_signature": {
            "warhead": row["warhead"],
            "warhead_class": row["warhead_class"],
            "dg_on_kcal_per_mol": row["dg_on_kcal_per_mol"],
            "dg_off_kcal_per_mol": row["dg_off_kcal_per_mol"],
            "dg_rxn_kcal_per_mol": row["dg_rxn_kcal_per_mol"],
            "kon_per_s": row["kon_per_s"],
            "koff_per_s": row["koff_per_s"],
            "K_eq": row["K_eq"],
            "K_eq_consistency_rel_err": row["K_eq_consistency_rel_err"],
            "residence_time_s": row["residence_time_s"],
            "residence_time_human": row["residence_time_human"],
            "reversibility": row["reversibility"],
            "eyring_prefactor_ceiling_per_s": row["eyring_prefactor_ceiling_per_s"],
            "kon_below_eyring_ceiling": row["kon_below_eyring_ceiling"],
            "koff_below_eyring_ceiling": row["koff_below_eyring_ceiling"],
        },
        "illustrative_only": True,
        "not_a_redesign_recommendation": True,
        "lens_caveat": (
            "L1 is the STATUS-QUO modality (the actual nirmatrelvir "
            "mechanism). The model SIGNATURE is the in-silico Eyring "
            "equilibrium for the nitrile warhead CLASS; it is NOT a "
            "fit to nirmatrelvir's measured Ki / kinact / residence."
        ),
    }


def build_lens_L2_irreversible(cis) -> dict:
    """L2: COVALENT expansion-main (irreversible) — acrylamide-style."""
    rows = cis.build_rows()
    # illustrative irreversible re-engineering: an acrylamide warhead on a
    # cysteine protease. The sotorasib row is the surrogate (acrylamide on
    # KRAS-G12C Cys12); analogously an acrylamide on Mpro Cys145 would be
    # an irreversible re-design. Surrogate-only — see lens_caveat.
    row = next(r for r in rows
               if r["inhibitor"] == "sotorasib_KRAS_Cys12")
    return {
        "lens_id": "L2",
        "lens_name": (
            "irreversible covalent (acrylamide) — illustrative re-engineering"
        ),
        "axis_mapping": {
            "axis": "COVALENT",
            "parent_axis": "(expansion-main — not core-5)",
            "axis_layer": "expansion-main",
        },
        "is_status_quo": False,
        "sim_module": "_python_bridge/module/covalent_inhibition_sim.py",
        "real_limit_anchor": (
            "Strelow kinact/Ki second-order efficiency framework for "
            "covalent inhibitors; Eyring transition-state theory ceiling "
            "kB*T/h. The covalent step's elementary rate cannot exceed "
            "the universal Eyring prefactor."
        ),
        "real_limit_citations": [
            "Strelow JM, J. Biomol. Screen. / SLAS Discov. 22(1):3-20 (2017)",
            "Eyring H, J. Chem. Phys. 3:107-115 (1935)",
        ],
        "modality_precedent_citations": [
            "Honigberg et al., PNAS 107:13075 (2010) — ibrutinib BTK Cys481",
            "Canon et al., Nature 575:217 (2019) — sotorasib KRAS-G12C Cys12",
            "afatinib FDA 2013 — acrylamide EGFR Cys797",
        ],
        "model_signature": {
            "inhibitor_surrogate": row["inhibitor"],
            "warhead_class": row["warhead_class"],
            "Ki_molar": row["Ki_molar"],
            "kinact_per_s": row["kinact_per_s"],
            "kinact_over_Ki_M_per_s": row["kinact_over_Ki_M_per_s"],
            "kobs_per_s": row["kobs_per_s"],
            "free_enzyme_half_life_s": row["free_enzyme_half_life_s"],
            "free_enzyme_half_life_human": row["free_enzyme_half_life_human"],
            "dg_covalent_step_kcal_per_mol": row["dg_covalent_step_kcal_per_mol"],
            "dg_implied_from_kinact_kcal_per_mol":
                row["dg_implied_from_kinact_kcal_per_mol"],
            "eyring_prefactor_ceiling_per_s": row["eyring_prefactor_ceiling_per_s"],
            "kinact_below_eyring_ceiling": row["kinact_below_eyring_ceiling"],
            "metric_consistency_rel_err": row["metric_consistency_rel_err"],
        },
        "illustrative_only": True,
        "not_a_redesign_recommendation": True,
        "lens_caveat": (
            "L2 uses the acrylamide-warhead CLASS (here the "
            "sotorasib-KRAS-G12C surrogate row) as an in-silico "
            "signature for what an irreversible covalent Mpro inhibitor "
            "would LOOK like as a model. It is NOT a proposal to put an "
            "acrylamide on Mpro Cys145; published Mpro warhead chemistry "
            "(nitrile / aldehyde / alpha-ketoamide) deliberately favours "
            "reversible warheads for viral-protease selectivity."
        ),
    }


def build_lens_L3_protac(prot) -> dict:
    """L3: PROTAC :> BIFUNCTIONAL — illustrative Mpro-PROTAC signature."""
    rows = prot.build_rows()
    # illustrative ternary-complex signature: the strong positive-
    # cooperativity reference (Gadd-2017-style alpha >> 1) gives the
    # productive degradation-drive profile. Surrogate-only.
    row = next(r for r in rows
               if r["protac"] == "strongcoop_PROTAC_like")
    return {
        "lens_id": "L3",
        "lens_name": (
            "degradation — PROTAC bifunctional degrader (illustrative)"
        ),
        "axis_mapping": {
            "axis": "PROTAC",
            "parent_axis": "BIFUNCTIONAL (expansion-main)",
            "axis_layer": "sub-axis",
        },
        "is_status_quo": False,
        "sim_module": "_python_bridge/module/protac_sim.py",
        "real_limit_anchor": (
            "Three-body mass-action equilibrium (law of mass action; "
            "fraction-bound theta = [L]/(K_d+[L]) with theta = 1/2 "
            "exactly at [L] = K_d). The hook effect (non-monotone "
            "[T.D.E] vs [PROTAC]) is the thermodynamic consequence of "
            "high-[PROTAC] binary saturation; cooperativity factor "
            "alpha sets apparent K_d,ternary = K_d(E3)/alpha."
        ),
        "real_limit_citations": [
            "Douglass et al., J. Am. Chem. Soc. 135:6092 (2013)",
            "Gadd et al., Nat. Chem. Biol. 13:514 (2017) — alpha for VHL-BRD4",
            "Han, J. Biol. Chem. 295:15280 (2020) — ternary mathematical solutions",
        ],
        "modality_precedent_citations": [
            "Sakamoto et al., PNAS 98:8554 (2001) — first PROTAC concept",
            "ARV-471 / vepdegestrant (Arvinas/Pfizer) — ER PROTAC, clinical",
            "ARV-110 / bavdegalutamide (Arvinas) — AR PROTAC, clinical",
        ],
        "model_signature": {
            "protac_surrogate": row["protac"],
            "e3_ligase": row["e3_ligase"],
            "kd_target_nM": row["kd_target_nM"],
            "kd_e3_nM": row["kd_e3_nM"],
            "alpha_cooperativity": row["alpha_cooperativity"],
            "kd_ternary_apparent_nM": row["kd_ternary_apparent_nM"],
            "cooperativity_class": row["cooperativity_class"],
            "transfer_efficiency": row["transfer_efficiency"],
            "ternary_fraction_peak": row["ternary_fraction_peak"],
            "protac_at_peak_nM": row["protac_at_peak_nM"],
            "hook_effect_present": row["hook_effect_present"],
            "degradation_drive": row["degradation_drive"],
        },
        "illustrative_only": True,
        "not_a_redesign_recommendation": True,
        "lens_caveat": (
            "L3 uses the strong-cooperativity reference PROTAC row as "
            "an in-silico signature for what an Mpro-targeting PROTAC "
            "would LOOK like as a model. It is NOT a proposal of a "
            "real Mpro PROTAC; no FDA-approved PROTAC exists in any "
            "indication as of the witness ts, and viral-protease "
            "degraders face host-E3-ligase availability constraints "
            "in infected cells that this surrogate does NOT model."
        ),
    }


def build_lens_L4_ppi(ppi) -> dict:
    """L4: PPI :> QUANTUM — illustrative Mpro dimerization PPI signature."""
    rows = ppi.build_rows()
    # illustrative dimerization-interface signature: the alpha-helix
    # peptide cleft row is the closest surrogate for a hotspot-driven
    # protease N-finger interface (alpha-helical hotspot insertion). Mpro's
    # functional dimer requires the N-finger of one protomer to insert
    # into a cleft on the partner; small molecules disrupting this
    # interface have been reported in the literature as a research strategy.
    row = next(r for r in rows
               if r["interface"] == "mdm2_p53_cleft")
    return {
        "lens_id": "L4",
        "lens_name": (
            "PPI disruption — Mpro dimerization interface (illustrative)"
        ),
        "axis_mapping": {
            "axis": "PPI",
            "parent_axis": "QUANTUM (core-5)",
            "axis_layer": "sub-axis",
        },
        "is_status_quo": False,
        "sim_module": "_python_bridge/module/ppi_sim.py",
        "real_limit_anchor": (
            "Bogan-Thorn binding-hotspot theory (J. Mol. Biol. 280:1, "
            "1998): interface binding free energy is concentrated in a "
            "few hotspot residues (operationally Delta-Delta-G >= 2 "
            "kcal/mol by alanine scanning), NOT spread uniformly over "
            "the buried surface. A small-molecule mimic cannot recover "
            "more hotspot energy than the alanine-scanning ledger "
            "carries."
        ),
        "real_limit_citations": [
            "Bogan & Thorn, J. Mol. Biol. 280:1 (1998) — hotspot theory",
            "Clackson & Wells, Science 267:383 (1995) — alanine scanning",
            "Wells & McClendon, Nature 450:1001 (2007) — PPI druggability",
        ],
        "modality_precedent_citations": [
            "Souers et al., Nat. Med. 19:202 (2013); venetoclax FDA 2016 — BH3-mimetic BCL-2",
            "Tse et al., Cancer Res. 68:3421 (2008) — navitoclax dual BCL-2/BCL-xL",
            "Goyal & Goyal, Protein Sci. 22:1547 (2013) — Mpro dimerization disruption (research)",
        ],
        "model_signature": {
            "interface_surrogate": row["interface"],
            "interface_class": row["interface_class"],
            "n_interface_residues": row["n_interface_residues"],
            "n_hotspot_residues": row["n_hotspot_residues"],
            "alanine_scan_ddg_kcal_per_mol": row["alanine_scan_ddg_kcal_per_mol"],
            "sum_ddg_kcal_per_mol": row["sum_ddg_kcal_per_mol"],
            "sum_hotspot_ddg_kcal_per_mol": row["sum_hotspot_ddg_kcal_per_mol"],
            "hotspot_energy_fraction": row["hotspot_energy_fraction"],
            "dg_interface_kcal_per_mol": row["dg_interface_kcal_per_mol"],
            "dg_hotspot_cluster_kcal_per_mol": row["dg_hotspot_cluster_kcal_per_mol"],
            "mimicry_fraction": row["mimicry_fraction"],
            "dg_mimic_kcal_per_mol": row["dg_mimic_kcal_per_mol"],
            "small_molecule_disruption_viable": row["small_molecule_disruption_viable"],
            "hotspot_driven": row["hotspot_driven"],
            "ledger_residual_kcal_per_mol": row["ledger_residual_kcal_per_mol"],
        },
        "illustrative_only": True,
        "not_a_redesign_recommendation": True,
        "lens_caveat": (
            "L4 uses an alpha-helix-peptide-cleft hotspot interface "
            "row as a SURROGATE for the Mpro N-finger dimerization "
            "interface signature; it is NOT a measured alanine scan of "
            "the Mpro dimer. Mpro is functionally obligate-dimeric, "
            "and dimerization-disruption inhibitors have been "
            "reported as a research strategy (Goyal & Goyal 2013), but "
            "no FDA-approved Mpro PPI disruptor exists and venetoclax "
            "is the cited PPI-drug precedent for the modality, NOT for "
            "the target."
        ),
    }


# ── Cross-links (existing in-repo work this sandbox is built on) ─────
CROSS_LINKS = [
    {
        "id": "A5",
        "module": (
            "_python_bridge/module/reversible_covalent_mpro_vqe_cross.py"
        ),
        "note": (
            "REVERSIBLE-COVALENT x Mpro warhead VQE cross — the existing "
            "bridge whose `illustrative_only=true` caveat pattern this "
            "sandbox echoes on every alternative-lens row."
        ),
    },
    {
        "id": "mpro_warhead_library_vqe_v7",
        "module": "tests/mpro_warhead_library_vqe_v7.py",
        "note": (
            "the mpro warhead library that already covers the Mpro "
            "Cys145 warhead-class space; the sandbox builds on it "
            "(not modified) and adds three more axis lenses around it."
        ),
    },
    {
        "id": "REVERSIBLE-COVALENT",
        "module": "_python_bridge/module/reversible_covalent_sim.py",
        "note": "parent sim for L1 (status quo); IMPORTED via importlib (f3).",
    },
    {
        "id": "COVALENT",
        "module": "_python_bridge/module/covalent_inhibition_sim.py",
        "note": "parent sim for L2 (irreversible); IMPORTED via importlib (f3).",
    },
    {
        "id": "PROTAC",
        "module": "_python_bridge/module/protac_sim.py",
        "note": "parent sim for L3 (PROTAC); IMPORTED via importlib (f3).",
    },
    {
        "id": "PPI",
        "module": "_python_bridge/module/ppi_sim.py",
        "note": "parent sim for L4 (PPI disruption); IMPORTED via importlib (f3).",
    },
]


# ── Acceptance ───────────────────────────────────────────────────────
def acceptance(lenses: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1..X10)."""
    by_id = {L["lens_id"]: L for L in lenses}
    crit = {
        "X1_four_lenses": len(lenses) == 4,
        "X2_lens_ids_unique_L1_L2_L3_L4": (
            sorted(L["lens_id"] for L in lenses) == ["L1", "L2", "L3", "L4"]
        ),
        "X3_exactly_one_status_quo": (
            sum(1 for L in lenses if L["is_status_quo"]) == 1
        ),
        "X4_status_quo_is_L1": by_id["L1"]["is_status_quo"] is True,
        "X5_all_alt_lenses_illustrative_only_true": all(
            L["illustrative_only"] is True for L in lenses
        ),
        "X6_all_alt_lenses_not_a_redesign_recommendation_true": all(
            L["not_a_redesign_recommendation"] is True for L in lenses
        ),
        "X7_each_lens_has_real_limit_anchor": all(
            L.get("real_limit_anchor") for L in lenses
        ),
        "X8_each_lens_has_axis_mapping": all(
            L["axis_mapping"]["axis"] for L in lenses
        ),
        "X9_L1_reversible_signature_consistent": (
            by_id["L1"]["model_signature"]["reversibility"] == "reversible"
            and (by_id["L1"]["model_signature"]
                 ["K_eq_consistency_rel_err"] < 1e-9)
            and by_id["L1"]["model_signature"]["kon_below_eyring_ceiling"]
            and by_id["L1"]["model_signature"]["koff_below_eyring_ceiling"]
        ),
        "X10_L2_kinact_below_eyring_ceiling": (
            by_id["L2"]["model_signature"]["kinact_below_eyring_ceiling"]
            is True
            and (by_id["L2"]["model_signature"]
                 ["metric_consistency_rel_err"] < 1e-9)
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
    rcs, cis, prot, ppi = _import_sims()
    lenses = [
        build_lens_L1_reversible_covalent(rcs),
        build_lens_L2_irreversible(cis),
        build_lens_L3_protac(prot),
        build_lens_L4_ppi(ppi),
    ]
    acc = acceptance(lenses)
    return {
        "schema_version": SCHEMA_VERSION,
        "case_study_id": CASE_STUDY_ID,
        "ts": TS_FIXED,
        "target": TARGET,
        "original_drug": ORIGINAL_DRUG,
        "lenses": lenses,
        "cross_links": CROSS_LINKS,
        "honesty": {
            "in_silico_only": True,
            "comparison_is_ranking": False,
            "not_a_redesign_recommendation": True,
            "original_drug_remains_the_clinical_truth": True,
            "all_alternative_lenses_illustrative": True,
            "no_fork_of_sister_sims": True,
            "no_lattice_derivation": True,
            "core_5_unchanged": True,
            "one_target_sandbox_not_200_disease_remap": True,
            "statement": (
                "Drug-redesign SANDBOX for one target (SARS-CoV-2 Mpro) "
                "around one FDA-approved drug (nirmatrelvir / Paxlovid). "
                "The four axis lenses (L1 reversible-covalent status quo; "
                "L2 irreversible covalent; L3 PROTAC; L4 PPI disruption) "
                "are in-silico simulator-consistency MODEL SIGNATURES, "
                "NOT efficacy predictions, NOT redesign proposals, NOT "
                "clinical / therapeutic / regulatory claims (g8 / f2). "
                "nirmatrelvir is clinically validated; the three "
                "alternative lenses are RESEARCH/ILLUSTRATIVE projections. "
                "Each alternative-lens row carries `illustrative_only` and "
                "`not_a_redesign_recommendation`, echoing the A5 cross's "
                "caveat pattern. No quantity is derived from the n=6 "
                "lattice (g3 / f1 / f_lattice_fit); each lens cites its "
                "OWN modality precedent. f3 no-fork: all four parent sims "
                "are imported, never re-implemented. Core-5 axes unchanged."
            ),
        },
        "acceptance": acc,
        "sentinel": (
            "__DRUG_REDESIGN_SANDBOX__ PASS"
            if acc["verdict"] == "PASS"
            else "__DRUG_REDESIGN_SANDBOX__ FAIL"
        ),
    }


def main() -> int:
    print("drug_redesign_runner — one-target modality-space sandbox\n",
          flush=True)
    print("  target:        SARS-CoV-2 Mpro (3CLpro / nsp5)")
    print("  original drug: nirmatrelvir (Paxlovid, Pfizer; FDA EUA 2022 / "
          "full 2023)")
    print("  lenses:        L1 REVERSIBLE-COVALENT (status quo)")
    print("                 L2 COVALENT (irreversible — illustrative)")
    print("                 L3 PROTAC :> BIFUNCTIONAL (illustrative)")
    print("                 L4 PPI :> QUANTUM (illustrative)\n", flush=True)

    witness = build_witness()
    acc = witness["acceptance"]

    print("## lens signatures (in-silico model only)")
    for L in witness["lenses"]:
        ax = L["axis_mapping"]
        print(f"  [{L['lens_id']}] {L['lens_name']}")
        print(f"        axis = {ax['axis']} ({ax['axis_layer']}) :> "
              f"{ax['parent_axis']}")
        print(f"        sim  = {L['sim_module']}")
        print(f"        illustrative_only={L['illustrative_only']}  "
              f"not_a_redesign_recommendation="
              f"{L['not_a_redesign_recommendation']}")

    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: "
          f"{acc['verdict']} ---\n")

    print("  [honesty g8 / f2] every PASS verifies IN-SILICO simulator + ")
    print("  metadata internal consistency ONLY. NEVER a redesign claim, ")
    print("  NEVER a clinical / therapeutic / efficacy / regulatory claim. ")
    print("  nirmatrelvir is the clinically-validated truth; L2/L3/L4 are ")
    print("  RESEARCH/ILLUSTRATIVE projections. One-target sandbox, NOT ")
    print("  the deferred 200-disease re-mapping (AXIS/HIERARCHY.tape Log).\n")

    print("## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
