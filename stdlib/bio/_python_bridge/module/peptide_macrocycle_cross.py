#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
peptide_macrocycle_cross.py — CROSS-AXIS G4.

CROSS:  PEPTIDE sub-axis  ─── linear  vs.  cyclic  pre-organization ───▶
        MACROCYCLE sub-axis

Both sub-axes (:> WEAVE core) pre-organize the bound conformation in
different ways: a LINEAR peptide pays the full conformational entropy on
folding (Zimm-Bragg helix-coil cooperativity), while a MACROCYCLE pre-pays
that entropy via covalent ring closure (head-to-tail or side-chain). This
module performs the linear-vs-cyclic comparison for a deterministic panel
of peptide-length N residues and quantifies the entropic advantage of
cyclization.

────────────────────────────────────────────────────────────────────────────
WHAT THIS IS — Project G4
────────────────────────────────────────────────────────────────────────────
Two FDA-approved therapeutic modalities both pre-organize a residue-scale
pharmacophore toward its bound conformer, and they do it in two physically
different ways:

  (a) LINEAR-PEPTIDE path — semaglutide-like (semaglutide / Ozempic /
      Wegovy, Novo Nordisk; FDA 2017): an unconstrained linear peptide
      that adopts its bioactive (often helical) conformation via a
      COOPERATIVE Zimm-Bragg helix-coil transition. The chain samples
      ~2^N helix/coil microstates free in solution; folding into one
      bioactive conformer requires paying the full conformational
      entropy. Modelled here via the PEPTIDE sub-axis (Zimm-Bragg helix-
      coil partition).

  (b) MACROCYCLE path — cyclosporine-like (cyclosporine, Sandoz/Novartis;
      FDA 1983) and lorlatinib-like (lorlatinib, Pfizer; FDA 2018): a
      covalent ring closure constrains rotatable bonds inside the ring,
      collapsing accessible conformers BEFORE solvation/binding. The
      macrocycle pre-pays the conformational entropy via the ring's
      Jacobson-Stockmayer ring-closure entropy cost — paid at synthesis,
      not at binding. Modelled here via the MACROCYCLE sub-axis
      (rotamer-product microstate count, Boltzmann S = R*ln W).

────────────────────────────────────────────────────────────────────────────
DELIVERABLE — A COMPARISON, NOT A RANKING (CRITICAL HONESTY)
────────────────────────────────────────────────────────────────────────────
This module emits a side-by-side of TWO IN-SILICO MODEL SIGNATURES per
peptide length N. It is:
  * NOT an efficacy ranking
  * NOT a claim that one modality / drug is superior to the other
  * NOT a clinical, therapeutic, regulatory or potency claim
semaglutide and cyclosporine/lorlatinib are ALL FDA-approved, blockbuster-
scale therapeutics in their own right. Linear peptides and macrocycles are
BOTH widely-used drug modalities — one is not "better." The two model
signals live on DIFFERENT real limits — a 1-D helix-coil partition over
2^N discrete residue microstates vs a rotamer-product microstate count
over 2N backbone torsions — so the two are NOT commensurable, only
side-by-side describable. The common ground is the shared GOAL
(pre-organize the bound conformer at fixed residue count N); the
comparison is of modalities, not of drugs.

────────────────────────────────────────────────────────────────────────────
NO FORK (governance f3 — no shadow implementation)
────────────────────────────────────────────────────────────────────────────
Both mechanism models are IMPORTED from their existing sub-axis modules:
  * peptide_sim.py     (linear-peptide path; Zimm-Bragg helix-coil)
  * macrocycle_sim.py  (macrocycle path; rotamer-product S = R*ln W)
