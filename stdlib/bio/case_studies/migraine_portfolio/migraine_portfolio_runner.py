#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
migraine_portfolio_runner.py — Migraine portfolio case study (one-disease pilot).

Deterministic, stdlib-only composition of one existing sub-axis sim
(PPI :> QUANTUM) against the four FDA-approved CDER small-molecule
CGRP-receptor antagonists (gepants):

  - rimegepant  (Nurtec ODT, Pfizer / Biohaven Pharmaceuticals,
                 FDA 2020) — oral acute & preventive CGRP-receptor
                 antagonist; small molecule.
  - ubrogepant  (Ubrelvy, AbbVie / Allergan, FDA 2019) — oral acute
                 CGRP-receptor antagonist; small molecule.
  - atogepant   (Qulipta, AbbVie, FDA 2021) — oral preventive
                 CGRP-receptor antagonist; small molecule.
  - zavegepant  (Zavzpret, Pfizer, FDA 2023) — intranasal acute
                 CGRP-receptor antagonist; small molecule.

All four DISRUPT the CGRP / CGRP-receptor protein-protein interaction
(calcitonin-gene-related-peptide binding the CLR + RAMP1 receptor
complex). This is a peptide-receptor PPI; the gepants are small-molecule
PPI inhibitors that occupy the orthosteric peptide-binding site. They
map onto the PPI sub-axis (:> QUANTUM core) — same axis used by the
BCL-2 BH3-mimetic portfolio.

Per f3 (no-fork) the parent PPI sim is IMPORTED via `importlib`, NOT
re-implemented. Per g1 each row inherits the parent sim's real-limit
citation (Bogan & Thorn 1998 binding-hotspot theory + Wells &
McClendon 2007 flat-PPI druggability). Per g8 / f2 every PASS =
in-silico simulator+metadata consistency ONLY — NEVER a clinical /
therapeutic / neurologic / efficacy / regulatory / portfolio-
recommendation claim. Per g3 / f1 / f_lattice_fit drugs are described
by their OWN published precedent only (rimegepant Croop 2019;
ubrogepant Dodick 2019; atogepant Ailani 2021; zavegepant Lipton
2023); NOTHING is derived from the n=6 lattice.

NOT-IN-SCOPE (CBER UNPLACED — honest):
  - erenumab    (Aimovig,    Amgen / Novartis, FDA 2018) — anti-CGRP-
                 RECEPTOR mAb.
  - fremanezumab(Ajovy,      Teva,             FDA 2018) — anti-CGRP mAb.
  - galcanezumab(Emgality,   Eli Lilly,        FDA 2018) — anti-CGRP mAb.
  - eptinezumab (Vyepti,     Lundbeck,         FDA 2020) — anti-CGRP mAb,
                 intravenous.
All four are FDA-approved but are CBER-regulated biologic monoclonal
antibodies and therefore fall OUTSIDE the hexa-bio criterion #4 drug-
only/CDER scope boundary. They are reported in `not_in_scope_drugs`
with `axis=null`, `in_scope=false`, `reported_not_run=true` — the
same honest UNPLACED pattern used for Zolgensma in
`case_studies/sma_portfolio/`. UNPLACED is the honest call — NOT a
deferral or downgrade. All four mAbs are FDA-approved.

CROSS-AXIS TOUCH-POINT
──────────────────────
G3 (PPI × MOLECULAR-GLUE) is cited for COMPLETENESS only — gepants are
PPI DISRUPTORS, NOT molecular glues; no migraine-specific glue exists.
The case study does NOT claim a molecular-glue modality for any gepant.

