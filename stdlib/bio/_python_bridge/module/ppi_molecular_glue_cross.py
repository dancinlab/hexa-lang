#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ppi_molecular_glue_cross.py — CROSS-AXIS integration G3.

CROSS:  PPI sub-axis Bogan-Thorn hotspot energetics  ──same energetic ledger──▶
        MOLECULAR-GLUE sub-axis cooperative-ternary equilibrium.

PPI inhibitors DISRUPT a protein-protein interface; molecular glues CREATE one
(a neo-interface between a target and an E3 ligase). The honest framing of
this cross: a glue is the INVERSE PPI problem. The Bogan-Thorn hotspot ledger
that quantifies whether a PPI is disruptable by a small-molecule mimic is
EXACTLY the ledger that quantifies whether a glue-induced neo-interface is
even thermodynamically accessible. Disrupting vs creating an interface uses
the SAME energetic accounting — total interface free energy is bounded by the
alanine-scanning ddG ledger (Bogan-Thorn 1998); occupancies are governed by
mass action (Guldberg & Waage 1864) amplified by a cooperativity factor
(Douglass et al. 2013).

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sims, no fork)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/ppi_sim.py — PPI sub-axis (:> QUANTUM core).
      Alanine-scanning ddG ledger; Bogan-Thorn hotspot definition (>= 2
      kcal/mol); hotspot-cluster energy dg_hotspot_cluster as the bounded
      energy a small-molecule disruptor can recover.

  (2) _python_bridge/module/molecular_glue_sim.py — MOLECULAR-GLUE sub-axis
      (:> BIFUNCTIONAL expansion-main). Cooperative ternary-complex
      mass-action with K_glue, K_PPI and cooperativity alpha; "neither
      binary alone sufficient yet cooperative ternary high" glue signature.

This module is the BRIDGE. For each PPI interface in ppi_sim's deterministic
panel:

  ppi_sim.interface_profile()  ─▶  dg_hotspot_cluster (kcal/mol)
                                    │
                                    │  Gibbs / Guldberg-Waage:
                                    │      K_d = exp(dG / RT)
                                    ▼
                            K_PPI_effective (nM)  — the K_PPI a glue
                                    │            would see if it created
                                    │            a neo-interface mirroring
                                    │            the PPI hotspot energy
                                    ▼
                molecular_glue_sim.cooperative_ternary(
                    k_glue_nM = fixed illustrative,
                    k_ppi_nM  = K_PPI_effective,
                    alpha     = deterministic search ladder)
                                    │
                                    ▼
                  smallest alpha at which glue_signature == True
                  → alpha_required_for_glue_signature

The PPI hotspot real-limit is the FLOOR: a hotspot-poor PPI gives a weak
effective K_PPI, and the cooperativity factor alpha must work harder (or
cannot reach feasibility within a sane ladder) to clear the cooperative-
ternary threshold. A hotspot-rich PPI gives a tighter effective K_PPI and
the glue signature is accessible at modest alpha. This is the SAME energetic
ledger speaking from both sides.

────────────────────────────────────────────────────────────────────────────
WHY THIS UNIFICATION IS HONEST (governance g3 / g8 — model level, not claim)
────────────────────────────────────────────────────────────────────────────
This cross unifies TWO ENERGETIC ACCOUNTINGS at the model level:

  * disruption side  — what is the floor on hotspot energy I can recover by
    mimicry? (ppi_sim hotspot-mimicry gate)
  * creation side    — what is the floor on hotspot energy I must create by
    glue-induced neo-interface? (molecular_glue_sim cooperative ternary)