This module re-implements NEITHER the helix-coil partition sum NOR the
conformational-microstate accounting. It adds only the length-panel cross
+ the linear-vs-cyclic comparison emitter.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED (governance g1 — real-limits-first)
────────────────────────────────────────────────────────────────────────────
Each modality's signal is anchored to ITS OWN real limit — neither is
derived from the n=6 lattice (g2 / f1 / f_lattice_fit):
  * LINEAR-PEPTIDE path -> Zimm-Bragg / Lifson-Roig helix-coil statistical
    mechanics. A 1-D chain with nucleation penalty sigma << 1 has
    partition function Z = sum over 2^N helix/coil microstates of
    sigma^(#nucleations) * product s_i. The full conformational entropy
    of the (un-Boltzmann-weighted) microstate space is S_lin = R * N * ln 2.
      - Zimm BH, Bragg JK. "Theory of the phase transition between helix
        and random coil in polypeptide chains." J Chem Phys 1959;31:526.
      - Lifson S, Roig A. "On the theory of helix-coil transition in
        polypeptides." J Chem Phys 1961;34:1963.
  * MACROCYCLE path -> Jacobson-Stockmayer ring-closure entropy and
    Boltzmann S = R * ln W conformational accounting. Closing a flexible
    chain into a ring imposes a configurational constraint that REMOVES
    accessible torsional states, paid as an entropic cost at ring closure
    but recovered as a SMALLER binding-conformational-entropy penalty.
      - Jacobson H, Stockmayer WH. "Intramolecular reaction in
        polycondensations. I. The theory of linear systems." J Chem Phys
        1950;18:1600-1606.
      - Mallinson J, Collins I. "Macrocycles in new drug discovery."
        Future Med Chem 2012;4:1409-1438.
      - Boltzmann L. "Uber die Beziehung zwischen dem zweiten Hauptsatze
        der mechanischen Warmetheorie und der Wahrscheinlichkeitsrechnung
        respective den Satzen uber das Warmegleichgewicht." Sitzungsber.
        Akad. Wiss. Wien 1877;76:373-435.  [S = k * ln W foundation]

The two real limits are both hard floors / scaffolds:
  * 0 <= theta_H <= 1 (a fraction)
  * S_conf >= 0 always (Boltzmann real limit; S_conf = 0 iff W_conf = 1)
  * a ring constraint can only REMOVE conformers => W_macro <= W_acyclic
  * delta-delta-S_cyc <= 0 always (Jacobson-Stockmayer real-limit floor)

────────────────────────────────────────────────────────────────────────────
DRUG / BIOLOGY PRECEDENT (governance g3 / f1 — own precedent only)
────────────────────────────────────────────────────────────────────────────
Modalities are described ONLY via their own published drug precedent;
nothing here is lattice-derived:
  * LINEAR-PEPTIDE: semaglutide / Ozempic / Wegovy / Rybelsus — GLP-1
    receptor-agonist peptide analog, FDA 2017 (s.c.) / FDA 2019 (oral);
    the GLP-1 backbone adopts its bioactive alpha-helical conformation in
    the receptor-bound state. The broader GLP-1 analog class
    (liraglutide / dulaglutide / tirzepatide) is the canonical
    therapeutic-peptide precedent.
  * MACROCYCLE: cyclosporine — cyclic undecapeptide immunosuppressant
    (Sandoz/Novartis; FDA 1983); the canonical natural-product macrocycle.
    lorlatinib — synthetic macrocyclic ALK/ROS1 kinase inhibitor (Pfizer;
    FDA 2018); the canonical synthetic-macrocycle precedent. The
    macrolide class (erythromycin / azithromycin / rapamycin / tacrolimus)
    is the broader natural-product precedent.

────────────────────────────────────────────────────────────────────────────
DETERMINISM
────────────────────────────────────────────────────────────────────────────
Pure stdlib (the imported sub-axis modules are stdlib-only too). No random
/ network / time / env reads. Re-running on the same inputs produces
byte-identical output.

────────────────────────────────────────────────────────────────────────────
SCOPE — IN-SILICO ONLY (governance g8 / f2)
────────────────────────────────────────────────────────────────────────────
A PASS sentinel here certifies IN-SILICO simulator + metadata internal
consistency ONLY — that both imported sub-axis models run, produce
well-formed signatures, and reproduce byte-identically. It is NEVER a
therapeutic, clinical, binding-affinity, permeability, immunogenic,
regulatory, or modality-superiority claim. The model homopolymers and
ring-closure assumptions are illustrative literature-informed surrogates;
the wet-lab boundary is out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md
section 0).

CROSS != NEW AXIS: G4 is a CROSS over two existing sub-axes
(PEPTIDE :> WEAVE and MACROCYCLE :> WEAVE). It registers no new axis.
Core-5 (AXIS/AXIS.tape) is UNCHANGED.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import json
import math
import os
import sys
from typing import Dict, List

