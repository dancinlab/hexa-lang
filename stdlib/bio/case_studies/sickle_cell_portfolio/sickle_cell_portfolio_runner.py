#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sickle_cell_portfolio_runner.py — Sickle Cell Disease (SCD) portfolio
case study (one-disease pilot).

WHAT THIS IS
────────────
SCD is the rare disease with FDA-approved drugs across MULTIPLE
distinct modality classes — making it a uniquely rich axis-mapping
showcase. This runner emits a deterministic portfolio witness that
records THREE structurally-distinct categories of FDA-approved SCD
drugs:

  (1) IN-SCOPE with axis mapping — CDER small molecules whose modality
      maps onto in-repo axes. For SCD this is voxelotor, with a
      uniquely DUAL axis mapping (PPI primary + ALLOSTERIC secondary).

  (2) CDER in-scope but NO axis mapping — FDA-approved CDER small
      molecules inside the criterion #4 scope whose mechanism does NOT
      map onto any current in-repo axis (hydroxyurea, L-glutamine).
      The honest call is: list them, do not invent forced axes.

  (3) CBER UNPLACED — FDA-approved drugs whose regulatory jurisdiction
      is CBER (gene/cell therapy or biologic mAb), excluded by
      criterion #4 drug-only/CDER discipline (Casgevy, Lyfgenia,
      crizanlizumab).

  - voxelotor / Oxbryta (Pfizer / Global Blood Therapeutics, FDA 2019,
    NDA 213137 — approved 2019-11-25) — hemoglobin oxygen-affinity
    modulator. Binds HbS at α-chain N-terminal Val1 via a reversible
    Schiff-base / aldehyde-imine linkage; stabilizes the high-affinity
    R (oxy) state, which BOTH (a) reduces the deoxy-HbS population
    available to enter the polymer (allosteric R/T shift — pure MWC)
    AND (b) disrupts the HbS-HbS deoxy-polymer contact at the
    α-chain N-terminal contact patch with the neighboring tetramer
    (β6-Val sickle-mutation acceptor pocket geometry). The two
    mechanisms are NOT alternatives — they are simultaneous
    consequences of the same R-state stabilization. The portfolio
    records BOTH axis mappings (PPI primary + ALLOSTERIC secondary)
    to reflect the literature mechanism honestly.

  - hydroxyurea / Hydrea / Droxia / Siklos (Bristol-Myers Squibb;
    originally FDA-approved as Hydrea 1967 for cancer; FDA-approved
    for SCD specifically as Droxia 1998-02-25, NDA 016295 supplement;
    Siklos pediatric approval 2017) — ribonucleotide reductase
    inhibitor that induces fetal hemoglobin (HbF) reactivation. The
    HbF-induction mechanism (mostly via NO-mediated upregulation of
    γ-globin gene expression) does NOT map cleanly onto any current
    in-repo axis (it is a gene-expression modulator, not a PPI /
    allosteric / RNA-targeting small molecule / oligonucleotide /
    capsid modulator / bifunctional degrader). HONESTLY
    `cder_in_scope_but_no_axis_mapping`.

  - L-glutamine / Endari (Emmaus Medical, FDA 2017-07-07, NDA 208587)
    — pharmaceutical-grade oral L-glutamine; reduces acute vaso-
    occlusive complications. Mechanism is nitrogen-substrate / NAD+/
    glutathione redox balance support in erythrocytes (anti-oxidative
    substrate). Does NOT map cleanly onto any current in-repo axis.
    HONESTLY `cder_in_scope_but_no_axis_mapping`.

  - exagamglogene autotemcel (exa-cel) / Casgevy (Vertex
    Pharmaceuticals / CRISPR Therapeutics, FDA 2023-12-08, BLA
    125787 — CBER) — ex-vivo CRISPR-Cas9 gene editing of patient
    autologous CD34+ HSCs at the BCL11A erythroid enhancer to
    de-repress γ-globin and reactivate HbF. CBER biologic — criterion
    #4 disqualified. UNPLACED.

  - lovotibeglogene autotemcel (lovo-cel) / Lyfgenia (bluebird bio,
    FDA 2023-12-08, BLA 125765 — CBER) — autologous lentiviral
    gene therapy adding a modified anti-sickling β-globin gene
    (T87Q) ex-vivo. CBER biologic — criterion #4 disqualified.
    UNPLACED.

  - crizanlizumab / Adakveo (Novartis, FDA 2019-11-15, BLA 761128 —
    CBER) — humanized anti-P-selectin monoclonal antibody, reduces
    frequency of vaso-occlusive crises. Regulatory complexity
    flagged honestly: EMA conditional marketing authorization was
    REVOKED in 2023 after a confirmatory trial failed to demonstrate
    benefit; FDA approval has remained in place through 2024. CBER
    biologic — criterion #4 disqualified regardless of regional
    regulatory status. UNPLACED.

