#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rna_modality_comparison_smn2_cross.py — CROSS-AXIS in-silico modality
comparison for the SMN2 exon-7 splicing target.

WHAT THIS IS — Project A3
─────────────────────────
Spinal muscular atrophy (SMA) is caused by loss of the SMN1 gene; the
near-identical paralog SMN2 carries a single C>T variant in exon 7 that
makes exon 7 mostly SKIPPED, producing an unstable truncated SMN protein.
TWO FDA-approved drug modalities both target SMN2 exon-7 splicing to
restore exon-7 INCLUSION — and they hit it in two physically different
ways:

  (a) SMALL-MOLECULE path — risdiplam-like (risdiplam / Evrysdi, Roche /
      PTC Therapeutics / SMA Foundation; FDA 2020): an orally-bioavailable
      small molecule that binds the SMN2 pre-mRNA exon-7 region and shifts
      the RNA secondary-structure ENSEMBLE toward the inclusion-competent
      fold. Modelled here via the RNA-TARGETING-SMALL-MOLECULE sub-axis
      (Nussinov base-pair ensemble shift).

  (b) ANTISENSE-OLIGONUCLEOTIDE path — nusinersen-like (nusinersen /
      Spinraza, Ionis / Biogen; FDA 2016): an ASO that HYBRIDIZES the
      ISS-N1 intronic splicing-silencer element in intron 7, blocking the
      silencer so exon 7 is included. Modelled here via the OLIGONUCLEOTIDE
      hybridization axis (SantaLucia nearest-neighbor duplex ΔG/Tm).

DELIVERABLE — A COMPARISON, NOT A RANKING (CRITICAL HONESTY)
────────────────────────────────────────────────────────────
This module emits a side-by-side of TWO IN-SILICO MODEL SIGNATURES. It is:
  • NOT an efficacy ranking
  • NOT a claim that one modality / drug is superior to the other
  • NOT a clinical, therapeutic, regulatory or potency claim
risdiplam and nusinersen are BOTH FDA-approved SMA drugs. The two model
signals live in DIFFERENT UNITS and rest on DIFFERENT real limits — a
dimensionless RNA-structure ensemble shift vs a hybridization free energy
in kcal/mol — so they are NOT even commensurable, let alone rankable. The
comparison reports WHAT EACH MODEL SAYS about its own mechanism. The
common ground is only the shared TARGET (SMN2 exon 7) and the shared
biological GOAL (promote exon-7 inclusion); the comparison is of
modalities, not of drugs.

NO FORK (governance f3 — no shadow implementation)
──────────────────────────────────────────────────
The two mechanism models are IMPORTED from their existing axis modules:
  • rna_targeting_small_molecule_sim.py  (small-molecule path)
  • oligonucleotide_hybridization_sim.py (ASO path)
This module adds ONLY the SMN2-framed cross + the comparison emitter; it
re-implements neither the Nussinov solver nor the SantaLucia NN model.

REAL LIMITS ANCHORED (governance g1 — real-limits-first)
─────────────────────────────────────────────────────────
Each modality's signal is anchored to ITS OWN real limit — neither is
derived from the n=6 lattice (g2 / f1 / f_lattice_fit):
  • SMALL-MOLECULE path → RNA secondary-structure thermodynamics. The
    accessible structural ensemble of an RNA is governed by base-pair
    free energy.
      - Nussinov RC, Pieczenik G, Griggs JR, Kleitman DJ. "Algorithms for
        loop matchings." SIAM J Appl Math 1978;35:68-82.
      - Turner DH, Mathews DH. "NNDB: the nearest-neighbor parameter
        database for predicting RNA secondary structure." Nucleic Acids
        Res 2010;38:D280-D282.
  • ASO path → nucleic-acid duplex hybridization thermodynamics. Duplex
    stability is bounded by nearest-neighbor base-pair stacking free
    energy.
      - SantaLucia J Jr. "A unified view of polymer, dumbbell, and
        oligonucleotide DNA nearest-neighbor thermodynamics." Proc Natl
        Acad Sci USA 1998;95(4):1460-1465.

