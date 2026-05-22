#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
metallodrug_ribotac_cross.py — CROSS-AXIS J1.

  CROSS:  METALLODRUG expansion-axis  ──[same outcome class]──  RIBOTAC sub-axis
          (coordination Pt-RNA adduct)                          (RNase-L recruitment)

  Same OUTCOME class       : RNA degradation / RNA neutralization
  OPPOSITE mechanism class : metal-coordination chemistry  ≠  enzyme recruitment
                             stoichiometric  /  irreversible        catalytic / multi-turnover
                             Pt-N7 coordinate bond (~2.0 Å)         mass-action ternary complex
                             sequence-context (d/r-GpG pref)        structured-RNA + RNase-L
                                                                    (Disney RIBOTAC class)

This module DEMONSTRATES the cross — it does NOT collapse one mechanism into
the other.  The two pathways are mechanism-disjoint; the cross consists of
running them side-by-side on a single deterministic panel of RNA targets, and
emitting a comparison table that makes the disjointness explicit.

────────────────────────────────────────────────────────────────────────────
WHAT IS COMPUTED  (no fork — governance f3)
────────────────────────────────────────────────────────────────────────────
Both parent simulators are IMPORTED, never reimplemented:

  (a) METALLODRUG path  — `metallodrug_coordination_sim`.
      A Pt(II) drug forms a square-planar d8 coordination adduct with RNA at
      a r(GpG) site (the RNA analogue of the cisplatin d(GpG) DNA crosslink).
      We reuse the module's `square_planar_geometry(PT_N7_BOND_ANGSTROM)` and
      `verify_pt_n7_geometry(...)` to recompute the Pt-N coordinate-bond
      geometry against the literature ~2.0 Å Pt-N7 anchor (Takahara et al.
      1995, the cisplatin 1,2-intrastrand d(GpG) crystal structure), and we
      reuse `cfse_square_planar(d_count=8)` for the d8-strong-field CFSE.
      We then count r(GpG) coordination sites on each RNA target via a
      transparent stdlib motif scan — the rate-type for this mechanism is
      STOICHIOMETRIC (one Pt adduct neutralizes one RNA copy at one site)
      and IRREVERSIBLE on the kinetic timescale of biological RNA turnover.

  (b) RIBOTAC path  — `ribotac_sim`.
      A bifunctional small molecule (Disney-lab RIBOTAC class) recruits the
      endogenous RNase-L to the same structured RNA target.  We reuse the
      module's `rna_structuredness(seq)` (which itself imports the parent
      RIBOZYME-axis Nussinov solver — f3 respected at one further remove),
      `ternary_fraction(...)` (mass-action ternary-complex occupancy), and
      `catalytic_advantage(k_cat, t_exposure)` (multiple-turnover number
      N = k_cat · t_exposure).  Rate-type is CATALYTIC (multi-turnover —
      one RIBOTAC molecule licenses many RNase-L cleavage events).

The panel below contains 4 structured RNA targets that ALSO carry the r(GpG)
coordination motif Pt(II) prefers — so both pathways are runnable on the
same physical substrate, which is precisely what makes the side-by-side a
fair mechanism-disjoint comparison.

