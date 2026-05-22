#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aptamer_oligonucleotide_cross.py — CROSS-AXIS in-silico comparison of two
nucleic-acid therapeutic modalities that share the same chemistry but emit
mechanistically opposite model signals.

WHAT THIS IS — CROSS-AXIS G5
────────────────────────────
Two nucleic-acid modalities that share the same backbone chemistry and the
same nearest-neighbor (SantaLucia 1998 PNAS 95:1460) thermodynamic real-limit
anchor — but act on biology in OPPOSITE ways:

  (a) OLIGONUCLEOTIDE / ASO / siRNA — sequence-driven.
      An antisense oligonucleotide (or siRNA guide) HYBRIDIZES the target
      mRNA via Watson-Crick complementarity. The model signal is a duplex
      thermodynamic signature (NN ΔH°/ΔS°/ΔG° → Tm). Mechanism: the
      OLIGONUCLEOTIDE axis (`oligonucleotide_hybridization_sim.py`).
      Drug precedent (own, NOT lattice-derived — g3/f1/f_lattice_fit):
      nusinersen / Spinraza (ASO, FDA 2016); patisiran / Onpattro (siRNA,
      FDA 2018); inclisiran / Leqvio (siRNA, 2021).

  (b) APTAMER — shape-driven.
      An aptamer FOLDS into a 3D pocket that recognizes a NON-nucleic-acid
      ligand (small molecule, protein, ion). It is a NON-catalytic binder
      (k_cat = 0 by construction). The model signal is a fold ΔG plus a
      1:1 Langmuir Kd / saturation isotherm. Mechanism: the APTAMER
      sub-axis (`aptamer_affinity_sim.py`, :> RIBOZYME).
      Drug precedent (own, NOT lattice-derived — g3/f1/f_lattice_fit):
      pegaptanib / Macugen (anti-VEGF165 RNA aptamer, FDA 2004);
      avacincaptad pegol / Izervay (anti-C5 RNA aptamer, FDA 2023).

The honest cross: SAME nucleic-acid chemistry → SAME thermodynamic backbone
(SantaLucia NN), but the model signal each modality emits is on a DIFFERENT
mechanism (hybridization Tm in °C vs target-binding Kd in nM). The two
signals live in different units, on different mechanisms — they are
structurally non-rankable.

DELIVERABLE — A COMPARISON, NOT A RANKING (CRITICAL HONESTY)
────────────────────────────────────────────────────────────
This module emits a side-by-side of TWO IN-SILICO MODEL SIGNATURES plus a
unification row showing the shared thermodynamic anchor and the mechanism-
distinct outputs. It is:
  • NOT an efficacy ranking
  • NOT a claim that one modality / drug is superior to the other
  • NOT a clinical, therapeutic, regulatory, immunogenic or potency claim
Both modalities have INDEPENDENT FDA-approved drug precedents. Schema
constants make the non-rankability explicit:
    comparison_is_ranking  = False
    signals_commensurable  = False

NO FORK (governance f3 — no shadow implementation of sister sims)
─────────────────────────────────────────────────────────────────
The two mechanism models are IMPORTED from their existing axis modules:
  • oligonucleotide_hybridization_sim.py — SantaLucia NN duplex Tm.
  • aptamer_affinity_sim.py             — Nussinov + NN-stack fold ΔG and
                                          Langmuir 1:1 Kd / theta.
This module adds ONLY the cross + the comparison emitter; it re-implements
neither the SantaLucia NN model nor the Nussinov solver nor the Langmuir
isotherm. CROSS != NEW AXIS — the core-5 axis set (QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED.

REAL LIMITS ANCHORED (governance g1 — real-limits-first)
─────────────────────────────────────────────────────────
Each modality's signal is anchored to a real physical limit — neither is
derived from the n=6 lattice (g2 / f1 / f_lattice_fit). The two share their
PRIMARY anchor:
  • SHARED real-limit anchor — nucleic-acid nearest-neighbor thermodynamics.
    Duplex stability AND folded-stem stability are bounded by NN base-pair
    stacking free energy. Same backbone, same statistical-mechanics frame.
      - SantaLucia J Jr. "A unified view of polymer, dumbbell, and
        oligonucleotide DNA nearest-neighbor thermodynamics." Proc Natl
        Acad Sci USA 1998;95(4):1460-1465.
  • APTAMER additional Kd anchor — published binding-affinity literature.
      - Bock LC, Griffin LC, Latham JA, Vermaas EH, Toole JJ. "Selection of
        single-stranded DNA molecules that bind and inhibit human
        thrombin." Nature 1992;355:564-566.  (thrombin-binding 15-mer DNA
        aptamer "TBA", reported Kd in the low/mid-nanomolar regime —
        operational literature anchor for the Langmuir equilibrium.)