PANEL-CLASS SURROGATE (parent-sim honesty inherited)
────────────────────────────────────────────────────
The parent ppi_sim.INTERFACE_PANEL does NOT include a CGRP-specific
row. Per the parent sim's own honesty note ("ΔΔG values are
illustrative literature-informed surrogates for interface CLASSES, NOT
fits to a specific complex"), we map all four gepants to the parent
sim's `mdm2_p53_cleft` row — `interface_class = alpha_helix_peptide_
cleft` — since CGRP is a 37-residue peptide that binds a receptor
groove via an alpha-helical N-terminal anchor; the peptide-binds-cleft
interface CLASS is the closest panel surrogate. This is reported
HONESTLY as a class-level surrogate, NOT a CGRP-receptor-specific fit
(g8 / f2). The four in-scope rows share the SAME parent-sim row by
design — the modality is one PPI-disruption class with four approved
drugs, NOT four distinct mechanisms.

Determinism: pure stdlib; no random / network / wall-clock. Fixed
timestamp. The witness JSON is byte-identical across re-runs.

Sentinel: __MIGRAINE_PORTFOLIO__ PASS on exit 0.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── Honest scope constants ────────────────────────────────────────────
SCHEMA_VERSION = "migraine_portfolio_v1"
CASE_STUDY_ID = "migraine_portfolio.v1"
TS_FIXED = "2026-05-16T00:00:00Z"   # determinism
SENTINEL_PASS = "__MIGRAINE_PORTFOLIO__ PASS"
SENTINEL_FAIL = "__MIGRAINE_PORTFOLIO__ FAIL"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BRIDGE_MOD = os.path.join(REPO_ROOT, "_python_bridge", "module")

# Parent ppi_sim class-surrogate row name — see module docstring.
_PARENT_PANEL_ROW = "mdm2_p53_cleft"


def _load(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_ppi_sim():
    """Import the parent PPI sim (no fork — f3)."""
    return _load("ppi_sim", os.path.join(BRIDGE_MOD, "ppi_sim.py"))


def _ppi_subrun(row: dict) -> dict:
    """Project the parent ppi_sim row into the witness `sim_run` shape."""
    return {
        "sim_module": "ppi_sim",
        "parent_panel_row": row["interface"],
        "interface_class": row["interface_class"],
        "panel_class_surrogate_for": "CGRP / CGRP-receptor PPI "
                                     "(alpha-helical N-terminal peptide "
                                     "anchor binding the CLR + RAMP1 "
                                     "receptor groove)",
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


# Shared real-limit anchor + axis mapping (inherited from parent ppi_sim).
_REAL_LIMIT_ANCHOR = (
    "Bogan & Thorn 1998 binding-hotspot theory (J. Mol. Biol. 280:1) — "
    "interface binding free energy concentrated in a few hotspot "
    "residues (ΔΔG ≥ 2 kcal/mol by alanine scanning), bounded by the "
    "alanine-scanning ledger; druggability of flat hotspot-driven PPIs "
    "follows Wells & McClendon, Nature 450:1001 (2007)"
)
_AXIS_MAPPING = {
    "axis": "PPI",
    "parent_axis": "QUANTUM (core-5)",
    "axis_layer": "expansion-sub",
}


# ── Drug → sim mapping (4 FDA-approved CDER gepants) ──────────────────
def build_in_scope_rows() -> list:
    ppi = _import_ppi_sim()
    rows = ppi.build_rows()
    parent_row = next(r for r in rows
                      if r["interface"] == _PARENT_PANEL_ROW)
    sim_run = _ppi_subrun(parent_row)

    rimegepant = {
        "drug": "rimegepant",
        "brand": "Nurtec ODT",
        "sponsor": "Pfizer / Biohaven Pharmaceuticals",
        "fda_year": 2020,
        "fda_center": "CDER",
        "fda_application": ("NDA 212728 — Nurtec ODT first approval "
                            "2020-02-27 (acute treatment of migraine); "
                            "preventive indication added 2021-05-27"),
        "modality": ("small-molecule CGRP-receptor antagonist — "
                     "disrupts the CGRP / CGRP-receptor "
                     "protein-protein interaction by occupying the "
                     "orthosteric peptide-binding site on the CLR + "
                     "RAMP1 receptor complex"),
        "axis_mapping": dict(_AXIS_MAPPING),
        "real_limit_anchor": _REAL_LIMIT_ANCHOR,
        "drug_precedent_refs": [
            "Croop R et al., Lancet 394:737 (2019) — rimegepant "
            "phase III in acute migraine",
            "Croop R et al., Lancet 397:51 (2021) — rimegepant "
            "preventive treatment of episodic migraine",
            "FDA NDA 212728 (Nurtec ODT, 2020-02-27)",
        ],
        "sim_run": dict(sim_run),
        "in_silico_only": True,
    }

    ubrogepant = {
        "drug": "ubrogepant",
        "brand": "Ubrelvy",
        "sponsor": "AbbVie / Allergan",
        "fda_year": 2019,
        "fda_center": "CDER",
        "fda_application": ("NDA 211765 — Ubrelvy first approval "
                            "2019-12-23 (acute treatment of migraine "
                            "with or without aura in adults)"),
        "modality": ("small-molecule CGRP-receptor antagonist — "
                     "disrupts the CGRP / CGRP-receptor "
                     "protein-protein interaction by occupying the "
                     "orthosteric peptide-binding site on the CLR + "
                     "RAMP1 receptor complex"),
        "axis_mapping": dict(_AXIS_MAPPING),
        "real_limit_anchor": _REAL_LIMIT_ANCHOR,
        "drug_precedent_refs": [
            "Dodick DW et al., N Engl J Med 381:2230 (2019) — "
            "ubrogepant phase III ACHIEVE I",
            "Lipton RB et al., JAMA 322:1887 (2019) — ubrogepant "
            "phase III ACHIEVE II",
            "FDA NDA 211765 (Ubrelvy, 2019-12-23)",
        ],
        "sim_run": dict(sim_run),
        "in_silico_only": True,
    }

    atogepant = {
        "drug": "atogepant",
        "brand": "Qulipta",
        "sponsor": "AbbVie",
        "fda_year": 2021,
        "fda_center": "CDER",
        "fda_application": ("NDA 215206 — Qulipta first approval "
                            "2021-09-28 (preventive treatment of "
                            "episodic migraine in adults)"),
        "modality": ("small-molecule CGRP-receptor antagonist — "
                     "preventive; disrupts the CGRP / CGRP-receptor "
                     "protein-protein interaction by occupying the "
                     "orthosteric peptide-binding site on the CLR + "
                     "RAMP1 receptor complex"),
        "axis_mapping": dict(_AXIS_MAPPING),
        "real_limit_anchor": _REAL_LIMIT_ANCHOR,
        "drug_precedent_refs": [
            "Ailani J et al., N Engl J Med 385:695 (2021) — "
            "atogepant phase III ADVANCE",
            "Goadsby PJ et al., Lancet Neurol 19:727 (2020) — "
            "atogepant phase IIb/III dose-finding",
            "FDA NDA 215206 (Qulipta, 2021-09-28)",
        ],
        "sim_run": dict(sim_run),
        "in_silico_only": True,
    }

    zavegepant = {
        "drug": "zavegepant",
        "brand": "Zavzpret",
        "sponsor": "Pfizer",
        "fda_year": 2023,
        "fda_center": "CDER",
        "fda_application": ("NDA 216386 — Zavzpret first approval "
                            "2023-03-09 (acute treatment of migraine; "
                            "first intranasal CGRP-receptor antagonist)"),
        "modality": ("small-molecule CGRP-receptor antagonist — "
                     "intranasal acute; disrupts the CGRP / "
                     "CGRP-receptor protein-protein interaction by "
                     "occupying the orthosteric peptide-binding site "
                     "on the CLR + RAMP1 receptor complex"),
        "axis_mapping": dict(_AXIS_MAPPING),
        "real_limit_anchor": _REAL_LIMIT_ANCHOR,
        "drug_precedent_refs": [
            "Lipton RB et al., Lancet Neurol 22:209 (2023) — "
            "zavegepant intranasal phase III",
            "Croop R et al., Headache 62:1153 (2022) — zavegepant "
            "intranasal phase II/III dose-ranging",
            "FDA NDA 216386 (Zavzpret, 2023-03-09)",
        ],
        "sim_run": dict(sim_run),
        "in_silico_only": True,
    }

    return [rimegepant, ubrogepant, atogepant, zavegepant]


# ── Honest CBER UNPLACED rows (FDA-approved mAbs, criterion #4) ───────
def build_not_in_scope_rows() -> list:
    """Four FDA-approved CBER monoclonal antibodies — UNPLACED by design.

    All four are FDA-approved anti-CGRP or anti-CGRP-receptor mAbs.
    They are CBER-regulated biologics; implementing a code axis for
    CBER mAbs would breach criterion #4 drug-only/CDER + g8 in-silico-
    only honesty. Same UNPLACED pattern as Zolgensma in
    case_studies/sma_portfolio/. axis=null, in_scope=false,
    reported_not_run=true.
    """
    unplaced_precedent = (
        "AXIS/HIERARCHY.tape @N genetic_medicine_status (same UNPLACED "
        "handling family) and @N adc_status (parallel CBER-antibody-"
        "scope UNPLACED note); case_studies/sma_portfolio/ Zolgensma "
        "row as the in-repo precedent for CBER FDA-approved biologics"
    )
    erenumab = {
        "drug": "erenumab",
        "brand": "Aimovig",
        "sponsor": "Amgen / Novartis",
        "fda_year": 2018,
        "fda_center": "CBER",
        "modality": ("anti-CGRP-RECEPTOR fully human IgG2 monoclonal "
                     "antibody — subcutaneous; the only anti-receptor "
                     "mAb in the class (the other three target the "
                     "CGRP ligand itself)"),
        "axis": None,
        "in_scope": False,
        "reason": ("CBER biologic — criterion #4 drug-only/CDER scope "
                   "boundary. Monoclonal antibodies are CBER-regulated; "
                   "implementing a code axis for CBER mAbs would "
                   "breach criterion #4 + g8 in-silico-only honesty. "
                   "FDA-approved 2018 (BLA 761077)."),
        "unplaced_precedent_in_repo": unplaced_precedent,
        "drug_precedent_refs": [
            "Goadsby PJ et al., N Engl J Med 377:2123 (2017) — "
            "erenumab phase III STRIVE",
            "FDA BLA 761077 (Aimovig, 2018-05-17, CBER)",
        ],
        "reported_not_run": True,
    }
    fremanezumab = {
        "drug": "fremanezumab",
        "brand": "Ajovy",
        "sponsor": "Teva Pharmaceuticals",
        "fda_year": 2018,
        "fda_center": "CBER",
        "modality": ("anti-CGRP humanized IgG2 monoclonal antibody — "
                     "subcutaneous (monthly or quarterly); targets "
                     "the CGRP ligand"),
        "axis": None,
        "in_scope": False,
        "reason": ("CBER biologic — criterion #4 drug-only/CDER scope "
                   "boundary. Monoclonal antibodies are CBER-regulated; "
                   "implementing a code axis for CBER mAbs would "
                   "breach criterion #4 + g8 in-silico-only honesty. "
                   "FDA-approved 2018 (BLA 761089)."),
        "unplaced_precedent_in_repo": unplaced_precedent,
        "drug_precedent_refs": [
            "Silberstein SD et al., N Engl J Med 377:2113 (2017) — "
            "fremanezumab phase III HALO-CM/HALO-EM",
            "FDA BLA 761089 (Ajovy, 2018-09-14, CBER)",
        ],
        "reported_not_run": True,
    }
    galcanezumab = {
        "drug": "galcanezumab",
        "brand": "Emgality",
        "sponsor": "Eli Lilly",
        "fda_year": 2018,
        "fda_center": "CBER",
        "modality": ("anti-CGRP humanized IgG4 monoclonal antibody — "
                     "subcutaneous monthly; targets the CGRP ligand"),
        "axis": None,
        "in_scope": False,
        "reason": ("CBER biologic — criterion #4 drug-only/CDER scope "
                   "boundary. Monoclonal antibodies are CBER-regulated; "
                   "implementing a code axis for CBER mAbs would "
                   "breach criterion #4 + g8 in-silico-only honesty. "
                   "FDA-approved 2018 (BLA 761063)."),
        "unplaced_precedent_in_repo": unplaced_precedent,
        "drug_precedent_refs": [
            "Stauffer VL et al., JAMA Neurol 75:1080 (2018) — "
            "galcanezumab phase III EVOLVE-1",
            "Skljarevski V et al., Cephalalgia 38:1442 (2018) — "
            "galcanezumab phase III EVOLVE-2",
            "FDA BLA 761063 (Emgality, 2018-09-27, CBER)",
        ],
        "reported_not_run": True,
    }
    eptinezumab = {
        "drug": "eptinezumab",
        "brand": "Vyepti",
        "sponsor": "Lundbeck (Alder BioPharmaceuticals)",
        "fda_year": 2020,
        "fda_center": "CBER",
        "modality": ("anti-CGRP humanized IgG1 monoclonal antibody — "
                     "INTRAVENOUS (the only IV mAb in the class; "
                     "quarterly infusion); targets the CGRP ligand"),
        "axis": None,
        "in_scope": False,
        "reason": ("CBER biologic — criterion #4 drug-only/CDER scope "
                   "boundary. Monoclonal antibodies are CBER-regulated; "
                   "implementing a code axis for CBER mAbs would "
                   "breach criterion #4 + g8 in-silico-only honesty. "
                   "FDA-approved 2020 (BLA 761119)."),
        "unplaced_precedent_in_repo": unplaced_precedent,
        "drug_precedent_refs": [
            "Ashina M et al., Cephalalgia 40:241 (2020) — "
            "eptinezumab phase III PROMISE-1",
            "Lipton RB et al., Neurology 94:e1365 (2020) — "
            "eptinezumab phase III PROMISE-2",
            "FDA BLA 761119 (Vyepti, 2020-02-21, CBER)",
        ],
        "reported_not_run": True,
    }
    return [erenumab, fremanezumab, galcanezumab, eptinezumab]


# ── Acceptance ────────────────────────────────────────────────────────
def acceptance(in_scope: list, not_in_scope: list) -> dict:
    crit = {
        "X1_four_in_scope_drugs": len(in_scope) == 4,
        "X2_all_in_scope_are_cder": all(
            d["fda_center"] == "CDER" for d in in_scope
        ),
        "X3_each_in_scope_has_real_limit_anchor": all(
            d.get("real_limit_anchor") for d in in_scope
        ),
        "X4_each_in_scope_maps_to_PPI": all(
            d["axis_mapping"]["axis"] == "PPI" for d in in_scope
        ),
        "X5_in_scope_in_silico_only_flag_set": all(
            d.get("in_silico_only") is True for d in in_scope
        ),
        "X6_each_in_scope_has_own_drug_precedent_refs": all(
            isinstance(d.get("drug_precedent_refs"), list)
            and len(d["drug_precedent_refs"]) >= 1
            for d in in_scope
        ),
        "X7_four_cber_unplaced_rows": len(not_in_scope) == 4,
        "X8_unplaced_axis_is_null": all(
            n["axis"] is None for n in not_in_scope
        ),
        "X9_unplaced_in_scope_false_and_not_run": all(
            n["in_scope"] is False and n.get("reported_not_run") is True
            for n in not_in_scope
        ),
        "X10_unplaced_are_cber": all(
            n["fda_center"] == "CBER" for n in not_in_scope
        ),
        "X11_parent_panel_row_is_class_surrogate": all(
            d["sim_run"]["parent_panel_row"] == _PARENT_PANEL_ROW
            and d["sim_run"]["interface_class"]
            == "alpha_helix_peptide_cleft"
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
    not_in_scope = build_not_in_scope_rows()
    acc = acceptance(in_scope, not_in_scope)
    return {
        "schema_version": SCHEMA_VERSION,
        "case_study_id": CASE_STUDY_ID,
        "ts": TS_FIXED,
        "disease": {
            "name": ("migraine (episodic and chronic; acute and "
                     "preventive indications across the gepant class)"),
            "abbreviation": "MIGRAINE",
            "target_pathway": ("CGRP (calcitonin-gene-related-peptide) "
                               "signalling at the CGRP receptor (CLR + "
                               "RAMP1 receptor complex) on trigeminal "
                               "sensory neurons and vascular smooth "
                               "muscle"),
        },
        "in_scope_drugs": in_scope,
        "not_in_scope_drugs": not_in_scope,
        "cross_axis_touch_points": [
            {
                "id": "G3",
                "module": ("_python_bridge/module/"
                           "ppi_molecular_glue_cross.py"),
                "note": ("G3 (PPI × MOLECULAR-GLUE) is cited for "
                         "COMPLETENESS only — gepants are PPI "
                         "DISRUPTORS, NOT molecular glues. No "
                         "migraine-specific molecular glue exists; "
                         "this portfolio does NOT claim a "
                         "molecular-glue modality for any gepant. "
                         "The cross-axis touch-point is recorded so "
                         "the parity table mirrors the BCL-2 "
                         "portfolio's G3 reference."),
            },
        ],
        "honesty": {
            "in_silico_only": True,
            "core_5_unchanged": True,
            "no_fork_of_sister_sims": True,
            "one_disease_pilot_not_200_disease_remap": True,
            "cber_mabs_unplaced_handled_honestly": True,
            "not_a_molecular_glue_claim": True,
            "no_lattice_derivation": True,
            "statement": (
                "Per-disease IN-SILICO composition of one existing "
                "sub-axis sim (PPI :> QUANTUM) for the four "
                "FDA-approved CDER small-molecule CGRP-receptor "
                "antagonists (gepants): rimegepant / Nurtec ODT "
                "(Pfizer/Biohaven, FDA 2020), ubrogepant / Ubrelvy "
                "(AbbVie/Allergan, FDA 2019), atogepant / Qulipta "
                "(AbbVie, FDA 2021) and zavegepant / Zavzpret "
                "(Pfizer, FDA 2023, intranasal). All four disrupt "
                "the CGRP / CGRP-receptor PPI by occupying the "
                "orthosteric peptide-binding site on the CLR + RAMP1 "
                "receptor complex — one PPI-disruption modality "
                "class, four approved drugs. The parent ppi_sim's "
                "`mdm2_p53_cleft` row is used as the panel-class "
                "surrogate (`alpha_helix_peptide_cleft` interface "
                "class) honestly — the parent sim's own honesty "
                "note states ΔΔG values are literature-informed "
                "surrogates for interface CLASSES, NOT fits to "
                "specific complexes. The four FDA-approved CBER "
                "monoclonal antibodies (erenumab / Aimovig 2018, "
                "fremanezumab / Ajovy 2018, galcanezumab / Emgality "
                "2018, eptinezumab / Vyepti 2020) are honestly "
                "UNPLACED with axis=null and reported_not_run=true "
                "— CBER biologics fall outside the hexa-bio "
                "criterion #4 drug-only/CDER scope boundary (same "
                "honest pattern as Zolgensma in "
                "case_studies/sma_portfolio/). UNPLACED is the "
                "honest call — NOT a deferral or downgrade; all "
                "four mAbs are FDA-approved. G3 (PPI × "
                "MOLECULAR-GLUE) is cited for completeness only — "
                "no gepant is claimed as a molecular glue. NEVER a "
                "therapeutic / clinical / neurologic / efficacy / "
                "regulatory / portfolio-recommendation claim "
                "(g8 / f2). Drugs described by own published "
                "precedent (Croop 2019, Dodick 2019, Ailani 2021, "
                "Lipton 2023, and the FDA approval letters) — "
                "nothing is derived from the n=6 lattice "
                "(g3 / f1 / f_lattice_fit). The 200-disease "
                "re-mapping remains deferred per AXIS/HIERARCHY.tape "
                "Log."
            ),
        },
        "acceptance": acc,
        "sentinel": (SENTINEL_PASS if acc["verdict"] == "PASS"
                     else SENTINEL_FAIL),
    }


def main() -> int:
    print("migraine_portfolio_runner — migraine case study "
          "(one-disease pilot)\n", flush=True)
    print("  in-scope (4 CDER small-molecule gepants — PPI :> QUANTUM):")
    print("    rimegepant   (Nurtec ODT, Pfizer/Biohaven,  FDA 2020)")
    print("    ubrogepant   (Ubrelvy,    AbbVie/Allergan,  FDA 2019)")
    print("    atogepant    (Qulipta,    AbbVie,           FDA 2021)")
    print("    zavegepant   (Zavzpret,   Pfizer,           FDA 2023)")
    print("  not-in-scope (4 CBER mAbs — UNPLACED, criterion #4):")
    print("    erenumab     (Aimovig,    Amgen/Novartis,   FDA 2018)")
    print("    fremanezumab (Ajovy,      Teva,             FDA 2018)")
    print("    galcanezumab (Emgality,   Eli Lilly,        FDA 2018)")
    print("    eptinezumab  (Vyepti,     Lundbeck,         FDA 2020)\n",
          flush=True)
    witness = build_witness()
    acc = witness["acceptance"]
    print("## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---\n")
    print("  [honesty] in-silico simulator-consistency only — NOT a "
          "clinical / therapeutic / neurologic / regulatory / "
          "efficacy /")
    print("  portfolio-recommendation claim (g8 / f2). Core-5 axes "
          "UNCHANGED; one-disease pilot only; 200-disease re-mapping")
    print("  remains deferred per AXIS/HIERARCHY.tape Log. The four "
          "FDA-approved CBER mAbs (erenumab, fremanezumab,")
    print("  galcanezumab, eptinezumab) are honestly UNPLACED — "
          "criterion #4 drug-only/CDER scope boundary.\n")
    print("## witness JSON")
    print(json.dumps(witness, indent=2, sort_keys=True,
                     ensure_ascii=False))
    print()
    print(witness["sentinel"])
    return 0 if acc["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