DRUG / BIOLOGY PRECEDENT (governance g3 / f1 — own precedent only)
───────────────────────────────────────────────────────────────────
Modalities are described ONLY via their own published drug precedent;
nothing here is lattice-derived:
  • risdiplam / Evrysdi — small-molecule SMN2 exon-7 splicing modulator,
    FDA 2020. Ratni H et al. J Med Chem 2018;61:6501-6517; Campagne S
    et al. Nat Chem Biol 2019;15:1191-1198 (structural basis).
  • nusinersen / Spinraza — ASO targeting the ISS-N1 intronic splicing
    silencer of SMN2 intron 7, FDA 2016. Hua Y et al. "Antisense masking
    of an hnRNP A1/A2 intronic splicing silencer corrects SMN2 splicing
    in transgenic mice." Am J Hum Genet 2008;82:834-848; Singh NN et al.
    "An intronic splicing silencer (ISS-N1) ... in SMN2." Mol Cell Biol
    2006;26:1333-1346.

DETERMINISM
───────────
Pure stdlib (the imported axis modules are stdlib-only too). No random /
network / time / env reads. Re-running on the same inputs produces
byte-identical output → the §11 deductive-verification contract.

SCOPE — IN-SILICO ONLY (governance g8 / f2)
────────────────────────────────────────────
A PASS sentinel here certifies IN-SILICO simulator + metadata internal
consistency ONLY — that both imported models run, produce well-formed
signatures, and reproduce byte-identically. It is NEVER a therapeutic,
clinical, splicing-correction, efficacy, immunogenic, regulatory, or
modality-superiority claim. The illustrative SMN2 / ISS-N1 sequences
below are TOY constructs that exercise the two models' arithmetic; they
are NOT genuine SMN2 sequence and the module asserts no real splice
outcome. The wet-lab boundary is out of repo scope
(CLOSURE_RESIDUAL_BACKLOG.md §0).

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

# (a) RNA-TARGETING-SMALL-MOLECULE sub-axis — risdiplam-like path.
from rna_targeting_small_molecule_sim import simulate as rtsm_simulate  # noqa: E402
# (b) OLIGONUCLEOTIDE axis — nusinersen-like ASO path.
from oligonucleotide_hybridization_sim import (  # noqa: E402
    duplex_report,
    reverse_complement,
)

SCHEMA_VERSION = "rna_modality_comparison_smn2_cross_v1"
SENTINEL_PASS = "__RNA_MODALITY_COMPARISON_SMN2_CROSS__ PASS"
SENTINEL_FAIL = "__RNA_MODALITY_COMPARISON_SMN2_CROSS__ FAIL"

# ── illustrative SMN2 exon-7 / ISS-N1 reference region ──────────────────
#
# DETERMINISTIC TOY CONSTRUCTS — NOT genuine SMN2 sequence. They exercise
# the two mechanism models' arithmetic; they assert no real splice outcome
# (governance g8 / f2). The shared biological framing: SMN2 exon 7 is
# mostly skipped; both modalities act to restore exon-7 INCLUSION.
#
# (a) SMALL-MOLECULE target — a toy SMN2-exon-7-style pre-mRNA segment.
#     The "exon-inclusion stem" is the structural proxy for the
#     splice-competent conformation a risdiplam-class molecule promotes.
#     The small molecule occludes a competing 5' arm; with that competitor
#     removed the transcript re-folds toward the inclusion-competent stem.
_SMN2_EXON7_PREMRNA = "CCCCCCAAAAAAAAAAGGGGGGAAUUCCCCCCAAAAAAAAAA"
_EXON_INCLUSION_STEM = [16, 32]   # half-open window of the inclusion stem
_SM_MOTIF_FORBID = [0, 1, 2, 3, 4, 5]  # competing 5' arm the ligand occludes

# (b) ASO target — a toy ISS-N1 intronic-splicing-silencer element. The
#     nusinersen-like ASO is the reverse complement of this element; it
#     hybridizes and masks the silencer so exon 7 is included. The duplex
#     ΔG / Tm is the model signal for how stably the ASO would clamp the
#     silencer (SantaLucia NN). The element is DNA-alphabet for the NN
#     model (U->T handled by the imported sanitizer).
_ISS_N1_ELEMENT = "GCTGGCAGACTTACTCCTTAA"   # toy 21-nt intronic silencer