DRUG / BIOLOGY PRECEDENT (governance g3 / f1 — own precedent only)
───────────────────────────────────────────────────────────────────
Modalities are described ONLY via their own published drug precedent;
nothing here is lattice-derived:
  • OLIGONUCLEOTIDE — nusinersen / Spinraza (ASO, FDA 2016);
    patisiran / Onpattro (siRNA, FDA 2018);
    inclisiran / Leqvio (siRNA, 2021).
  • APTAMER       — pegaptanib / Macugen (anti-VEGF165 RNA aptamer, FDA
    2004); avacincaptad pegol / Izervay (anti-C5 RNA aptamer, FDA 2023).

DETERMINISM
───────────
Pure stdlib (the imported axis modules are stdlib-only too). No random /
network / time / env reads. Re-running on the same inputs produces
byte-identical output → deductive-verification contract.

SCOPE — IN-SILICO ONLY (governance g8 / f2)
────────────────────────────────────────────
A PASS sentinel here certifies IN-SILICO simulator + metadata internal
consistency ONLY — that both imported models run, produce well-formed
signatures, and reproduce byte-identically. It is NEVER a therapeutic,
clinical, knockdown, binding-affinity, splicing-correction, efficacy,
immunogenic, or regulatory claim. The wet-lab boundary is out of repo
scope (CLOSURE_RESIDUAL_BACKLOG.md §0).

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import json
import os
import sys
from typing import Dict, List

# ── sister-axis imports (no fork — governance f3) ───────────────────────
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# (a) OLIGONUCLEOTIDE axis — sequence-driven Watson-Crick hybridization.
from oligonucleotide_hybridization_sim import (  # noqa: E402
    duplex_report,
    reverse_complement,
)

# (b) APTAMER sub-axis (:> RIBOZYME) — shape-driven folded binder.
from aptamer_affinity_sim import (  # noqa: E402
    model_aptamer,
    check_row as aptamer_check_row,
)

SCHEMA_VERSION = "aptamer_oligonucleotide_cross_v1"
SENTINEL_PASS = "__APTAMER_OLIGONUCLEOTIDE_CROSS__ PASS"
SENTINEL_FAIL = "__APTAMER_OLIGONUCLEOTIDE_CROSS__ FAIL"

# Schema-level non-rankability constants (also enforced by JSON Schema).
COMPARISON_IS_RANKING = False
SIGNALS_COMMENSURABLE = False

# ── deterministic comparison panel (one ASO scenario + one aptamer) ─────
#
# (a) OLIGONUCLEOTIDE scenario — a deterministic toy target mRNA window and
#     its perfectly-complementary ASO (the ASO is the reverse complement of
#     the target window). Model emits a SantaLucia NN duplex signature →
#     hybridization Tm at the standard 0.4 µM strand concentration. This is
#     the "sequence-driven hybridization" arm of the cross. The sequence is
#     a deterministic toy construct — not a real mRNA region; it exercises
#     the SantaLucia NN arithmetic only (governance g8 / f2).
_TARGET_MRNA_WINDOW = "GCAGCAACTGCAGCAACTGCA"   # 21-nt toy mRNA window
_ASO_TOTAL_STRAND_M = 0.4e-6                    # 0.4 µM (SantaLucia 1998 ref)