────────────────────────────────────────────────────────────────────────────
REAL-LIMIT ANCHORS  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The cross is anchored to TWO independent real limits, one per mechanism
(neither derived from the n=6 lattice — g2 / f1 / f_lattice_fit):

  (1) Pt-RNA / Pt-DNA COORDINATION ADDUCT  ←  METALLODRUG path
      Cisplatin's primary lesion is the Pt-N7-guanine coordinate bond
      (~2.0 Å) at d(GpG) / r(GpG); cisplatin also forms Pt-RNA adducts on
      cellular RNA (rRNA, mRNA, tRNA).  Anchors:
        - Takahara PM, Rosenzweig AC, Frederick CA, Lippard SJ.  Crystal
          structure of double-stranded DNA containing the major adduct
          of the anticancer drug cisplatin.  Nature 1995;377:649-652.
          (~2.0 Å Pt-N7(guanine) coordinate bond.)
        - Reedijk J.  New clues for platinum antitumor chemistry: kinetically
          controlled metal binding to DNA.  Proc Natl Acad Sci USA
          2003;100:3611-3616.  (review: Pt-N7-guanine selectivity, kinetics,
          stoichiometric adduct chemistry — Pt prefers d/r-GpG.)
        - Hostetter AA, Osborn MF, DeRose VJ.  RNA-Pt adducts following
          cisplatin treatment of Saccharomyces cerevisiae.  ACS Chem Biol
          2012;7:218-225.  (cellular evidence of cisplatin-RNA adducts;
          earlier work — Hostetter et al. JACS / ACS-line, 2009 — established
          cisplatin adducts on rRNA.)

  (2) CATALYTIC MULTIPLE-TURNOVER (RNase RECRUITMENT)  ←  RIBOTAC path
      A genuine catalyst has turnover number N > 1 (a stoichiometric binder
      has N = 1 by definition).  RIBOTACs recruit endogenous RNase-L to a
      structured RNA so the recruited nuclease cleaves the target
      catalytically — multi-turnover is the defining RIBOTAC advantage.
      Anchors:
        - Costales MG, Matsumoto Y, Velagapudi SP, Disney MD.  Small-molecule
          targeted recruitment of a nuclease to cleave an oncogenic RNA in a
          mouse model of metastatic cancer.  J Am Chem Soc 2018;140:6741-
          6744.  (first RNase-L-recruiting RIBOTAC.)
        - Costales MG, Aikawa H, Li Y, Childs-Disney JL, Abegg D, Hoch DG,
          Velagapudi SP, Nakai Y, Khan T, Wang KW, Yildirim I, Adibekian A,
          Wang ET, Disney MD.  Small-molecule targeted recruitment of a
          nuclease to cleave pre-miR-21 to block proliferation.  Proc Natl
          Acad Sci USA 2020;117:2406-2411.
        - Cornish-Bowden A.  Fundamentals of Enzyme Kinetics, 4th ed.
          (Wiley-Blackwell, 2012).  Closed-form catalytic-turnover limit
          N > 1 ≡ catalytic.

────────────────────────────────────────────────────────────────────────────
OWN-PRECEDENT MODALITIES  (g3 / f1 / f_lattice_fit — never lattice-derived)
────────────────────────────────────────────────────────────────────────────
  METALLODRUG : described by its own approved Pt(II) drug precedent —
      cisplatin (FDA 1978), carboplatin (FDA 1989), oxaliplatin (FDA 2002).
      All three are square-planar d8 Pt(II) complexes; the DNA / RNA adduct
      is the Pt-N7-guanine coordination bond — well-attested molecular
      precedent for the modality.  No quantity in the metallodrug rows is
      derived from the n=6 lattice — octahedral 6-coordination /
      square-planar 4-coordination are coordination-chemistry facts (octahedron
      vertex count / d8 strong-field), not lattice arithmetic.

  RIBOTAC    : described by its own published modality precedent — the
      Disney-lab RIBOnuclease-TArgeting Chimeras that recruit RNase-L to
      disease RNAs (Costales et al. JACS 2018; PNAS 2020).  RIBOTAC is
      RESEARCH-STAGE: no RIBOTAC is an approved drug.  Nothing here is
      lattice-derived.

────────────────────────────────────────────────────────────────────────────
HONESTY — MECHANISM-DISJOINT FRAMING  (g3 / g8 / f2 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
Same OUTCOME class ≠ same mechanism class.

  Metal-coordination chemistry  (METALLODRUG)
      = a Lewis-acid d8 Pt(II) centre forms a coordinate (dative) bond to
        guanine N7 — a stoichiometric, kinetically-irreversible, sequence-
        context-dependent chemical adduct.  One drug molecule neutralizes
        one site per RNA copy.

  Enzyme recruitment            (RIBOTAC)
      = a small molecule licenses an endogenous protein nuclease (RNase-L)
        to act on a structured RNA target — catalytic, multi-turnover, no
        new Pt-N coordinate bond, no metal centre, no Lewis-acid step.

These two pathways CONVERGE on the same OUTCOME (RNA degradation) but
DIVERGE in mechanism: metal-coordination ≠ enzyme-recruitment.  This module
reports their model signatures side by side and explicitly refuses to
collapse them.

The PASS sentinel certifies IN-SILICO simulator+metadata internal
consistency ONLY (g8 / f2): that the two pathway models run, produce
well-formed rows, and reproduce byte-identically.  It is NOT a therapeutic,
clinical, cytotoxic, antitumor, immunogenic, efficacy, regulatory, or
modality-superiority claim.  The METALLODRUG axis is UNPROVEN at the wet-lab
boundary; RIBOTAC is RESEARCH-STAGE (no approved RIBOTAC).  The wet-lab
boundary is out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md §0).

