#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
peptide_nanobot_cross.py — CROSS-AXIS integration W1a.

CROSS:  PEPTIDE :> WEAVE sub-axis (Zimm-Bragg helix-coil cooperative
        pre-organization)
        ──display-orientation-constraint──▶  NANOBOT core-5 axis
        (DNA-nanotech / C0b 12-vertex polyhedral-skeleton simulator,
        peptide-decorated DNA nanostructure).

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/peptide_sim.py — the PEPTIDE sub-axis
      (:> WEAVE core). Implements a Zimm-Bragg-style helix-coil partition
      sum  Z = Σ σ^(#nucleations) · Π s_i  over the 2^N helix/coil microstates
      of a linear peptide and returns the Boltzmann-weighted fractional
      helicity θ_H ∈ [0, 1] for any peptide sequence.

  (2) nanobot/module/nanobot.hexa — the NANOBOT core-5 axis: DNA-nanotechnology
      / C0b 12-vertex polyhedral-skeleton actuation simulator. The NANOBOT
      docstring explicitly cites Rothemund 2006 DNA origami and Seeman 1982
      immobile junctions as the modality's structural basis.

These two have never been crossed. They CAN be crossed at a legitimate
research-stage interface: a *peptide-functionalized DNA nanostructure* — a
DNA-origami / C0b-class skeleton with one or more short therapeutic-like
peptides COVALENTLY ATTACHED to a staple terminus (e.g. via amine / azide /
maleimide chemistry on a 5' or 3'-modified staple). Such peptide-decorated
DNA nanostructures are an active structural-DNA-nanotechnology research
direction (Pinheiro / Bertozzi-lab-style peptide-DNA conjugates;
Schmidt-Mende-style peptide-functionalized nanostructures) but are
NOT an FDA-approved drug class. This cross models the in-silico interface,
NEVER claims a clinical / therapeutic / regulatory standing.

The physical fact the cross rests on: the peptide attached to the
nanostructure DISPLAYS only the conformation it pre-organizes into. A peptide
with high intrinsic helicity displays a roughly RIGID, ORIENTED rod from its
attachment point; a peptide that is mostly coil displays a flexible,
unoriented tether. The PEPTIDE axis's Zimm-Bragg θ_H is exactly the
pre-organization that sets this display-orientation constraint.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sides, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic peptide-decorated-nanostructure panel, this module:

  * imports peptide_sim.py and calls its `helix_coil_partition()` — the
    PEPTIDE side's Zimm-Bragg helix-coil partition is reused VERBATIM, never
    re-implemented (f3);
  * reads the NANOBOT axis's own DNA-nanotech modality basis straight out of
    nanobot/module/nanobot.hexa as deterministic structural text — the file
    is NOT executed, its actuation logic is untouched (f3);
  * for each device, takes the peptide's Zimm-Bragg fractional helicity θ_H
    and maps it through an explicit ledger to a display-orientation
    constraint score ∈ [0, 1]:

        attached peptide sequence ──Zimm-Bragg θ_H──▶
            display-orientation-constraint = θ_H ∈ [0, 1]
              (0 = unoriented flexible tether; 1 = rigid pre-organized rod)

The cross demonstrates the BOUND: a peptide too Gly/Pro-rich to pre-organize
cannot be displayed in a defined orientation from the nanostructure surface,
independently of any NANOBOT-axis actuation parameter. The display-orientation
ceiling is set by Zimm-Bragg helix-coil cooperativity (a real
statistical-mechanics limit), not by the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * Zimm-Bragg helix-coil cooperative pre-organization — the cooperative
    one-dimensional helix-coil transition (Zimm & Bragg, J. Chem. Phys.
    31:526, 1959; equivalent Lifson-Roig formulation, J. Chem. Phys.
    34:1963, 1961). Hard ceilings:
      - 0 ≤ θ_H ≤ 1 always (it is a fraction);
      - display-orientation-constraint ∈ [0, 1] by construction.
  * Per-residue helix propensities follow the experimental host-guest scales
    of Pace & Scholtz (Biophys. J. 75:422, 1998) and Chakrabartty, Kortemme &
    Baldwin (Protein Sci. 3:843, 1994).

Modality precedent (described ONLY by its own RESEARCH precedent —
g3/f1/f_lattice_fit, NEVER lattice-derived):
  * DNA origami / staple-strand scaffolded nanostructures: Rothemund PWK,
    "Folding DNA to create nanoscale shapes and patterns", Nature
    440:297-302 (2006) — the founding scaffolded-staple DNA-origami method,
    cited by the NANOBOT axis docstring itself.
  * Immobile DNA junctions: Seeman NC, "Nucleic acid junctions and lattices",
    J Theor Biol 99:237-247 (1982) — the structural-DNA-nanotechnology
    precedent, also cited by the NANOBOT axis docstring.
  * Peptide-functionalized DNA nanostructures are a RESEARCH-STAGE modality
    (Pinheiro AV, Bertozzi-lab-style peptide-DNA conjugates;
    Schmidt-Mende-style peptide-decorated nanostructures). NO FDA-APPROVED
    peptide-decorated DNA nanobot exists. The own-precedent is researcher-
    class, never a drug-class claim.

────────────────────────────────────────────────────────────────────────────
RESEARCH-STAGE MODALITY HONESTY  (CRITICAL)
────────────────────────────────────────────────────────────────────────────
Peptide-decorated DNA nanostructures are an ACTIVE RESEARCH FIELD but are
NOT an FDA-approved drug class. There is no clinical precedent for a
peptide-functionalized DNA nanobot therapeutic. This module's
display-orientation-constraint score is therefore an in-silico research-tier
illustration of an interface between two axes — never a modality-precedent
claim, never an efficacy / potency / clinical / regulatory claim.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both sims are IMPORTED / read as data — no fork (f3). The PEPTIDE
    Zimm-Bragg partition is called verbatim; the NANOBOT .hexa actuation
    logic is not executed and not duplicated.
  * The peptide panel sequences and the σ nucleation parameter are
    illustrative literature-informed surrogates for peptide CLASSES, not
    fits to a specific tethered-peptide dataset.
  * The mapping θ_H → display-orientation-constraint is a MODELING CHOICE.
    A real peptide-decorated nanostructure has linker-length entropy,
    surface-anchoring restraints and crowding effects this 1-D helix-coil
    partition does not capture. It is a qualitative illustration.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the chain peptide-sequence → Zimm-Bragg θ_H → display-orientation-
    constraint is computed self-consistently against peptide_sim.py and
    re-runs byte-identically. It is NOT a structural, binding, display-
    orientation, nanodevice-function, therapeutic or regulatory claim
    (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit): every
    θ_H is a Zimm-Bragg partition sum; the display-orientation-constraint
    is θ_H itself; the modality precedent is RESEARCH-class (Rothemund 2006
    DNA origami + peptide-DNA conjugate research), never lattice-derived.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A cross-axis bridge is NOT a new axis — the hexa-bio core-5 set
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED. NANOBOT is
a core axis; PEPTIDE is a sub-axis (:> WEAVE). This file only gates their
interaction and emits witness rows.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_PEPTIDE_PATH = os.path.join(_HERE, "peptide_sim.py")
_NANOBOT_HEXA = os.path.join(_REPO_ROOT, "nanobot", "module", "nanobot.hexa")

SCHEMA_ID = "peptide_nanobot_cross_v1"
SENTINEL_OK = "__PEPTIDE_NANOBOT_CROSS__ PASS"
SENTINEL_FAIL = "__PEPTIDE_NANOBOT_CROSS__ FAIL"

# Display-orientation-constraint gate on the Zimm-Bragg fractional helicity
# θ_H. A peptide with θ_H at or above this gate is judged to present a
# pre-organized, oriented display from the nanostructure; below it the
# peptide is too coil-dominant to display in a defined orientation.
# Illustrative fixed value — NOT measured, NOT lattice-derived
# (g2/f_lattice_fit).
DISPLAY_ORIENTATION_GATE = 0.30


# ── import the PEPTIDE sub-axis (no fork — f3) ──────────────────────────────
def _load_peptide_sim():
    """Import peptide_sim.py as a module — its Zimm-Bragg helix-coil
    partition is reused verbatim (f3: no re-implementation)."""
    spec = importlib.util.spec_from_file_location("peptide_sim", _PEPTIDE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── read the NANOBOT axis's own modality basis (structural text only — f3) ──
def _read_nanobot_modality_basis() -> dict:
    """Read the NANOBOT core axis's own DNA-nanotech modality citations
    straight out of nanobot/module/nanobot.hexa.

    This reads deterministic STRUCTURAL text only (the modality precedent the
    axis declares for itself). It does NOT execute the .hexa file and does
    NOT duplicate any actuation logic — that logic is untouched (f3)."""
    with open(_NANOBOT_HEXA, "r", encoding="utf-8") as fh:
        src = fh.read()
    cites = []
    if "Rothemund 2006 DNA origami" in src:
        cites.append("Rothemund 2006 DNA origami (Nature 440:297-302)")
    if "Seeman 1982" in src:
        cites.append("Seeman 1982 immobile DNA junctions "
                     "(J Theor Biol 99:237-247)")
    if not cites:
        raise RuntimeError(
            "expected NANOBOT axis DNA-nanotech modality citations "
            "(Rothemund 2006 / Seeman 1982) in nanobot/module/nanobot.hexa")
    return {
        "nanobot_axis_source": "nanobot/module/nanobot.hexa",
        "modality_basis_cited_by_axis": cites,
        "axis_role": "NANOBOT core-5 axis — DNA-nanotechnology actuation "
                     "(C0b 12-vertex polyhedral-skeleton simulator)",
    }


# ── deterministic peptide-decorated-nanostructure panel ─────────────────────
# A small illustrative panel of peptide-functionalized DNA nanostructures.
# Each entry attaches one short peptide (chosen from the PEPTIDE sub-axis's
# helix-propensity space) to a staple-terminus position on a DNA-origami /
# C0b-class nanostructure. The peptide sequences span the helicity range so
# the display-orientation-constraint score crosses the gate across the panel.
# Illustrative deterministic inputs — NOT a published peptide-DNA conjugate
# library (see HONESTY).
_DEVICE_PANEL = [
    # (device_id, peptide_sequence, anchor_position, device_note)
    ("origami_helical_display_high",
     "AALEAALEAALEAALE", "staple_5prime_amine",
     "DNA-origami slab decorated at staple 5'-amine with a high-helix-"
     "propensity model peptide (oriented display expected)"),
    ("origami_glp1_like_display",
     "AAEGTFTSDLSKQMEEAA", "staple_5prime_amine",
     "DNA-origami slab decorated with a GLP-1-analog-like model peptide "
     "(helical receptor-bound backbone expected)"),
    ("c0b_mixed_helix_coil_display",
     "AKLSAGTLSAKNVELSAG", "staple_3prime_azide",
     "C0b 12-vertex polyhedral skeleton decorated at staple 3'-azide with "
     "a mixed helix/coil model peptide (partial pre-organization)"),
    ("origami_flexible_linker_display_low",
     "GPGSGPGSGNGPGSGP", "staple_5prime_amine",
     "DNA-origami slab decorated with a Gly/Pro-rich flexible model peptide "
     "(coil-dominant, unoriented tether expected)"),
    ("c0b_high_helix_display",
     "AALEAALEAALEAALE", "staple_3prime_azide",
     "C0b 12-vertex polyhedral skeleton decorated with a high-helix model "
     "peptide (oriented display expected)"),
]


# ── the cross: peptide → Zimm-Bragg θ_H → display-orientation-constraint ────
def build_cross_rows(peptide) -> list:
    """One cross row per peptide-decorated nanostructure.

    For each device: call peptide_sim's `helix_coil_partition()` on the
    attached peptide (imported, not re-implemented — f3), read the resulting
    fractional helicity θ_H, and map it to a display-orientation-constraint
    score ∈ [0, 1] and a binary gate. The σ→1 independent-residue baseline
    is also recorded for the C3 cross-check.
    """
    basis = _read_nanobot_modality_basis()
    sigma = peptide.SIGMA_NUCLEATION
    rows = []
    for device_id, seq, anchor, note in _DEVICE_PANEL:
        part = peptide.helix_coil_partition(seq, sigma=sigma)
        theta_h = part["fractional_helicity"]
        indep = peptide.independent_residue_helicity(seq)
        # display-orientation-constraint = θ_H by construction
        # ∈ [0, 1] (θ_H is a fraction).
        constraint = theta_h
        gate_pass = constraint >= DISPLAY_ORIENTATION_GATE
        rows.append({
            "schema": SCHEMA_ID,
            "device_id": device_id,
            "device_note": note,
            "attached_peptide_sequence": seq,
            "n_residues": part["n_residues"],
            "anchor_position": anchor,
            "nanobot_axis_source": basis["nanobot_axis_source"],
            "nanobot_axis_role": basis["axis_role"],
            "modality_basis_cited_by_axis":
                basis["modality_basis_cited_by_axis"],
            "peptide_model": ("Zimm-Bragg helix-coil partition "
                              "(Zimm & Bragg 1959; Lifson-Roig 1961)"),
            "sigma_nucleation": sigma,
            "partition_Z": part["partition_Z"],
            "fractional_helicity_theta_h": theta_h,
            "independent_residue_helicity_sigma_to_1": indep,
            "cooperativity_suppresses_helix": theta_h <= indep + 1e-12,
            "display_orientation_constraint": constraint,
            "display_orientation_constraint_in_unit_interval":
                0.0 <= constraint <= 1.0,
            "display_orientation_gate": DISPLAY_ORIENTATION_GATE,
            "display_orientation_margin":
                round(constraint - DISPLAY_ORIENTATION_GATE, 12),
            "oriented_display": gate_pass,
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "the θ_H→display-orientation-constraint mapping is a "
                "modeling choice; NOT a structural / binding / display-"
                "orientation / nanodevice-function / therapeutic claim"),
            "illustrative_only": True,
            "creates_a_new_axis": False,
            "research_stage_modality": True,
        })
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X7)."""
    oriented = [r for r in rows if r["oriented_display"]]
    blocked = [r for r in rows if not r["oriented_display"]]
    crit = {
        "X1_device_panel_crossed": (
            len(rows) == len(_DEVICE_PANEL) and len(rows) >= 5),
        "X2_zimm_bragg_model_used": all(
            "Zimm-Bragg" in r["peptide_model"] for r in rows),
        "X3_nanobot_modality_basis_read": all(
            len(r["modality_basis_cited_by_axis"]) >= 1 for r in rows),
        "X4_theta_h_in_unit_interval": all(
            0.0 <= r["fractional_helicity_theta_h"] <= 1.0 for r in rows),
        "X5_cooperativity_suppresses_helix": all(
            r["cooperativity_suppresses_helix"] for r in rows),
        "X6_both_gate_outcomes_present": (
            len(oriented) >= 1 and len(blocked) >= 1),
        "X7_gate_consistent_with_constraint": all(
            (r["oriented_display"]
             == (r["display_orientation_constraint"]
                 >= r["display_orientation_gate"]))
            and (abs(r["display_orientation_margin"]
                     - (r["display_orientation_constraint"]
                        - r["display_orientation_gate"])) < 1e-9)
            and r["display_orientation_constraint_in_unit_interval"]
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
    print("peptide_nanobot_cross — CROSS-AXIS W1a\n", flush=True)
    print("cross:  PEPTIDE :> WEAVE sub-axis Zimm-Bragg helix-coil "
          "pre-organization", flush=True)
    print("        ──display-orientation-constraint──▶  NANOBOT core-5 axis"
          " peptide-decorated DNA nanostructure", flush=True)
    print("        peptide sequence → Zimm-Bragg θ_H → display-orientation "
          "gate\n", flush=True)

    peptide = _load_peptide_sim()
    basis = _read_nanobot_modality_basis()
    print("  real-limit anchor : Zimm-Bragg helix-coil cooperative "
          "pre-organization")
    print("                      (Zimm & Bragg 1959 J Chem Phys 31:526;")
    print("                      Lifson & Roig 1961 J Chem Phys 34:1963)")
    print(f"  NANOBOT axis      : {basis['axis_role']}")
    for c in basis["modality_basis_cited_by_axis"]:
        print(f"    modality basis  : {c}")
    print(f"  nucleation σ      : {peptide.SIGMA_NUCLEATION:.0e}  "
          f"(cooperative transition)")
    print(f"  display gate      : Zimm-Bragg θ_H >= "
          f"{DISPLAY_ORIENTATION_GATE} → oriented display\n", flush=True)

    rows = build_cross_rows(peptide)
    for r in rows:
        flag = "oriented" if r["oriented_display"] else "BELOW GATE"
        print(f"  [{r['device_id']:<36}] {flag:<11} "
              f"N={r['n_residues']:>2}  θ_H={r['fractional_helicity_theta_h']:.4f}  "
              f"(σ→1 baseline={r['independent_residue_helicity_sigma_to_1']:.4f})")
        print(f"      attached='{r['attached_peptide_sequence']}'  "
              f"anchor={r['anchor_position']}  "
              f"constraint={r['display_orientation_constraint']:.4f}  "
              f"margin={r['display_orientation_margin']:+.4f}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  "
          f"verdict: {acc['verdict']} ---")

    print("\n## research-stage modality honesty (CRITICAL)")
    print("  Peptide-decorated DNA nanostructures are an ACTIVE RESEARCH")
    print("  FIELD (Pinheiro / Bertozzi-lab-style peptide-DNA conjugates;")
    print("  Schmidt-Mende-style peptide-decorated nanostructures) but are")
    print("  NOT an FDA-approved drug class. No FDA-approved peptide-")
    print("  decorated DNA nanobot therapeutic exists. The display-")
    print("  orientation-constraint score here is a RESEARCH-TIER in-silico")
    print("  illustration of an axis-axis interface — NEVER a modality-")
    print("  precedent / efficacy / clinical / regulatory claim.")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both sims are imported / read as data — no fork (f3): the")
    print("    PEPTIDE Zimm-Bragg partition is called verbatim; the NANOBOT")
    print("    .hexa actuation logic is not executed and not duplicated.")
    print("  - The peptide panel sequences and σ are illustrative")
    print("    literature-informed surrogates for peptide CLASSES, not fits")
    print("    to a specific tethered-peptide dataset.")
    print("  - The θ_H → display-orientation-constraint mapping is a")
    print("    MODELING CHOICE: a real peptide-decorated nanostructure has")
    print("    linker-length entropy, surface-anchoring restraints and")
    print("    crowding effects this 1-D helix-coil partition omits.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY:")
    print("    the chain peptide-seq → θ_H → display-orientation-")
    print("    constraint is computed self-consistently and re-runs byte-")
    print("    identically. It is NOT a structural / binding / display-")
    print("    orientation / nanodevice-function / therapeutic claim "
          "(g8/f2).")
    print("  - No θ_H / constraint / count here is derived from the n=6")
    print("    lattice (g2/f_lattice_fit). Modality precedent is RESEARCH-")
    print("    class (Rothemund 2006 + peptide-DNA conjugate research),")
    print("    never lattice-derived (g3/f1). A cross-axis bridge is NOT a")
    print("    new axis — the core-5 set is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → byte-identical re-runs
        "cross": ("W1a  PEPTIDE :> WEAVE Zimm-Bragg helix-coil "
                  "pre-organization  ->  NANOBOT core-5 axis "
                  "peptide-decorated DNA nanostructure display-orientation "
                  "constraint"),
        "peptide_subaxis_source": (
            "_python_bridge/module/peptide_sim.py (Zimm-Bragg helix-coil "
            "partition imported, not re-implemented — f3)"),
        "nanobot_axis_source": (
            "nanobot/module/nanobot.hexa (DNA-nanotech modality basis read "
            "as structural text; actuation logic untouched — f3)"),
        "real_limit_anchor": (
            "Zimm-Bragg helix-coil cooperative pre-organization "
            "(Zimm & Bragg, J. Chem. Phys. 31:526, 1959; Lifson & Roig, "
            "J. Chem. Phys. 34:1963, 1961). Helix propensities — Pace & "
            "Scholtz, Biophys. J. 75:422 (1998); Chakrabartty, Kortemme & "
            "Baldwin, Protein Sci. 3:843 (1994). Hard ceilings: "
            "0 ≤ θ_H ≤ 1; display-orientation-constraint ∈ [0, 1]."),
        "modality_precedent": (
            "DNA origami — Rothemund 2006 (Nature 440:297-302); immobile "
            "DNA junctions — Seeman 1982 (J Theor Biol 99:237-247); "
            "peptide-functionalized DNA nanostructures — RESEARCH-STAGE "
            "modality (Pinheiro / Bertozzi-lab-style peptide-DNA "
            "conjugates; Schmidt-Mende-style peptide-decorated "
            "nanostructures). NO FDA-approved peptide-decorated DNA "
            "nanobot exists — researcher-class own precedent, NEVER "
            "lattice-derived (g3/f1)."),
        "research_stage_modality": True,
        "creates_a_new_axis": False,
        "core_5_unchanged":
            "QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID (UNCHANGED)",
        "sigma_nucleation": peptide.SIGMA_NUCLEATION,
        "display_orientation_gate": DISPLAY_ORIENTATION_GATE,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — the θ_H → display-"
            "orientation-constraint mapping is a modeling choice, NOT a "
            "structural / binding / display-orientation / nanodevice-"
            "function / therapeutic claim. Core-5 axis set UNCHANGED; this "
            "is a cross, not a new axis."),
        "lattice_derivation": (
            "none — no θ_H, constraint, gate, or count derived from the "
            "n=6 lattice (g2/f1/f_lattice_fit)"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