# (b) APTAMER scenario — the thrombin-binding DNA aptamer (TBA, Bock 1992
#     Nature 355:564) reused from the aptamer-axis corpus. Same nucleic-acid
#     backbone (DNA / RNA-folder normalises T -> U), but the model emits
#     the fold ΔG + Langmuir 1:1 Kd / theta — "shape-driven fold binding".
#     k_cat = 0 by construction (aptamer = non-catalytic binder).
_APTAMER_NAME = "thrombin_binding_aptamer_TBA"
_APTAMER_SEQ = "GGTTGGTGTGGTTGG"               # 15-mer G-quadruplex DNA aptamer
_APTAMER_LIGAND = "human alpha-thrombin"
_APTAMER_KD_nM = 100.0                         # low/mid-nM regime (Bock 1992)
_APTAMER_PAPER = "Bock LC et al. 1992 Nature 355:564-566"

# Shared anchor literature citation (real-limits-first, g1).
_SHARED_ANCHOR = (
    "Nucleic-acid nearest-neighbor thermodynamics — base-pair stacking "
    "free energy bounds both duplex stability (hybridization) and folded-"
    "stem stability (aptamer pocket)"
)
_SHARED_ANCHOR_CITE = "SantaLucia J Jr 1998 Proc Natl Acad Sci USA 95(4):1460-1465"


def _oligonucleotide_signature() -> Dict:
    """Run the OLIGONUCLEOTIDE (ASO) path: design the ASO as the reverse
    complement of the toy target mRNA window and compute the duplex
    thermodynamic signature (NN ΔH°/ΔS°/ΔG° + Tm at 37 °C reference, 0.4 µM).

    Real limit: SantaLucia (1998) unified NN model for nucleic-acid duplex
    thermodynamics. The model signal is the duplex melting temperature Tm
    (°C) — how stably the ASO clamps its complementary mRNA window.
    """
    aso = reverse_complement(_TARGET_MRNA_WINDOW)
    rep = duplex_report(aso, total_strand_M=_ASO_TOTAL_STRAND_M)
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "OLIGONUCLEOTIDE",
        "modality_label": "Antisense oligonucleotide / siRNA "
        "(sequence-driven Watson-Crick hybridization)",
        "axis_module": "oligonucleotide_hybridization_sim.py",
        "axis_name": "OLIGONUCLEOTIDE",
        "drug_precedent": "nusinersen / Spinraza (ASO, FDA 2016); "
        "patisiran / Onpattro (siRNA, FDA 2018); inclisiran / Leqvio "
        "(siRNA, 2021)",
        "mechanism": "An ASO (or siRNA guide) HYBRIDIZES the target mRNA "
        "via Watson-Crick complementarity. Sequence-driven: change the "
        "sequence and the target identity changes one-to-one.",
        "mechanism_kind": "sequence-driven-hybridization",
        "model_signal_name": "hybridization_tm_celsius",
        "model_signal_value": rep["Tm_celsius"],
        "model_signal_units": "°C (van 't Hoff two-state Tm; SantaLucia "
        "1998; 1 M Na+ standard state, 0.4 µM total strand — "
        "non-physiological)",
        "model_signal_detail": {
            "target_mrna_window_5to3": _TARGET_MRNA_WINDOW,
            "aso_5to3": aso,
            "aso_length_nt": rep["length_nt"],
            "gc_fraction": rep["gc_fraction"],
            "dH_kcal_mol": rep["dH_kcal_mol"],
            "dS_cal_mol_K": rep["dS_cal_mol_K"],
            "dG37_kcal_mol": rep["dG37_kcal_mol"],
            "Tm_celsius": rep["Tm_celsius"],
            "total_strand_M": rep["total_strand_M"],
            "self_complementary": rep["self_complementary"],
        },
        "real_limit_anchor": "Nucleic-acid duplex hybridization "
        "thermodynamics — nearest-neighbor base-pair stacking free energy "
        "bounds duplex stability (SHARED with the aptamer path)",
        "real_limit_citations": [
            "SantaLucia 1998, Proc Natl Acad Sci USA 95(4):1460-1465",
        ],
        "in_silico_only": True,
    }