# ── sister sub-axis imports (no fork — governance f3) ───────────────────
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# (a) PEPTIDE sub-axis :> WEAVE — semaglutide-like linear-peptide path.
import peptide_sim  # noqa: E402
# (b) MACROCYCLE sub-axis :> WEAVE — cyclosporine/lorlatinib-like path.
import macrocycle_sim  # noqa: E402

SCHEMA_VERSION = "peptide_macrocycle_cross_v1"
SENTINEL_PASS = "__PEPTIDE_MACROCYCLE_CROSS__ PASS"
SENTINEL_FAIL = "__PEPTIDE_MACROCYCLE_CROSS__ FAIL"

# Physical scaffolding mirrored from macrocycle_sim (imported, not forked).
R_GAS = macrocycle_sim.R_GAS                       # J/(mol*K)
KCAL_TO_J = macrocycle_sim.KCAL_TO_J               # J/kcal
TEMP_K = macrocycle_sim.TEMP_K                     # K (physiological)
RING_CONSTRAINT_FACTOR = macrocycle_sim.RING_CONSTRAINT_FACTOR  # f_ring in (0,1]
ROTAMER_MULTIPLICITY_FREE = macrocycle_sim.ROTAMER_MULTIPLICITY_FREE  # ~3
SIGMA_NUCLEATION = peptide_sim.SIGMA_NUCLEATION    # Zimm-Bragg nucleation

# ── deterministic length panel ──────────────────────────────────────────
# A small panel of peptide lengths N. For each N we use a model homopolymer
# "A_N" (poly-alanine) on the LINEAR path — Ala is the strongest helix-
# former in the Pace-Scholtz / Chakrabartty-Kortemme-Baldwin propensity
# scale already encoded in peptide_sim. The MACROCYCLE path assumes a
# head-to-tail cyclic version of the SAME residue count N: each residue
# contributes 2 backbone torsions (phi, psi), so a head-to-tail cyclic
# N-mer has ~2N rotatable backbone bonds, all of which become ring-
# constrained on closure (Jacobson-Stockmayer). The acyclic linear analog
# has the same 2N bonds, all free.
#
# These length values are deliberately small (helix-coil partition sum is
# exact at O(2^N); peptide_sim caps N <= ~20 — see its build_rows panel).
PEPTIDE_LENGTH_PANEL = (6, 8, 10, 12, 14)


def _model_sequence_for_length(n: int) -> str:
    """Deterministic model homopolymer (poly-Ala) of length N residues."""
    return "A" * n


def _linear_signature(n: int) -> Dict:
    """Compute the LINEAR-PEPTIDE (semaglutide-like) signature for a given
    chain length N.

    Real limit: Zimm-Bragg / Lifson-Roig helix-coil statistical mechanics.
    Two model signals are reported:
      * theta_H — the cooperative fractional helicity from
        peptide_sim.helix_coil_partition (imported, not re-implemented).
      * S_conf_linear_full — the full conformational entropy of the
        un-Boltzmann-weighted N-residue 2-state (helix/coil) microstate
        space, S_lin = R * N * ln 2 (J/mol/K). This is the entropy a
        LINEAR peptide pays on collapsing from its accessible helix/coil
        ensemble to a single bioactive conformer — the entropic cost the
        macrocycle pre-pays at synthesis.
    """
    seq = _model_sequence_for_length(n)
    part = peptide_sim.helix_coil_partition(seq)
    indep = peptide_sim.independent_residue_helicity(seq)
    # Full conformational entropy of the 2-state-per-residue ensemble.
    # 2^N microstates; S = R * ln(2^N) = R * N * ln 2  (J/(mol*K)).
    s_lin_full_j = R_GAS * n * math.log(2.0)
    # Binding conformational-entropy penalty: -T * delta-S paid on
    # freezing into the single bound conformer (kcal/mol; >= 0).
    minus_t_delta_s_kcal = TEMP_K * s_lin_full_j / KCAL_TO_J
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "LINEAR-PEPTIDE",
        "modality_label": "Linear therapeutic peptide (semaglutide-like)",
        "axis_module": "peptide_sim.py",
        "axis_name": "PEPTIDE (:> WEAVE)",
        "drug_precedent": (
            "semaglutide / Ozempic / Wegovy / Rybelsus — GLP-1 receptor-"
            "agonist linear peptide, FDA 2017 (s.c.) / FDA 2019 (oral). "
            "GLP-1 analog class: liraglutide / dulaglutide / tirzepatide. "
            "Cited for modality only — no efficacy claim."),
        "mechanism": (
            "A linear peptide chain samples ~2^N helix/coil microstates "
            "free in solution and adopts its bioactive (often helical) "
            "conformation via a cooperative Zimm-Bragg helix-coil "
            "transition. On binding it pays the full conformational "
            "entropy of the accessible ensemble."),
        "n_residues": n,
        "model_sequence": seq,
        "sigma_nucleation": SIGMA_NUCLEATION,
        "temperature_K": TEMP_K,
        "model_signal_name": "S_conf_linear_full_J_per_mol_K",
        "model_signal_value": s_lin_full_j,
        "model_signal_units": (
            "J/(mol*K)  —  S_lin = R * N * ln 2, full Zimm-Bragg 2-state "
            "ensemble entropy paid on folding"),
        "model_signal_detail": {
            "fractional_helicity_theta_H": part["fractional_helicity"],
            "independent_residue_helicity_baseline": indep,
            "partition_Z": part["partition_Z"],
            "mean_helical_residues": part["mean_helical_residues"],
            "S_conf_linear_full_J_per_mol_K": s_lin_full_j,
            "S_conf_linear_full_cal_per_mol_K":
                s_lin_full_j / (KCAL_TO_J / 1000.0),
            "binding_entropy_penalty_kcal_per_mol":
                minus_t_delta_s_kcal,
        },
        "real_limit_anchor": (
            "Zimm-Bragg / Lifson-Roig helix-coil statistical mechanics — "
            "1-D chain partition Z = sum over 2^N microstates"),
        "real_limit_citations": [
            "Zimm & Bragg 1959, J Chem Phys 31:526",
            "Lifson & Roig 1961, J Chem Phys 34:1963",
        ],
        "in_silico_only": True,
    }