It does NOT claim that every PPI is glue-able (the modalities have different
mechanistic requirements: a glue additionally needs a CRBN/DCAF15-style E3
ligase surface to remodel, and the target must tolerate ubiquitination); it
does NOT claim that every glue target presents as a classical PPI. The
unification is a MODEL-LEVEL ledger sharing, not a modality interchangeability
claim.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors >= 1 real limit)
────────────────────────────────────────────────────────────────────────────
  * Bogan-Thorn binding-hotspot theory (Bogan & Thorn, Anatomy of hot spots
    in protein interfaces, J. Mol. Biol. 280:1, 1998): interface binding free
    energy is concentrated in a few hotspot residues; the recoverable energy
    is BOUNDED by the alanine-scanning ddG ledger. This is the real-limit
    FLOOR — no glue-induced neo-interface can be stronger than the hotspot
    energy the corresponding PPI ledger permits.
  * Cooperative ternary-complex equilibrium (Douglass et al., J. Am. Chem.
    Soc. 135:6092, 2013; Han, Drug Discov. Today 25:1832, 2020): the ternary
    is governed by binary K_d's and a cooperativity factor alpha amplifying
    the second binding event.
  * Guldberg & Waage law of mass action (1864): occupancies obey closed-form
    mass-action partition functions; no occupancy may exceed 1.0.

Modality precedent (described ONLY by its own drug precedent — g3 / f1 /
f_lattice_fit, never lattice-derived):
  - PPI inhibitors:  venetoclax (BCL-2 / BH3 disruptor, FDA 2016; Souers et
    al., Nat. Med. 19:202, 2013) and navitoclax / ABT-263 (dual BCL-2/BCL-xL
    BH3-mimetic; Tse et al., Cancer Res. 68:3421, 2008).
  - Molecular glues: lenalidomide and thalidomide (CRBN glues recruiting
    IKZF1/IKZF3; Kronke et al., Science 343:301, 2014; Lu et al., Science
    343:305, 2014; FDA-approved) and indisulam (DCAF15 glue recruiting RBM39;
    Han et al., Science 356:eaal3755, 2017; Uehara et al., Nat. Chem. Biol.
    13:675, 2017).