def _aptamer_signature() -> Dict:
    """Run the APTAMER path: fold the thrombin-binding 15-mer DNA aptamer
    (Bock 1992) and run its Langmuir 1:1 binding model against thrombin
    (literature Kd in the low/mid-nM regime).

    Real limit: same SantaLucia / Turner NN nucleic-acid thermodynamics for
    the fold ΔG (shared backbone with the ASO path) PLUS the published
    aptamer Kd literature for the Langmuir equilibrium anchor. The model
    signal is the target-binding Kd in nM — how tightly the folded pocket
    grips its non-nucleic-acid ligand. k_cat = 0 (non-catalytic binder).
    """
    row = model_aptamer(
        _APTAMER_NAME, _APTAMER_SEQ, _APTAMER_LIGAND,
        _APTAMER_KD_nM, _APTAMER_PAPER,
    )
    fold = row["fold"]
    binding = row["binding"]
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "APTAMER",
        "modality_label": "Aptamer (shape-driven folded-pocket binder; "
        "non-catalytic, k_cat=0)",
        "axis_module": "aptamer_affinity_sim.py",
        "axis_name": "APTAMER (:> RIBOZYME)",
        "drug_precedent": "pegaptanib / Macugen — anti-VEGF165 RNA aptamer "
        "(FDA 2004); avacincaptad pegol / Izervay — anti-C5 RNA aptamer "
        "(FDA 2023)",
        "mechanism": "An aptamer FOLDS into a 3D pocket that recognizes a "
        "non-nucleic-acid ligand (small molecule, protein, ion). "
        "Shape-driven: the binding identity is set by the 3D fold of the "
        "pocket, not by Watson-Crick complementarity to the ligand.",
        "mechanism_kind": "shape-driven-fold-binding",
        "model_signal_name": "target_binding_kd_nM",
        "model_signal_value": binding["kd_nM"],
        "model_signal_units": "nM (1:1 Langmuir Kd at equilibrium; θ = 0.5 "
        "at [L] = Kd; Bock 1992 thrombin-aptamer literature regime)",
        "model_signal_detail": {
            "aptamer_name": row["name"],
            "aptamer_sequence_5to3": row["sequence"],
            "aptamer_length_nt": row["length_nt"],
            "ligand": row["ligand"],
            "fold_dot_bracket": fold["dot_bracket"],
            "fold_num_base_pairs": fold["num_base_pairs"],
            "fold_balanced": fold["balanced"],
            "fold_dG_kcal_per_mol": fold["folding_free_energy_kcal_per_mol"],
            "kd_M": binding["kd_M"],
            "kd_nM": binding["kd_nM"],
            "kon_M_inv_s": binding["kon_M_inv_s"],
            "koff_s": binding["koff_s"],
            "kd_identity_holds": binding["kd_identity_holds"],
            "theta_at_ligand_eq_kd": binding["theta_at_ligand_eq_kd"],
            "kcat_per_s": row["kcat_per_s"],
        },
        "kcat_per_s": row["kcat_per_s"],
        "real_limit_anchor": "Nucleic-acid folded-stem thermodynamics "
        "(SHARED nearest-neighbor backbone with the ASO path) + published "
        "aptamer Kd literature anchor (thrombin DNA aptamer, low/mid-nM)",
        "real_limit_citations": [
            "SantaLucia 1998, Proc Natl Acad Sci USA 95(4):1460-1465",
            "Bock LC et al. 1992, Nature 355:564-566 "
            "(thrombin-binding DNA aptamer, Kd anchor)",
        ],
        "in_silico_only": True,
    }


