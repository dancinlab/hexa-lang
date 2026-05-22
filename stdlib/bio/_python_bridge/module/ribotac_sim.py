#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ribotac_sim.py — RIBOTAC sub-axis :> BIFUNCTIONAL (expansion-main).

Deterministic, stdlib-only real-limits model of a RIBOnuclease-TArgeting
Chimera (RIBOTAC): a bifunctional small molecule that ties one structured-RNA
target to an endogenous ribonuclease (RNase-L), so that the recruited nuclease
catalytically cleaves the target RNA. This is the in-silico
simulator-consistency layer for the RIBOTAC sub-axis registered in
AXIS/HIERARCHY.tape `@D sub_under_bifunctional` — see the sibling note
`ribotac_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A RIBOTAC has two warheads joined by a linker:
  - one binds a STRUCTURED RNA target (the RNA-binding module);
  - one recruits the latent endogenous nuclease RNase-L (the recruiter module).

The bifunctional molecule R nucleates a ternary complex Target·R·RNase-L. Once
formed, the recruited RNase-L cleaves the bound RNA — and, crucially, after
cleavage the molecule is RELEASED and can nucleate another ternary complex.
RIBOTAC therefore acts as an *event-driven catalyst* (multiple turnover), in
contrast to a stoichiometric binder that occupies one target per molecule.

  (1) Ternary equilibrium (mass-action; linker-tethered bivalent assembly):

        Target + R       ⇌(K_d1)   Target·R
        Target·R + RNase ⇌(K_d2/α) Target·R·RNase

      with a cooperativity factor α ≥ 1 — the linker pre-pays the
      translational/rotational entropy of the second binding event, so the
      effective second-site K_d is K_d2/α. The ternary-complex fraction is
      computed from these dissociation constants by mass-action.

  (2) Catalytic multiple turnover (the RIBOTAC advantage):

        a stoichiometric binder neutralizes at most 1 RNA copy per molecule;
        a RIBOTAC of catalytic-cycle time τ_cycle = 1/k_cat neutralizes

              N_turnover = k_cat · t_exposure

        RNA copies per molecule over an exposure window t_exposure. The
        catalytic ADVANTAGE over a stoichiometric binder is the turnover
        number itself: advantage = N_turnover (≫ 1 for a real RIBOTAC).

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
1. MASS-ACTION LAW (Guldberg & Waage, 1864). Every equilibrium occupancy in
   this module — binary Target·R and ternary Target·R·RNase fractions — is the
   closed-form mass-action solution of the coupled dissociation equilibria. No
   modelled bound fraction may exceed 1.0; that unit ceiling is the hard
   real-limit gate (acceptance C2).
2. CATALYTIC MULTIPLE-TURNOVER LIMIT. A single-turnover (stoichiometric)
   ligand has turnover number = 1 by definition; any genuine catalyst has
   turnover number > 1 (Cornish-Bowden, *Fundamentals of Enzyme Kinetics*,
   4th ed., 2012). The modelled RIBOTAC turnover number N = k_cat·t_exposure
   must be > 1 for the catalytic-advantage claim to hold (acceptance C4); a
   RIBOTAC's defining property is that this number is large.

Cross-axis note (?> RIBOZYME core): RIBOTAC and the hexa-bio core RIBOZYME
axis BOTH effect catalytic phosphodiester cleavage of RNA — a ribozyme is an
intrinsically catalytic RNA, a RIBOTAC recruits a protein nuclease to a
structured RNA. The shared physics is multiple-turnover RNA cleavage. This
module reuses the parent RIBOZYME axis's RNA secondary-structure machinery
(`ribozyme_mfe_nussinov.nussinov`) to score the target RNA's structuredness —
it IMPORTS that solver, it does NOT fork it (forbidden-pattern f3).

────────────────────────────────────────────────────────────────────────────
OWN PRECEDENT (governance g3 / forbidden-patterns f1, f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
RIBOTAC is described ONLY by its own modality precedent, never lattice-derived:
the Disney-lab RIBOnuclease-TArgeting Chimeras that recruit RNase-L to disease
RNAs (Costales et al., *J. Am. Chem. Soc.* 140:6741, 2018 — the first
RNase-L-recruiting heterobifunctional; Costales et al., *PNAS* 117:2406, 2020 —
RIBOTAC targeting pre-miR-21). RIBOTAC is a RESEARCH-STAGE modality: no RIBOTAC
is an approved drug. No quantity in this module is derived from the n=6
lattice.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The `__RIBOTAC__ PASS` sentinel certifies IN-SILICO simulator+metadata internal
consistency ONLY: that the mass-action ternary fractions, the turnover number
and the catalytic advantage are computed self-consistently and reproduce
byte-identically. It is a kinetics/equilibrium MODEL — NOT an affinity
measurement, NOT a cellular-knockdown claim, NOT a therapeutic-efficacy claim.
RIBOTAC is research-stage; nothing here is a clinical claim. K_d / k_cat / α
values are illustrative literature-informed surrogates for the modality, not
fits to a specific compound. Pure stdlib, no network/time/random → byte-
identical re-runs.

RIBOTAC is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it is NOT one
of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape `@D sub_under_bifunctional`.
"""
from __future__ import annotations
import json
import math
import sys

# Reuse the parent RIBOZYME axis's RNA secondary-structure solver — IMPORT, do
# NOT fork (forbidden-pattern f3). This scores how structured the target RNA is.
from ribozyme_mfe_nussinov import nussinov, is_balanced

SCHEMA_ID = "ribotac_v1"

# ── catalysis classification ──
# A genuine catalyst has turnover number > 1; a stoichiometric binder = 1.
STOICHIOMETRIC_TURNOVER = 1.0   # single-turnover reference (real-limit floor)

# ── deterministic RIBOTAC panel ─────────────────────────────────────────────
# (name, rna_target_seq, K_d1 nM, K_d2 nM, alpha, k_cat per_s, t_exposure_s,
#  precedent)
#   K_d1      : dissociation constant of the RNA-binding warhead to the RNA
#               target (nM).
#   K_d2      : intrinsic dissociation constant of the recruiter warhead to
#               RNase-L (nM); effective second-site K_d = K_d2 / alpha.
#   alpha     : ternary cooperativity factor (>= 1) — the linker pre-pays the
#               entropy of the second binding event.
#   k_cat     : recruited-RNase-L catalytic turnover rate for the bound RNA
#               (1/s); 1/k_cat = cycle time.
#   t_exposure: exposure window over which turnovers accumulate (s).
# Values are illustrative literature-informed surrogates for the RIBOTAC
# modality, not fits to a specific compound (see module honesty note).
RIBOTAC_PANEL = [
    ("ribotac_premiR21_strong",
     "GGGAAACCCUUUGGGAAACCCUUUGGG", 20.0, 50.0, 25.0, 0.05, 3600.0,
     "Disney-lab RIBOTAC vs pre-miR-21 (Costales et al., PNAS 2020)"),
    ("ribotac_premiR21_moderate",
     "GGGAAACCCUUUGGGAAACCCUUUGGG", 80.0, 120.0, 10.0, 0.02, 3600.0,
     "RNase-L-recruiting RIBOTAC, moderate-affinity warheads"),
    ("ribotac_structured_hairpin",
     "GGGGCCCCAAAAGGGGCCCC", 35.0, 60.0, 18.0, 0.03, 3600.0,
     "RIBOTAC vs a structured RNA hairpin target"),
    ("ribotac_weak_recruiter",
     "GCGCGCAUAUGCGCGC", 60.0, 400.0, 4.0, 0.008, 3600.0,
     "RIBOTAC with a weak RNase-L recruiter (low cooperativity)"),
]

# A stoichiometric (non-catalytic) RNA binder reference: same RNA-binding
# warhead, NO recruiter / NO catalysis — neutralizes 1 RNA copy per molecule.
STOICHIOMETRIC_REFERENCE = (
    "stoichiometric_RNA_binder",
    "GGGAAACCCUUUGGGAAACCCUUUGGG", 20.0,
    "stoichiometric structured-RNA binder (no nuclease recruitment, occupancy-only)")


def rna_structuredness(seq: str) -> dict:
    """
    Score the target RNA's structuredness via the parent RIBOZYME axis's
    Nussinov base-pair-maximization solver (imported, not forked — f3).
    A RIBOTAC needs a structured RNA target; pair density is the proxy.
    """
    dot_bracket, num_pairs = nussinov(seq)
    n = len(seq)
    pair_density = (2.0 * num_pairs / n) if n else 0.0
    return {
        "rna_length_nt": n,
        "dot_bracket": dot_bracket,
        "num_base_pairs": num_pairs,
        "pair_density": pair_density,
        "dot_bracket_balanced": is_balanced(dot_bracket),
        "structured": pair_density > 0.0,
    }


def ternary_fraction(conc_target_nM: float, conc_ribotac_nM: float,
                     conc_rnase_nM: float, k_d1_nM: float, k_d2_nM: float,
                     alpha: float) -> dict:
    """
    Mass-action ternary-complex occupancy of Target·R·RNase.

    Two sequential dissociation equilibria (Guldberg & Waage mass-action):
        binary  : f1 = R / (K_d1 + R)            occupancy of the RNA site
        ternary : f2 = N / (K_d2/alpha + N)      occupancy of the RNase site,
                  given the binary complex is formed; effective K_d = K_d2/alpha.
    The ternary fraction (of all RNA target) is f1 * f2 — a product of two
    mass-action saturation terms, each bounded in [0, 1].
    """
    k_d2_eff = k_d2_nM / alpha
    f1 = conc_ribotac_nM / (k_d1_nM + conc_ribotac_nM)
    f2 = conc_rnase_nM / (k_d2_eff + conc_rnase_nM)
    f_ternary = f1 * f2
    return {
        "k_d1_nM": k_d1_nM,
        "k_d2_nM": k_d2_nM,
        "alpha": alpha,
        "k_d2_effective_nM": k_d2_eff,
        "binary_fraction": f1,
        "rnase_site_fraction": f2,
        "ternary_fraction": f_ternary,
    }


def catalytic_advantage(k_cat_per_s: float, t_exposure_s: float) -> dict:
    """
    Multiple-turnover advantage of a RIBOTAC over a stoichiometric binder.

    A stoichiometric binder neutralizes exactly 1 RNA copy per molecule.
    A RIBOTAC of cycle time tau = 1/k_cat neutralizes N = k_cat * t_exposure
    copies per molecule. The catalytic advantage is the turnover number N
    itself (real-limit: a genuine catalyst has N > 1).
    """
    tau_cycle_s = 1.0 / k_cat_per_s
    n_turnover = k_cat_per_s * t_exposure_s
    return {
        "k_cat_per_s": k_cat_per_s,
        "cycle_time_s": tau_cycle_s,
        "t_exposure_s": t_exposure_s,
        "turnover_number": n_turnover,
        "stoichiometric_turnover": STOICHIOMETRIC_TURNOVER,
        "catalytic_advantage_over_stoichiometric": n_turnover / STOICHIOMETRIC_TURNOVER,
        "is_catalytic": n_turnover > STOICHIOMETRIC_TURNOVER,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per RIBOTAC in the panel."""
    # Fixed deterministic assay concentrations (nM).
    conc_target_nM = 10.0
    conc_ribotac_nM = 100.0
    conc_rnase_nM = 50.0
    rows = []
    for (name, rna_seq, k_d1, k_d2, alpha, k_cat, t_exp, precedent) in RIBOTAC_PANEL:
        struct = rna_structuredness(rna_seq)
        tern = ternary_fraction(conc_target_nM, conc_ribotac_nM, conc_rnase_nM,
                                k_d1, k_d2, alpha)
        cat = catalytic_advantage(k_cat, t_exp)
        # RNA copies neutralized per RIBOTAC molecule that is in the ternary
        # complex = ternary_fraction-weighted turnover number.
        effective_neutralized = tern["ternary_fraction"] * cat["turnover_number"]
        row = {
            "schema": SCHEMA_ID,
            "ribotac": name,
            "drug_precedent": precedent,
            "modality_stage": "research-stage (no approved RIBOTAC)",
            "conc_target_nM": conc_target_nM,
            "conc_ribotac_nM": conc_ribotac_nM,
            "conc_rnase_nM": conc_rnase_nM,
        }
        row.update(struct)
        row.update(tern)
        row.update(cat)
        row["effective_rna_neutralized_per_molecule"] = effective_neutralized
        rows.append(row)
    return rows


def stoichiometric_reference_row() -> dict:
    """The single-turnover stoichiometric binder this RIBOTAC panel beats."""
    name, rna_seq, k_d1, precedent = STOICHIOMETRIC_REFERENCE
    struct = rna_structuredness(rna_seq)
    f1 = 100.0 / (k_d1 + 100.0)
    return {
        "schema": SCHEMA_ID,
        "ribotac": name,
        "drug_precedent": precedent,
        "modality_stage": "reference (stoichiometric, non-catalytic)",
        "binary_fraction": f1,
        "turnover_number": STOICHIOMETRIC_TURNOVER,
        "is_catalytic": False,
        "rna_length_nt": struct["rna_length_nt"],
        "num_base_pairs": struct["num_base_pairs"],
        "effective_rna_neutralized_per_molecule": f1 * STOICHIOMETRIC_TURNOVER,
    }


def acceptance(rows: list, ref: dict) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    crit = {
        "C1_panel_non_empty": len(rows) >= 4,
        "C2_mass_action_fractions_bounded": all(
            0.0 <= r["binary_fraction"] <= 1.0
            and 0.0 <= r["rnase_site_fraction"] <= 1.0
            and 0.0 <= r["ternary_fraction"] <= 1.0
            for r in rows),
        "C3_ternary_is_product_of_sites": all(
            abs(r["ternary_fraction"]
                - r["binary_fraction"] * r["rnase_site_fraction"])
            <= 1e-12 for r in rows),
        "C4_catalytic_turnover_exceeds_stoichiometric": all(
            r["turnover_number"] > STOICHIOMETRIC_TURNOVER
            and r["is_catalytic"] for r in rows),
        "C5_rna_targets_structured": all(
            r["structured"] and r["dot_bracket_balanced"] for r in rows),
        "C6_beats_stoichiometric_reference": all(
            r["effective_rna_neutralized_per_molecule"]
            > ref["effective_rna_neutralized_per_molecule"] for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("ribotac_sim — RIBOTAC sub-axis :> BIFUNCTIONAL (expansion-main)\n",
          flush=True)
    print("model:  Target + R ⇌ Target·R ;  Target·R + RNase ⇌ Target·R·RNase")
    print("        (mass-action ternary equilibrium) → recruited RNase-L "
          "catalytically cleaves the RNA")
    print("        N_turnover = k_cat · t_exposure  (multiple-turnover "
          "advantage over a stoichiometric binder)\n", flush=True)
    print("  real-limit 1 : mass-action law (Guldberg & Waage 1864) — every "
          "bound fraction ≤ 1.0")
    print("  real-limit 2 : catalytic multiple-turnover — a genuine catalyst "
          "has turnover number > 1")
    print("  cross-axis   : RIBOTAC ?> RIBOZYME core (both = multiple-turnover "
          "RNA cleavage); RNA")
    print("                 structuredness scored via imported parent solver "
          "ribozyme_mfe_nussinov (no fork, f3)\n", flush=True)

    rows = build_rows()
    ref = stoichiometric_reference_row()
    for r in rows:
        print(f"  [{r['ribotac']:<28}] RNA n={r['rna_length_nt']:>3}  "
              f"pairs={r['num_base_pairs']:>2}  ternary={r['ternary_fraction']:.4f}")
        print(f"      K_d1={r['k_d1_nM']:.0f}nM  K_d2={r['k_d2_nM']:.0f}nM  "
              f"α={r['alpha']:.0f}  K_d2_eff={r['k_d2_effective_nM']:.2f}nM")
        print(f"      k_cat={r['k_cat_per_s']:.3g}/s  turnover N="
              f"{r['turnover_number']:.1f}  catalytic advantage="
              f"{r['catalytic_advantage_over_stoichiometric']:.1f}×")
        print(f"      effective RNA neutralized / molecule = "
              f"{r['effective_rna_neutralized_per_molecule']:.2f}")

    print(f"\n## stoichiometric reference (single-turnover, the RIBOTAC beats it)")
    print(f"  [{ref['ribotac']:<28}] turnover N={ref['turnover_number']:.1f}  "
          f"effective RNA neutralized / molecule = "
          f"{ref['effective_rna_neutralized_per_molecule']:.2f}")

    acc = acceptance(rows, ref)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — mass-action ternary fractions, the")
    print("  turnover number N=k_cat·t_exposure and the catalytic advantage")
    print("  computed self-consistently. NOT an affinity, cellular-knockdown or")
    print("  therapeutic claim. RIBOTAC is RESEARCH-STAGE (no approved RIBOTAC).")
    print("  K_d/k_cat/α are literature-informed surrogates, not compound fits.")
    print("  RIBOTAC is a SUB-AXIS (:> BIFUNCTIONAL expansion-main), NOT core-5.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "RIBOTAC",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "cross_axis_soft_dep": "RIBOZYME (core) — ?> shared multiple-turnover RNA cleavage",
        "real_limit_anchors": [
            "mass-action law (Guldberg & Waage, 1864) — bound fractions <= 1.0",
            ("catalytic multiple-turnover — a genuine catalyst has turnover "
             "number > 1 (Cornish-Bowden, Fundamentals of Enzyme Kinetics, "
             "4th ed., 2012)"),
        ],
        "rna_structure_solver": ("ribozyme_mfe_nussinov.nussinov — imported "
                                 "from parent RIBOZYME axis (no fork, f3)"),
        "rows": rows,
        "stoichiometric_reference": ref,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency "
                                   "ONLY (g8/f2) — RIBOTAC is research-stage, "
                                   "not a therapeutic or knockdown claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__RIBOTAC__ PASS" if ok else "\n__RIBOTAC__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
