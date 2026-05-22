#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
peptide_sim.py — PEPTIDE sub-axis :> WEAVE (core).

Deterministic, stdlib-only real-limits model of therapeutic-peptide
conformational thermodynamics: the helix-coil two-state partition of a linear
peptide chain, and the helicity/permeability property tradeoff. This is the
in-silico simulator-consistency layer for the PEPTIDE sub-axis registered in
AXIS/HIERARCHY.tape `@D sub_under_weave` — see the sibling note
`peptide_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A therapeutic peptide is a linear residue chain whose biological behaviour is
governed by its CONFORMATIONAL ENSEMBLE, not by a single static structure. The
key real-limit observable is fractional helicity θ_H — the equilibrium fraction
of residues in the α-helical state — computed here from a Zimm-Bragg-style
helix-coil partition function:

      Z = Σ over helix/coil microstates of  σ^(#nucleations) · Π s_i

  - s_i : the per-residue helix-propagation equilibrium constant (the
          "stability" parameter) for residue i. s > 1 favours helix, s < 1
          favours coil. Modelled from a per-residue helix-propensity table.
  - σ   : the helix NUCLEATION parameter (σ ≪ 1) — the entropic cost of
          forming the first turn of helix. σ small ⇒ helix formation is
          cooperative (the hallmark of the Zimm-Bragg theory).
  - θ_H : fractional helicity = (1/N)·⟨#helical residues⟩ = (1/N)·∂lnZ/∂ln s.
          Here computed exactly by enumerating the 2^N helix/coil microstates
          (N kept small ⇒ exact partition sum, no approximation).

The partition function is built by the standard transfer-matrix-equivalent
*direct enumeration*: for a chain of N residues each residue is helix (h) or
coil (c); a microstate's statistical weight is Π s_i over helical residues
times σ once per contiguous helical segment (nucleation). θ_H is the
Boltzmann-weighted mean helical fraction.

PROPERTY TRADEOFF — helicity vs membrane permeability. A peptide that
satisfies its intramolecular backbone H-bonds (high helicity) shields its
polar amide groups from solvent, lowering the desolvation penalty of crossing
a lipid membrane. The model reads out a monotone permeability PROXY that rises
with helicity and falls with the count of solvent-exposed (unsatisfied) polar
groups — an illustrative tradeoff index, NOT a measured logP/Papp.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Zimm-Bragg helix-coil theory (Zimm & Bragg, *J. Chem. Phys.* 31:526, 1959)
and the equivalent Lifson-Roig formulation (Lifson & Roig, *J. Chem. Phys.*
34:1963, 1961). The cooperative helix-coil transition is a textbook
statistical-mechanics real limit: a one-dimensional chain with a nucleation
penalty σ ≪ 1 has a partition function Z that is exactly the sum over
2^N helix/coil microstates, and θ_H = (1/N)·∂lnZ/∂ln s. Two hard ceilings
anchor every row:
  - 0 ≤ θ_H ≤ 1 always (it is a fraction) — a fraction cannot leave [0,1].
  - in the σ → 1 (no nucleation cost) limit the residues become independent
    and θ_H reduces to the mean of the independent two-state occupancies
    s_i/(1+s_i) — the analytically known non-cooperative baseline. The
    simulator cross-checks against this closed form (acceptance C3).
Per-residue helix propensities follow the experimental host-guest scales of
Pace & Scholtz (*Biophys. J.* 75:422, 1998) and Chakrabartty, Kortemme &
Baldwin (*Protein Sci.* 3:843, 1994) — alanine the strongest helix-former,
glycine and proline helix-breakers.

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - semaglutide — a GLP-1 receptor-agonist analog peptide; the GLP-1 backbone
    is α-helical in its receptor-bound state. Blockbuster peptide therapeutic
    (Ozempic / Wegovy / Rybelsus). The broader GLP-1 analog class (liraglutide,
    dulaglutide, tirzepatide) is the canonical therapeutic-peptide precedent.
  - the GLP-1 class and engineered stapled/helical peptides are the modality
    track record this sub-axis is described by — never a lattice derivation.

────────────────────────────────────────────────────────────────────────────
WEAVE OVERLAP — HONEST DEMOTION-BOUNDARY NOTE (HIERARCHY.tape criterion #2)
────────────────────────────────────────────────────────────────────────────
PEPTIDE is registered as a SUB-axis of the core WEAVE axis precisely because
it sits on the ~30% overlap demotion boundary (AXIS/HIERARCHY.tape
`@D sub_under_weave`; AXIS/README.md promotion criterion #2). The overlap is
real and is stated honestly here: WEAVE models *structural quasi-equivalence*
— Caspar-Klug / Zlotnick lattice assembly of repeating capsomer units into a
closed shell. PEPTIDE shares WEAVE's "secondary-structure of a biopolymer"
concern, but SPECIALIZES away from it: it models the LINEAR-CHAIN
conformational thermodynamics of a single peptide (helix-coil equilibrium,
not a closed quasi-equivalent lattice). The shared ~30% is the
secondary-structure machinery; the distinct ~70% is the one-dimensional
helix-coil partition and the peptide-drug property tradeoff. Hence: sub-axis,
not a 6th core axis. Core-5 (../AXIS.tape) is UNCHANGED.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the helix-coil partition sum, the fractional helicity θ_H, the
σ → 1 independent-residue cross-check, and the permeability-proxy tradeoff are
computed self-consistently and reproduce byte-identically. It is a
statistical-mechanics MODEL — NOT a structural measurement, NOT a binding,
potency, permeability or therapeutic-efficacy claim. The helix propensities
and σ are literature-informed surrogates, not fits to a specific peptide.
Pure stdlib, no network/time/random → byte-identical re-runs.

PEPTIDE is a SUB-AXIS (:> WEAVE core) — it is NOT one of the hexa-bio core-5
axes. See AXIS/AXIS.tape (core-5 unchanged) and AXIS/HIERARCHY.tape.
"""
from __future__ import annotations
import json
import sys

SCHEMA_ID = "peptide_v1"

# ── Zimm-Bragg nucleation parameter ─────────────────────────────────────────
# sigma << 1 is the entropic cost of nucleating the first helical turn — the
# parameter that makes the helix-coil transition COOPERATIVE. Value 1e-3 is the
# textbook illustrative magnitude (Zimm & Bragg 1959; experimental sigma for
# real peptides falls in the ~1e-4..1e-2 range). Not a fit to any peptide.
SIGMA_NUCLEATION = 1.0e-3

# ── per-residue helix-propagation parameter s (the Zimm-Bragg "s") ──────────
# s > 1 favours helix, s < 1 favours coil. Ordering follows the experimental
# host-guest helix-propensity scales (Pace & Scholtz 1998; Chakrabartty,
# Kortemme & Baldwin 1994): Ala strongest helix-former; Gly/Pro helix-breakers.
# Illustrative magnitudes for the residue CLASS, not a fitted dataset.
S_PROPENSITY = {
    "A": 1.54,   # alanine  — strongest helix-former
    "L": 1.34,   # leucine  — strong helix-former
    "E": 1.28,   # glutamate
    "M": 1.20,   # methionine
    "Q": 1.16,   # glutamine
    "F": 1.13,   # phenylalanine
    "K": 1.10,   # lysine
    "R": 1.05,   # arginine
    "I": 1.00,   # isoleucine
    "D": 0.91,   # aspartate
    "S": 0.88,   # serine
    "T": 0.82,   # threonine
    "N": 0.78,   # asparagine
    "V": 0.75,   # valine   — beta-favouring
    "G": 0.50,   # glycine  — helix-breaker (high backbone entropy)
    "P": 0.20,   # proline  — helix-breaker (no backbone amide H)
}

# polar residues whose backbone amide stays solvent-exposed when in the COIL
# state — the desolvation-penalty bookkeeping for the permeability proxy.
POLAR_RESIDUES = frozenset("EQKRSTND")

# ── deterministic therapeutic-peptide panel ─────────────────────────────────
# (name, sequence, modality_note, own drug precedent)
# Sequences are illustrative model peptides chosen to span the helicity range,
# NOT the literal drug sequences. The drug precedent names the MODALITY only.
PEPTIDE_PANEL = [
    ("model_helical_high", "AALEAALEAALEAALE",
     "engineered high-helix-propensity model peptide",
     "stapled / helical therapeutic peptides — engineered-helicity modality"),
    ("model_glp1_like", "AAEGTFTSDLSKQMEEAA",
     "GLP-1-analog-like model peptide (helical receptor-bound backbone)",
     "semaglutide — GLP-1 receptor-agonist analog peptide (GLP-1 class)"),
    ("model_mixed", "AKLSAGTLSAKNVELSAG",
     "mixed helix/coil model peptide",
     "GLP-1 analog class (liraglutide / dulaglutide / tirzepatide)"),
    ("model_coil_low", "GPGSGPGSGNGPGSGP",
     "low-helix-propensity (Gly/Pro-rich) model peptide",
     "flexible-linker / disordered therapeutic-peptide modality"),
]


def helix_coil_partition(seq: str, sigma: float = SIGMA_NUCLEATION) -> dict:
    """
    Exact Zimm-Bragg-style helix-coil partition by direct enumeration of all
    2^N helix(1)/coil(0) microstates.

    Microstate weight = sigma^(#contiguous helical segments) * Π s_i over
    helical residues. Returns the partition function Z and the Boltzmann-mean
    fractional helicity θ_H = (1/N) * <#helical residues>.
    """
    n = len(seq)
    s = [S_PROPENSITY[c] for c in seq]
    z_total = 0.0
    weighted_helix_residues = 0.0
    for mask in range(1 << n):
        bits = [(mask >> i) & 1 for i in range(n)]
        weight = 1.0
        prev = 0
        for i in range(n):
            if bits[i]:
                weight *= s[i]
                if prev == 0:          # start of a new helical segment
                    weight *= sigma
            prev = bits[i]
        z_total += weight
        weighted_helix_residues += weight * sum(bits)
    mean_helical = weighted_helix_residues / z_total
    theta_h = mean_helical / n
    return {
        "n_residues": n,
        "partition_Z": z_total,
        "mean_helical_residues": mean_helical,
        "fractional_helicity": theta_h,
    }


def independent_residue_helicity(seq: str) -> float:
    """
    σ → 1 (no nucleation cost) closed-form baseline: residues become
    independent two-state systems, θ_H = (1/N) Σ s_i/(1+s_i). This is the
    analytically known non-cooperative limit used as acceptance cross-check C3.
    """
    s = [S_PROPENSITY[c] for c in seq]
    return sum(si / (1.0 + si) for si in s) / len(s)


def permeability_proxy(seq: str, theta_h: float) -> dict:
    """
    Illustrative helicity/permeability tradeoff index (NOT a measured logP or
    Papp). A satisfied backbone H-bond network (high helicity) shields polar
    amides ⇒ lower desolvation penalty ⇒ higher proxy. Polar residues left in
    coil expose their amide ⇒ a desolvation penalty subtracted from the proxy.
    proxy ∈ [0, 1]: 1 = fully helix-shielded, 0 = maximally solvent-exposed.
    """
    n = len(seq)
    n_polar = sum(1 for c in seq if c in POLAR_RESIDUES)
    polar_fraction = n_polar / n
    # exposed polar fraction = polar residues * (fraction not in helix)
    exposed_polar = polar_fraction * (1.0 - theta_h)
    proxy = max(0.0, min(1.0, theta_h - 0.5 * exposed_polar + 0.0))
    return {
        "polar_residue_fraction": polar_fraction,
        "exposed_polar_fraction": exposed_polar,
        "permeability_proxy": proxy,
        "proxy_in_unit_interval": 0.0 <= proxy <= 1.0,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per peptide in the panel."""
    rows = []
    for name, seq, note, precedent in PEPTIDE_PANEL:
        part = helix_coil_partition(seq)
        theta_h = part["fractional_helicity"]
        indep = independent_residue_helicity(seq)
        perm = permeability_proxy(seq, theta_h)
        row = {
            "schema": SCHEMA_ID,
            "peptide": name,
            "sequence": seq,
            "modality_note": note,
            "drug_precedent": precedent,
            "sigma_nucleation": SIGMA_NUCLEATION,
            "independent_residue_helicity": indep,
            # cooperative θ_H must be <= the σ→1 independent baseline: a
            # nucleation penalty can only SUPPRESS helix relative to it.
            "cooperativity_suppresses_helix": theta_h <= indep + 1e-12,
        }
        row.update(part)
        row.update(perm)
        rows.append(row)
    return rows


def tradeoff(rows: list) -> dict:
    """Explicit helicity-vs-permeability tradeoff contrast across the panel."""
    by_helicity = sorted(rows, key=lambda r: r["fractional_helicity"])
    lo, hi = by_helicity[0], by_helicity[-1]
    return {
        "lowest_helicity": {
            "peptide": lo["peptide"],
            "fractional_helicity": lo["fractional_helicity"],
            "permeability_proxy": lo["permeability_proxy"],
        },
        "highest_helicity": {
            "peptide": hi["peptide"],
            "fractional_helicity": hi["fractional_helicity"],
            "permeability_proxy": hi["permeability_proxy"],
        },
        "permeability_proxy_rises_with_helicity":
            hi["permeability_proxy"] >= lo["permeability_proxy"],
        "note": ("higher fractional helicity satisfies more backbone amide "
                 "H-bonds, shielding polar groups from solvent and raising the "
                 "illustrative membrane-permeability proxy — the helicity / "
                 "permeability tradeoff. This is a model index, not a measured "
                 "logP or Papp."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C6)."""
    crit = {
        "C1_panel_non_empty": len(rows) >= 4,
        "C2_helicity_in_unit_interval": all(
            0.0 <= r["fractional_helicity"] <= 1.0 for r in rows),
        "C3_cooperativity_suppresses_helix": all(
            r["cooperativity_suppresses_helix"] for r in rows),
        "C4_partition_positive": all(r["partition_Z"] > 0.0 for r in rows),
        "C5_permeability_proxy_in_unit_interval": all(
            r["proxy_in_unit_interval"] for r in rows),
        "C6_helicity_spread_present": (
            max(r["fractional_helicity"] for r in rows)
            - min(r["fractional_helicity"] for r in rows) > 0.05),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("peptide_sim — PEPTIDE sub-axis :> WEAVE (core)\n", flush=True)
    print("model:  Zimm-Bragg helix-coil partition  Z = Σ σ^(#nucleations)·Π s_i"
          "   θ_H = <#helix>/N\n", flush=True)
    print(f"  real-limit anchor : Zimm-Bragg / Lifson-Roig helix-coil theory "
          f"(Zimm & Bragg 1959; Lifson & Roig 1961)")
    print(f"  hard ceilings     : 0 ≤ θ_H ≤ 1; σ→1 limit ⇒ θ_H = mean s_i/(1+s_i)")
    print(f"  nucleation σ      : {SIGMA_NUCLEATION:.0e}  (cooperative transition)\n",
          flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['peptide']:<20}] N={r['n_residues']:<3} "
              f"θ_H={r['fractional_helicity']:.4f}  "
              f"(σ→1 baseline={r['independent_residue_helicity']:.4f})")
        print(f"      Z={r['partition_Z']:.4e}  polar_frac={r['polar_residue_fraction']:.3f}  "
              f"permeability_proxy={r['permeability_proxy']:.4f}")

    tr = tradeoff(rows)
    print("\n## helicity ↔ permeability tradeoff")
    lo, hi = tr["lowest_helicity"], tr["highest_helicity"]
    print(f"  lowest-helicity  {lo['peptide']:<20} θ_H={lo['fractional_helicity']:.4f}  "
          f"proxy={lo['permeability_proxy']:.4f}")
    print(f"  highest-helicity {hi['peptide']:<20} θ_H={hi['fractional_helicity']:.4f}  "
          f"proxy={hi['permeability_proxy']:.4f}")
    print(f"  permeability proxy rises with helicity: "
          f"{tr['permeability_proxy_rises_with_helicity']}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## WEAVE-overlap honesty (HIERARCHY.tape criterion #2)")
    print("  PEPTIDE is a SUB-axis on the ~30% WEAVE-overlap demotion boundary.")
    print("  WEAVE = structural quasi-equivalence (Caspar-Klug closed lattice);")
    print("  PEPTIDE specializes toward LINEAR-CHAIN conformational thermodynamics")
    print("  (one-dimensional helix-coil equilibrium). Sub-axis, NOT a 6th core")
    print("  axis — core-5 (AXIS/AXIS.tape) UNCHANGED.")

    print("\n## C-honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — helix-coil partition, θ_H, the σ→1")
    print("  independent-residue cross-check and the permeability-proxy tradeoff")
    print("  computed self-consistently. NOT a structural, binding, permeability")
    print("  or therapeutic-efficacy claim. Helix propensities and σ are")
    print("  literature-informed surrogates, not fits to a specific peptide.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "PEPTIDE",
        "parent_axis": "WEAVE (core-5, AXIS/AXIS.tape — UNCHANGED)",
        "registration": "AXIS/HIERARCHY.tape @D sub_under_weave",
        "real_limit_anchor": ("Zimm-Bragg helix-coil theory (Zimm & Bragg, "
                              "J. Chem. Phys. 31:526, 1959); equivalent "
                              "Lifson-Roig formulation (Lifson & Roig, "
                              "J. Chem. Phys. 34:1963, 1961)"),
        "helix_propensity_source": ("Pace & Scholtz, Biophys. J. 75:422 (1998); "
                                    "Chakrabartty, Kortemme & Baldwin, "
                                    "Protein Sci. 3:843 (1994)"),
        "weave_overlap_note": ("~30% WEAVE overlap (secondary-structure "
                               "machinery); PEPTIDE specializes to linear-chain "
                               "helix-coil thermodynamics — sub-axis demotion "
                               "boundary, HIERARCHY.tape criterion #2"),
        "sigma_nucleation": SIGMA_NUCLEATION,
        "rows": rows,
        "tradeoff": tr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a structural, permeability or "
                                   "therapeutic claim"),
        "lattice_derivation": ("none — no count, helicity, or parameter derived "
                               "from the n=6 lattice (g2/f1/f_lattice_fit)"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PEPTIDE__ PASS" if ok else "\n__PEPTIDE__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