def _unification_row(oligo_row: Dict, aptamer_row: Dict) -> Dict:
    """Build the unification row: the SHARED thermodynamic anchor on one
    side, the MECHANISM-DISTINCT outputs on the other.

    cross != merge: same backbone chemistry, opposite modality. The shared
    anchor is the SantaLucia 1998 NN model; the mechanism-distinct outputs
    are hybridization Tm in °C (sequence-driven) vs target-binding Kd in
    nM (shape-driven). The aptamer's k_cat is reported as exactly 0.0,
    the defining contrast with the parent RIBOZYME axis.
    """
    return {
        "shared_anchor": _SHARED_ANCHOR,
        "shared_anchor_citation": _SHARED_ANCHOR_CITE,
        "oligonucleotide_signal_name": oligo_row["model_signal_name"],
        "oligonucleotide_signal_value": oligo_row["model_signal_value"],
        "oligonucleotide_signal_units": oligo_row["model_signal_units"],
        "aptamer_signal_name": aptamer_row["model_signal_name"],
        "aptamer_signal_value": aptamer_row["model_signal_value"],
        "aptamer_signal_units": aptamer_row["model_signal_units"],
        "mechanism_distinction": (
            "Same nucleic-acid chemistry, opposite modality. "
            "OLIGONUCLEOTIDE: sequence-driven Watson-Crick hybridization to "
            "a target mRNA; the signal is a duplex Tm in °C. "
            "APTAMER: shape-driven folded-pocket recognition of a "
            "non-nucleic-acid ligand; the signal is a Langmuir Kd in nM "
            "and k_cat is exactly 0 (non-catalytic binder). The shared "
            "thermodynamic backbone (SantaLucia NN) is the substrate; the "
            "two modalities project onto it from opposite mechanisms."
        ),
        "aptamer_kcat_per_s": aptamer_row["kcat_per_s"],
    }


def build_comparison() -> Dict:
    """Assemble the full APTAMER × OLIGONUCLEOTIDE cross object.

    Returns a dict with the two per-modality signature rows + the
    unification row + an explicit honesty block. The comparison is
    descriptive (what each model says) — it does NOT and CANNOT rank the
    modalities: the two signals are in different units on different
    mechanisms, and both modalities have independent FDA-approved drug
    precedents.
    """
    oligo_row = _oligonucleotide_signature()
    aptamer_row = _aptamer_signature()
    unif = _unification_row(oligo_row, aptamer_row)
    return {
        "schema_version": SCHEMA_VERSION,
        "comparison_id": "aptamer_oligonucleotide_cross.v1",
        "shared_chemistry": "nucleic-acid backbone (DNA / RNA); Watson-Crick "
        "+ wobble pairing alphabet",
        "shared_thermodynamic_anchor": _SHARED_ANCHOR,
        "shared_anchor_citation": _SHARED_ANCHOR_CITE,
        "modality_rows": [oligo_row, aptamer_row],
        "unification_row": unif,
        "comparison_is_ranking": COMPARISON_IS_RANKING,
        "comparison_kind": "descriptive side-by-side of two in-silico "
        "model signatures sharing one thermodynamic anchor on opposite "
        "mechanisms (sequence-driven hybridization vs shape-driven "
        "fold-binding)",
        "signals_commensurable": SIGNALS_COMMENSURABLE,
        "signals_commensurable_note": "The two model signals share the "
        "SantaLucia (1998) NN thermodynamic backbone but project onto "
        "DIFFERENT mechanisms with DIFFERENT units: OLIGONUCLEOTIDE emits "
        "a hybridization Tm in °C (duplex melting); APTAMER emits a "
        "target-binding Kd in nM (Langmuir equilibrium against a "
        "non-nucleic-acid ligand). They are structurally non-rankable.",
        "honesty": {
            "in_silico_only": True,
            "not_an_efficacy_ranking": True,
            "not_a_superiority_claim": True,
            "not_a_clinical_claim": True,
            "both_modalities_have_fda_precedent": True,
            "cross_is_not_a_new_axis": True,
            "no_fork_of_sister_sims": True,
            "statement": (
                "This is a MODALITY COMPARISON of two in-silico model "
                "signatures sharing the SantaLucia (1998) NN thermodynamic "
                "backbone on opposite mechanisms — NOT an efficacy "
                "ranking, NOT a claim that one modality or drug is "
                "superior, NOT a clinical claim. The OLIGONUCLEOTIDE "
                "modality has FDA-approved precedent (nusinersen/Spinraza "
                "2016, patisiran/Onpattro 2018, inclisiran 2021); the "
                "APTAMER modality has FDA-approved precedent "
                "(pegaptanib/Macugen 2004, avacincaptad pegol/Izervay "
                "2023). Each PASS certifies in-silico simulator + "
                "metadata internal consistency ONLY — never a therapeutic, "
                "clinical, knockdown, splicing-correction, binding-"
                "affinity, efficacy, immunogenic or regulatory claim. "
                "Modalities are described via their own drug precedent "
                "only; nothing is derived from the n=6 lattice "
                "(g3 / f1 / f_lattice_fit). CROSS is NOT a new axis — "
                "the core-5 axis set (QUANTUM · WEAVE · NANOBOT · "
                "RIBOZYME · VIROCAPSID) is UNCHANGED. The two mechanism "
                "models are imported from their sister sims (no fork — "
                "f3)."
            ),
        },
    }