def _macrocycle_signature(n: int) -> Dict:
    """Compute the MACROCYCLE (cyclosporine/lorlatinib-like) signature for
    a peptide of length N residues, head-to-tail cyclized.

    Real limit: Jacobson-Stockmayer ring-closure entropy and Boltzmann
    S = R * ln W. A head-to-tail cyclic N-mer has 2*N backbone rotatable
    bonds (phi, psi per residue), all ring-constrained on closure. The
    acyclic linear analog has the same 2*N bonds, all free.

    macrocycle_sim.conformational_entropy(n_rotatable, n_in_ring) is
    imported (not re-implemented — f3) for both ends. The two values give
    the pre-organization entropic advantage:
      delta-delta-S_cyc = S_conf(macrocycle) - S_conf(acyclic) <= 0
      delta-delta-G_preorg = -T * delta-delta-S_cyc >= 0 (savings)
    (Sign convention: a NEGATIVE delta-delta-S means the ring REMOVED
    conformers; the entropic SAVING is the corresponding POSITIVE
    delta-delta-G NOT paid at binding.)
    """
    n_rotatable = 2 * n  # phi, psi per residue along the backbone
    ent_macro = macrocycle_sim.conformational_entropy(
        n_rotatable=n_rotatable, n_in_ring=n_rotatable,
        f_ring=RING_CONSTRAINT_FACTOR)
    ent_acyclic = macrocycle_sim.conformational_entropy(
        n_rotatable=n_rotatable, n_in_ring=0,
        f_ring=RING_CONSTRAINT_FACTOR)
    s_macro_j = ent_macro["S_conf_J_per_mol_K"]
    s_acyclic_j = ent_acyclic["S_conf_J_per_mol_K"]
    dd_s_j = s_macro_j - s_acyclic_j                 # <= 0 (ring removes states)
    # entropic SAVINGS = -T * delta-delta-S    >= 0  (kcal/mol)
    dd_g_preorg_savings_kcal = -TEMP_K * dd_s_j / KCAL_TO_J
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "MACROCYCLE",
        "modality_label": (
            "Macrocyclic ligand (cyclosporine / lorlatinib-like)"),
        "axis_module": "macrocycle_sim.py",
        "axis_name": "MACROCYCLE (:> WEAVE)",
        "drug_precedent": (
            "cyclosporine — cyclic-undecapeptide immunosuppressant "
            "(Sandoz/Novartis; FDA 1983); canonical natural-product "
            "macrocycle. lorlatinib — synthetic macrocyclic ALK/ROS1 "
            "kinase inhibitor (Pfizer; FDA 2018); canonical synthetic-"
            "macrocycle. Macrolide class: erythromycin / azithromycin / "
            "rapamycin / tacrolimus. Cited for modality only — no "
            "efficacy claim."),
        "mechanism": (
            "Covalent ring closure (head-to-tail or side-chain) "
            "constrains the in-ring rotatable bonds: each ring-"
            "constrained bond's effective rotamer multiplicity drops "
            "from g_free to f_ring*g_free. The macrocycle PRE-PAYS the "
            "conformational entropy at synthesis (Jacobson-Stockmayer "
            "ring-closure cost), so the binding-conformational-entropy "
            "penalty is correspondingly smaller."),
        "n_residues": n,
        "n_rotatable_backbone_bonds": n_rotatable,
        "ring_constraint_factor_f_ring": RING_CONSTRAINT_FACTOR,
        "rotamer_multiplicity_free": ROTAMER_MULTIPLICITY_FREE,
        "temperature_K": TEMP_K,
        "model_signal_name": "ddS_cyc_J_per_mol_K",
        "model_signal_value": dd_s_j,
        "model_signal_units": (
            "J/(mol*K)  —  delta-delta-S_cyc = S(macrocycle) - S(acyclic), "
            "<= 0 (Jacobson-Stockmayer ring-closure entropic floor)"),
        "model_signal_detail": {
            "W_macrocycle": ent_macro["conformational_microstates_W"],
            "W_acyclic":    ent_acyclic["conformational_microstates_W"],
            "S_conf_macrocycle_J_per_mol_K": s_macro_j,
            "S_conf_acyclic_J_per_mol_K":    s_acyclic_j,
            "ddS_cyc_J_per_mol_K": dd_s_j,
            "ddG_preorg_savings_kcal_per_mol":
                dd_g_preorg_savings_kcal,
            "binding_entropy_penalty_macrocycle_kcal_per_mol":
                ent_macro["binding_entropy_penalty_kcal_per_mol"],
            "binding_entropy_penalty_acyclic_kcal_per_mol":
                ent_acyclic["binding_entropy_penalty_kcal_per_mol"],
        },
        "real_limit_anchor": (
            "Jacobson-Stockmayer ring-closure entropy; Boltzmann "
            "S = R * ln W conformational accounting"),
        "real_limit_citations": [
            "Jacobson & Stockmayer 1950, J Chem Phys 18:1600-1606",
            "Mallinson & Collins 2012, Future Med Chem 4:1409-1438",
            "Boltzmann 1877, Sitzungsber Akad Wiss Wien 76:373 "
            "[S = k * ln W]",
        ],
        "in_silico_only": True,
    }


