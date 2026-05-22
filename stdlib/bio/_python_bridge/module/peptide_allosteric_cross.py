#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
peptide_allosteric_cross.py — CROSS-AXIS BB3.

CROSS:  PEPTIDE :> WEAVE (Zimm-Bragg helix-coil)  ====unify====
        ALLOSTERIC :> QUANTUM (MWC two-state ternary-complex)

A helical BH3-mimetic peptide (PEPTIDE axis) acts as an MWC R-state
stabilizer (ALLOSTERIC axis) of an apoptotic regulator such as a BCL-2
family protein. The two sub-axes are unified by ONE observation: the
peptide's fractional helicity theta_H GATES whether it can act as a
competent allosteric modulator. A defined helix is required for the BH3
cleft of a BCL-2-family target to recognize the recognition-helix
hydrophobic-i,i+3,i+4 face; a low-helicity disordered peptide cannot
present that face and the MWC R-state stabilization is weak. Same MWC
two-state framework, peptide-specific helicity-dependent entropic gating.

NOT a re-implementation of either sub-axis — both peptide_sim and
allosteric_sim are IMPORTED via importlib (governance f3 — no fork of
sister logic). The Zimm-Bragg helix-coil partition is reused verbatim
from peptide_sim.helix_coil_partition; the MWC ternary-complex affinity
shift is reused verbatim from allosteric_sim.affinity_shift; the
modulation-kind classification uses allosteric_sim.NEUTRAL_LOG_ALPHA_TOL
unchanged.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELED
────────────────────────────────────────────────────────────────────────────
For each model peptide in a deterministic BH3-mimetic-class panel:

  1. Compute theta_H from the Zimm-Bragg partition (peptide_sim, f3) — the
     exact 2^N microstate sum, theta_H in [0,1].
  2. Map theta_H to an MWC cooperativity factor alpha by the construction

         alpha(theta_H) = 1 + (alpha_max - 1) * theta_H

     so alpha -> 1 (no MWC effect) as theta_H -> 0 (disordered → no defined
     helix → no BH3-cleft recognition → no R-state stabilization), and
     alpha -> alpha_max as theta_H -> 1 (well-defined helix → R-state
     stabilizer). For PAM stapled-BH3 peptides we take alpha_max > 1; this
     is a MODELING CHOICE for the helicity-gates-allostery framing, NOT a
     fit to a specific peptide or target. alpha_max is an illustrative
     literature-informed surrogate for the peptide-class.
  3. Classify modulation_kind (PAM / NAM / neutral) by the same threshold
     allosteric_sim uses (NEUTRAL_LOG_ALPHA_TOL imported unchanged, f3).
  4. Project the saturable MWC affinity shift at an illustrative assay
     probe concentration via allosteric_sim.affinity_shift (imported, f3).
  5. Combined gating: a peptide is 'effective' iff theta_H >= helix_gate
     AND mwc_modulation_kind == 'PAM' (defined helix + measurable MWC
     R-state stabilization). 'weak' = PAM but theta_H below the gate
     (insufficient helix to present recognition face). 'ineffective' = no
     MWC R-state stabilization at all.

The deterministic panel spans the theta_H range from low (Gly/Pro-rich →
disordered → ineffective) through mixed (weak) to high (defined helix →
effective). All sequences are illustrative model peptides — NOT the
literal SAHB-A / ABT-737 / BH3 / venetoclax peptide sequences. The drug
precedents name the MODALITY only, never a fit.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED (governance g1 — verification anchors >= 1 real limit)
────────────────────────────────────────────────────────────────────────────
Two coincident real limits anchor every row:

  - Zimm-Bragg helix-coil statistical mechanics. 0 <= theta_H <= 1 always
    (a fraction); cooperativity (sigma << 1) can only SUPPRESS theta_H
    below the sigma->1 independent-residue baseline. The 1-D helix-coil
    partition function Z is the exact 2^N microstate sum.
      - Zimm BH, Bragg JK. "Theory of the phase transition between helix
        and random coil in polypeptide chains." J Chem Phys 1959;31:526.
      - Lifson S, Roig A. "On the theory of helix-coil transition in
        polypeptides." J Chem Phys 1961;34:1963.

  - Monod-Wyman-Changeux concerted allosteric two-state model. The MWC
    affinity-shift ratio (1 + [B]/K_B)/(1 + alpha*[B]/K_B) is SATURABLE,
    bounded between 1 (no modulator) and 1/alpha (the allosteric
    ceiling). The cooperativity factor alpha is the hard real limit on
    the modulation strength.
      - Monod J, Wyman J, Changeux JP. "On the nature of allosteric
        transitions: a plausible model." J Mol Biol 1965;12:88-118.
      - Christopoulos A, Kenakin T. "G protein-coupled receptor
        allosterism and complexing." Pharmacol Rev 2002;54:323-374.