No quantity in this module is derived from the n=6 lattice. The cross is NOT
a new axis — it spans existing sub-axes (PPI :> QUANTUM core, MOLECULAR-GLUE
:> BIFUNCTIONAL expansion-main), AXIS/HIERARCHY.tape is unchanged.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both sister sims are IMPORTED and their published functions reused
    verbatim — ppi_sim.interface_profile() and molecular_glue_sim.
    cooperative_ternary(); no logic is re-implemented (f3).
  * The PPI ddG values are illustrative literature-informed surrogates for
    interface CLASSES (ppi_sim's own honesty note); K_glue and alpha are
    illustrative literature-informed surrogates for the glue modality
    (molecular_glue_sim's own honesty note). Both caveats are carried
    forward — no claim sharper than either parent permits.
  * The Gibbs conversion  K_d = exp(dG_hotspot_cluster / RT)  applied to the
    PPI hotspot-cluster energy is the standard thermodynamic relationship
    between a binding free energy and a dissociation constant. The result
    K_PPI_effective is the K_PPI a glue WOULD see if the neo-interface it
    creates mirrored the PPI's hotspot ledger; the FLOOR the glue cannot
    beat. It is NOT a measurement, NOT an affinity prediction.
  * alpha_required_for_glue_signature comes from a DETERMINISTIC alpha
    ladder, not an optimisation. The smallest alpha in the ladder at which
    molecular_glue_sim.cooperative_ternary() returns glue_signature=True is
    reported; if no alpha within the ladder clears the gate the row honestly
    reports glue_signature_achievable=False.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: the
    chain  hotspot ddG ledger -> dg_hotspot_cluster -> K_PPI_effective ->
    cooperative-ternary mass-action -> alpha_required  is computed self-
    consistently, the two sister sims agree at the bridge, and re-runs are
    byte-identical (g8 / f2 — NOT a binding-affinity / DC50 / Dmax /
    immunogenicity / therapeutic-efficacy claim).
  * This is a MODEL-LEVEL UNIFICATION of two energetic accountings — NOT a
    claim that every PPI is glue-able or vice versa. The two modalities have
    distinct mechanistic requirements outside this energetic ledger.
  * Pure stdlib, no network / time / random -> byte-identical re-runs.
"""
from __future__ import annotations
import importlib.util
import json
import math
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_PPI_PATH = os.path.join(_HERE, "ppi_sim.py")
_GLUE_PATH = os.path.join(_HERE, "molecular_glue_sim.py")

SCHEMA_ID = "ppi_molecular_glue_cross_v1"

# ── thermodynamics anchors (deterministic constants) ────────────────────────
TEMP_K = 310.0                       # body temperature (K)
R_KCAL_PER_MOL_K = 1.987204258e-3    # gas constant (kcal/mol/K)
# Standard-state concentration for converting a dG_bind in kcal/mol to a K_d
# in nM. K_d (M) = exp(dG / RT) (standard state 1 M); rescale to nM by 1e9.
M_TO_NM = 1.0e9

# Fixed illustrative K_glue (nM) for the glue->target binary leg — the modality-
# typical weak K_d range used in molecular_glue_sim's deterministic panel.
# Holding K_glue fixed isolates the cross variable: the effective K_PPI
# determined by the PPI hotspot ledger.
K_GLUE_FIXED_nM = 10000.0

# Deterministic alpha search ladder. molecular_glue_sim's panel spans
# alpha 200..1500 for real-world glues; this ladder brackets that range
# (lower bound 2.0 = barely-positive cooperativity; upper bound 5000 =
# beyond the strongest panel entry).
ALPHA_LADDER = [2.0, 5.0, 10.0, 25.0, 50.0, 100.0, 200.0, 500.0,
                1000.0, 1500.0, 2000.0, 3000.0, 5000.0]


# ── import both sister sims (no fork — f3) ──────────────────────────────────
def _load_module(name: str, path: str):
    """Import a sibling sim by file path — functions reused verbatim (f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── Gibbs conversion: hotspot-cluster dG -> effective K_PPI ────────────────
def _k_d_nM_from_dg(dg_kcal_per_mol: float,
                    temperature_K: float = TEMP_K) -> float:
    """
    Standard Gibbs relationship between a binding free energy and a
    dissociation constant: K_d = exp(dG / RT). Returns K_d in nM.

    For a favourable (negative) dG the K_d is small. dG_hotspot_cluster from
    ppi_sim is favourable, so the returned K_PPI_effective is small (tight
    interface) for hotspot-rich PPIs and larger (weak interface) for
    hotspot-poor PPIs — the FLOOR a glue's neo-interface cannot beat.
    """
    k_d_M = math.exp(dg_kcal_per_mol / (R_KCAL_PER_MOL_K * temperature_K))
    return k_d_M * M_TO_NM


# ── the cross: PPI hotspot ledger -> effective K_PPI -> required alpha ─────
def build_cross_rows(ppi_mod, glue_mod) -> list:
    """
    One cross row per PPI interface in ppi_sim's deterministic panel.

    For each interface:
      1. compute its hotspot energetics via ppi_sim.interface_profile()
         (imported, not re-implemented — f3);
      2. convert dg_hotspot_cluster to an effective K_PPI via Gibbs;
      3. with K_glue fixed, sweep the deterministic alpha ladder calling
         glue_mod.cooperative_ternary() (imported, not re-implemented — f3),
         and find the smallest alpha at which glue_signature is True.
    """
    rows = []
    for name, ddg_list, mimicry_fraction, iclass, ppi_precedent in \
            ppi_mod.INTERFACE_PANEL:
        prof = ppi_mod.interface_profile(ddg_list, mimicry_fraction)
        dg_hot = prof["dg_hotspot_cluster_kcal_per_mol"]
        # Effective K_PPI from the PPI hotspot ledger (the floor).
        k_ppi_effective = _k_d_nM_from_dg(dg_hot)
        # Sweep the alpha ladder for the smallest alpha clearing the
        # cooperative-ternary glue signature. molecular_glue_sim's gate
        # is f_binary_target < 0.30 AND f_binary_ppi < 0.30 AND
        # f_ternary > 0.50 (the published thresholds; reused verbatim).
        alpha_required = None
        eq_at_required = None
        for alpha in ALPHA_LADDER:
            eq = glue_mod.cooperative_ternary(
                K_GLUE_FIXED_nM, k_ppi_effective, alpha)
            if eq["glue_signature"]:
                alpha_required = alpha
                eq_at_required = eq
                break
        # If no alpha within the ladder clears the gate, honestly report
        # that — the PPI hotspot floor is too weak (hotspot-poor interface)
        # for the glue signature to emerge at sane cooperativity.
        achievable = alpha_required is not None
        if not achievable:
            # Evaluate at the ladder maximum so the row still carries
            # diagnostic occupancies (without falsely claiming success).
            eq_at_required = glue_mod.cooperative_ternary(
                K_GLUE_FIXED_nM, k_ppi_effective, ALPHA_LADDER[-1])
            alpha_required = ALPHA_LADDER[-1]
        # Real-limit ledger respect: the effective K_PPI is derived from the
        # hotspot ledger by a closed-form Gibbs relation; it is therefore
        # bounded by the ledger by construction. The cross-check enforces
        # that the *recovered* hotspot-cluster magnitude does not exceed the
        # total alanine-scan ledger (Bogan-Thorn floor).
        ppi_floor_ok = (abs(dg_hot)
                        <= abs(prof["dg_interface_kcal_per_mol"]) + 1e-9)

        row = {
            "schema": SCHEMA_ID,
            "interface": name,
            "interface_class": iclass,
            "ppi_drug_precedent": ppi_precedent,
            "glue_drug_precedent": (
                "lenalidomide / thalidomide (CRBN glues, IKZF1/IKZF3; "
                "Kronke 2014 · Lu 2014) and indisulam (DCAF15 glue, RBM39; "
                "Han 2017 · Uehara 2017)"),
            "n_hotspot_residues": prof["n_hotspot_residues"],
            "ppi_hotspot_cluster_kcal_per_mol": dg_hot,
            "ppi_hotspot_energy_fraction": prof["hotspot_energy_fraction"],
            "ppi_hotspot_driven": prof["hotspot_driven"],
            "temperature_K": TEMP_K,
            "k_ppi_effective_nM": k_ppi_effective,
            "k_glue_nM": K_GLUE_FIXED_nM,
            "alpha_required_for_glue_signature": alpha_required,
            "alpha_search_max": ALPHA_LADDER[-1],
            "f_binary_target_at_required_alpha":
                eq_at_required["f_binary_target"],
            "f_binary_ppi_at_required_alpha":
                eq_at_required["f_binary_ppi"],
            "f_ternary_at_required_alpha": eq_at_required["f_ternary"],
            "glue_signature_achievable": achievable,
            "ppi_floor_respected": ppi_floor_ok,
            "unification_note": (
                "Bogan-Thorn hotspot ledger (PPI disruption floor) ≡ "
                "K_PPI floor in Guldberg-Waage cooperative ternary "
                "mass-action (glue creation) — same energetic ledger, "
                "inverse problems"),
            "illustrative_only": True,
        }
        rows.append(row)
    return rows


def acceptance(rows: list, ppi_mod, glue_mod) -> dict:
    """
    In-silico simulator-CONSISTENCY acceptance criteria (X1–X6).

    The cross PASSes iff:
      X1 — every PPI panel entry produced exactly one cross row;
      X2 — every effective K_PPI is finite, positive and bounded;
      X3 — the PPI-floor ledger respect holds on every row;
      X4 — alpha_required monotonically tracks the inverse of the hotspot
           floor: a hotspot-richer (more-negative dg_hot) interface requires
           equal-or-smaller alpha than a hotspot-poorer interface;
      X5 — at least one row achieves glue_signature within the ladder AND
           at least one row honestly does NOT (the gate discriminates,
           never just permits);
      X6 — the ternary fractions at alpha_required (when achievable)
           satisfy molecular_glue_sim's own glue-signature thresholds, i.e.
           the cross agrees with the sister sim's gate verbatim.
    """
    achievable_rows = [r for r in rows if r["glue_signature_achievable"]]
    not_achievable_rows = [r for r in rows
                           if not r["glue_signature_achievable"]]

    # X4 — monotonicity check. Sort by dg_hot ascending (more negative
    # first = hotspot-richer). alpha_required should be non-decreasing as
    # dg_hot becomes less negative.
    sorted_rows = sorted(rows,
                         key=lambda r: r["ppi_hotspot_cluster_kcal_per_mol"])
    monotone = True
    for a, b in zip(sorted_rows, sorted_rows[1:]):
        # if a is hotspot-richer (more negative) than b, alpha_required(a)
        # must be <= alpha_required(b).
        if (a["ppi_hotspot_cluster_kcal_per_mol"]
                < b["ppi_hotspot_cluster_kcal_per_mol"]):
            if a["alpha_required_for_glue_signature"] > \
                    b["alpha_required_for_glue_signature"]:
                monotone = False
                break

    # X6 — sister-sim agreement at the bridge: for rows that achieved the
    # signature, the published thresholds must be cleared.
    binary_ceiling = glue_mod.BINARY_INSUFFICIENT_CEILING
    ternary_floor = glue_mod.TERNARY_SUFFICIENT_FLOOR
    bridge_agreement = all(
        (r["f_binary_target_at_required_alpha"] < binary_ceiling
         and r["f_binary_ppi_at_required_alpha"] < binary_ceiling
         and r["f_ternary_at_required_alpha"] > ternary_floor)
        for r in achievable_rows)

    crit = {
        "X1_one_row_per_ppi_panel_entry":
            len(rows) == len(ppi_mod.INTERFACE_PANEL),
        "X2_k_ppi_effective_finite_positive": all(
            math.isfinite(r["k_ppi_effective_nM"])
            and r["k_ppi_effective_nM"] > 0.0
            for r in rows),
        "X3_ppi_floor_respected": all(r["ppi_floor_respected"] for r in rows),
        "X4_alpha_monotone_with_hotspot_floor": monotone,
        "X5_discriminating_gate_both_outcomes_present":
            len(achievable_rows) >= 1 and len(not_achievable_rows) >= 1,
        "X6_bridge_agrees_with_sister_thresholds": bridge_agreement,
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("ppi_molecular_glue_cross — CROSS-AXIS G3\n", flush=True)
    print("cross:  PPI Bogan-Thorn hotspot ledger  ──same energetic floor──▶")
    print("        MOLECULAR-GLUE cooperative-ternary feasibility")
    print("        disrupting an interface (PPI) vs creating one (glue)")
    print("        uses the SAME energetic accounting (inverse problems)\n",
          flush=True)

    ppi_mod = _load_module("ppi_sim", _PPI_PATH)
    glue_mod = _load_module("molecular_glue_sim", _GLUE_PATH)

    print(f"  real-limit anchor (PPI side)   : Bogan-Thorn hotspot theory")
    print(f"                                   (Bogan & Thorn, J. Mol. Biol. "
          f"280:1, 1998)")
    print(f"                                   hotspot ddG threshold = "
          f"{ppi_mod.HOTSPOT_DDG_THRESHOLD_KCAL} kcal/mol")
    print(f"  real-limit anchor (glue side)  : cooperative ternary mass-action")
    print(f"                                   (Douglass JACS 135:6092, 2013; "
          f"Han DDT 25:1832, 2020;")
    print(f"                                   Guldberg-Waage mass action 1864)")
    print(f"                                   binary insufficiency ceiling = "
          f"{glue_mod.BINARY_INSUFFICIENT_CEILING}")
    print(f"                                   ternary sufficiency floor    = "
          f"{glue_mod.TERNARY_SUFFICIENT_FLOOR}\n", flush=True)
    print(f"  fixed K_glue = {K_GLUE_FIXED_nM:.0f} nM  (modality-typical weak "
          f"binary; isolates K_PPI as the cross variable)")
    print(f"  alpha ladder = {ALPHA_LADDER}\n", flush=True)

    rows = build_cross_rows(ppi_mod, glue_mod)
    for r in rows:
        ach = "achievable" if r["glue_signature_achievable"] \
            else "NOT achievable within ladder"
        print(f"  [{r['interface']:<26}] hotspots="
              f"{r['n_hotspot_residues']}  "
              f"ΔG_hotspot={r['ppi_hotspot_cluster_kcal_per_mol']:+6.2f} kcal/mol")
        print(f"      K_PPI_eff={r['k_ppi_effective_nM']:.3e} nM   "
              f"α_required={r['alpha_required_for_glue_signature']:.0f}   "
              f"f_ternary={r['f_ternary_at_required_alpha']:.3f}   "
              f"({ach})")

    acc = acceptance(rows, ppi_mod, glue_mod)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  "
          f"verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both sims IMPORTED, never re-implemented (f3). ppi_sim.")
    print("    interface_profile() and molecular_glue_sim.cooperative_ternary()")
    print("    are reused verbatim; the cross only bridges their outputs via the")
    print("    standard Gibbs relation K_d = exp(dG/RT).")
    print("  - The PPI ddG values and the K_glue / alpha values are illustrative")
    print("    literature-informed surrogates for the modality CLASSES (each")
    print("    parent sim's own honesty caveat). No claim sharper than either")
    print("    parent permits is made here.")
    print("  - This is a MODEL-LEVEL UNIFICATION of two energetic accountings —")
    print("    NOT a claim that every PPI is glue-able or vice versa. The two")
    print("    modalities have distinct mechanistic requirements (E3 ligase")
    print("    surface, ubiquitin handling) outside this energetic ledger.")
    print("  - Modality precedents are own-precedent only (g3 / f1 / f_lattice_fit):")
    print("    PPI side  — venetoclax (BCL-2/BH3 disruptor, FDA 2016) and")
    print("                navitoclax / ABT-263 (dual BCL-2/BCL-xL).")
    print("    Glue side — lenalidomide / thalidomide (CRBN glues, IKZF1/IKZF3,")
    print("                FDA-approved) and indisulam (DCAF15 glue, RBM39).")
    print("  - PASS certifies IN-SILICO simulator-CONSISTENCY ONLY (g8 / f2) —")
    print("    NOT a binding-affinity, degradation (DC50 / Dmax), immunogenicity")
    print("    or therapeutic-efficacy claim. No quantity is derived from the")
    print("    n=6 lattice. The cross is NOT a new axis — AXIS/HIERARCHY.tape")
    print("    unchanged; PPI :> QUANTUM core, MOLECULAR-GLUE :> BIFUNCTIONAL")
    print("    expansion-main are existing sub-axes.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "cross": ("G3  PPI Bogan-Thorn hotspot ledger  ->  MOLECULAR-GLUE "
                  "cooperative-ternary feasibility"),
        "ppi_subaxis_source": (
            "_python_bridge/module/ppi_sim.py (interface_profile imported; "
            "INTERFACE_PANEL reused — f3)"),
        "molecular_glue_subaxis_source": (
            "_python_bridge/module/molecular_glue_sim.py (cooperative_ternary "
            "imported — f3)"),
        "real_limit_anchor_ppi": (
            "Bogan-Thorn binding-hotspot theory (Bogan & Thorn, Anatomy of "
            "hot spots in protein interfaces, J. Mol. Biol. 280:1, 1998) — "
            "interface energy concentrated in hotspot residues; recoverable "
            "energy bounded by the alanine-scanning ddG ledger"),
        "real_limit_anchor_glue": (
            "cooperative ternary-complex equilibrium (Douglass et al., JACS "
            "135:6092, 2013; Han, Drug Discov. Today 25:1832, 2020) atop the "
            "Guldberg-Waage law of mass action (1864) — occupancies <= 1.0"),
        "temperature_K": TEMP_K,
        "R_kcal_per_mol_K": R_KCAL_PER_MOL_K,
        "k_glue_fixed_nM": K_GLUE_FIXED_nM,
        "alpha_ladder": ALPHA_LADDER,
        "rows": rows,
        "acceptance": acc,
        "unification_demonstrated": (
            "PPI inhibitors disrupt an interface; molecular glues create one; "
            "both are governed by the SAME Bogan-Thorn hotspot ledger plus "
            "Guldberg-Waage mass action. The hotspot ledger is the FLOOR a "
            "glue-induced neo-interface cannot beat — a hotspot-poor PPI "
            "yields a weak K_PPI_effective and the glue signature requires "
            "higher cooperativity alpha (or is not achievable within sane "
            "alpha); a hotspot-rich PPI yields a tight K_PPI_effective and "
            "the glue signature emerges at modest alpha"),
        "modality_interchangeability_claim": False,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — NOT a binding-affinity, "
            "degradation-potency (DC50/Dmax), immunogenicity or therapeutic-"
            "efficacy claim. MODEL-LEVEL UNIFICATION of two energetic "
            "accountings, NOT a claim that every PPI is glue-able or vice "
            "versa. PPI :> QUANTUM core; MOLECULAR-GLUE :> BIFUNCTIONAL "
            "expansion-main — cross is NOT a new axis"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PPI_MOLECULAR_GLUE_CROSS__ PASS" if ok
          else "\n__PPI_MOLECULAR_GLUE_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