def _small_molecule_signature() -> Dict:
    """Run the SMALL-MOLECULE (risdiplam-like) path on the SMN2 exon-7
    toy target and reduce it to one comparison row.

    Real limit: RNA secondary-structure thermodynamics (Nussinov 1978;
    Turner-Mathews NNDB 2010). The model signal is the structural-ensemble
    SHIFT of the exon-inclusion stem, baseline -> ligand-bound.
    """
    case = {
        "id": "smn2.exon7.small_molecule.risdiplam_like.v1",
        "transcript": _SMN2_EXON7_PREMRNA,
        "exon_stem": _EXON_INCLUSION_STEM,
        "ligand_mode": "stabilizer",
        "motif_force": [],
        "motif_forbid": _SM_MOTIF_FORBID,
        "precedent": "risdiplam (Evrysdi) — small-molecule SMN2 exon-7 "
        "splicing modulator, FDA 2020 (Roche / PTC Therapeutics / SMA "
        "Foundation). Cited for modality only — no efficacy claim.",
    }
    sim = rtsm_simulate(case)
    shift = sim["structural_shift"]
    signal = shift["mfe_stem_fraction_delta"]
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "SMALL-MOLECULE",
        "modality_label": "RNA-structure-targeting small molecule "
        "(risdiplam-like)",
        "axis_module": "rna_targeting_small_molecule_sim.py",
        "axis_name": "RNA-TARGETING-SMALL-MOLECULE (:> RIBOZYME)",
        "drug_precedent": "risdiplam / Evrysdi — FDA 2020 (Ratni 2018 "
        "J Med Chem 61:6501; Campagne 2019 Nat Chem Biol 15:1191)",
        "mechanism": "Binds the SMN2 pre-mRNA exon-7 region and shifts "
        "the RNA secondary-structure ensemble toward the exon-7 "
        "inclusion-competent fold (ensemble shift, not hybridization).",
        "smn2_target": "SMN2 pre-mRNA exon-7 5'-region (toy construct)",
        "model_signal_name": "exon_inclusion_stem_fraction_shift",
        "model_signal_value": signal,
        "model_signal_units": "dimensionless (Δ paired-fraction, "
        "baseline -> ligand-bound)",
        "model_signal_detail": {
            "baseline_stem_fraction": sim["baseline"]["stem_paired_fraction"],
            "ligand_bound_stem_fraction":
                sim["ligand_bound"]["stem_paired_fraction"],
            "mfe_stem_fraction_delta": shift["mfe_stem_fraction_delta"],
            "ensemble_stem_fraction_delta":
                shift["ensemble_stem_fraction_delta"],
            "direction_consistent": shift["direction_consistent"],
        },
        "real_limit_anchor": "RNA secondary-structure thermodynamics — "
        "base-pair free energy governs the structural ensemble",
        "real_limit_citations": [
            "Nussinov et al. 1978, SIAM J Appl Math 35:68-82",
            "Turner & Mathews 2010, NNDB, Nucleic Acids Res 38:D280-D282",
        ],
        "in_silico_only": True,
    }


def _oligonucleotide_signature() -> Dict:
    """Run the ANTISENSE-OLIGONUCLEOTIDE (nusinersen-like) path: design the
    ASO as the reverse complement of the toy ISS-N1 element and compute the
    ASO:silencer duplex thermodynamics.

    Real limit: nucleic-acid duplex hybridization thermodynamics
    (SantaLucia 1998 unified nearest-neighbor model). The model signal is
    the hybridization free energy ΔG°(37 °C) of the ASO:silencer duplex —
    how stably the ASO would clamp the ISS-N1 silencer.
    """
    aso = reverse_complement(_ISS_N1_ELEMENT)
    rep = duplex_report(aso)
    signal = rep["dG37_kcal_mol"]
    return {
        "schema_version": SCHEMA_VERSION,
        "modality": "ANTISENSE-OLIGONUCLEOTIDE",
        "modality_label": "Antisense oligonucleotide (nusinersen-like)",
        "axis_module": "oligonucleotide_hybridization_sim.py",
        "axis_name": "OLIGONUCLEOTIDE",
        "drug_precedent": "nusinersen / Spinraza — ASO targeting the "
        "ISS-N1 intronic splicing silencer, FDA 2016 (Hua 2008 Am J Hum "
        "Genet 82:834; Singh 2006 Mol Cell Biol 26:1333)",
        "mechanism": "An ASO hybridizes the ISS-N1 intronic "
        "splicing-silencer element in SMN2 intron 7, masking the silencer "
        "so exon 7 is included (Watson-Crick duplex, not an ensemble "
        "shift).",
        "smn2_target": "SMN2 intron-7 ISS-N1 silencer element "
        "(toy 21-nt construct)",
        "model_signal_name": "aso_silencer_duplex_dG37",
        "model_signal_value": signal,
        "model_signal_units": "kcal/mol (NN ΔG° at 37 °C, 1 M Na+ "
        "standard state — non-physiological)",
        "model_signal_detail": {
            "aso_5to3": aso,
            "aso_length_nt": rep["length_nt"],
            "gc_fraction": rep["gc_fraction"],
            "dH_kcal_mol": rep["dH_kcal_mol"],
            "dS_cal_mol_K": rep["dS_cal_mol_K"],
            "dG37_kcal_mol": rep["dG37_kcal_mol"],
            "Tm_celsius": rep["Tm_celsius"],
        },
        "real_limit_anchor": "Nucleic-acid duplex hybridization "
        "thermodynamics — nearest-neighbor base-pair stacking free energy "
        "bounds duplex stability",
        "real_limit_citations": [
            "SantaLucia 1998, Proc Natl Acad Sci USA 95(4):1460-1465",
        ],
        "in_silico_only": True,
    }