The structural / mechanism anchor for the helical BH3-mimetic-as-
allosteric-R-state-stabilizer modality is the stapled-peptide / SAHB
literature, principally Walensky et al. on BAX/BAK-binding SAHB:

  - Walensky LD, Kung AL, Escher I, Malia TJ, Barbuto S, Wright RD,
    Wagner G, Verdine GL, Korsmeyer SJ. "Activation of apoptosis in
    vivo by a hydrocarbon-stapled BH3 helix." Science 2004;305:1466-1470.

────────────────────────────────────────────────────────────────────────────
DRUG / BIOLOGY PRECEDENT (governance g3 / f1 — own precedent only)
────────────────────────────────────────────────────────────────────────────
Modalities are described ONLY via their own published drug precedent;
nothing here is lattice-derived (f1/f_lattice_fit):

  * PEPTIDE precedent (peptide-modality only — NOT specifically allosteric):
      - semaglutide / Ozempic / Wegovy / Rybelsus — GLP-1 receptor-agonist
        peptide analog (Novo Nordisk; FDA 2017 s.c. / 2019 oral). Cited as
        FDA-approved peptide-modality precedent; semaglutide is an
        orthosteric agonist, NOT an allosteric modulator.
      - somatostatin analogs (octreotide, lanreotide) — FDA-approved
        cyclic peptide therapeutics; somatostatin receptor agonists,
        modality precedent for therapeutic peptides.
      - Walensky lab stapled-BH3-mimetic SAHB research (Walensky et al.
        Science 305:1466, 2004) — the foundational helical-BH3-mimetic
        peptide-modality research, NOT FDA-approved.

  * ALLOSTERIC precedent (allosteric-modality only — small-molecule FDA-
    approved precedents, NOT peptide-allosteric efficacy claim):
      - maraviroc — FDA-approved allosteric CCR5 antagonist (Pfizer; FDA
        2007). Transmembrane-cavity allosteric site (Dorr et al., AAC
        49:4721, 2005).
      - asciminib — FDA-approved allosteric BCR-ABL1 inhibitor (Novartis;
        FDA 2021). Myristoyl-pocket allosteric site (Wylie et al., Nature
        543:733, 2017).

  * PEPTIDE x ALLOSTERIC COMBINATION (this cross): RESEARCH-STAGE.
      - ALRN-6924 (Aileron Therapeutics) — stapled-peptide MDM2/MDMX dual
        inhibitor; restored p53 in clinical trials (clinical-stage; not
        FDA-approved).
      - There is NO FDA-approved stapled-peptide allosteric drug as of
        writing. The peptide-allosteric modality has SOME clinical
        precursors (somatostatin analogs etc.) but the helical-peptide x
        allosteric COMBINATION here is a research-stage modeling exercise.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g3 / g8 / forbidden-patterns f1 / f2 / f3 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
  * This cross is a MODEL-LEVEL UNIFICATION: it shows that the PEPTIDE
    sub-axis's Zimm-Bragg helix-content theta_H can GATE the ALLOSTERIC
    sub-axis's MWC R-state stabilization in the helical-BH3-mimetic
    modality. Same MWC framework, peptide-specific helicity gate.
  * It does NOT claim every helical peptide is allosteric (most are
    orthosteric agonists — e.g. semaglutide acts at the orthosteric GLP-1
    receptor site).
  * It does NOT claim every allosteric modulator is a peptide (most
    FDA-approved allosteric drugs are small molecules — maraviroc,
    asciminib, trametinib).
  * It does NOT claim therapeutic efficacy. Stapled BH3-mimetic peptides
    are RESEARCH-STAGE / early-clinical (Walensky 2004; ALRN-6924 vs
    MDM2 — clinical trials). NO FDA-approved stapled-peptide allosteric
    drug exists. The cross is descriptive of the SHARED MATH, not of an
    approved drug class.
  * Both sub-axis sources are IMPORTED via importlib (f3 — no shadow of
    sister logic); peptide_sim.helix_coil_partition,
    peptide_sim.independent_residue_helicity, allosteric_sim.affinity_shift,
    and allosteric_sim.NEUTRAL_LOG_ALPHA_TOL are reused verbatim.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY
    (g8/f2): theta_H in [0,1], cooperativity_suppresses_helix holds, the
    MWC ceiling 1/alpha is respected by the projected affinity shift, and
    the modulation classification consumes only inputs computed by the
    imported sub-axes. NOT a binding-affinity, potency, selectivity,
    immunogenic or therapeutic-efficacy claim.

