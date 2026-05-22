#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oligonucleotide_ribotac_cross.py — CROSS-AXIS W3.

  CROSS:  OLIGONUCLEOTIDE expansion-axis  ──[same RNA-target CLASS]──  RIBOTAC sub-axis
          (ASO / siRNA hybridization)                                  (RNase-L recruitment)

  Same RNA-target CLASS    : both modalities target RNA
  OPPOSITE turnover REGIME : STOICHIOMETRIC      ≠      CATALYTIC (multi-turnover)
                             N_RNA_blocked  =  N_ASO         N_RNA_cleaved = k_cat · t_exposure
                             one ASO blocks one transcript   one RIBOTAC turns over many RNA
                             ASO consumed (RNase-H or steric)recruited RNase-L cleaves and releases
                             SantaLucia NN ΔG° / Tm         mass-action ternary + catalytic N>1

This module DEMONSTRATES the cross — it does NOT collapse one regime into
the other. The two regimes are turnover-disjoint; the cross consists of
running both side-by-side on a single deterministic panel of RNA targets,
and emitting a comparison table that makes the disjointness explicit.

────────────────────────────────────────────────────────────────────────────
WHAT IS COMPUTED  (governance f3 — both parents imported, neither forked)
────────────────────────────────────────────────────────────────────────────
Both parent simulators are IMPORTED, never reimplemented:

  (a) OLIGONUCLEOTIDE path  —  `oligonucleotide_hybridization_sim`.
      For each RNA target we design the ASO as the reverse complement of a
      deterministic window of the target and call the parent module's
      `duplex_report(aso)` (SantaLucia 1998 unified NN ΔH°/ΔS°/ΔG°(37) and
      van 't Hoff two-state Tm). The TURNOVER REGIME is STOICHIOMETRIC:
      one ASO molecule blocks at most one transcript (RNase-H cleaves the
      hybrid and the ASO is sequestered; or the ASO sterically blocks
      ribosome / splicesome at one site per transcript copy). Under that
      regime, N_RNA_blocked = N_ASO_molecules — a 1-to-1 ceiling.

  (b) RIBOTAC path        —  `ribotac_sim`.
      For the same RNA target we call the parent module's
      `rna_structuredness(seq)` (which itself imports the parent RIBOZYME-
      axis Nussinov solver — f3 respected at one further remove),
      `ternary_fraction(...)` (mass-action ternary-complex occupancy of
      Target·R·RNase-L), and `catalytic_advantage(k_cat, t_exposure)`
      (multiple-turnover number N = k_cat · t_exposure). The TURNOVER
      REGIME is CATALYTIC: one RIBOTAC molecule licenses many cleavage
      events; N_RNA_cleaved = k_cat · t_exposure (>> 1 for a real RIBOTAC).

The panel below contains 4 structured RNA targets that BOTH modalities can
in principle address — making the side-by-side fair while leaving the
turnover-regime disagreement explicit.

────────────────────────────────────────────────────────────────────────────
REAL-LIMIT ANCHORS  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The cross is anchored to TWO independent real limits, one per regime
(neither derived from the n=6 lattice — g2 / f1 / f_lattice_fit):

  (1) NEAREST-NEIGHBOR HYBRIDIZATION THERMODYNAMICS  ←  OLIGONUCLEOTIDE path
      Duplex stability is bounded by base-pair stacking free energy — an
      ASO cannot hybridize its RNA target more stably than the NN
      free-energy sum of the paired stretch allows. Anchor:
        - SantaLucia J Jr. "A unified view of polymer, dumbbell, and
          oligonucleotide DNA nearest-neighbor thermodynamics." Proc Natl
          Acad Sci USA 1998;95(4):1460-1465.  (The 10 unified NN ΔH°/ΔS°
          parameters + van 't Hoff Tm.)

  (2) CATALYTIC MULTIPLE-TURNOVER + MASS-ACTION  ←  RIBOTAC path
      A genuine catalyst has turnover number N > 1 (a stoichiometric binder
      has N = 1 by definition); the bifunctional small molecule recruits
      endogenous RNase-L to a structured RNA so the recruited nuclease
      cleaves the target catalytically. Anchors:
        - Costales MG, Matsumoto Y, Velagapudi SP, Disney MD.  Small-
          molecule targeted recruitment of a nuclease to cleave an
          oncogenic RNA in a mouse model of metastatic cancer.  J Am Chem
          Soc 2018;140:6741-6744.  (First RNase-L-recruiting RIBOTAC.)
        - Costales MG, Aikawa H, Li Y, et al.  Small-molecule targeted
          recruitment of a nuclease to cleave pre-miR-21 to block
          proliferation.  Proc Natl Acad Sci USA 2020;117:2406-2411.
        - Cornish-Bowden A.  Fundamentals of Enzyme Kinetics, 4th ed.
          (Wiley-Blackwell, 2012).  Closed-form catalytic-turnover limit
          N > 1 ≡ catalytic.
        - Guldberg & Waage 1864 — mass-action law; bound fractions ≤ 1.0.

────────────────────────────────────────────────────────────────────────────
OWN-PRECEDENT MODALITIES  (g3 / f1 / f_lattice_fit — never lattice-derived)
────────────────────────────────────────────────────────────────────────────
  OLIGONUCLEOTIDE : described by its own approved drug precedent —
      nusinersen / Spinraza (ASO, intrathecal SMN2 splice-switching, FDA
      2016), patisiran / Onpattro (siRNA, hereditary ATTR amyloidosis, FDA
      2018), inclisiran / Leqvio (siRNA, hypercholesterolemia, FDA 2021).
      Three FDA-approved drugs across two oligo modalities (ASO and siRNA)
      — well-attested clinical precedent for the modality. No quantity in
      the oligonucleotide rows is derived from the n=6 lattice.

  RIBOTAC : described by its own published modality precedent — the
      Disney-lab RIBOnuclease-TArgeting Chimeras that recruit RNase-L to
      disease RNAs (Costales JACS 2018; PNAS 2020). RIBOTAC is RESEARCH-
      STAGE: no RIBOTAC is an approved drug. Nothing here is lattice-
      derived.

────────────────────────────────────────────────────────────────────────────
HONESTY — COMPARISON ≠ RANKING  (g3 / g8 / f2 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
Same RNA-target CLASS ≠ same turnover REGIME.

  Stoichiometric ASO        (OLIGONUCLEOTIDE)
      = Watson-Crick duplex with the RNA, then RNase-H cleaves the
        hybrid (gapmer ASO) OR the ASO sterically blocks splicing /
        translation. The ASO is consumed / sequestered after acting.
        One ASO molecule blocks at most one transcript copy.

  Catalytic RIBOTAC          (RIBOTAC)
      = a bifunctional small molecule licenses endogenous RNase-L to
        cleave a structured RNA target catalytically. The RIBOTAC is
        RELEASED after each cleavage and can recruit RNase-L to a fresh
        target. One RIBOTAC molecule licenses N = k_cat · t_exposure
        cleavages (>> 1 for a real RIBOTAC).

These two pathways act on the SAME RNA-TARGET CLASS but DISAGREE on the
TURNOVER REGIME: stoichiometric ≠ catalytic. The two model signals are
NOT commensurable: the OLIGONUCLEOTIDE row reports Tm in °C + N_blocked
(stoichiometric ceiling); the RIBOTAC row reports K_d in nM + N_cleaved
(catalytic multi-turnover). Different units on different real limits.

This is a DESCRIPTIVE side-by-side, NEVER a ranking. Nusinersen /
patisiran / inclisiran (FDA-approved ASO and siRNA drugs) and Disney-
lab RIBOTACs (research-stage, NO FDA-approved RIBOTAC) are NOT competing
modalities to be ranked in this module — they target different RNA
biology questions (e.g. splice-switching / steady-state knockdown of
intronic or coding mRNA regions vs catalytic cleavage of a structured
non-coding RNA such as pre-miR-21). Comparison ≠ ranking.

The PASS sentinel certifies IN-SILICO simulator+metadata internal
consistency ONLY (g8 / f2): that the two pathway models run, produce
well-formed rows, and reproduce byte-identically. It is NOT a
therapeutic, clinical, knockdown, efficacy, immunogenic, regulatory,
or modality-superiority claim. The OLIGONUCLEOTIDE axis is described
solely via FDA-approved drug precedent; RIBOTAC is RESEARCH-STAGE (no
approved RIBOTAC). The wet-lab boundary is out of repo scope
(CLOSURE_RESIDUAL_BACKLOG.md §0).

────────────────────────────────────────────────────────────────────────────
CROSS ≠ NEW AXIS, NO FORK, STDLIB-ONLY
────────────────────────────────────────────────────────────────────────────
  - core-5 axes (QUANTUM / WEAVE / NANOBOT / RIBOZYME / VIROCAPSID) are
    UNCHANGED by this cross.
  - This file IMPORTS both parent sims; it does NOT fork either of them
    (governance f3). All chemistry / thermodynamics is delegated to the
    parents.
  - Pure stdlib (json, importlib, os, sys). No network, no random, no
    wall-clock. Byte-identical re-runs.

Sentinel:  __OLIGONUCLEOTIDE_RIBOTAC_CROSS__ PASS   (or FAIL).
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate sibling parent sims ─────────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_OLIGO_PATH = os.path.join(_HERE, "oligonucleotide_hybridization_sim.py")
_RIBOTAC_PATH = os.path.join(_HERE, "ribotac_sim.py")

SCHEMA_ID = "oligonucleotide_ribotac_cross_v1"
SENTINEL_PASS = "__OLIGONUCLEOTIDE_RIBOTAC_CROSS__ PASS"
SENTINEL_FAIL = "__OLIGONUCLEOTIDE_RIBOTAC_CROSS__ FAIL"


def _load_module(name: str, path: str):
    """importlib loader — no shadow reimplementation (governance f3).

    Ensure ribotac_sim's own sibling import (ribozyme_mfe_nussinov)
    resolves: put the module dir on sys.path.
    """
    if _HERE not in sys.path:
        sys.path.insert(0, _HERE)
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── deterministic cross panel ─────────────────────────────────────────────
#
# Each entry is a structured RNA target both modalities can in principle
# address.  The ASO window (start, length) selects the contiguous region of
# the RNA target the antisense oligonucleotide is complementary to — its
# reverse complement (DNA-alphabet, U->T handled by the parent NN engine)
# is the ASO sequence used in the OLIGONUCLEOTIDE row.  The
# `ribotac_panel_index` parameterises the RIBOTAC row from the parent
# module's RIBOTAC_PANEL (K_d1, K_d2, alpha, k_cat, t_exposure, precedent).
#
# Fields:
#   name                 : panel identifier
#   rna_target_class     : human-readable shared RNA-target class
#   rna_seq              : RNA sequence (A/C/G/U)
#   aso_window           : (start, length) of the ASO-complementary region
#   n_aso_molecules      : illustrative ASO molecule count for the
#                          stoichiometric N_blocked ceiling
#   ribotac_panel_index  : which of ribotac_sim.RIBOTAC_PANEL parameterises
#                          the RNase-L recruitment for this target
#
_CROSS_PANEL = [
    {
        "name": "premiR21_like_strong",
        "rna_target_class": "structured non-coding RNA — pre-miRNA hairpin",
        "rna_seq": "GGGAAACCCUUUGGGAAACCCUUUGGG",
        "aso_window": (0, 20),
        "n_aso_molecules": 100,
        "ribotac_panel_index": 0,           # ribotac_premiR21_strong
    },
    {
        "name": "premiR21_like_moderate",
        "rna_target_class": "structured non-coding RNA — pre-miRNA hairpin",
        "rna_seq": "GGGAAACCCUUUGGGAAACCCUUUGGG",
        "aso_window": (4, 20),
        "n_aso_molecules": 100,
        "ribotac_panel_index": 1,           # ribotac_premiR21_moderate
    },
    {
        "name": "structured_hairpin",
        "rna_target_class": "structured RNA hairpin target",
        "rna_seq": "GGGGCCCCAAAAGGGGCCCC",
        "aso_window": (0, 18),
        "n_aso_molecules": 100,
        "ribotac_panel_index": 2,           # ribotac_structured_hairpin
    },
    {
        "name": "short_stem_loop",
        "rna_target_class": "short structured stem-loop RNA",
        "rna_seq": "GCGCGCAUAUGCGCGC",
        "aso_window": (0, 14),
        "n_aso_molecules": 100,
        "ribotac_panel_index": 3,           # ribotac_weak_recruiter
    },
]


# ── helpers ────────────────────────────────────────────────────────────────

def _ribotac_params(ribotac_mod, idx: int) -> dict:
    """Return the (K_d1, K_d2, alpha, k_cat, t_exposure, precedent) tuple
    from the parent ribotac panel as a dict, by index."""
    tup = ribotac_mod.RIBOTAC_PANEL[idx]
    name, _rna_seq, k_d1, k_d2, alpha, k_cat, t_exp, precedent = tup
    return {
        "ribotac_panel_name": name,
        "k_d1_nM": k_d1,
        "k_d2_nM": k_d2,
        "alpha": alpha,
        "k_cat_per_s": k_cat,
        "t_exposure_s": t_exp,
        "drug_precedent": precedent,
    }


# ── per-row builders (delegate to parent sims — f3 no fork) ────────────────

def _oligonucleotide_row(oligo_mod, target: dict) -> dict:
    """OLIGONUCLEOTIDE pathway row — SantaLucia NN duplex thermodynamics,
    stoichiometric turnover regime."""
    rna_seq = target["rna_seq"]
    start, length = target["aso_window"]
    # The ASO is the reverse complement of the targeted window of the RNA
    # (the parent NN engine accepts U and maps U->T internally).
    rna_window = rna_seq[start:start + length]
    aso = oligo_mod.reverse_complement(rna_window)
    # Reuse the parent module's full duplex thermodynamics report.
    dup = oligo_mod.duplex_report(aso)

    n_aso = target["n_aso_molecules"]
    # Stoichiometric model — one ASO molecule blocks at most one transcript.
    # The 1-to-1 ceiling is the defining feature of the stoichiometric regime
    # (cf. ribotac_sim.STOICHIOMETRIC_TURNOVER = 1).
    n_rna_blocked = n_aso
    rna_per_molecule = 1.0  # by construction (stoichiometric)

    return {
        "schema": SCHEMA_ID,
        "row_kind": "oligonucleotide",
        "modality": "OLIGONUCLEOTIDE",
        "target_name": target["name"],
        "rna_target_class": target["rna_target_class"],
        "turnover_regime": "stoichiometric",
        "turnover_regime_description": (
            "STOICHIOMETRIC: one ASO molecule blocks at most one RNA "
            "transcript (RNase-H cleaves the ASO:RNA hybrid and the ASO "
            "is sequestered, OR the ASO sterically blocks splicing / "
            "translation at one site per transcript copy). N_RNA_blocked "
            "= N_ASO_molecules — the 1-to-1 ceiling is the stoichiometric "
            "turnover number = 1 (Cornish-Bowden 2012, real-limit floor)."),
        "drug_precedent": (
            "nusinersen / Spinraza (ASO, intrathecal SMN2 splice-switching, "
            "FDA 2016); patisiran / Onpattro (siRNA, hereditary ATTR "
            "amyloidosis, FDA 2018); inclisiran / Leqvio (siRNA, "
            "hypercholesterolemia, FDA 2021) — three FDA-approved drugs "
            "across two oligonucleotide modalities (ASO and siRNA). "
            "Own precedent only (g3/f1) — never lattice-derived."),
        "modality_stage": "approved (multiple FDA-approved ASO and siRNA drugs since 2016)",
        "mechanism": (
            "The ASO hybridizes the RNA target via Watson-Crick base "
            "pairing (SantaLucia 1998 unified NN duplex thermodynamics). "
            "After hybridization the ASO either recruits RNase-H to "
            "cleave the RNA strand of the hybrid (gapmer ASO mechanism) "
            "or sterically blocks splicesome / ribosome access at the "
            "ASO:RNA site. In either case the ASO is CONSUMED / "
            "sequestered — stoichiometric, not catalytic."),
        # ── SantaLucia NN thermodynamics (parent-sim — f3 no fork) ──
        "oligo_sequence_5to3": aso,
        "oligo_length_nt": dup["length_nt"],
        "duplex_dH_kcal_mol": dup["dH_kcal_mol"],
        "duplex_dS_cal_mol_K": dup["dS_cal_mol_K"],
        "duplex_dG37_kcal_mol": dup["dG37_kcal_mol"],
        "duplex_Tm_celsius": dup["Tm_celsius"],
        # ── stoichiometric turnover counts ──
        "n_aso_molecules": n_aso,
        "n_rna_blocked_stoichiometric": n_rna_blocked,
        "n_rna_neutralized_per_drug_molecule": rna_per_molecule,
        # ── model-signal summary fields ──
        "model_signal_name": "duplex_Tm_celsius + N_RNA_blocked_stoichiometric",
        "model_signal_value": dup["Tm_celsius"],
        "model_signal_units": (
            "deg C (van 't Hoff two-state Tm at 0.4 uM strand, 1 M Na+ "
            "standard state; non-physiological) — paired with the "
            "stoichiometric N_RNA_blocked count (= N_ASO_molecules, "
            "dimensionless integer)."),
        "model_signal_detail": {
            "duplex_dH_kcal_mol": dup["dH_kcal_mol"],
            "duplex_dS_cal_mol_K": dup["dS_cal_mol_K"],
            "duplex_dG37_kcal_mol": dup["dG37_kcal_mol"],
            "duplex_Tm_celsius": dup["Tm_celsius"],
            "n_aso_molecules": n_aso,
            "n_rna_blocked_stoichiometric": n_rna_blocked,
            "rna_blocked_per_aso_molecule": rna_per_molecule,
        },
        "real_limit_anchor": (
            "Nucleic-acid duplex hybridization thermodynamics — "
            "nearest-neighbor base-pair stacking free energy bounds "
            "duplex stability (SantaLucia 1998 unified NN). Stoichiometric "
            "turnover number = 1 by definition (Cornish-Bowden 2012, "
            "real-limit floor)."),
        "real_limit_citations": [
            "SantaLucia J Jr., Proc Natl Acad Sci USA 1998;95(4):1460-1465 "
            "(unified NN parameters; van 't Hoff Tm).",
            "Cornish-Bowden A., Fundamentals of Enzyme Kinetics, 4th ed. "
            "(Wiley-Blackwell, 2012) — stoichiometric turnover number = 1.",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed. Duplex ΔH°/ΔS°/ΔG°/Tm "
            "are nearest-neighbor base-pair stacking facts (SantaLucia "
            "1998), and N_RNA_blocked is the stoichiometric 1-to-1 ceiling. "
            "Nothing here is derived from σ/τ/φ/J₂ (AGENTS.tape g2 / g3 / "
            "f1 / f_lattice_fit)."),
        "comparison_is_ranking": False,
        "signals_commensurable": False,
        "illustrative_only": True,
        "creates_a_new_axis": False,
        "in_silico_only": True,
    }


def _ribotac_row(ribotac_mod, target: dict) -> dict:
    """RIBOTAC pathway row — mass-action ternary occupancy + catalytic
    multi-turnover."""
    rna_seq = target["rna_seq"]
    params = _ribotac_params(ribotac_mod, target["ribotac_panel_index"])

    # Deterministic assay concentrations match ribotac_sim.build_rows().
    conc_target_nM = 10.0
    conc_ribotac_nM = 100.0
    conc_rnase_nM = 50.0

    struct = ribotac_mod.rna_structuredness(rna_seq)
    tern = ribotac_mod.ternary_fraction(
        conc_target_nM, conc_ribotac_nM, conc_rnase_nM,
        params["k_d1_nM"], params["k_d2_nM"], params["alpha"])
    cat = ribotac_mod.catalytic_advantage(
        params["k_cat_per_s"], params["t_exposure_s"])
    n_cleaved = cat["turnover_number"]  # k_cat * t_exposure
    effective = tern["ternary_fraction"] * n_cleaved

    return {
        "schema": SCHEMA_ID,
        "row_kind": "ribotac",
        "modality": "RIBOTAC",
        "target_name": target["name"],
        "rna_target_class": target["rna_target_class"],
        "turnover_regime": "catalytic",
        "turnover_regime_description": (
            "CATALYTIC (multiple-turnover): a single bifunctional RIBOTAC "
            "molecule recruits endogenous RNase-L to a structured RNA "
            "target; the recruited nuclease cleaves the RNA and the "
            "RIBOTAC is RELEASED to nucleate a fresh ternary complex on "
            "another RNA copy. N_RNA_cleaved = k_cat · t_exposure (>> 1 "
            "for a real RIBOTAC). Real-limit: a genuine catalyst has "
            "turnover number N > 1 (Cornish-Bowden 2012)."),
        "drug_precedent": params["drug_precedent"],
        "modality_stage": "research-stage (no approved RIBOTAC)",
        "mechanism": (
            "Bifunctional small molecule: one warhead binds a structured "
            "RNA target, the other recruits endogenous RNase-L. Mass-"
            "action ternary occupancy of Target·R·RNase-L (Guldberg & "
            "Waage 1864); recruited RNase-L cleaves the RNA "
            "catalytically; the RIBOTAC is RELEASED post-cleavage and "
            "can turn over again (Disney-lab RIBOTAC class — Costales "
            "JACS 2018, PNAS 2020)."),
        # ── RNA structure (parent — Nussinov via ribotac_sim — f3 no fork) ──
        "rna_target_seq": rna_seq,
        "rna_length_nt": struct["rna_length_nt"],
        "dot_bracket": struct["dot_bracket"],
        "num_base_pairs": struct["num_base_pairs"],
        # ── mass-action ternary (parent — f3 no fork) ──
        "k_d1_nM": tern["k_d1_nM"],
        "k_d2_nM": tern["k_d2_nM"],
        "alpha": tern["alpha"],
        "k_d2_effective_nM": tern["k_d2_effective_nM"],
        "binary_fraction": tern["binary_fraction"],
        "rnase_site_fraction": tern["rnase_site_fraction"],
        "ternary_fraction": tern["ternary_fraction"],
        # ── catalytic multi-turnover (parent — f3 no fork) ──
        "k_cat_per_s": cat["k_cat_per_s"],
        "t_exposure_s": cat["t_exposure_s"],
        "turnover_number": cat["turnover_number"],
        "n_rna_cleaved_catalytic": n_cleaved,
        "is_catalytic": cat["is_catalytic"],
        "n_rna_neutralized_per_drug_molecule": effective,
        # ── model-signal summary fields ──
        "model_signal_name": "K_d1_nM + N_RNA_cleaved_catalytic",
        "model_signal_value": n_cleaved,
        "model_signal_units": (
            "K_d1 in nM (RNA-binding-warhead dissociation constant; "
            "mass-action ternary occupancy) paired with N_RNA_cleaved = "
            "k_cat · t_exposure (catalytic multi-turnover, "
            "dimensionless)."),
        "model_signal_detail": {
            "k_d1_nM": tern["k_d1_nM"],
            "k_d2_nM": tern["k_d2_nM"],
            "alpha": tern["alpha"],
            "k_d2_effective_nM": tern["k_d2_effective_nM"],
            "ternary_fraction": tern["ternary_fraction"],
            "k_cat_per_s": cat["k_cat_per_s"],
            "t_exposure_s": cat["t_exposure_s"],
            "turnover_number": cat["turnover_number"],
            "n_rna_cleaved_catalytic": n_cleaved,
        },
        "real_limit_anchor": (
            "Catalytic multiple-turnover (a genuine catalyst has turnover "
            "number N > 1) + mass-action law (bound fractions ≤ 1.0). "
            "Disney-lab RIBOTAC class recruits endogenous RNase-L."),
        "real_limit_citations": [
            "Costales MG et al., J Am Chem Soc 2018;140:6741-6744 "
            "(first RNase-L-recruiting RIBOTAC).",
            "Costales MG et al., Proc Natl Acad Sci USA 2020;117:2406-2411 "
            "(RIBOTAC vs pre-miR-21).",
            "Cornish-Bowden A., Fundamentals of Enzyme Kinetics, 4th ed. "
            "(Wiley-Blackwell, 2012) — catalytic turnover number N > 1.",
            "Guldberg & Waage 1864 — mass-action law; bound fractions ≤ 1.",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed. Mass-action ternary "
            "occupancy and catalytic turnover are the real-limit anchors; "
            "nothing here is derived from σ/τ/φ/J₂ (AGENTS.tape g2 / g3 / "
            "f1 / f_lattice_fit)."),
        "comparison_is_ranking": False,
        "signals_commensurable": False,
        "illustrative_only": True,
        "creates_a_new_axis": False,
        "in_silico_only": True,
    }


# ── orchestration ──────────────────────────────────────────────────────────

def build_rows() -> list:
    """Build the full cross panel — two rows (oligonucleotide + ribotac)
    per target — by delegating to the imported parent sims."""
    oligo_mod = _load_module("oligonucleotide_hybridization_sim", _OLIGO_PATH)
    ribotac_mod = _load_module("ribotac_sim", _RIBOTAC_PATH)

    rows = []
    for target in _CROSS_PANEL:
        o_row = _oligonucleotide_row(oligo_mod, target)
        r_row = _ribotac_row(ribotac_mod, target)
        o_row["paired_target_name"] = target["name"]
        r_row["paired_target_name"] = target["name"]
        rows.append(o_row)
        rows.append(r_row)
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (W3-X1 .. W3-X8)."""
    o_rows = [r for r in rows if r["row_kind"] == "oligonucleotide"]
    r_rows = [r for r in rows if r["row_kind"] == "ribotac"]

    crit = {
        "W3_X1_panel_has_both_pathways":
            len(o_rows) >= 1 and len(r_rows) >= 1,
        "W3_X2_pathways_paired_per_target":
            len(o_rows) == len(r_rows)
            and all(o["paired_target_name"] == r["paired_target_name"]
                    for o, r in zip(o_rows, r_rows)),
        "W3_X3_oligo_stoichiometric_regime":
            all(o["turnover_regime"] == "stoichiometric"
                and o["n_rna_neutralized_per_drug_molecule"] <= 1.0
                and o["n_rna_blocked_stoichiometric"] == o["n_aso_molecules"]
                for o in o_rows),
        "W3_X4_oligo_nn_thermodynamics_well_formed":
            all(o["duplex_dH_kcal_mol"] < 0.0          # exothermic duplex
                and o["duplex_dS_cal_mol_K"] < 0.0     # entropy loss on duplexing
                and o["duplex_dG37_kcal_mol"] < 0.0    # stable duplex at 37 C
                and o["duplex_Tm_celsius"] > 0.0       # physical Tm
                for o in o_rows),
        "W3_X5_ribotac_mass_action_bounded":
            all(0.0 <= r["binary_fraction"] <= 1.0
                and 0.0 <= r["rnase_site_fraction"] <= 1.0
                and 0.0 <= r["ternary_fraction"] <= 1.0
                for r in r_rows),
        "W3_X6_ribotac_catalytic_regime":
            all(r["turnover_regime"] == "catalytic"
                and r["is_catalytic"]
                and r["turnover_number"] > 1.0
                and r["n_rna_cleaved_catalytic"] == r["turnover_number"]
                for r in r_rows),
        "W3_X7_turnover_regimes_disjoint":
            (all(o["turnover_regime"] == "stoichiometric" for o in o_rows)
             and all(r["turnover_regime"] == "catalytic" for r in r_rows)
             and (set(o["turnover_regime"] for o in o_rows)
                  & set(r["turnover_regime"] for r in r_rows) == set())),
        "W3_X8_honesty_flags_in_every_row":
            all((row["comparison_is_ranking"] is False
                 and row["signals_commensurable"] is False
                 and row["illustrative_only"] is True
                 and row["creates_a_new_axis"] is False
                 and row["in_silico_only"] is True)
                for row in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def build_witness() -> dict:
    rows = build_rows()
    acc = acceptance(rows)
    return {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "cross": ("W3  OLIGONUCLEOTIDE (ASO / siRNA hybridization)  ||  "
                  "RIBOTAC (RNase-L recruitment)  — same RNA-target CLASS "
                  "(both target RNA), opposite TURNOVER REGIME "
                  "(stoichiometric vs catalytic)."),
        "oligonucleotide_source":
            "_python_bridge/module/oligonucleotide_hybridization_sim.py "
            "(imported, not forked — f3)",
        "ribotac_source":
            "_python_bridge/module/ribotac_sim.py "
            "(imported, not forked — f3; itself imports the parent "
            "RIBOZYME-axis Nussinov solver, also unforked)",
        "real_limit_anchors": [
            ("Nucleic-acid duplex hybridization thermodynamics — "
             "SantaLucia 1998 PNAS 95(4):1460-1465 (unified NN ΔH°/ΔS° + "
             "van 't Hoff Tm)."),
            ("Catalytic multiple-turnover N > 1 — Cornish-Bowden, "
             "Fundamentals of Enzyme Kinetics 4th ed., Wiley-Blackwell "
             "2012; Disney-lab RIBOTAC: Costales et al. JACS 2018;140:6741, "
             "Costales et al. PNAS 2020;117:2406."),
            ("Mass-action law — Guldberg & Waage 1864; bound fractions ≤ 1."),
        ],
        "turnover_regime_disjoint_statement": (
            "Same RNA-target CLASS, opposite TURNOVER REGIME. "
            "OLIGONUCLEOTIDE (ASO / siRNA) is stoichiometric: one ASO "
            "blocks at most one transcript (RNase-H gapmer or steric "
            "block), gets consumed; N_RNA_blocked = N_ASO_molecules. "
            "RIBOTAC is catalytic multi-turnover: one RIBOTAC recruits "
            "RNase-L, the recruited nuclease cleaves the RNA, the "
            "RIBOTAC is RELEASED and turns over many cycles; "
            "N_RNA_cleaved = k_cat · t_exposure (>> 1). This cross "
            "reports both side-by-side and refuses to collapse the "
            "two regimes."),
        "comparison_is_ranking": False,
        "signals_commensurable": False,
        "signals_commensurable_note": (
            "The two model signals are NOT commensurable. The "
            "OLIGONUCLEOTIDE row reports Tm in °C + N_RNA_blocked "
            "(stoichiometric, dimensionless count); the RIBOTAC row "
            "reports K_d in nM + N_RNA_cleaved (catalytic, "
            "dimensionless count). Different units on different real "
            "limits. They cannot be ranked against each other."),
        "creates_a_new_axis": False,
        "core_axes_unchanged": (
            "Cross ≠ new axis. Core-5 axes (QUANTUM / WEAVE / NANOBOT / "
            "RIBOZYME / VIROCAPSID) are untouched by this module. "
            "OLIGONUCLEOTIDE remains an expansion-main axis; RIBOTAC "
            "remains a sub-axis :> BIFUNCTIONAL (also an expansion-"
            "main)."),
        "modality_precedents_own_only": {
            "OLIGONUCLEOTIDE": [
                "nusinersen / Spinraza (ASO, FDA 2016) — intrathecal "
                "SMN2 splice-switching for SMA",
                "patisiran / Onpattro (siRNA, FDA 2018) — hereditary "
                "ATTR amyloidosis",
                "inclisiran / Leqvio (siRNA, FDA 2021) — "
                "hypercholesterolemia",
            ],
            "RIBOTAC": [
                "Disney-lab RIBOTAC class — research-stage, NO "
                "FDA-approved RIBOTAC (Costales et al. JACS 2018;"
                "140:6741; Costales et al. PNAS 2020;117:2406)",
            ],
        },
        "lattice_stance": (
            "Neither pathway is described via the n=6 lattice. "
            "OLIGONUCLEOTIDE thermodynamics anchor to SantaLucia NN; "
            "RIBOTAC kinetics anchor to mass-action + catalytic-turnover "
            "real limits. No n=6 derivation appears in either row "
            "(AGENTS.tape g2 lattice-is-tool, g3/f1 honesty-external, "
            "f_lattice_fit)."),
        "in_silico_scope_caveat": (
            "This PASS certifies IN-SILICO simulator+metadata internal "
            "consistency ONLY (AGENTS.tape g8 / f2). NOT a therapeutic, "
            "clinical, knockdown, efficacy, immunogenic, regulatory, or "
            "modality-superiority claim. OLIGONUCLEOTIDE has FDA-approved "
            "precedent for the modality, but the rows here are "
            "ILLUSTRATIVE in-silico signatures, not drug-equivalent "
            "claims. RIBOTAC is RESEARCH-STAGE (no approved RIBOTAC). "
            "Wet-lab boundary is out of repo scope "
            "(CLOSURE_RESIDUAL_BACKLOG.md §0)."),
        "comparison_not_ranking_note": (
            "COMPARISON ≠ RANKING. Nusinersen / patisiran / inclisiran "
            "(FDA-approved ASO and siRNA drugs) and Disney-lab RIBOTACs "
            "(research-stage, no FDA-approved RIBOTAC) are NOT competing "
            "modalities to be ranked here — they target different RNA "
            "biology questions (splice-switching / steady-state "
            "knockdown vs catalytic cleavage of structured non-coding "
            "RNA)."),
        "rows": rows,
        "acceptance": acc,
    }


# ── self-check / main ──────────────────────────────────────────────────────

def main() -> int:
    print("oligonucleotide_ribotac_cross — CROSS-AXIS W3\n", flush=True)
    print("cross:  OLIGONUCLEOTIDE (ASO / siRNA hybridization)  ||  "
          "RIBOTAC (RNase-L recruitment)")
    print("        same RNA-target CLASS  : both modalities target RNA")
    print("        opposite turnover REGIME : "
          "stoichiometric (1:1)  ≠  catalytic (multi-turnover)")
    print("        OLIGO row : N_RNA_blocked = N_ASO_molecules   "
          "(SantaLucia NN Tm)")
    print("        RIBOTAC row : N_RNA_cleaved = k_cat · t_exposure  "
          "(mass-action ternary + catalytic N>1)\n", flush=True)
    print("  real-limit (a) : nucleic-acid duplex hybridization "
          "thermodynamics — SantaLucia 1998 PNAS 95:1460")
    print("  real-limit (b) : catalytic multi-turnover N>1 + mass-action — "
          "Disney RIBOTAC")
    print("                   (Costales JACS 2018 / PNAS 2020); "
          "Cornish-Bowden, Enzyme Kinetics 4e 2012;")
    print("                   Guldberg & Waage 1864 (mass-action law)\n",
          flush=True)

    witness = build_witness()
    rows = witness["rows"]
    acc = witness["acceptance"]

    # group by target for legibility
    paired = {}
    for r in rows:
        paired.setdefault(r["paired_target_name"], {})[r["row_kind"]] = r

    for tgt, pair in paired.items():
        o = pair["oligonucleotide"]
        rb = pair["ribotac"]
        print(f"  target: {tgt}  (RNA class: {o['rna_target_class']})")
        print(f"    OLIGONUCLEOTIDE  [stoichiometric  ] "
              f"ASO 5'-{o['oligo_sequence_5to3']}-3' ({o['oligo_length_nt']} nt)")
        print(f"        SantaLucia NN: ΔG°(37)={o['duplex_dG37_kcal_mol']:>7.2f} "
              f"kcal/mol  Tm={o['duplex_Tm_celsius']:>6.2f} °C")
        print(f"        N_RNA_blocked = N_ASO = "
              f"{o['n_rna_blocked_stoichiometric']}  (1:1 stoichiometric "
              f"ceiling)")
        print(f"    RIBOTAC          [catalytic       ] "
              f"K_d1={rb['k_d1_nM']:.0f}nM  K_d2={rb['k_d2_nM']:.0f}nM  "
              f"α={rb['alpha']:.0f}")
        print(f"        ternary fraction={rb['ternary_fraction']:.4f}  "
              f"k_cat={rb['k_cat_per_s']:.3g}/s  "
              f"t_exposure={rb['t_exposure_s']:.0f}s")
        print(f"        N_RNA_cleaved = k_cat · t_exposure = "
              f"{rb['n_rna_cleaved_catalytic']:.1f}  "
              f"(catalytic multi-turnover)")

    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---")

    print()
    print("  ── turnover-regime honesty (g3 / g8 / f2 / f_lattice_fit) ──")
    print("  Same RNA-target CLASS, opposite TURNOVER REGIME.")
    print("  OLIGONUCLEOTIDE: an ASO forms a Watson-Crick duplex with the")
    print("  RNA (SantaLucia NN); then RNase-H cleaves the hybrid (gapmer)")
    print("  OR the ASO sterically blocks splicesome/ribosome — the ASO is")
    print("  consumed. One ASO molecule blocks at most one transcript.")
    print("  N_RNA_blocked = N_ASO_molecules — stoichiometric.")
    print("  RIBOTAC: a bifunctional molecule recruits endogenous RNase-L")
    print("  to a structured RNA (Disney-lab class, Costales JACS 2018,")
    print("  PNAS 2020); the recruited nuclease cleaves the RNA and the")
    print("  RIBOTAC is RELEASED and can turn over again.")
    print("  N_RNA_cleaved = k_cat · t_exposure (>> 1) — catalytic.")
    print("  This cross reports both side-by-side and refuses to collapse")
    print("  the two regimes.")
    print()
    print("  ── comparison ≠ ranking (g3 / g8 / f2) ──")
    print("  The two model signals are NOT commensurable: Tm in °C +")
    print("  N_blocked (stoichiometric, dimensionless count) vs K_d in")
    print("  nM + N_cleaved (catalytic, dimensionless count). Different")
    print("  units on different real limits. Nusinersen / patisiran /")
    print("  inclisiran (FDA-approved ASO and siRNA drugs) and Disney-")
    print("  lab RIBOTACs (research-stage, NO FDA-approved RIBOTAC) are")
    print("  NOT competing modalities to be ranked here — they target")
    print("  different RNA biology questions (splice-switching / steady-")
    print("  state knockdown of mRNA vs catalytic cleavage of structured")
    print("  non-coding RNA such as pre-miR-21).")
    print()
    print("  ── in-silico scope caveat (g8 / f2) ──")
    print("  This PASS certifies IN-SILICO simulator+metadata internal")
    print("  consistency ONLY. NOT a therapeutic, clinical, knockdown,")
    print("  efficacy, immunogenic, regulatory or modality-superiority")
    print("  claim. OLIGONUCLEOTIDE has FDA-approved precedent (nusinersen")
    print("  2016, patisiran 2018, inclisiran 2021), but the rows here are")
    print("  ILLUSTRATIVE in-silico signatures, not drug-equivalent")
    print("  claims. RIBOTAC is RESEARCH-STAGE (no approved RIBOTAC).")
    print("  Nothing is derived from the n=6 lattice (g2 / g3 / f1 /")
    print("  f_lattice_fit). Wet-lab is out of repo scope")
    print("  (CLOSURE_RESIDUAL_BACKLOG.md §0).")
    print()
    print("  ── no-fork (f3) ──")
    print("  Both parent sims are IMPORTED, never reimplemented. All")
    print("  thermodynamics / kinetics is delegated to")
    print("  oligonucleotide_hybridization_sim and ribotac_sim (which")
    print("  itself imports the parent RIBOZYME-axis Nussinov solver —")
    print("  also unforked). Cross ≠ new axis: core-5 axes are UNCHANGED")
    print("  by this module.")

    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_PASS if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