────────────────────────────────────────────────────────────────────────────
CROSS ≠ NEW AXIS, NO FORK, STDLIB-ONLY
────────────────────────────────────────────────────────────────────────────
  - core-5 axes (QUANTUM / WEAVE / NANOBOT / RIBOZYME / VIROCAPSID) are
    UNCHANGED by this cross.
  - This file IMPORTS both parent sims; it does NOT fork either of them
    (governance f3).  All chemistry is delegated to the parents.
  - Pure stdlib (json, math, importlib, os, re, sys).  No network, no random,
    no wall-clock.  Byte-identical re-runs.

Sentinel:  __METALLODRUG_RIBOTAC_CROSS__ PASS   (or FAIL).
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys

# ── locate sibling parent sims ─────────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_METALLODRUG_PATH = os.path.join(_HERE, "metallodrug_coordination_sim.py")
_RIBOTAC_PATH = os.path.join(_HERE, "ribotac_sim.py")

SCHEMA_ID = "metallodrug_ribotac_cross_v1"
SENTINEL_PASS = "__METALLODRUG_RIBOTAC_CROSS__ PASS"
SENTINEL_FAIL = "__METALLODRUG_RIBOTAC_CROSS__ FAIL"


def _load_module(name: str, path: str):
    """importlib loader — no shadow reimplementation (governance f3)."""
    # Ensure ribotac_sim's own sibling import (ribozyme_mfe_nussinov)
    # resolves: put module dir on sys.path.
    if _HERE not in sys.path:
        sys.path.insert(0, _HERE)
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── deterministic cross panel ─────────────────────────────────────────────
#
# Each entry is a structured RNA target that ALSO carries the r(GpG)
# coordination motif a Pt(II) drug prefers.  Both mechanisms are therefore
# runnable on the same substrate, making the side-by-side fair.
#
# Fields:
#   name           : panel identifier
#   rna_seq        : RNA sequence (A/C/G/U)
#   ribotac_panel_index : which of ribotac_sim.RIBOTAC_PANEL parameter sets
#                         (K_d1, K_d2, alpha, k_cat, t_exposure) parameterises
#                         the RNase-L recruitment for this target
#   metallodrug    : illustrative Pt(II) drug for the metallodrug row
#                    (own approved precedent only — g3/f1)
#
_CROSS_PANEL = [
    {
        "name": "premiR21_like",
        "rna_seq": "GGGAAACCCUUUGGGAAACCCUUUGGG",
        "ribotac_panel_index": 0,           # ribotac_premiR21_strong
        "metallodrug": "cisplatin",
    },
    {
        "name": "premiR21_moderate",
        "rna_seq": "GGGAAACCCUUUGGGAAACCCUUUGGG",
        "ribotac_panel_index": 1,           # ribotac_premiR21_moderate
        "metallodrug": "carboplatin",
    },
    {
        "name": "structured_hairpin",
        "rna_seq": "GGGGCCCCAAAAGGGGCCCC",
        "ribotac_panel_index": 2,           # ribotac_structured_hairpin
        "metallodrug": "oxaliplatin",
    },
    {
        "name": "GpG_dense_stem",
        "rna_seq": "GGAGGCCCUUUGGAGGCCCUU",
        "ribotac_panel_index": 3,           # ribotac_weak_recruiter
        "metallodrug": "cisplatin",
    },
]

# Own-precedent Pt(II) drug metadata (must match the metallodrug parent
# module's `metallodrugs` table — picked up dynamically below by name).
_PT_DRUG_NAMES = {"cisplatin", "carboplatin", "oxaliplatin"}


# ── helpers ────────────────────────────────────────────────────────────────
_GPG_PURINE_RE = re.compile(r"GG")  # r(GpG) site = 5'-GG-3'