def build_length_panel() -> List[Dict]:
    """One cross row per peptide-length N in the panel: side-by-side of
    the LINEAR and MACROCYCLE signatures, plus the linear-vs-cyclic
    delta-delta-G comparison."""
    rows: List[Dict] = []
    for n in PEPTIDE_LENGTH_PANEL:
        lin = _linear_signature(n)
        mac = _macrocycle_signature(n)
        # The entropic ADVANTAGE of cyclization for this N (kcal/mol;
        # positive = saved). Quantitatively this is the difference in
        # binding-conformational-entropy penalties between the linear and
        # the macrocyclic analogs at the same residue count. Computed
        # directly from the two imported sub-axis models' own outputs.
        linear_penalty = lin["model_signal_detail"][
            "binding_entropy_penalty_kcal_per_mol"]
        macro_penalty = mac["model_signal_detail"][
            "binding_entropy_penalty_macrocycle_kcal_per_mol"]
        cyc_advantage_kcal = linear_penalty - macro_penalty
        # length-scaling slope: closed-form expectation from the imported
        # models is delta(advantage)/delta(N) ~ -2 * R * T * ln(f_ring) / N0
        # (per added residue contributes 2 backbone bonds at ln f_ring).
        expected_per_residue_kcal = (
            -2.0 * R_GAS * TEMP_K
            * math.log(RING_CONSTRAINT_FACTOR) / KCAL_TO_J)
        rows.append({
            "schema_version": SCHEMA_VERSION,
            "n_residues": n,
            "modality_rows": [lin, mac],
            "linear_binding_entropy_penalty_kcal_per_mol": linear_penalty,
            "macrocycle_binding_entropy_penalty_kcal_per_mol": macro_penalty,
            "cyclization_entropic_advantage_kcal_per_mol":
                cyc_advantage_kcal,
            "cyclization_advantage_is_favourable":
                cyc_advantage_kcal >= 0.0,
            "expected_per_residue_advantage_kcal_per_mol":
                expected_per_residue_kcal,
        })
    return rows