def build_comparison() -> Dict:
    """Assemble the full SMN2 modality comparison object.

    Returns a dict with the two per-modality signature rows plus an
    explicit honesty block. The comparison is descriptive (what each model
    says) — it does NOT and CANNOT rank the modalities: the two signals
    are in different units, rest on different real limits, and both drugs
    are FDA-approved.
    """
    sm_row = _small_molecule_signature()
    aso_row = _oligonucleotide_signature()
    return {
        "schema_version": SCHEMA_VERSION,
        "comparison_id": "smn2_exon7_modality_comparison.v1",
        "shared_gene_target": "SMN2",
        "shared_splicing_event": "exon-7 inclusion vs skipping",
        "shared_biological_goal": "promote SMN2 exon-7 inclusion "
        "(restore full-length SMN protein)",
        "modality_rows": [sm_row, aso_row],
        "comparison_is_ranking": False,
        "comparison_kind": "descriptive side-by-side of two in-silico "
        "model signatures",
        "signals_commensurable": False,
        "signals_commensurable_note": "The two model signals are in "
        "DIFFERENT units (dimensionless RNA-structure ensemble shift vs "
        "duplex ΔG° in kcal/mol) and rest on DIFFERENT real limits — they "
        "are not commensurable and cannot be ranked against each other.",
        "honesty": {
            "in_silico_only": True,
            "not_an_efficacy_ranking": True,
            "not_a_superiority_claim": True,
            "not_a_clinical_claim": True,
            "both_drugs_fda_approved": True,
            "statement": "This is a MODALITY COMPARISON of two in-silico "
            "model signatures, NOT an efficacy ranking and NOT a claim "
            "that one drug or modality is superior. risdiplam (Evrysdi, "
            "FDA 2020) and nusinersen (Spinraza, FDA 2016) are BOTH "
            "FDA-approved SMA drugs. Each PASS certifies in-silico "
            "simulator + metadata internal consistency ONLY — never a "
            "therapeutic, clinical, splicing-correction, efficacy, "
            "immunogenic or regulatory claim. Modalities are described "
            "via their own drug precedent only; nothing is derived from "
            "the n=6 lattice (g3 / f1 / f_lattice_fit).",
        },
    }


# ── self-check / demo ───────────────────────────────────────────────────


def _validate_row(row: Dict) -> List[str]:
    """Lightweight in-module shape check of a modality row (the JSON
    Schema in _python_bridge/spec/ is the authoritative contract)."""
    errs: List[str] = []
    required = (
        "schema_version", "modality", "axis_module", "axis_name",
        "drug_precedent", "mechanism", "smn2_target",
        "model_signal_name", "model_signal_value", "model_signal_units",
        "real_limit_anchor", "real_limit_citations", "in_silico_only",
    )
    for key in required:
        if key not in row:
            errs.append(f"missing key '{key}'")
    if row.get("schema_version") != SCHEMA_VERSION:
        errs.append("schema_version mismatch")
    if row.get("modality") not in ("SMALL-MOLECULE", "ANTISENSE-OLIGONUCLEOTIDE"):
        errs.append(f"unexpected modality {row.get('modality')!r}")
    if not isinstance(row.get("model_signal_value"), (int, float)):
        errs.append("model_signal_value must be numeric")
    if not isinstance(row.get("real_limit_citations"), list) or \
            not row.get("real_limit_citations"):
        errs.append("real_limit_citations must be a non-empty list")
    if row.get("in_silico_only") is not True:
        errs.append("in_silico_only must be True")
    return errs