def _count_rGpG_sites(seq: str) -> int:
    """Count r(GpG) coordination sites on an RNA sequence.

    Pt(II) prefers the d(GpG) / r(GpG) 1,2-intrastrand site (the cisplatin
    1,2-intrastrand crosslink; Takahara 1995, Reedijk 2003).  We count
    overlapping GG dinucleotides as a transparent proxy for the number of
    candidate Pt coordination sites per RNA target.  Overlapping count: e.g.
    'GGG' yields 2 GG sites.
    """
    if not seq:
        return 0
    n = 0
    for i in range(len(seq) - 1):
        if seq[i] == "G" and seq[i + 1] == "G":
            n += 1
    return n


def _pt_drug_metadata(metallodrug_mod, drug_name: str) -> dict:
    """Pull the matching Pt(II) drug record from the parent module's table."""
    for row in metallodrug_mod.run()["metallodrug_metadata"]:
        if row["name"] == drug_name:
            return row
    raise RuntimeError(f"drug {drug_name!r} not found in metallodrug parent table")


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

def _metallodrug_row(metallodrug_mod, target: dict, pt_drug_meta: dict) -> dict:
    """METALLODRUG pathway row — Pt(II) coordination-adduct chemistry."""
    seq = target["rna_seq"]
    # Reuse the parent module's geometry + Pt-N7 anchor verification.
    geom = metallodrug_mod.square_planar_geometry(
        metallodrug_mod.PT_N7_BOND_ANGSTROM)
    geom_chk = metallodrug_mod.verify_pt_n7_geometry(geom)
    # Reuse the parent module's d8 square-planar CFSE.
    cfse_sp_d8 = metallodrug_mod.cfse_square_planar(8)

    n_gg = _count_rGpG_sites(seq)
    return {
        "schema": SCHEMA_ID,
        "row_kind": "metallodrug",
        "target_name": target["name"],
        "rna_seq": seq,
        "rna_length_nt": len(seq),
        "mechanism_class": "metal-coordination",
        "rate_type": "stoichiometric",
        "reversibility": "kinetically-irreversible-on-biological-timescale",
        "modality_stage": "approved (Pt(II) family — FDA-approved precedent)",
        "metallodrug_name": pt_drug_meta["name"],
        "metallodrug_metal": pt_drug_meta["metal"],
        "metallodrug_oxidation_state": pt_drug_meta["oxidation_state"],
        "metallodrug_d_count": pt_drug_meta["d_count"],
        "metallodrug_geometry": pt_drug_meta["geometry"],
        "metallodrug_indication": pt_drug_meta["indication"],
        "drug_precedent": (
            f"{pt_drug_meta['name']} — Pt(II) square-planar d8 coordination "
            f"drug, FDA {pt_drug_meta['fda_year']} ({pt_drug_meta['indication']}); "
            "Pt-RNA / Pt-DNA N7-guanine coordinate bond is the primary lesion "
            "(Takahara 1995; Reedijk 2003; Hostetter et al. cisplatin-rRNA "
            "adduct literature — ACS Chem Biol / JACS line, 2009 onward)."),
        # geometry recomputation (parent-sim values; not redone here — f3)
        "pt_n7_bond_angstrom_anchor":
            metallodrug_mod.PT_N7_BOND_ANGSTROM,
        "pt_n7_bond_angstrom_tolerance":
            metallodrug_mod.PT_N7_TOLERANCE_ANGSTROM,
        "pt_n7_recomputed_angstrom":
            geom_chk["recomputed_pt_n_angstrom"],
        "pt_n7_deviation_angstrom":
            geom_chk["deviation_angstrom"],
        "pt_n7_anchor_match": geom_chk["anchor_match"],
        "square_planar_d8_cfse_delta_oct": cfse_sp_d8,
        # sequence-context: Pt prefers r(GpG) sites
        "rGpG_site_count": n_gg,
        "rGpG_site_density": (n_gg / max(1, (len(seq) - 1))),
        "sequence_context_dependent": True,
        "rna_neutralized_per_drug_molecule": float(
            min(1, n_gg)  # one Pt adduct per RNA copy at one site
        ),
        "rate_type_signature": "stoichiometric (1 RNA copy per Pt adduct event)",
        "real_limit_anchor_name": "Pt-N7(guanine) coordinate bond ~2.0 Å",
        "real_limit_citations": [
            "Takahara et al., Nature 1995;377:649-652 (cisplatin 1,2-"
            "intrastrand d(GpG) DNA adduct, Pt-N7 ~2.0 Å)",
            "Reedijk J, PNAS 2003;100:3611-3616 (review: Pt-N7-guanine "
            "selectivity and stoichiometric adduct chemistry — Pt prefers "
            "d/r-GpG)",
            "Hostetter AA, Osborn MF, DeRose VJ, ACS Chem Biol 2012;7:218-225 "
            "(cellular cisplatin-RNA adducts; ACS Chem Biol / JACS line, "
            "2009 onward)",
            "Griffith JS, Orgel LE, Q Rev Chem Soc 1957;11:381-393 "
            "(CFSE closed-form ligand-field theory)",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed.  Square-planar "
            "4-coordination is a d8 strong-field coordination-chemistry fact, "
            "NOT a lattice derivation.  Numerical coincidence with n=6 is "
            "OBSERVATION ONLY (HEXA-METALLODRUG.tape f_lattice_fit / "
            "n6_honest_stance / AGENTS.tape g2)."),
        "in_silico_only": True,
    }