HONEST UNPLACED HANDLING
────────────────────────
A portfolio that pretends to cover all six drugs by inventing forced
axes would be DISHONEST. The honest record is:

  - 1 in-scope drug (voxelotor) with a UNIQUE DUAL axis mapping.
  - 2 CDER-in-scope-no-axis drugs (hydroxyurea, L-glutamine) — recorded
    structurally (`category=cder_in_scope_but_no_axis_mapping`),
    `axis=null`, `reported_not_run=true`. The hexa-bio criterion #4
    scope ADMITS them as CDER small molecules, but the axis tree does
    not currently cover their mechanism — that is a coverage fact, not
    a coverage failure.
  - 3 CBER UNPLACED drugs (Casgevy, Lyfgenia, crizanlizumab) — same
    pattern as the Zolgensma row in the SMA portfolio
    (`@N genetic_medicine_status` in `AXIS/HIERARCHY.tape`).

Per f3 (no-fork) both parent sims are IMPORTED via `importlib`, not
re-implemented. Per g1 the voxelotor row inherits each parent sim's
real-limit citation on the corresponding axis side (Bogan & Thorn 1998
on the PPI side; MWC 1965 on the ALLOSTERIC side). Per g8/f2 every PASS
= in-silico simulator+metadata consistency ONLY, never a clinical /
therapeutic / regulatory / efficacy / portfolio-recommendation claim.
Per g3/f1 each drug is described by its OWN published precedent —
nothing is derived from the n=6 lattice.

DETERMINISM
───────────
Pure stdlib. No random / network / wall-clock. Fixed timestamp string.
The witness JSON is byte-identical across re-runs.

EXIT
────
Exit 0 on PASS with `__SICKLE_CELL_PORTFOLIO__ PASS` printed at the end.
Exit 1 on FAIL with `__SICKLE_CELL_PORTFOLIO__ FAIL`.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from typing import Any, Dict, List

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "sickle_cell_portfolio_v1"
CASE_STUDY_ID = "sickle_cell_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism
SENTINEL_PASS = "__SICKLE_CELL_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__SICKLE_CELL_PORTFOLIO__ FAIL"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")