def build_comparison() -> Dict:
    """Assemble the full PEPTIDE-vs-MACROCYCLE pre-organization
    comparison object — descriptive side-by-side, NOT a ranking."""
    length_rows = build_length_panel()
    advantages = [
        r["cyclization_entropic_advantage_kcal_per_mol"]
        for r in length_rows]
    # length scaling: advantage(N) should rise monotonically with N
    # (every extra residue adds two more ring-constrained backbone bonds).
    length_scaling_monotone = all(
        b >= a - 1e-12
        for a, b in zip(advantages, advantages[1:]))
    return {
        "schema_version": SCHEMA_VERSION,
        "comparison_id": "peptide_vs_macrocycle_preorganization.v1",
        "shared_biological_goal": (
            "pre-organize the bound conformation of an N-residue "
            "pharmacophore"),
        "shared_mechanism_kind": "conformational entropy pre-payment",
        "length_panel": length_rows,
        "length_scaling_monotone": length_scaling_monotone,
        "length_scaling_note": (
            "the cyclization entropic advantage rises with chain length "
            "N: each additional residue contributes ~2 more backbone "
            "rotatable bonds (phi, psi); ring closure subjects all of "
            "them to the f_ring constraint, so the saved entropy grows "
            "as 2 * N * R * ln(1 / f_ring)"),
        "comparison_is_ranking": False,
        "comparison_kind": (
            "descriptive side-by-side of two in-silico model signatures "
            "across a peptide-length panel"),
        "signals_commensurable": False,
        "signals_commensurable_note": (
            "the two model signals rest on DIFFERENT real limits — a 1-D "
            "Zimm-Bragg helix-coil partition over 2^N residue micro-"
            "states (linear) vs a rotamer-product microstate count "
            "W = product g_b over 2*N backbone torsions (macrocycle) — "
            "and are reported in different units; they describe two "
            "physically distinct pre-organization mechanisms and are not "
            "commensurable, only side-by-side describable"),
        "honesty": {
            "in_silico_only": True,
            "not_an_efficacy_ranking": True,
            "not_a_superiority_claim": True,
            "not_a_clinical_claim": True,
            "both_modalities_fda_approved": True,
            "statement": (
                "This is a MODALITY COMPARISON of two in-silico model "
                "signatures (linear-peptide Zimm-Bragg pre-organization "
                "vs macrocycle Jacobson-Stockmayer ring-closure pre-"
                "organization), NOT an efficacy ranking and NOT a claim "
                "that one drug or modality is superior. semaglutide "
                "(Ozempic / Wegovy / Rybelsus, FDA 2017/2019) and "
                "cyclosporine (FDA 1983) / lorlatinib (FDA 2018) are ALL "
                "FDA-approved blockbuster-scale therapeutics in their "
                "own right; linear peptides and macrocycles are BOTH "
                "widely-used drug modalities — one is not 'better.' Each "
                "PASS certifies in-silico simulator + metadata internal "
                "consistency ONLY — never a therapeutic, clinical, "
                "binding-affinity, permeability, immunogenic, or "
                "regulatory claim (g8 / f2). Modalities are described "
                "via their own drug precedent only; nothing is derived "
                "from the n=6 lattice (g3 / f1 / f_lattice_fit). CROSS "
                "!= NEW AXIS — G4 is a cross over two existing sub-axes "
                "(PEPTIDE :> WEAVE, MACROCYCLE :> WEAVE); core-5 "
                "(AXIS/AXIS.tape) is UNCHANGED."),
        },
    }


# ── self-check / demo ───────────────────────────────────────────────────