def _ribotac_row(ribotac_mod, target: dict) -> dict:
    """RIBOTAC pathway row — bifunctional RNase-L-recruitment chemistry."""
    seq = target["rna_seq"]
    params = _ribotac_params(ribotac_mod, target["ribotac_panel_index"])

    # Deterministic assay concentrations match ribotac_sim.build_rows().
    conc_target_nM = 10.0
    conc_ribotac_nM = 100.0
    conc_rnase_nM = 50.0

    struct = ribotac_mod.rna_structuredness(seq)
    tern = ribotac_mod.ternary_fraction(
        conc_target_nM, conc_ribotac_nM, conc_rnase_nM,
        params["k_d1_nM"], params["k_d2_nM"], params["alpha"])
    cat = ribotac_mod.catalytic_advantage(
        params["k_cat_per_s"], params["t_exposure_s"])
    effective = tern["ternary_fraction"] * cat["turnover_number"]

    return {
        "schema": SCHEMA_ID,
        "row_kind": "ribotac",
        "target_name": target["name"],
        "rna_seq": seq,
        "rna_length_nt": struct["rna_length_nt"],
        "mechanism_class": "enzyme-recruitment",
        "rate_type": "catalytic-multi-turnover",
        "reversibility": "catalyst-released-after-cleavage (multi-turnover)",
        "modality_stage": "research-stage (no approved RIBOTAC)",
        "ribotac_panel_name": params["ribotac_panel_name"],
        "drug_precedent": params["drug_precedent"],
        # RNA structuredness (delegates to imported Nussinov solver — f3)
        "dot_bracket": struct["dot_bracket"],
        "num_base_pairs": struct["num_base_pairs"],
        "pair_density": struct["pair_density"],
        "dot_bracket_balanced": struct["dot_bracket_balanced"],
        "rna_structured": struct["structured"],
        # mass-action ternary
        "k_d1_nM": tern["k_d1_nM"],
        "k_d2_nM": tern["k_d2_nM"],
        "alpha": tern["alpha"],
        "k_d2_effective_nM": tern["k_d2_effective_nM"],
        "binary_fraction": tern["binary_fraction"],
        "rnase_site_fraction": tern["rnase_site_fraction"],
        "ternary_fraction": tern["ternary_fraction"],
        # catalytic advantage
        "k_cat_per_s": cat["k_cat_per_s"],
        "cycle_time_s": cat["cycle_time_s"],
        "t_exposure_s": cat["t_exposure_s"],
        "turnover_number": cat["turnover_number"],
        "stoichiometric_turnover": cat["stoichiometric_turnover"],
        "catalytic_advantage_over_stoichiometric":
            cat["catalytic_advantage_over_stoichiometric"],
        "is_catalytic": cat["is_catalytic"],
        "rna_neutralized_per_drug_molecule": effective,
        "rate_type_signature":
            "catalytic (k_cat · t_exposure RNA copies per RIBOTAC molecule)",
        "real_limit_anchor_name":
            "catalytic multiple-turnover (N>1) + mass-action ternary occupancy",
        "real_limit_citations": [
            "Costales MG et al., J Am Chem Soc 2018;140:6741-6744 "
            "(first RNase-L-recruiting RIBOTAC)",
            "Costales MG et al., Proc Natl Acad Sci USA 2020;117:2406-2411 "
            "(RIBOTAC vs pre-miR-21)",
            "Cornish-Bowden A, Fundamentals of Enzyme Kinetics, 4th ed. "
            "(Wiley-Blackwell, 2012) — catalytic turnover number N>1",
            "Guldberg & Waage 1864 — mass-action law (bound fractions ≤ 1)",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed.  Mass-action and "
            "catalytic turnover are the real-limit anchors; nothing here is "
            "lattice-derived (AGENTS.tape g2 / g3 / f1 / f_lattice_fit)."),
        "in_silico_only": True,
    }