# ── self-check / demo ───────────────────────────────────────────────────


def _validate_row(row: Dict) -> List[str]:
    """Lightweight in-module shape check of a modality row (the JSON Schema
    in _python_bridge/spec/ is the authoritative contract)."""
    errs: List[str] = []
    required = (
        "schema_version", "modality", "axis_module", "axis_name",
        "drug_precedent", "mechanism", "mechanism_kind",
        "model_signal_name", "model_signal_value", "model_signal_units",
        "real_limit_anchor", "real_limit_citations", "in_silico_only",
    )
    for key in required:
        if key not in row:
            errs.append(f"missing key '{key}'")
    if row.get("schema_version") != SCHEMA_VERSION:
        errs.append("schema_version mismatch")
    if row.get("modality") not in ("OLIGONUCLEOTIDE", "APTAMER"):
        errs.append(f"unexpected modality {row.get('modality')!r}")
    if row.get("mechanism_kind") not in (
        "sequence-driven-hybridization", "shape-driven-fold-binding",
    ):
        errs.append(f"unexpected mechanism_kind {row.get('mechanism_kind')!r}")
    if not isinstance(row.get("model_signal_value"), (int, float)):
        errs.append("model_signal_value must be numeric")
    if not isinstance(row.get("real_limit_citations"), list) or \
            not row.get("real_limit_citations"):
        errs.append("real_limit_citations must be a non-empty list")
    if row.get("in_silico_only") is not True:
        errs.append("in_silico_only must be True")
    # Modality-specific: APTAMER must report k_cat = 0 (non-catalytic binder).
    if row.get("modality") == "APTAMER" and row.get("kcat_per_s") != 0.0:
        errs.append("APTAMER row must report kcat_per_s == 0.0 "
                    "(non-catalytic binder)")
    return errs


def _validate_unification(unif: Dict) -> List[str]:
    """Shape check for the unification row."""
    errs: List[str] = []
    required = (
        "shared_anchor", "shared_anchor_citation",
        "oligonucleotide_signal_name", "oligonucleotide_signal_value",
        "oligonucleotide_signal_units",
        "aptamer_signal_name", "aptamer_signal_value",
        "aptamer_signal_units",
        "mechanism_distinction", "aptamer_kcat_per_s",
    )
    for key in required:
        if key not in unif:
            errs.append(f"unification missing key '{key}'")
    if unif.get("aptamer_kcat_per_s") != 0.0:
        errs.append("unification.aptamer_kcat_per_s must be 0.0")
    if unif.get("oligonucleotide_signal_units", "").find("°C") < 0 and \
            unif.get("oligonucleotide_signal_units", "").find("C") < 0:
        errs.append("oligonucleotide_signal_units should reference Celsius")
    if "nM" not in unif.get("aptamer_signal_units", ""):
        errs.append("aptamer_signal_units should reference nM")
    return errs