def _load(name: str, path: str):
    """Import a parent sim by file path — no fork (governance f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_sims():
    """Import the two parent sims (governance f3 — no re-implementation)."""
    ppi = _load("ppi_sim", os.path.join(BRIDGE_MOD, "ppi_sim.py"))
    allo = _load("allosteric_sim",
                 os.path.join(BRIDGE_MOD, "allosteric_sim.py"))
    return ppi, allo


# ── voxelotor — illustrative HbS-HbS deoxy contact ΔΔG signature ─────
#
# Voxelotor binds HbS at the α-chain N-terminal Val1 (a chiral aldehyde
# / Schiff-base linkage) and stabilizes the R (oxy) state of the
# hemoglobin tetramer. The PPI-side consequence is disruption of the
# HbS-HbS deoxy-polymer contact at the α-chain N-terminal contact
# patch with the neighboring tetramer (the β6-Val-acceptor pocket
# geometry described by Wishner & Love 1975 and re-mapped by
# Harrington 1997). These ΔΔG values are LITERATURE-INFORMED
# SURROGATES for the HbS-HbS contact CLASS (in line with the parent
# ppi_sim's panel convention — see ppi_sim.py module docstring "ΔΔG
# values are illustrative literature-informed surrogates for interface
# CLASSES, not fits to a specific complex"). They exercise the parent
# sim's arithmetic; they assert no measured binding free energy.
_VOXELOTOR_HBS_HBS_DDG_KCAL = [3.5, 2.8, 2.2, 1.0, 0.6, 0.4]
_VOXELOTOR_HBS_HBS_MIMICRY = 0.78

# ── voxelotor — allosteric R/T cooperativity surrogate ─────────────
#
# Voxelotor stabilizes the R (oxy) state, increasing oxygen affinity
# (left-shift of the Hb-O2 dissociation curve). On the MWC
# orthosteric / allosteric formalism, this is a positive allosteric
# modulator (PAM) of oxygen binding from the modulator (voxelotor)
# perspective: α > 1 (oxygen affinity ENHANCED). The α / K_B values
# below are illustrative surrogates for the PAM CLASS, in line with
# the parent allosteric_sim's panel convention.
_VOXELOTOR_ALPHA = 6.0
_VOXELOTOR_KB_UM = 12.0


def _row_voxelotor_ppi_side(ppi_mod) -> Dict[str, Any]:
    """Voxelotor PPI side — HbS-HbS deoxy-polymer contact disruption."""
    prof = ppi_mod.interface_profile(
        list(_VOXELOTOR_HBS_HBS_DDG_KCAL),
        _VOXELOTOR_HBS_HBS_MIMICRY,
    )
    return {
        "axis": "PPI",
        "parent_axis": "QUANTUM (core-5)",
        "axis_layer": "expansion-sub",
        "role": "primary",
        "axis_module": "_python_bridge/module/ppi_sim.py",
        "real_limit_anchor": (
            "Bogan & Thorn 1998 binding-hotspot theory "
            "(J. Mol. Biol. 280:1) — interface binding free energy "
            "concentrated in a few hotspot residues (ΔΔG ≥ 2 kcal/mol "
            "by alanine scanning), bounded by the alanine-scanning "
            "ledger; druggability of flat hotspot-driven PPIs follows "
            "Wells & McClendon, Nature 450:1001 (2007). Applied here "
            "to the HbS-HbS deoxy-polymer contact patch — the "
            "β6-Val-acceptor geometry mapped by Wishner & Love 1975 "
            "(J. Mol. Biol. 98:179) and re-examined by Harrington "
            "et al. 1997 (J. Mol. Biol. 272:398)."
        ),
        "drug_precedent_refs": [
            "Oksenberg et al., Br. J. Haematol. 175:141 (2016) — "
            "GBT440 / voxelotor discovery + HbS polymerization "
            "inhibition",
            "Vichinsky et al., N. Engl. J. Med. 381:509 (2019) — "
            "HOPE trial, voxelotor in SCD",
            "FDA NDA 213137 — voxelotor (Oxbryta) approval, "
            "2019-11-25, CDER",
        ],
        "sim_run": {
            "sim_module": "ppi_sim",
            "interface": "voxelotor_HbS_HbS_deoxy_contact",
            "interface_class": "hbs_polymer_contact_patch",
            "n_interface_residues": prof["n_interface_residues"],
            "n_hotspot_residues": prof["n_hotspot_residues"],
            "hotspot_ddg_threshold_kcal_per_mol":
                prof["hotspot_ddg_threshold_kcal_per_mol"],
            "sum_ddg_kcal_per_mol": prof["sum_ddg_kcal_per_mol"],
            "sum_hotspot_ddg_kcal_per_mol":
                prof["sum_hotspot_ddg_kcal_per_mol"],
            "hotspot_energy_fraction": prof["hotspot_energy_fraction"],
            "dg_interface_kcal_per_mol":
                prof["dg_interface_kcal_per_mol"],
            "dg_hotspot_cluster_kcal_per_mol":
                prof["dg_hotspot_cluster_kcal_per_mol"],
            "mimicry_fraction": prof["mimicry_fraction"],
            "dg_mimic_kcal_per_mol": prof["dg_mimic_kcal_per_mol"],
            "small_molecule_disruption_viable":
                prof["small_molecule_disruption_viable"],
            "hotspot_driven": prof["hotspot_driven"],
            "ledger_residual_kcal_per_mol":
                prof["ledger_residual_kcal_per_mol"],
            "mimic_within_ledger": prof["mimic_within_ledger"],
        },
    }


def _row_voxelotor_allosteric_side(allo_mod) -> Dict[str, Any]:
    """Voxelotor allosteric side — R/T state stabilization (MWC PAM)."""
    prof = allo_mod.allosteric_profile(
        _VOXELOTOR_ALPHA, _VOXELOTOR_KB_UM)
    return {
        "axis": "ALLOSTERIC",
        "parent_axis": "QUANTUM (core-5)",
        "axis_layer": "expansion-sub",
        "role": "secondary",
        "axis_module": "_python_bridge/module/allosteric_sim.py",
        "real_limit_anchor": (
            "Monod, Wyman & Changeux 1965 (J. Mol. Biol. 12:88) MWC "
            "concerted two-state allosteric model — modulation is "
            "SATURABLE, bounded by the ceiling 1/α; ternary-complex / "
            "two-state extension follows Hall, Mol. Pharmacol. 58:1412 "
            "(2000) and Christopoulos & Kenakin, Pharmacol. Rev. "
            "54:323 (2002). Applied here to the R/T equilibrium of "
            "the hemoglobin tetramer in line with Perutz's classic "
            "R/T two-state account (Perutz, Nature 228:726, 1970)."
        ),
        "drug_precedent_refs": [
            "Metcalf et al., ACS Med. Chem. Lett. 8:321 (2017) — "
            "GBT440 / voxelotor — R-state HbS stabilization by "
            "α-Val1 Schiff-base linkage",
            "FDA NDA 213137 — voxelotor (Oxbryta) approval, "
            "2019-11-25, CDER",
        ],
        "sim_run": {
            "sim_module": "allosteric_sim",
            "modulator": "voxelotor_Hb_R_state_PAM",
            "modulator_class": "positive_allosteric_modulator",
            "cooperativity_alpha": prof["cooperativity_alpha"],
            "modulator_kd_uM": prof["modulator_kd_uM"],
            "modulation_kind": prof["modulation_kind"],
            "log10_alpha": prof["log10_alpha"],
            "allosteric_ceiling_shift": prof["allosteric_ceiling_shift"],
            "ec50_shift_at_max_conc": prof["ec50_shift_at_max_conc"],
            "ceiling_respected": prof["ceiling_respected"],
            "sweep_monotone_toward_ceiling":
                prof["sweep_monotone_toward_ceiling"],
            "is_allosteric_modulator":
                prof["modulation_kind"] in ("NAM", "PAM"),
        },
    }


# ── In-scope drugs (axis-mapped) ──────────────────────────────────────
def build_in_scope_rows() -> List[Dict[str, Any]]:
    """One in-scope drug — voxelotor — with TWO axis mappings."""
    ppi, allo = _import_sims()
    voxelotor = {
        "drug": "voxelotor",
        "brand": "Oxbryta",
        "sponsor": "Pfizer / Global Blood Therapeutics",
        "fda_year": 2019,
        "fda_center": "CDER",
        "fda_application": "NDA 213137 — Oxbryta approval 2019-11-25",
        "modality": (
            "hemoglobin oxygen-affinity modulator — reversible "
            "covalent Schiff-base / aldehyde-imine linkage to the "
            "α-chain N-terminal Val1; stabilizes the R (oxy) state, "
            "simultaneously increasing O2 affinity (allosteric R/T "
            "shift — pure MWC) AND reducing the deoxy-HbS population "
            "available to enter the sickle polymer (disrupting the "
            "HbS-HbS contact at the α-chain N-terminal contact patch)"
        ),
        "axis_mappings": [
            _row_voxelotor_ppi_side(ppi),
            _row_voxelotor_allosteric_side(allo),
        ],
        "in_silico_only": True,
    }
    return [voxelotor]


# ── CDER in-scope but NO axis mapping (honest coverage gaps) ─────────
CDER_IN_SCOPE_NO_AXIS = [
    {
        "drug": "hydroxyurea",
        "brand": "Hydrea / Droxia / Siklos",
        "sponsor": "Bristol-Myers Squibb (Hydrea / Droxia); Addmedica (Siklos)",
        "fda_year": 1998,
        "fda_center": "CDER",
        "modality": (
            "ribonucleotide reductase inhibitor; induces fetal "
            "hemoglobin (HbF) reactivation in erythroid progenitors "
            "(primarily via NO-mediated upregulation of γ-globin "
            "expression). The mechanism is a gene-expression / "
            "transcriptional response — not a protein-protein contact "
            "disruption, not an allosteric modulator on a defined "
            "MWC two-state target, not an RNA-targeting small "
            "molecule, not an oligonucleotide, not a capsid modulator, "
            "not a bifunctional degrader."
        ),
        "axis": None,
        "in_scope": False,
        "reason": (
            "CDER small molecule INSIDE the criterion #4 drug-only/"
            "CDER scope, but its gene-expression-modulator mechanism "
            "does NOT map cleanly onto any current in-repo axis. The "
            "honest call is to list it structurally as "
            "`cder_in_scope_but_no_axis_mapping`, not to invent a "
            "forced axis."
        ),
        "drug_precedent_refs": [
            "Charache et al., N. Engl. J. Med. 332:1317 (1995) — "
            "Multicenter Study of Hydroxyurea in Sickle Cell Anemia",
            "FDA NDA 016295 (Hydrea, originally approved 1967 for "
            "neoplastic disease); SCD supplemental approval as Droxia "
            "1998-02-25 (CDER)",
            "FDA NDA 208843 — Siklos pediatric SCD approval "
            "2017-12-21 (Addmedica, CDER)",
        ],
        "reported_not_run": True,
        "category": "cder_in_scope_but_no_axis_mapping",
    },
    {
        "drug": "L-glutamine",
        "brand": "Endari",
        "sponsor": "Emmaus Medical",
        "fda_year": 2017,
        "fda_center": "CDER",
        "modality": (
            "pharmaceutical-grade oral L-glutamine; nitrogen-substrate "
            "/ NAD+ / glutathione redox-balance support in "
            "erythrocytes (antioxidant-substrate mechanism). Reduces "
            "frequency of acute vaso-occlusive complications. The "
            "mechanism is metabolic substrate provision — not a "
            "protein-protein contact disruption, not an allosteric "
            "modulator on a defined MWC two-state target."
        ),
        "axis": None,
        "in_scope": False,
        "reason": (
            "CDER small molecule INSIDE the criterion #4 drug-only/"
            "CDER scope, but its antioxidant-substrate mechanism does "
            "NOT map cleanly onto any current in-repo axis. The "
            "honest call is to list it structurally as "
            "`cder_in_scope_but_no_axis_mapping`."
        ),
        "drug_precedent_refs": [
            "Niihara et al., N. Engl. J. Med. 379:226 (2018) — "
            "Phase III L-glutamine in SCD",
            "FDA NDA 208587 — Endari approval 2017-07-07 (CDER)",
        ],
        "reported_not_run": True,
        "category": "cder_in_scope_but_no_axis_mapping",
    },
]


# ── CBER UNPLACED — criterion #4 disqualified ────────────────────────
NOT_IN_SCOPE_DRUGS = [
    {
        "drug": "exagamglogene autotemcel (exa-cel)",
        "brand": "Casgevy",
        "sponsor": "Vertex Pharmaceuticals / CRISPR Therapeutics",
        "fda_year": 2023,
        "fda_center": "CBER",
        "modality": (
            "autologous ex-vivo CRISPR-Cas9 gene editing of patient "
            "CD34+ HSCs at the BCL11A erythroid enhancer, "
            "de-repressing γ-globin and reactivating fetal "
            "hemoglobin (HbF). One-time intravenous infusion of "
            "edited cells after myeloablative conditioning."
        ),
        "axis": None,
        "in_scope": False,
        "reason": (
            "CBER-regulated cell-and-gene therapy biologic. "
            "criterion #4 drug-only/CDER scope boundary — same "
            "pattern as the Zolgensma row in the SMA portfolio. "
            "Implementing a CBER-scope code axis would breach "
            "criterion #4 + g8 in-silico-only honesty."
        ),
        "drug_precedent_refs": [
            "Frangoul et al., N. Engl. J. Med. 384:252 (2021) — "
            "CTX001 (now exa-cel) editing BCL11A enhancer in SCD/TDT",
            "FDA STN BL 125787 — exa-cel (Casgevy) approval, "
            "2023-12-08, CBER",
        ],
        "reported_not_run": True,
        "category": "cber_unplaced_criterion_4",
        "regulatory_status_note": (
            "First FDA-approved CRISPR-based therapy; co-approved "
            "with Lyfgenia for SCD on the same day (2023-12-08)."
        ),
    },
    {
        "drug": "lovotibeglogene autotemcel (lovo-cel)",
        "brand": "Lyfgenia",
        "sponsor": "bluebird bio",
        "fda_year": 2023,
        "fda_center": "CBER",
        "modality": (
            "autologous ex-vivo lentiviral gene-addition therapy: a "
            "BB305 lentiviral vector transduces patient CD34+ HSCs to "
            "express a modified anti-sickling β-globin transgene "
            "(βA-T87Q). Single-dose infusion after myeloablative "
            "conditioning."
        ),
        "axis": None,
        "in_scope": False,
        "reason": (
            "CBER-regulated cell-and-gene therapy biologic. "
            "criterion #4 drug-only/CDER scope boundary — same "
            "pattern as the Zolgensma row in the SMA portfolio."
        ),
        "drug_precedent_refs": [
            "Kanter et al., N. Engl. J. Med. 386:617 (2022) — "
            "LentiGlobin / lovo-cel in SCD",
            "FDA STN BL 125765 — lovo-cel (Lyfgenia) approval, "
            "2023-12-08, CBER",
        ],
        "reported_not_run": True,
        "category": "cber_unplaced_criterion_4",
        "regulatory_status_note": (
            "Co-approved with Casgevy on 2023-12-08; carries a "
            "boxed-warning label for hematologic malignancy risk "
            "associated with lentiviral integration."
        ),
    },
    {
        "drug": "crizanlizumab",
        "brand": "Adakveo",
        "sponsor": "Novartis",
        "fda_year": 2019,
        "fda_center": "CBER",
        "modality": (
            "humanized IgG2 monoclonal antibody targeting P-selectin "
            "(CD62P), reducing leukocyte-endothelial adhesion and the "
            "frequency of vaso-occlusive crises. Intravenous infusion."
        ),
        "axis": None,
        "in_scope": False,
        "reason": (
            "CBER-regulated biologic (therapeutic monoclonal "
            "antibody). criterion #4 drug-only/CDER scope boundary. "
            "Same UNPLACED pattern as antibody modalities elsewhere "
            "in the axis tree."
        ),
        "drug_precedent_refs": [
            "Ataga et al., N. Engl. J. Med. 376:429 (2017) — "
            "SUSTAIN trial, crizanlizumab in SCD",
            "FDA STN BL 761128 — crizanlizumab (Adakveo) approval, "
            "2019-11-15, CBER",
        ],
        "reported_not_run": True,
        "category": "cber_unplaced_criterion_4",
        "regulatory_status_note": (
            "Regulatory complexity noted honestly: EMA conditional "
            "marketing authorization was REVOKED in 2023 after the "
            "STAND confirmatory trial failed to demonstrate benefit; "
            "FDA approval status has remained in place through 2024 "
            "at the time of this writing. Readers should re-check "
            "current FDA status directly on Drugs@FDA before quoting."
        ),
    },
]


# ── Cross-axis touch-points ──────────────────────────────────────────
CROSS_AXIS_TOUCH_POINTS = [
    {
        "id": "G2",
        "module":
            "_python_bridge/module/allosteric_cryptic_pocket_cross.py",
        "note": (
            "ALLOSTERIC × CRYPTIC-POCKET. The MWC two-state model and "
            "the cryptic-pocket open/closed population coincide "
            "identically under R↔open mapping. Voxelotor's R-state "
            "stabilization is the textbook MWC mechanism the G2 cross "
            "formalizes."
        ),
    },
    {
        "id": "G3",
        "module": "_python_bridge/module/ppi_molecular_glue_cross.py",
        "note": (
            "PPI × MOLECULAR-GLUE. Listed for completeness of the "
            "cross-axis touch-point map; voxelotor is a PPI disruptor "
            "(not a glue), so this touch-point is cited as a "
            "framework anchor for the PPI side, not as a mechanism "
            "claim for voxelotor."
        ),
    },
]


# ── Acceptance ────────────────────────────────────────────────────────
def acceptance(in_scope: List[Dict[str, Any]],
               cder_no_axis: List[Dict[str, Any]],
               not_in_scope: List[Dict[str, Any]]) -> Dict[str, Any]:
    crit = {
        "X1_one_in_scope_drug_voxelotor": (
            len(in_scope) == 1
            and in_scope[0]["drug"] == "voxelotor"
        ),
        "X2_voxelotor_has_two_axis_mappings": (
            len(in_scope[0]["axis_mappings"]) == 2
        ),
        "X3_voxelotor_ppi_is_primary": (
            in_scope[0]["axis_mappings"][0]["axis"] == "PPI"
            and in_scope[0]["axis_mappings"][0]["role"] == "primary"
        ),
        "X4_voxelotor_allosteric_is_secondary": (
            in_scope[0]["axis_mappings"][1]["axis"] == "ALLOSTERIC"
            and in_scope[0]["axis_mappings"][1]["role"] == "secondary"
        ),
        "X5_in_scope_is_cder": (
            in_scope[0]["fda_center"] == "CDER"
        ),
        "X6_in_silico_only_flag_set": (
            in_scope[0].get("in_silico_only") is True
        ),
        "X7_ppi_side_hotspot_driven": (
            in_scope[0]["axis_mappings"][0]["sim_run"]["hotspot_driven"]
            is True
        ),
        "X8_ppi_side_ledger_conserved": (
            in_scope[0]["axis_mappings"][0]["sim_run"]
            ["ledger_residual_kcal_per_mol"] < 1e-9
        ),
        "X9_allosteric_side_is_PAM": (
            in_scope[0]["axis_mappings"][1]["sim_run"]
            ["modulation_kind"] == "PAM"
        ),
        "X10_allosteric_ceiling_respected": (
            in_scope[0]["axis_mappings"][1]["sim_run"]
            ["ceiling_respected"] is True
        ),
        "X11_two_cder_no_axis_drugs": len(cder_no_axis) == 2,
        "X12_cder_no_axis_all_cder_and_axis_null": all(
            (d["fda_center"] == "CDER" and d["axis"] is None
             and d["in_scope"] is False
             and d.get("category") == "cder_in_scope_but_no_axis_mapping")
            for d in cder_no_axis
        ),
        "X13_three_cber_unplaced_drugs": len(not_in_scope) == 3,
        "X14_cber_unplaced_all_cber_and_axis_null": all(
            (d["fda_center"] == "CBER" and d["axis"] is None
             and d["in_scope"] is False
             and d.get("category") == "cber_unplaced_criterion_4"
             and d.get("reported_not_run") is True)
            for d in not_in_scope
        ),
        "X15_all_negatives_have_drug_precedent_refs": all(
            isinstance(d.get("drug_precedent_refs"), list)
            and len(d["drug_precedent_refs"]) >= 1
            for d in (cder_no_axis + not_in_scope)
        ),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


# ── Witness assembly ─────────────────────────────────────────────────
def build_witness() -> Dict[str, Any]:
    in_scope = build_in_scope_rows()
    acc = acceptance(in_scope, CDER_IN_SCOPE_NO_AXIS, NOT_IN_SCOPE_DRUGS)
    return {
        "schema_version": SCHEMA_VERSION,
        "case_study_id": CASE_STUDY_ID,
        "ts": TS_FIXED,
        "disease": {
            "name": "Sickle Cell Disease",
            "abbreviation": "SCD",
            "shared_gene": "HBB (β-globin) — β6 Glu→Val sickle mutation",
            "shared_pathology": (
                "deoxy-HbS polymerization in erythrocytes → "
                "vaso-occlusive crises and chronic hemolytic anemia"
            ),
        },
        "in_scope_drugs": in_scope,
        "cder_in_scope_no_axis_mapping": CDER_IN_SCOPE_NO_AXIS,
        "not_in_scope_drugs": NOT_IN_SCOPE_DRUGS,
        "cross_axis_touch_points": CROSS_AXIS_TOUCH_POINTS,
        "honesty": {
            "in_silico_only": True,
            "core_5_unchanged": True,
            "no_fork_of_sister_sims": True,
            "one_disease_pilot_not_200_disease_remap": True,
            "cder_no_axis_listed_honestly": True,
            "cber_unplaced_listed_honestly": True,
            "voxelotor_dual_mapping_is_a_feature": True,
            "no_lattice_derivation": True,
            "statement": (
                "Per-disease IN-SILICO composition of two existing "
                "axis sims (ppi_sim + allosteric_sim) for the single "
                "FDA-approved CDER small molecule that maps cleanly "
                "onto in-repo axes for SCD: voxelotor (Oxbryta, FDA "
                "2019). Voxelotor uniquely carries a DUAL axis "
                "mapping — its mechanism is simultaneously a PPI "
                "disruption (HbS-HbS deoxy-polymer contact at the "
                "α-chain N-terminal patch — primary) and a pure-MWC "
                "allosteric R/T modulation (secondary). The dual "
                "mapping is recorded structurally via an "
                "`axis_mappings` LIST. Two CDER-in-scope drugs whose "
                "mechanisms do not map onto current in-repo axes "
                "(hydroxyurea, L-glutamine) are recorded structurally "
                "in `cder_in_scope_no_axis_mapping` — honest coverage "
                "facts, not failures. Three CBER drugs (Casgevy, "
                "Lyfgenia, crizanlizumab) are recorded as UNPLACED in "
                "`not_in_scope_drugs` per criterion #4 drug-only/"
                "CDER discipline — same pattern as the Zolgensma row "
                "in the SMA portfolio. NEVER a therapeutic / "
                "clinical / efficacy / regulatory / portfolio-"
                "recommendation claim (g8 / f2). Each drug is "
                "described by its OWN published precedent (g3 / f1) "
                "— nothing is derived from the n=6 lattice "
                "(f_lattice_fit). Scope = one-disease pilot, NOT the "
                "200-disease deferred re-mapping."
            ),
        },
        "acceptance": acc,
        "sentinel": (SENTINEL_PASS if acc["verdict"] == "PASS"
                     else SENTINEL_FAIL),
    }


# ── CLI ───────────────────────────────────────────────────────────────
def main() -> int:
    print("sickle_cell_portfolio_runner — SCD portfolio case study "
          "(one-disease pilot)\n", flush=True)
    print("  IN-SCOPE  (CDER, axis-mapped — DUAL mapping)")
    print("    voxelotor (Oxbryta, FDA 2019)")
    print("      → PPI (primary)         :> QUANTUM   "
          "[Bogan & Thorn 1998]")
    print("      → ALLOSTERIC (secondary):> QUANTUM   [MWC 1965]")
    print()
    print("  CDER-IN-SCOPE-NO-AXIS  (CDER, mechanism not axis-mapped)")
    print("    hydroxyurea (Hydrea/Droxia/Siklos, FDA 1998 for SCD)")
    print("    L-glutamine (Endari, FDA 2017)")
    print()
    print("  CBER UNPLACED  (criterion #4 disqualified)")
    print("    exa-cel (Casgevy, FDA 2023) — CRISPR gene editing")
    print("    lovo-cel (Lyfgenia, FDA 2023) — lentiviral gene therapy")
    print("    crizanlizumab (Adakveo, FDA 2019) — anti-P-selectin mAb")
    print("        [regulatory complexity: EMA revoked 2023; FDA "
          "approval intact through 2024]\n", flush=True)

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
    print("  remains deferred per AXIS/HIERARCHY.tape Log. CDER-no-axis "
          "and CBER-UNPLACED categories listed honestly via")
    print("  structurally-distinct schema fields.\n")

    # Determinism cross-check: re-run produces byte-identical JSON.
    a = json.dumps(build_witness(), sort_keys=True)
    b = json.dumps(build_witness(), sort_keys=True)
    print(f"  [determinism] byte-identical re-run: {a == b}\n")

    print("## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