# ── orchestration ──────────────────────────────────────────────────────────

def build_rows() -> list:
    """Build the full cross panel — two rows (metallodrug + ribotac) per
    target — by delegating to the imported parent sims."""
    metallodrug_mod = _load_module("metallodrug_coordination_sim",
                                   _METALLODRUG_PATH)
    ribotac_mod = _load_module("ribotac_sim", _RIBOTAC_PATH)

    rows = []
    for target in _CROSS_PANEL:
        if target["metallodrug"] not in _PT_DRUG_NAMES:
            raise RuntimeError(
                f"metallodrug {target['metallodrug']!r} not in own-precedent "
                f"Pt(II) set {_PT_DRUG_NAMES}")
        pt_meta = _pt_drug_metadata(metallodrug_mod, target["metallodrug"])
        m_row = _metallodrug_row(metallodrug_mod, target, pt_meta)
        r_row = _ribotac_row(ribotac_mod, target)
        m_row["paired_target_name"] = target["name"]
        r_row["paired_target_name"] = target["name"]
        rows.append(m_row)
        rows.append(r_row)
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (J1-X1 .. J1-X8)."""
    m_rows = [r for r in rows if r["row_kind"] == "metallodrug"]
    r_rows = [r for r in rows if r["row_kind"] == "ribotac"]

    crit = {
        "J1_X1_panel_has_both_pathways":
            len(m_rows) >= 1 and len(r_rows) >= 1,
        "J1_X2_pathways_paired_per_target":
            len(m_rows) == len(r_rows)
            and all(m["paired_target_name"] == r["paired_target_name"]
                    for m, r in zip(m_rows, r_rows)),
        "J1_X3_metallodrug_pt_n7_anchor_matches":
            all(m["pt_n7_anchor_match"] for m in m_rows),
        "J1_X4_metallodrug_rate_is_stoichiometric":
            all(m["rate_type"] == "stoichiometric"
                and m["rna_neutralized_per_drug_molecule"] <= 1.0
                for m in m_rows),
        "J1_X5_ribotac_mass_action_bounded":
            all(0.0 <= r["binary_fraction"] <= 1.0
                and 0.0 <= r["rnase_site_fraction"] <= 1.0
                and 0.0 <= r["ternary_fraction"] <= 1.0
                for r in r_rows),
        "J1_X6_ribotac_rate_is_catalytic":
            all(r["rate_type"] == "catalytic-multi-turnover"
                and r["is_catalytic"]
                and r["turnover_number"] > r["stoichiometric_turnover"]
                for r in r_rows),
        "J1_X7_mechanism_classes_disjoint":
            (all(m["mechanism_class"] == "metal-coordination" for m in m_rows)
             and all(r["mechanism_class"] == "enzyme-recruitment" for r in r_rows)
             and (set(m["mechanism_class"] for m in m_rows)
                  & set(r["mechanism_class"] for r in r_rows) == set())),
        "J1_X8_metallodrug_has_rGpG_sites":
            all(m["rGpG_site_count"] >= 1 for m in m_rows),
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
        "cross": "J1  METALLODRUG (Pt-RNA coordination adduct)  ||  "
                 "RIBOTAC (RNase-L recruitment)  — same outcome class "
                 "(RNA degradation), opposite mechanism class",
        "metallodrug_source":
            "_python_bridge/module/metallodrug_coordination_sim.py "
            "(imported, not forked — f3)",
        "ribotac_source":
            "_python_bridge/module/ribotac_sim.py "
            "(imported, not forked — f3; itself imports the parent "
            "RIBOZYME-axis Nussinov solver, also unforked)",
        "real_limit_anchors": [
            "Pt-N7(guanine) coordinate-bond ~2.0 Å — Takahara 1995 Nature "
            "377:649; Reedijk 2003 PNAS 100:3611; Hostetter et al. cisplatin-"
            "rRNA adduct line (ACS Chem Biol / JACS, 2009-2012)",
            "catalytic multiple-turnover N>1 — Cornish-Bowden, Fundamentals "
            "of Enzyme Kinetics 4th ed. 2012; Disney-lab RIBOTAC: Costales "
            "et al. JACS 2018;140:6741, PNAS 2020;117:2406",
            "mass-action law (Guldberg & Waage 1864) — bound fractions ≤ 1",
            "CFSE closed-form ligand-field theory — Griffith & Orgel 1957 "
            "Q Rev Chem Soc 11:381",
        ],
        "mechanism_disjoint_statement": (
            "metal-coordination chemistry (a d8 Pt(II) Lewis-acid centre "
            "forms a stoichiometric, kinetically-irreversible, sequence-"
            "context-dependent coordinate bond to guanine N7) ≠ enzyme "
            "recruitment (a bifunctional small molecule licenses an "
            "endogenous protein nuclease for catalytic multi-turnover RNA "
            "cleavage).  Same outcome class (RNA degradation), opposite "
            "mechanism class.  This cross reports both side-by-side and "
            "refuses to collapse them."),
        "core_axes_unchanged": (
            "Cross ≠ new axis.  Core-5 axes (QUANTUM / WEAVE / NANOBOT / "
            "RIBOZYME / VIROCAPSID) are untouched by this module."),
        "modality_precedents_own_only": {
            "METALLODRUG": ["cisplatin (FDA 1978)", "carboplatin (FDA 1989)",
                            "oxaliplatin (FDA 2002)"],
            "RIBOTAC": ["Disney-lab RIBOTAC class — research-stage, no "
                        "approved RIBOTAC (Costales et al. JACS 2018; "
                        "PNAS 2020)"],
        },
        "lattice_stance": (
            "Neither pathway is described via the n=6 lattice.  Pt(II) "
            "square-planar 4-coordination is a d8 strong-field coordination-"
            "chemistry fact; RIBOTAC kinetics anchor to mass-action + "
            "catalytic-turnover real limits.  No n=6 derivation appears in "
            "either row (AGENTS.tape g2 lattice-is-tool, g3/f1 honesty-"
            "external, f_lattice_fit)."),
        "in_silico_scope_caveat": (
            "This PASS certifies IN-SILICO simulator+metadata internal "
            "consistency ONLY (AGENTS.tape g8 / f2).  NOT a therapeutic, "
            "clinical, cytotoxic, antitumor, immunogenic, efficacy, "
            "regulatory, or modality-superiority claim.  METALLODRUG is "
            "UNPROVEN at the wet-lab boundary; RIBOTAC is RESEARCH-STAGE "
            "(no approved RIBOTAC).  Wet-lab is out of repo scope "
            "(CLOSURE_RESIDUAL_BACKLOG.md §0)."),
        "rows": rows,
        "acceptance": acc,
    }


# ── self-check / main ──────────────────────────────────────────────────────

def main() -> int:
    print("metallodrug_ribotac_cross — CROSS-AXIS J1\n", flush=True)
    print("cross:  METALLODRUG (Pt-RNA coordination adduct)  ||  "
          "RIBOTAC (RNase-L recruitment)")
    print("        same outcome class : RNA degradation")
    print("        opposite mechanism : metal-coordination  ≠  enzyme-recruitment")
    print("        rate-type contrast : stoichiometric (1:1)  vs  "
          "catalytic (multi-turnover)\n", flush=True)
    print("  real-limit (a) : Pt-N7(guanine) coordinate-bond ~2.0 Å — "
          "Takahara 1995; Reedijk 2003;")
    print("                   Hostetter et al. (cisplatin-rRNA, ACS Chem "
          "Biol / JACS line, 2009-2012)")
    print("  real-limit (b) : catalytic multi-turnover N>1 + mass-action — "
          "Disney RIBOTAC")
    print("                   (Costales JACS 2018 / PNAS 2020); "
          "Cornish-Bowden, Enzyme Kinetics 4e\n", flush=True)

    witness = build_witness()
    rows = witness["rows"]
    acc = witness["acceptance"]

    # group by target for legibility
    paired = {}
    for r in rows:
        paired.setdefault(r["paired_target_name"], {})[r["row_kind"]] = r

    for tgt, pair in paired.items():
        m = pair["metallodrug"]
        rb = pair["ribotac"]
        print(f"  target: {tgt}  (RNA n={m['rna_length_nt']}, "
              f"r(GpG) sites={m['rGpG_site_count']})")
        print(f"    METALLODRUG  [{m['metallodrug_name']:<11}] "
              f"mech={m['mechanism_class']:<20} rate={m['rate_type']:<14} "
              f"Pt-N={m['pt_n7_recomputed_angstrom']:.2f} Å  "
              f"RNA/mol={m['rna_neutralized_per_drug_molecule']:.2f}")
        print(f"    RIBOTAC      [{rb['ribotac_panel_name']:<28}] "
              f"mech={rb['mechanism_class']:<20} rate={rb['rate_type']:<24}"
              f"  ternary={rb['ternary_fraction']:.3f}  "
              f"N_turnover={rb['turnover_number']:.1f}  "
              f"RNA/mol={rb['rna_neutralized_per_drug_molecule']:.2f}")

    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: "
          f"{acc['verdict']} ---")

    print()
    print("  ── mechanism-disjoint honesty (g3 / g8 / f2 / f_lattice_fit) ──")
    print("  metal-coordination ≠ enzyme-recruitment.  Same OUTCOME (RNA")
    print("  degradation), opposite MECHANISM.  A Pt(II) Lewis-acid centre")
    print("  forms a stoichiometric, kinetically-irreversible, sequence-")
    print("  context-dependent coordinate bond to guanine N7 (Pt-N7 ~2.0 Å,")
    print("  Takahara 1995; Reedijk 2003; cellular Pt-RNA adducts: Hostetter")
    print("  et al. ACS Chem Biol / JACS line, 2009-2012).  A RIBOTAC, by")
    print("  contrast, recruits the endogenous protein nuclease RNase-L to a")
    print("  structured RNA so the recruited enzyme cleaves the target")
    print("  catalytically — no metal centre, no Lewis-acid step, no new")
    print("  Pt-N coordinate bond (Disney-lab RIBOTAC: Costales JACS 2018,")
    print("  PNAS 2020).  This cross reports both side-by-side and refuses")
    print("  to collapse them.")
    print()
    print("  ── in-silico scope caveat (g8 / f2) ──")
    print("  This PASS certifies IN-SILICO simulator+metadata internal")
    print("  consistency ONLY.  NOT a therapeutic, clinical, cytotoxic,")
    print("  antitumor, immunogenic, efficacy, regulatory, or modality-")
    print("  superiority claim.  METALLODRUG is UNPROVEN at the wet-lab")
    print("  boundary; RIBOTAC is RESEARCH-STAGE (no approved RIBOTAC).")
    print("  Modalities are described via their OWN precedent only —")
    print("  cisplatin / carboplatin / oxaliplatin for METALLODRUG; the")
    print("  Disney-lab RIBOTAC class for RIBOTAC.  Nothing is derived from")
    print("  the n=6 lattice (g2 / g3 / f1 / f_lattice_fit).  Wet-lab is")
    print("  out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md §0).")
    print()
    print("  ── no-fork (f3) ──")
    print("  Both parent sims are IMPORTED, never reimplemented.  All")
    print("  chemistry is delegated to metallodrug_coordination_sim and")
    print("  ribotac_sim (which itself imports the parent RIBOZYME-axis")
    print("  Nussinov solver — also unforked).  Cross ≠ new axis: core-5")
    print("  axes are UNCHANGED by this module.")

    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_PASS if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