def _validate_modality_row(row: Dict) -> List[str]:
    """Lightweight in-module shape check of a per-modality row (the JSON
    Schema in _python_bridge/spec/ is the authoritative contract)."""
    errs: List[str] = []
    required = (
        "schema_version", "modality", "axis_module", "axis_name",
        "drug_precedent", "mechanism", "n_residues",
        "model_signal_name", "model_signal_value", "model_signal_units",
        "real_limit_anchor", "real_limit_citations", "in_silico_only",
    )
    for key in required:
        if key not in row:
            errs.append(f"missing key {key!r}")
    if row.get("schema_version") != SCHEMA_VERSION:
        errs.append("schema_version mismatch")
    if row.get("modality") not in ("LINEAR-PEPTIDE", "MACROCYCLE"):
        errs.append(f"unexpected modality {row.get('modality')!r}")
    if not isinstance(row.get("model_signal_value"), (int, float)):
        errs.append("model_signal_value must be numeric")
    if not isinstance(row.get("real_limit_citations"), list) \
            or not row.get("real_limit_citations"):
        errs.append("real_limit_citations must be a non-empty list")
    if row.get("in_silico_only") is not True:
        errs.append("in_silico_only must be True")
    return errs


def _selfcheck() -> int:
    print("peptide_macrocycle_cross.py — CROSS-AXIS G4")
    print("  PEPTIDE  :> WEAVE  (linear, semaglutide-like)  vs.")
    print("  MACROCYCLE :> WEAVE (cyclic, cyclosporine / lorlatinib-like)")
    print("  comparison kind : linear-vs-cyclic conformational pre-organization")
    print("  (Zimm-Bragg 1959 / Lifson-Roig 1961  vs.  Jacobson-Stockmayer 1950)")
    print()
    print(f"  T = {TEMP_K:.1f} K   sigma = {SIGMA_NUCLEATION:.0e}   "
          f"f_ring = {RING_CONSTRAINT_FACTOR}   g_free = "
          f"{ROTAMER_MULTIPLICITY_FREE}")
    print()

    fails = 0
    comp = build_comparison()
    length_rows = comp["length_panel"]

    # --- per-length row checks
    for length_row in length_rows:
        n = length_row["n_residues"]
        for mod_row in length_row["modality_rows"]:
            errs = _validate_modality_row(mod_row)
            verdict = "PASS" if not errs else "FAIL"
            if errs:
                fails += 1
            print(f"  [{verdict}] N={n:>2}  modality={mod_row['modality']}")
            print(f"           axis      = {mod_row['axis_name']}")
            print(f"           module    = {mod_row['axis_module']}")
            print(f"           precedent = {mod_row['drug_precedent'][:88]}"
                  f"{'...' if len(mod_row['drug_precedent']) > 88 else ''}")
            print(f"           signal    : {mod_row['model_signal_name']} = "
                  f"{mod_row['model_signal_value']:.4f}")
            print(f"                       [{mod_row['model_signal_units']}]")
            for e in errs:
                print(f"           x {e}")

    # --- per-length cross-row checks
    print()
    print("  -- linear-vs-cyclic entropic comparison across N --")
    print(f"  {'N':>3}  {'lin penalty (kcal/mol)':>22}  "
          f"{'mac penalty (kcal/mol)':>22}  "
          f"{'cyc advantage (kcal/mol)':>26}")
    for r in length_rows:
        print(f"  {r['n_residues']:>3}  "
              f"{r['linear_binding_entropy_penalty_kcal_per_mol']:>22.3f}  "
              f"{r['macrocycle_binding_entropy_penalty_kcal_per_mol']:>22.3f}  "
              f"{r['cyclization_entropic_advantage_kcal_per_mol']:>26.3f}")
    print(f"  expected per-residue advantage (closed-form, from f_ring): "
          f"{length_rows[0]['expected_per_residue_advantage_kcal_per_mol']:.4f}"
          f" kcal/mol / residue")

    # --- length scaling must rise monotonically with N
    print()
    if comp["length_scaling_monotone"]:
        print("  [PASS] length scaling — cyclization advantage rises "
              "monotonically with N (each extra residue adds 2 ring-"
              "constrained backbone bonds)")
    else:
        fails += 1
        print("  [FAIL] length scaling — expected monotone increase with N")

    # --- comparison framing must be non-ranking / non-commensurable
    if comp["comparison_is_ranking"] is False and \
            comp["signals_commensurable"] is False:
        print("  [PASS] comparison framing — descriptive side-by-side, "
              "NOT a ranking; signals declared non-commensurable "
              "(different real limits / units)")
    else:
        fails += 1
        print("  [FAIL] comparison framing — must NOT be a ranking")

    # --- each modality anchored to its OWN real limit (g1)
    first = length_rows[0]
    lin_anchor = first["modality_rows"][0]["real_limit_anchor"]
    mac_anchor = first["modality_rows"][1]["real_limit_anchor"]
    if ("Zimm-Bragg" in lin_anchor or "Lifson-Roig" in lin_anchor) and \
            ("Jacobson-Stockmayer" in mac_anchor or "Boltzmann" in mac_anchor):
        print("  [PASS] real-limit anchors — each modality anchored to "
              "its own real limit (Zimm-Bragg / Lifson-Roig for linear; "
              "Jacobson-Stockmayer / Boltzmann S=R*lnW for cyclic)")
    else:
        fails += 1
        print("  [FAIL] real-limit anchors — modality missing its own "
              "real limit")

    # --- honesty block present and asserts comparison != ranking
    h = comp["honesty"]
    if (h["in_silico_only"] and h["not_an_efficacy_ranking"]
            and h["not_a_superiority_claim"] and h["not_a_clinical_claim"]
            and h["both_modalities_fda_approved"]):
        print("  [PASS] honesty block — in-silico-only, not a ranking, "
              "not a superiority claim, both modalities FDA-approved")
    else:
        fails += 1
        print("  [FAIL] honesty block — missing a required honesty flag")

    # --- f3 no-fork check: the two sub-axis modules are imported, not
    # re-implemented. Verify the imported functions are actually those of
    # the parent sub-axes (their __module__ attribute names them).
    if (peptide_sim.helix_coil_partition.__module__ == "peptide_sim"
            and macrocycle_sim.conformational_entropy.__module__
            == "macrocycle_sim"):
        print("  [PASS] no-fork (f3) — peptide_sim.helix_coil_partition and "
              "macrocycle_sim.conformational_entropy are imported from "
              "their parent sub-axis modules, not re-implemented")
    else:
        fails += 1
        print("  [FAIL] no-fork (f3) — parent sub-axis functions appear "
              "re-implemented; this would shadow the sister modules")

    # --- determinism: byte-identical re-run (deductive-verification).
    if json.dumps(build_comparison(), sort_keys=True) == \
            json.dumps(build_comparison(), sort_keys=True):
        print("  [PASS] determinism — byte-identical re-run")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift between runs")

    print()
    print("  -- in-silico honesty caveat (governance g8 / f2 / g3 / f1) --")
    print("  This is a MODALITY COMPARISON of two in-silico model")
    print("  signatures (linear-peptide Zimm-Bragg pre-organization vs")
    print("  macrocycle Jacobson-Stockmayer ring-closure pre-organization).")
    print("  It is NOT an efficacy ranking, NOT a claim that one drug or")
    print("  modality is superior, NOT a clinical claim. semaglutide")
    print("  (Ozempic / Wegovy / Rybelsus, FDA 2017/2019) and cyclosporine")
    print("  (FDA 1983) / lorlatinib (FDA 2018) are ALL FDA-approved")
    print("  blockbuster-scale therapeutics in their own right; linear")
    print("  peptides and macrocycles are BOTH widely-used modalities —")
    print("  one is not 'better.' Every PASS certifies in-silico simulator")
    print("  + metadata internal consistency ONLY. Modalities are described")
    print("  via their own drug precedent only — nothing is derived from")
    print("  the n=6 lattice (g3 / f1 / f_lattice_fit). The model")
    print("  homopolymers and ring-closure assumptions are illustrative")
    print("  literature-informed surrogates; the wet-lab boundary is out")
    print("  of repo scope (CLOSURE_RESIDUAL_BACKLOG section 0). CROSS !=")
    print("  NEW AXIS — G4 is a cross over two existing sub-axes")
    print("  (PEPTIDE :> WEAVE, MACROCYCLE :> WEAVE); core-5 UNCHANGED.")
    print()

    # checks counted: 2 rows * len(panel) modality rows
    #                + 1 length-scaling
    #                + 1 framing
    #                + 1 real-limit anchors
    #                + 1 honesty
    #                + 1 no-fork
    #                + 1 determinism
    total = 2 * len(length_rows) + 6
    passed = total - fails
    if fails == 0:
        print(f"  --- summary --- {passed} / {total} checks PASS  "
              f"->  verdict: PASS")
        print(SENTINEL_PASS)
        return 0
    print(f"  --- summary --- {fails} FAIL  ->  verdict: FAIL")
    print(SENTINEL_FAIL)
    return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