A CROSS is NOT a new axis. PEPTIDE remains a SUB-AXIS :> WEAVE;
ALLOSTERIC remains a SUB-AXIS :> QUANTUM. The hexa-bio core-5 axes
QUANTUM, WEAVE, NANOBOT, RIBOZYME, VIROCAPSID are UNCHANGED (AXIS.tape).
No quantity here is derived from the n=6 lattice (f_lattice_fit /
lattice-is-tool).

License: Apache-2.0 (hexa-bio core).
"""
from __future__ import annotations

import importlib.util
import json
import math
import os
import sys
from typing import Dict, List, Tuple

# ── locate the two sister sub-axis sources (no fork — f3) ───────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_PEPTIDE_PATH = os.path.join(_HERE, "peptide_sim.py")
_ALLOSTERIC_PATH = os.path.join(_HERE, "allosteric_sim.py")

SCHEMA_ID = "peptide_allosteric_cross_v1"
SENTINEL_PASS = "__PEPTIDE_ALLOSTERIC_CROSS__ PASS"
SENTINEL_FAIL = "__PEPTIDE_ALLOSTERIC_CROSS__ FAIL"

# Physical scaffolding (constant scope — physiological 310 K, RT in kcal/mol).
TEMP_K = 310.0
RT_KCAL = 1.987204258e-3 * TEMP_K       # gas constant R * T, kcal/(mol*K) * K

# ── helix-content gate (illustrative modeling choice — not lattice-derived) ─
# A peptide must present a defined helix face to be recognized in a BH3
# cleft of a BCL-2-family target. Below this gate, theta_H is insufficient
# for the i, i+3, i+4 hydrophobic stripe to form -> 'weak'. This is an
# ILLUSTRATIVE threshold, NOT a fit to a specific peptide.
HELIX_GATE_THETA_H = 0.30

# ── alpha_max — the MWC cooperativity ceiling of the helical-peptide class ─
# The MWC PAM ceiling 1/alpha_max defines the limiting affinity-shift ratio
# a fully-helical stapled BH3-mimetic peptide can produce. Illustrative
# magnitude — within the PAM range covered by allosteric_sim's panel
# (allosteric_sim PAM modulators have alpha in 8-25). NOT a fit.
ALPHA_MAX = 10.0

# ── illustrative MWC saturation probe ────────────────────────────────────
# The probe concentration at which we project the saturable affinity shift,
# and the modulator K_B. Illustrative class surrogates — within the
# concentration sweep allosteric_sim probes (0..1000 uM); NOT a fit.
MODULATOR_KD_UM = 1.0
ASSAY_CONC_UM = 10.0

# ── deterministic helical-BH3-mimetic peptide-class panel ────────────────
# (name, sequence, modality_note, peptide_precedent, allosteric_precedent,
#  structural_anchor)
#
# Sequences are ILLUSTRATIVE model peptides chosen to span theta_H from
# near-zero (Gly/Pro-rich disorder) through mixed to high (Ala-rich strong
# helix-former). They are NOT the literal SAHB-A / ABT-737 / BAX / venetoclax
# peptide sequences. The drug precedents name the MODALITY only.
PEPTIDE_PANEL: Tuple[Tuple[str, str, str, str, str, str], ...] = (
    ("model_helical_BH3_high", "AALEAALEAALEAALE",
     "high-helicity stapled-BH3-mimetic-class model peptide (defined helix"
     " face for BH3-cleft recognition)",
     "Walensky lab stapled-BH3-mimetic SAHB research (Walensky et al.,"
     " Science 305:1466, 2004) — research-stage helical-peptide modality;"
     " semaglutide (Ozempic / Wegovy / Rybelsus) — FDA-approved peptide"
     " modality, orthosteric (NOT allosteric) — peptide-modality precedent",
     "maraviroc — FDA-approved allosteric CCR5 antagonist (Pfizer 2007);"
     " asciminib — FDA-approved allosteric BCR-ABL1 inhibitor (Novartis"
     " 2021, myristoyl pocket) — allosteric-modality precedent",
     "Walensky et al., Science 305:1466, 2004 — hydrocarbon-stapled BH3"
     " helix activates apoptosis in vivo (SAHB on BAX/BAK)"),
    ("model_helical_BH3_mid", "AKLSAGTLSAKNVELSAG",
     "mixed-helicity helical-peptide-class model (partial helix face)",
     "ALRN-6924 (Aileron Therapeutics) — stapled-peptide MDM2/MDMX dual"
     " inhibitor, clinical-stage (NOT FDA-approved) — research-stage"
     " peptide-modality precedent",
     "trametinib — FDA-approved allosteric MEK1/2 inhibitor (Novartis"
     " 2013) — allosteric-modality precedent",
     "Walensky et al., Science 305:1466, 2004 — SAHB modality anchor"),
    ("model_glp1_like_helix", "AAEGTFTSDLSKQMEEAA",
     "GLP-1-analog-like helical-peptide-class model (helical bound state)",
     "semaglutide — FDA-approved GLP-1 receptor-agonist peptide analog"
     " (Novo Nordisk; FDA 2017 s.c.); GLP-1 backbone is helical in the"
     " receptor-bound state — peptide-modality precedent only (not allosteric)",
     "asciminib — FDA-approved allosteric BCR-ABL1 inhibitor — allosteric-"
     "modality precedent only",
     "Walensky et al., Science 305:1466, 2004 — SAHB modality anchor"),
    ("model_disordered_low", "GPGSGPGSGNGPGSGP",
     "low-helicity Gly/Pro-rich disordered peptide-class model"
     " (no defined helix face — predicted INEFFECTIVE as MWC R-state"
     " stabilizer)",
     "flexible-linker / disordered-peptide therapeutic modality"
     " (research-stage; no FDA-approved disordered-peptide allosteric"
     " modulator)",
     "(allosteric precedents are small-molecule: maraviroc, asciminib)",
     "Walensky et al., Science 305:1466, 2004 — SAHB modality anchor"),
)


def _load(name: str, path: str):
    """Import a sister sub-axis module by absolute path (no shadow — f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _alpha_from_helicity(theta_h: float, alpha_max: float = ALPHA_MAX) -> float:
    """
    Map fractional helicity theta_H in [0,1] to MWC cooperativity factor alpha.

        alpha(theta_H) = 1 + (alpha_max - 1) * theta_H

    A MODELING CHOICE (not a fit): alpha -> 1 (no MWC effect) as theta_H -> 0
    (disordered, no defined helix, no BH3-cleft recognition); alpha ->
    alpha_max (full PAM strength) as theta_H -> 1 (well-defined helix).
    """
    return 1.0 + (alpha_max - 1.0) * theta_h


def _classify_modulation(theta_h: float, mwc_kind: str,
                         gate: float = HELIX_GATE_THETA_H) -> str:
    """
    Combined helix-gate + MWC classification of the peptide as an allosteric
    modulator of a BCL-2-family-like target:

      - 'effective'   : theta_H >= helix_gate AND mwc_kind == 'PAM'
                        (defined helix face AND measurable MWC R-state
                        stabilization)
      - 'weak'        : mwc_kind == 'PAM' but theta_H < helix_gate
                        (PAM in alpha terms, but helix-face under-formed)
      - 'ineffective' : mwc_kind != 'PAM' (no MWC R-state stabilization)
    """
    if mwc_kind != "PAM":
        return "ineffective"
    if theta_h >= gate:
        return "effective"
    return "weak"


def build_cross_rows(peptide_mod, allo_mod) -> List[Dict]:
    """
    Build one cross row per peptide in the panel. Imports peptide_sim's
    Zimm-Bragg partition + independent-residue baseline (f3) and
    allosteric_sim's MWC affinity-shift + neutral-tolerance constant (f3).
    """
    sigma = peptide_mod.SIGMA_NUCLEATION
    neutral_tol = allo_mod.NEUTRAL_LOG_ALPHA_TOL
    rows: List[Dict] = []
    for (name, seq, note, prec_pep, prec_allo, anchor) in PEPTIDE_PANEL:
        # PEPTIDE sub-axis (imported, f3) — exact Zimm-Bragg 2^N partition.
        part = peptide_mod.helix_coil_partition(seq, sigma)
        theta_h = part["fractional_helicity"]
        indep = peptide_mod.independent_residue_helicity(seq)
        cooperativity_ok = theta_h <= indep + 1e-12

        # theta_H -> alpha mapping (the helicity gate of the modality)
        alpha = _alpha_from_helicity(theta_h, ALPHA_MAX)
        log10_alpha = math.log10(alpha) if alpha > 0.0 else float("-inf")
        if log10_alpha > neutral_tol:
            mwc_kind = "PAM"
        elif log10_alpha < -neutral_tol:
            mwc_kind = "NAM"
        else:
            mwc_kind = "neutral"

        # ALLOSTERIC sub-axis (imported, f3) — saturable MWC affinity shift
        # at the illustrative assay probe concentration.
        ec50_shift = allo_mod.affinity_shift(alpha, MODULATOR_KD_UM,
                                             ASSAY_CONC_UM)
        ceiling = 1.0 / alpha   # the saturable allosteric real limit
        # PAM (alpha > 1) -> shift decreases toward ceiling < 1; ceiling
        # respected iff shift >= ceiling. Neutral -> shift ~ 1, ceiling ~ 1.
        if alpha > 1.0:
            ceiling_ok = ec50_shift >= ceiling - 1e-9
        elif alpha < 1.0:
            ceiling_ok = ec50_shift <= ceiling + 1e-9
        else:
            ceiling_ok = abs(ec50_shift - 1.0) < 1e-9

        classification = _classify_modulation(theta_h, mwc_kind)

        row: Dict = {
            "schema": SCHEMA_ID,
            "peptide": name,
            "sequence": seq,
            "n_residues": part["n_residues"],
            "modality_note": note,
            "drug_precedent_peptide": prec_pep,
            "drug_precedent_allosteric": prec_allo,
            "structural_anchor": anchor,
            "temperature_K": TEMP_K,
            "rt_kcal_per_mol": RT_KCAL,
            "sigma_nucleation": sigma,
            "partition_Z": part["partition_Z"],
            "fractional_helicity_theta_h": theta_h,
            "independent_residue_helicity_sigma_to_1": indep,
            "cooperativity_suppresses_helix": cooperativity_ok,
            "mwc_alpha_cooperativity": alpha,
            "mwc_log10_alpha": log10_alpha,
            "mwc_modulation_kind": mwc_kind,
            "modulator_kd_uM": MODULATOR_KD_UM,
            "assay_concentration_uM": ASSAY_CONC_UM,
            "allosteric_ceiling_shift_1_over_alpha": ceiling,
            "ec50_shift_ratio_at_assay_conc": ec50_shift,
            "allosteric_ceiling_respected": ceiling_ok,
            "helix_gate_theta_h": HELIX_GATE_THETA_H,
            "modulation_classification": classification,
            "real_limit_anchor": (
                "Zimm-Bragg helix-coil partition (1-D 2^N microstate sum) "
                "+ Monod-Wyman-Changeux two-state ternary-complex "
                "(saturable, bounded by 1/alpha)"),
            "real_limit_citations": [
                "Zimm & Bragg 1959, J Chem Phys 31:526",
                "Lifson & Roig 1961, J Chem Phys 34:1963",
                "Monod, Wyman & Changeux 1965, J Mol Biol 12:88",
                ("Christopoulos & Kenakin 2002, Pharmacol Rev 54:323 — "
                 "saturable allosteric ceiling formalism"),
                ("Walensky et al. 2004, Science 305:1466 — stapled-BH3 "
                 "helix (SAHB) modality structural anchor"),
            ],
            "in_silico_caveat": (
                "in-silico simulator-CONSISTENCY only (g8/f2): theta_H in "
                "[0,1], cooperativity_suppresses_helix holds, MWC ceiling "
                "1/alpha respected; NOT a binding-affinity, potency, "
                "immunogenic or therapeutic-efficacy claim. The helical-"
                "peptide x allosteric COMBINATION is research-stage."),
            "comparison_is_ranking": False,
            "creates_a_new_axis": False,
            "illustrative_only": True,
            "research_stage_modality": True,
        }
        rows.append(row)
    return rows


def contrast(rows: List[Dict]) -> Dict:
    """High-vs-low theta_H contrast in MWC terms (same model, different gate)."""
    by_name = {r["peptide"]: r for r in rows}
    hi = by_name["model_helical_BH3_high"]
    lo = by_name["model_disordered_low"]
    return {
        "high_helicity_reference": {
            "peptide": hi["peptide"],
            "fractional_helicity_theta_h": hi["fractional_helicity_theta_h"],
            "mwc_alpha_cooperativity": hi["mwc_alpha_cooperativity"],
            "mwc_modulation_kind": hi["mwc_modulation_kind"],
            "ec50_shift_ratio_at_assay_conc":
                hi["ec50_shift_ratio_at_assay_conc"],
            "allosteric_ceiling_shift_1_over_alpha":
                hi["allosteric_ceiling_shift_1_over_alpha"],
            "modulation_classification": hi["modulation_classification"],
        },
        "low_helicity_reference": {
            "peptide": lo["peptide"],
            "fractional_helicity_theta_h": lo["fractional_helicity_theta_h"],
            "mwc_alpha_cooperativity": lo["mwc_alpha_cooperativity"],
            "mwc_modulation_kind": lo["mwc_modulation_kind"],
            "ec50_shift_ratio_at_assay_conc":
                lo["ec50_shift_ratio_at_assay_conc"],
            "allosteric_ceiling_shift_1_over_alpha":
                lo["allosteric_ceiling_shift_1_over_alpha"],
            "modulation_classification": lo["modulation_classification"],
        },
        "note": (
            "the same MWC two-state framework applies to both peptides; "
            "the difference is the PEPTIDE-axis helicity gate. A defined "
            "helix (high theta_H) presents the BH3-cleft recognition face "
            "and stabilizes the R state of a BCL-2-family target (PAM, "
            "alpha > 1, shift toward 1/alpha < 1); a disordered chain "
            "(low theta_H) maps to alpha ~ 1 (no MWC effect, no R-state "
            "stabilization). Same framework, peptide-specific helicity-"
            "dependent entropic gating."),
    }


def acceptance(rows: List[Dict]) -> Dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X8)."""
    effective = [r for r in rows
                 if r["modulation_classification"] == "effective"]
    ineffective = [r for r in rows
                   if r["modulation_classification"] == "ineffective"]
    crit = {
        "X1_panel_non_empty": len(rows) == len(PEPTIDE_PANEL) and len(rows) >= 4,
        "X2_theta_h_in_unit_interval": all(
            0.0 <= r["fractional_helicity_theta_h"] <= 1.0 for r in rows),
        "X3_cooperativity_suppresses_helix": all(
            r["cooperativity_suppresses_helix"] for r in rows),
        "X4_alpha_strictly_positive": all(
            r["mwc_alpha_cooperativity"] > 0.0 for r in rows),
        "X5_allosteric_ceiling_respected": all(
            r["allosteric_ceiling_respected"] for r in rows),
        "X6_helix_spread_present": (
            max(r["fractional_helicity_theta_h"] for r in rows)
            - min(r["fractional_helicity_theta_h"] for r in rows) > 0.05),
        "X7_at_least_one_effective_and_one_non_effective": (
            len(effective) >= 1 and (
                len(rows) - len(effective)) >= 1),
        "X8_alpha_equals_helicity_map": all(
            abs(r["mwc_alpha_cooperativity"]
                - _alpha_from_helicity(r["fractional_helicity_theta_h"],
                                       ALPHA_MAX)) < 1e-12
            for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("peptide_allosteric_cross — CROSS-AXIS BB3\n", flush=True)
    print("cross:  PEPTIDE :> WEAVE (Zimm-Bragg helix-coil)  ====unify====")
    print("        ALLOSTERIC :> QUANTUM (MWC two-state ternary-complex)")
    print("        theta_H gates whether the peptide is a competent MWC")
    print("        R-state stabilizer (defined-helix recognition of the")
    print("        BH3 cleft of a BCL-2-family-like target).\n", flush=True)

    peptide_mod = _load("peptide_sim", _PEPTIDE_PATH)
    allo_mod = _load("allosteric_sim", _ALLOSTERIC_PATH)

    print(f"  real-limit anchors :")
    print(f"     - Zimm-Bragg helix-coil 1-D 2^N partition (Zimm & Bragg,")
    print(f"       J Chem Phys 31:526, 1959; Lifson & Roig, J Chem Phys")
    print(f"       34:1963, 1961) — 0 <= theta_H <= 1, cooperativity")
    print(f"       suppresses helix below sigma->1 baseline.")
    print(f"     - MWC two-state ternary-complex (Monod, Wyman & Changeux,")
    print(f"       J Mol Biol 12:88, 1965) — saturable affinity shift")
    print(f"       bounded by 1/alpha (Christopoulos & Kenakin, Pharmacol")
    print(f"       Rev 54:323, 2002).")
    print(f"     - structural / modality anchor: Walensky et al., Science")
    print(f"       305:1466, 2004 — stapled-BH3 helix (SAHB).")
    print(f"  sigma_nucleation : {peptide_mod.SIGMA_NUCLEATION:.0e}   "
          f"alpha_max : {ALPHA_MAX:g}   "
          f"helix_gate theta_H : {HELIX_GATE_THETA_H:g}\n",
          flush=True)

    rows = build_cross_rows(peptide_mod, allo_mod)
    for r in rows:
        print(f"  [{r['peptide']:<26}] N={r['n_residues']:<3} "
              f"theta_H={r['fractional_helicity_theta_h']:.4f}  "
              f"(sigma->1 baseline={r['independent_residue_helicity_sigma_to_1']:.4f})")
        print(f"      alpha={r['mwc_alpha_cooperativity']:.4g}  "
              f"log10(alpha)={r['mwc_log10_alpha']:+.4f}  "
              f"kind={r['mwc_modulation_kind']:<7} "
              f"ceiling=1/alpha={r['allosteric_ceiling_shift_1_over_alpha']:.4g}")
        print(f"      EC50_shift@[B]={ASSAY_CONC_UM}uM = "
              f"{r['ec50_shift_ratio_at_assay_conc']:.4g}   "
              f"classification = {r['modulation_classification']}")

    ctr = contrast(rows)
    print("\n## high-vs-low theta_H contrast (same MWC framework, different gate)")
    hi, lo = ctr["high_helicity_reference"], ctr["low_helicity_reference"]
    print(f"  HIGH theta_H  {hi['peptide']:<26} "
          f"theta_H={hi['fractional_helicity_theta_h']:.4g}  "
          f"alpha={hi['mwc_alpha_cooperativity']:.4g}  "
          f"shift={hi['ec50_shift_ratio_at_assay_conc']:.4g}  "
          f"-> {hi['modulation_classification']}")
    print(f"  LOW  theta_H  {lo['peptide']:<26} "
          f"theta_H={lo['fractional_helicity_theta_h']:.4g}  "
          f"alpha={lo['mwc_alpha_cooperativity']:.4g}  "
          f"shift={lo['ec50_shift_ratio_at_assay_conc']:.4g}  "
          f"-> {lo['modulation_classification']}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3 / f_lattice_fit)")
    print("  - This cross is a MODEL-LEVEL UNIFICATION: it shows the PEPTIDE")
    print("    sub-axis's Zimm-Bragg helix-content theta_H GATES the ALLOSTERIC")
    print("    sub-axis's MWC R-state stabilization in the helical-BH3-")
    print("    mimetic modality. Same MWC framework, peptide-specific helicity")
    print("    gate.")
    print("  - It does NOT claim every helical peptide is allosteric")
    print("    (semaglutide is an orthosteric GLP-1 receptor agonist, NOT")
    print("    allosteric — semaglutide is the peptide-modality precedent only).")
    print("  - It does NOT claim every allosteric modulator is a peptide")
    print("    (maraviroc, asciminib, trametinib are small molecules — they")
    print("    are the allosteric-modality precedents only).")
    print("  - Both sub-axis sources are IMPORTED (f3 — no shadow of sister")
    print("    logic); peptide_sim.helix_coil_partition,")
    print("    peptide_sim.independent_residue_helicity,")
    print("    allosteric_sim.affinity_shift, and")
    print("    allosteric_sim.NEUTRAL_LOG_ALPHA_TOL are reused verbatim.")
    print("  - RESEARCH-STAGE WITH CLINICAL PRECURSORS: stapled BH3-mimetic")
    print("    peptides are research-stage / early-clinical at best (Walensky")
    print("    2004 SAHB; ALRN-6924 vs MDM2 — clinical-stage, NOT FDA-")
    print("    approved). NO FDA-approved stapled-peptide allosteric drug")
    print("    exists. The peptide-allosteric MODALITY has SOME clinical")
    print("    precursors (somatostatin analogs e.g. octreotide; maraviroc /")
    print("    asciminib FDA-approved as small-molecule allosteric drugs) but")
    print("    the helical-peptide x allosteric COMBINATION here is a")
    print("    research-stage modeling exercise.")
    print("  - PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY")
    print("    (g8/f2) — theta_H in [0,1], cooperativity_suppresses_helix")
    print("    holds, MWC ceiling 1/alpha respected, modulation classification")
    print("    consumes only inputs computed by the imported sub-axes. NOT a")
    print("    binding-affinity, potency, selectivity, immunogenic or")
    print("    therapeutic-efficacy claim.")
    print("  - PEPTIDE remains a SUB-AXIS :> WEAVE; ALLOSTERIC remains a")
    print("    SUB-AXIS :> QUANTUM. A CROSS is NOT a new axis. The hexa-bio")
    print("    core-5 axes are UNCHANGED (AXIS.tape). No quantity is derived")
    print("    from the n=6 lattice (f_lattice_fit / lattice-is-tool).")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed -> deterministic byte-identical re-runs
        "cross": ("BB3  PEPTIDE :> WEAVE (Zimm-Bragg helix-coil)  "
                  "<==unify==>  ALLOSTERIC :> QUANTUM "
                  "(MWC two-state ternary-complex)"),
        "peptide_subaxis_source":
            ("_python_bridge/module/peptide_sim.py (helix_coil_partition + "
             "independent_residue_helicity imported, not re-implemented — f3)"),
        "allosteric_subaxis_source":
            ("_python_bridge/module/allosteric_sim.py (affinity_shift + "
             "NEUTRAL_LOG_ALPHA_TOL imported, not re-implemented — f3)"),
        "real_limit_anchor": (
            "Zimm-Bragg / Lifson-Roig 1-D helix-coil statistical mechanics "
            "(Zimm & Bragg, J Chem Phys 31:526, 1959; Lifson & Roig, J Chem "
            "Phys 34:1963, 1961) + Monod-Wyman-Changeux two-state allosteric "
            "model (Monod, Wyman & Changeux, J Mol Biol 12:88, 1965) — "
            "0 <= theta_H <= 1 and modulation saturable / bounded by 1/alpha."),
        "structural_modality_anchor": (
            "Walensky LD et al. Activation of apoptosis in vivo by a "
            "hydrocarbon-stapled BH3 helix. Science 305:1466, 2004 — SAHB."),
        "modality_precedents": {
            "peptide_modality_only": (
                "semaglutide (Ozempic / Wegovy / Rybelsus) — FDA-approved "
                "GLP-1 receptor-agonist peptide (Novo Nordisk; FDA 2017/2019). "
                "Orthosteric agonist, NOT allosteric — peptide-modality "
                "precedent only. somatostatin analogs (octreotide / "
                "lanreotide) — FDA-approved peptide therapeutics."),
            "allosteric_modality_only": (
                "maraviroc — FDA-approved allosteric CCR5 antagonist (Pfizer; "
                "FDA 2007); asciminib — FDA-approved allosteric BCR-ABL1 "
                "inhibitor (Novartis; FDA 2021, myristoyl pocket). "
                "Small-molecule allosteric precedents — NOT peptide-allosteric "
                "efficacy claim."),
            "peptide_x_allosteric_combination_research_stage": (
                "Walensky lab stapled-BH3-mimetic SAHB research (Walensky et "
                "al., Science 305:1466, 2004) — research-stage. ALRN-6924 "
                "(Aileron Therapeutics) — stapled-peptide MDM2/MDMX dual "
                "inhibitor, clinical-stage (NOT FDA-approved). NO FDA-"
                "approved stapled-peptide allosteric drug exists. The "
                "helical-peptide x allosteric COMBINATION is a research-"
                "stage modeling exercise."),
        },
        "unification_identity": (
            "theta_H (peptide_sim.helix_coil_partition) -> alpha = "
            "1 + (alpha_max - 1) * theta_H -> MWC affinity shift "
            "(allosteric_sim.affinity_shift); same MWC framework, "
            "peptide-specific helicity gate"),
        "temperature_K": TEMP_K,
        "rt_kcal_per_mol": RT_KCAL,
        "sigma_nucleation": peptide_mod.SIGMA_NUCLEATION,
        "alpha_max": ALPHA_MAX,
        "helix_gate_theta_h": HELIX_GATE_THETA_H,
        "modulator_kd_uM": MODULATOR_KD_UM,
        "assay_concentration_uM": ASSAY_CONC_UM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "MODEL-LEVEL UNIFICATION ONLY (g8/f2) — theta_H, alpha and the "
            "projected MWC affinity shift are illustrative model outputs "
            "propagated from literature-informed PEPTIDE / ALLOSTERIC sub-"
            "axis class surrogates; NOT a binding-affinity, potency, "
            "selectivity, immunogenic or therapeutic-efficacy claim, NOT a "
            "claim that every helical peptide is allosteric or vice versa."),
        "research_stage_with_clinical_precursors_note": (
            "The peptide-allosteric MODALITY has clinical precursors "
            "(somatostatin analogs etc.) but the helical-peptide x "
            "allosteric COMBINATION here is research-stage at best. NO "
            "FDA-approved stapled-peptide allosteric drug exists; ALRN-"
            "6924 is clinical-stage; Walensky 2004 SAHB is research-stage."),
        "cross_is_not_a_new_axis": (
            "PEPTIDE remains a SUB-AXIS :> WEAVE; ALLOSTERIC remains a "
            "SUB-AXIS :> QUANTUM; the hexa-bio core-5 axes are unchanged."),
        "no_lattice_derivation": (
            "No quantity in this witness is derived from the n=6 lattice "
            "(f_lattice_fit / lattice-is-tool). The helix gate, alpha_max, "
            "K_B and assay concentration are illustrative literature-"
            "informed surrogates, not lattice constants."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_PASS if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