def _selfcheck() -> int:
    print("rna_modality_comparison_smn2_cross.py — CROSS-AXIS in-silico")
    print("  SMN2 exon-7 modality comparison")
    print("  (a) SMALL-MOLECULE  : RNA-TARGETING-SMALL-MOLECULE sub-axis")
    print("        risdiplam-like ensemble shift (Nussinov 1978;")
    print("        Turner-Mathews NNDB 2010)")
    print("  (b) ANTISENSE-OLIGO : OLIGONUCLEOTIDE axis")
    print("        nusinersen-like ISS-N1 hybridization (SantaLucia 1998)")
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
        print(f"         precedent   = {row['drug_precedent']}")
        print(f"         SMN2 target = {row['smn2_target']}")
        print(f"         model signal: {row['model_signal_name']} = "
              f"{row['model_signal_value']}")
        print(f"                       [{row['model_signal_units']}]")
        print(f"         real limit  = {row['real_limit_anchor']}")
        for cite in row["real_limit_citations"]:
            print(f"           cite: {cite}")
        for e in errs:
            print(f"         x {e}")

    # --- the two signals must be reported as NON-commensurable.
    print()
    if comp["comparison_is_ranking"] is False and \
            comp["signals_commensurable"] is False:
        print("  [PASS] comparison framing — descriptive side-by-side, "
              "NOT a ranking;")
        print("         signals declared non-commensurable "
              "(different units / real limits)")
    else:
        fails += 1
        print("  [FAIL] comparison framing — must NOT be a ranking")

    # --- both modalities anchored to their OWN real limit (g1).
    sm = rows[0]
    aso = rows[1]
    if "RNA secondary-structure" in sm["real_limit_anchor"] and \
            "duplex hybridization" in aso["real_limit_anchor"]:
        print("  [PASS] real-limit anchors — each modality anchored to "
              "its own real limit")
    else:
        fails += 1
        print("  [FAIL] real-limit anchors — modality missing its own "
              "real limit")

    # --- honesty block present and asserts comparison != ranking.
    h = comp["honesty"]
    if (h["in_silico_only"] and h["not_an_efficacy_ranking"]
            and h["not_a_superiority_claim"] and h["not_a_clinical_claim"]
            and h["both_drugs_fda_approved"]):
        print("  [PASS] honesty block — in-silico-only, not a ranking, "
              "not a superiority claim")
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
    print(f"  shared target : {comp['shared_gene_target']} — "
          f"{comp['shared_splicing_event']}")
    print(f"  shared goal   : {comp['shared_biological_goal']}")
    print(f"  (a) SMALL-MOLECULE  signal "
          f"{sm['model_signal_name']} = {sm['model_signal_value']} "
          f"[{sm['model_signal_units']}]")
    print(f"  (b) ANTISENSE-OLIGO signal "
          f"{aso['model_signal_name']} = {aso['model_signal_value']} "
          f"[{aso['model_signal_units']}]")
    print("  The two signals are in different units on different real")
    print("  limits — reported side by side, NOT ranked.")

    print()
    print("  ── in-silico honesty caveat (governance g8 / f2 / g3 / f1) ──")
    print("  This is a MODALITY COMPARISON of two in-silico model")
    print("  signatures — NOT an efficacy ranking, NOT a claim that one")
    print("  drug or modality is superior, NOT a clinical claim. risdiplam")
    print("  (Evrysdi, FDA 2020) and nusinersen (Spinraza, FDA 2016) are")
    print("  BOTH FDA-approved SMA drugs. Every PASS certifies in-silico")
    print("  simulator + metadata internal consistency ONLY. Modalities")
    print("  are described via their own drug precedent only — nothing is")
    print("  derived from the n=6 lattice (g3 / f1 / f_lattice_fit). The")
    print("  SMN2 / ISS-N1 sequences are toy constructs; the wet-lab")
    print("  boundary is out of repo scope (CLOSURE_RESIDUAL_BACKLOG §0).")
    print()

    total = len(rows) + 4
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