def _selfcheck() -> int:
    print("aptamer_oligonucleotide_cross.py — CROSS-AXIS in-silico")
    print("  APTAMER × OLIGONUCLEOTIDE modality comparison")
    print("  (a) OLIGONUCLEOTIDE : sequence-driven Watson-Crick hybridization")
    print("        SantaLucia 1998 NN duplex Tm")
    print("        (nusinersen/Spinraza 2016; patisiran/Onpattro 2018;")
    print("         inclisiran 2021)")
    print("  (b) APTAMER         : shape-driven folded-pocket binder (k_cat=0)")
    print("        Nussinov fold + NN-stack ΔG; 1:1 Langmuir Kd")
    print("        (pegaptanib/Macugen 2004; avacincaptad pegol/Izervay 2023)")
    print()
    print("  REAL LIMITS (g1):")
    print("   - SHARED — nucleic-acid nearest-neighbor thermodynamics")
    print("     (SantaLucia 1998 PNAS 95:1460-1465)")
    print("   - APTAMER Kd anchor — thrombin DNA aptamer low/mid-nM")
    print("     (Bock LC et al. 1992 Nature 355:564-566)")
    print()
    print("  NO FORK (f3): both mechanism models IMPORTED from their sister")
    print("  sims — oligonucleotide_hybridization_sim.py + aptamer_affinity_sim.py.")
    print("  CROSS != NEW AXIS — core-5 axis set unchanged.")
    print()

    fails = 0
    comp = build_comparison()
    rows = comp["modality_rows"]

    for row in rows:
        errs = _validate_row(row)
        verdict = "PASS" if not errs else "FAIL"
        if errs:
            fails += 1
        print(f"  [{verdict}] modality row — {row['modality']}")
        print(f"         axis        = {row['axis_name']}")
        print(f"         module      = {row['axis_module']}")
        print(f"         mechanism   = {row['mechanism_kind']}")
        print(f"         precedent   = {row['drug_precedent']}")
        print(f"         model signal: {row['model_signal_name']} = "
              f"{row['model_signal_value']}")
        print(f"                       [{row['model_signal_units']}]")
        print(f"         real limit  = {row['real_limit_anchor']}")
        for cite in row["real_limit_citations"]:
            print(f"           cite: {cite}")
        for e in errs:
            print(f"         x {e}")

    # --- unification row check.
    print()
    unif = comp["unification_row"]
    unif_errs = _validate_unification(unif)
    if unif_errs:
        fails += 1
        print("  [FAIL] unification row")
        for e in unif_errs:
            print(f"         x {e}")
    else:
        print("  [PASS] unification row — shared anchor + mechanism-distinct outputs")
        print(f"         shared anchor : {unif['shared_anchor_citation']}")
        print(f"         ASO signal    : {unif['oligonucleotide_signal_name']} "
              f"= {unif['oligonucleotide_signal_value']} "
              f"[{unif['oligonucleotide_signal_units']}]")
        print(f"         aptamer signal: {unif['aptamer_signal_name']} "
              f"= {unif['aptamer_signal_value']} "
              f"[{unif['aptamer_signal_units']}]")
        print(f"         aptamer k_cat : {unif['aptamer_kcat_per_s']} "
              f"(non-catalytic binder)")

    # --- per-row self-consistency from the sister sims (no fork; reuse).
    # Recompute the aptamer row via the imported model_aptamer and verify
    # its own check_row passes (the sister's own gate).
    apt_row = model_aptamer(
        _APTAMER_NAME, _APTAMER_SEQ, _APTAMER_LIGAND,
        _APTAMER_KD_nM, _APTAMER_PAPER,
    )
    ok, msgs = aptamer_check_row(apt_row)
    if ok:
        print("  [PASS] aptamer sister-sim self-consistency "
              "(theta=0.5 at [L]=Kd; Kd=koff/kon; balanced fold; k_cat=0)")
    else:
        fails += 1
        print("  [FAIL] aptamer sister-sim self-consistency")
        for m in msgs:
            print(f"         x {m}")

    # --- the two signals must be reported as NON-commensurable + NOT ranking.
    print()
    if comp["comparison_is_ranking"] is False and \
            comp["signals_commensurable"] is False:
        print("  [PASS] comparison framing — descriptive side-by-side, "
              "NOT a ranking;")
        print("         signals declared non-commensurable "
              "(different units / different mechanisms despite shared backbone)")
    else:
        fails += 1
        print("  [FAIL] comparison framing — must NOT be a ranking")

    # --- both modalities anchored to their own real limit (g1) and share
    #     the SantaLucia NN backbone explicitly.
    oligo = rows[0]
    apt = rows[1]
    shared_ok = any("SantaLucia 1998" in c for c in oligo["real_limit_citations"]) \
        and any("SantaLucia 1998" in c for c in apt["real_limit_citations"])
    bock_ok = any("Bock" in c for c in apt["real_limit_citations"])
    if shared_ok and bock_ok:
        print("  [PASS] real-limit anchors — shared SantaLucia 1998 NN "
              "backbone cited on BOTH modalities;")
        print("         aptamer Kd additionally anchored to Bock 1992 thrombin "
              "DNA aptamer")
    else:
        fails += 1
        print("  [FAIL] real-limit anchors — shared SantaLucia + aptamer "
              "Bock anchor missing")

    # --- mechanism-distinction explicit (sequence-driven vs shape-driven).
    if oligo["mechanism_kind"] == "sequence-driven-hybridization" and \
            apt["mechanism_kind"] == "shape-driven-fold-binding":
        print("  [PASS] mechanism distinction — sequence-driven hybridization "
              "vs shape-driven fold-binding")
    else:
        fails += 1
        print("  [FAIL] mechanism distinction missing or mislabeled")

    # --- honesty block present and asserts comparison != ranking.
    h = comp["honesty"]
    if (h["in_silico_only"] and h["not_an_efficacy_ranking"]
            and h["not_a_superiority_claim"] and h["not_a_clinical_claim"]
            and h["both_modalities_have_fda_precedent"]
            and h["cross_is_not_a_new_axis"]
            and h["no_fork_of_sister_sims"]):
        print("  [PASS] honesty block — in-silico-only, not a ranking, "
              "not a superiority claim, cross != new axis, no fork")
    else:
        fails += 1
        print("  [FAIL] honesty block — missing a required honesty flag")

    # --- determinism: byte-identical re-run (deductive-verification).
    if json.dumps(build_comparison(), sort_keys=True) == \
            json.dumps(build_comparison(), sort_keys=True):
        print("  [PASS] determinism — byte-identical re-run")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift between runs")

    print()
    print("  ── comparison summary (descriptive — NOT a ranking) ──")
    print(f"  shared chemistry : {comp['shared_chemistry']}")
    print(f"  shared anchor    : {comp['shared_anchor_citation']}")
    print(f"  (a) OLIGONUCLEOTIDE signal "
          f"{oligo['model_signal_name']} = {oligo['model_signal_value']}")
    print(f"                       [{oligo['model_signal_units']}]")
    print(f"  (b) APTAMER         signal "
          f"{apt['model_signal_name']} = {apt['model_signal_value']}")
    print(f"                       [{apt['model_signal_units']}]")
    print("  Same nucleic-acid chemistry, opposite mechanism — reported")
    print("  side by side, NOT ranked.")

    print()
    print("  ── in-silico honesty caveat (governance g8 / f2 / g3 / f1) ──")
    print("  This is a MODALITY COMPARISON of two in-silico model")
    print("  signatures — NOT an efficacy ranking, NOT a claim that one")
    print("  modality or drug is superior, NOT a clinical claim. Both the")
    print("  OLIGONUCLEOTIDE modality (nusinersen/Spinraza 2016; patisiran/")
    print("  Onpattro 2018; inclisiran 2021) and the APTAMER modality")
    print("  (pegaptanib/Macugen 2004; avacincaptad pegol/Izervay 2023) have")
    print("  independent FDA-approved drug precedent. Every PASS certifies")
    print("  in-silico simulator + metadata internal consistency ONLY.")
    print("  Modalities are described via their own drug precedent only —")
    print("  nothing is derived from the n=6 lattice (g3 / f1 / f_lattice_fit).")
    print("  The toy target-mRNA window is a deterministic illustrative")
    print("  construct, not a real mRNA region; the wet-lab boundary is out")
    print("  of repo scope (CLOSURE_RESIDUAL_BACKLOG.md §0).")
    print()

    # 2 modality rows + 1 unification + 1 sister-sim check
    # + 1 framing + 1 anchors + 1 mechanism + 1 honesty + 1 determinism
    total = len(rows) + 7
    passed = total - fails
    if fails == 0:
        print(f"  --- summary --- {passed} / {total} checks PASS "
              f"-> verdict: PASS")
        print(SENTINEL_PASS)
        return 0
    print(f"  --- summary --- {fails} FAIL -> verdict: FAIL")
    print(SENTINEL_FAIL)
    return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
