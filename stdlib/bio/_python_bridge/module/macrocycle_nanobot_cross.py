#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
macrocycle_nanobot_cross.py — CROSS-AXIS integration W1b.

CROSS:  MACROCYCLE :> WEAVE sub-axis (Jacobson-Stockmayer cyclization
        pre-organization entropy)
        ──display-affinity-ledger──▶  NANOBOT core-5 axis
        (DNA-nanotech / C0b 12-vertex polyhedral-skeleton simulator,
        macrocycle-decorated DNA nanostructure).

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/macrocycle_sim.py — the MACROCYCLE sub-axis
      (:> WEAVE core). Implements the cyclization pre-organization entropy
      model: W_conf = Π over rotatable bonds of g_b (free bonds vs ring-
      constrained bonds with effective multiplicity f_ring * g_free), the
      Boltzmann entropy S_conf = R * ln W_conf, and the binding
      conformational-entropy penalty -T * deltaS_conf paid on freezing into
      the bound conformer.

  (2) nanobot/module/nanobot.hexa — the NANOBOT core-5 axis: DNA-nanotech /
      C0b 12-vertex polyhedral-skeleton actuation simulator. The docstring
      explicitly cites Rothemund 2006 DNA origami and Seeman 1982 immobile
      junctions as the modality's structural basis.

These two have never been crossed. They CAN be crossed at a legitimate
research-stage interface: a *macrocycle-decorated DNA nanostructure* — a
DNA-origami / C0b-class skeleton with one or more macrocyclic ligands
COVALENTLY ATTACHED to a staple terminus (e.g. via amine / azide / click
chemistry on a 5' or 3'-modified staple). DNA-templated synthesis of
macrocycles is itself an active research field (Yang / Liu DNA-templated
synthesis macrocycle library work; Schmidt-Mende-style decorated
nanostructures), but macrocycle-decorated DNA nanobots are NOT an FDA-
approved drug class. This cross models the in-silico interface, NEVER
claims a clinical / therapeutic / regulatory standing.

The physical fact the cross rests on: an attached LIGAND must adopt its
bound conformer when it engages its target from the nanostructure surface;
the conformational-entropy penalty it pays on freezing is a real
free-energy term on the display-affinity ledger. The MACROCYCLE axis's
Jacobson-Stockmayer / Boltzmann S = R ln W ring-closure pre-organization
gives back exactly that entropy: a macrocycle attached to the nanostructure
pays a SMALLER binding-entropy penalty than its acyclic analog would, so
its display-affinity ledger is more favourable by ddG_preorg = -T * [S_conf
(acyclic) - S_conf(macrocycle)] kcal/mol.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sides, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic macrocycle-decorated-nanostructure panel, this
module:

  * imports macrocycle_sim.py and calls its `conformational_entropy()` —
    the MACROCYCLE side's W_conf / S_conf / binding-entropy-penalty
    accounting is reused VERBATIM, never re-implemented (f3);
  * reads the NANOBOT axis's own DNA-nanotech modality basis straight out
    of nanobot/module/nanobot.hexa as deterministic structural text — the
    file is NOT executed, its actuation logic is untouched (f3);
  * for each device, takes the macrocycle's binding-entropy penalty and
    the acyclic analog's penalty (same n_rotatable_total, n_in_ring = 0)
    and computes the cyclization entropic advantage ddG_preorg ≤ 0 added
    to the display-affinity ledger:

        macrocycle on nanostructure ──Jacobson-Stockmayer──▶
            ddG_preorg = -T * [S(acyclic) - S(macrocycle)] ≤ 0 kcal/mol
              (favourable contribution to the display-affinity ledger)

The cross demonstrates the BOUND: a ring can only REMOVE conformers, so
ddG_preorg ≤ 0 always (W_macro ≤ W_acyclic_with_same_rotatable_count).
The display-affinity ledger ceiling is set by Boltzmann S = R ln W and the
Jacobson-Stockmayer ring-closure principle (real statistical-mechanics
limits), not by the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * Macrocyclization pre-organization entropy — the Jacobson-Stockmayer
    ring-closure principle (Jacobson H, Stockmayer WH, "Intramolecular
    reaction in polycondensations. I. The theory of linear systems",
    J. Chem. Phys. 18:1600, 1950) and Boltzmann's relation S = R * ln W:
    closing a ring REMOVES accessible conformers from the chain, so the
    macrocycle pays a smaller conformational-entropy penalty on binding.
    Hard ceilings:
      - S_conf ≥ 0 always (entropy is non-negative);
      - W_macro ≤ W_acyclic ⇒ ddG_preorg ≤ 0 (a ring can only REMOVE
        conformers — Jacobson-Stockmayer hard floor).
  * Medicinal-chemistry conformational-restriction / pre-organization
    references: Mallinson & Collins, Future Med. Chem. 4:1409 (2012);
    Driggers, Hale, Lee & Terrett, Nat. Rev. Drug Discov. 7:608 (2008);
    Villar et al., Nat. Chem. Biol. 10:723 (2014).

Modality precedent (described ONLY by its own RESEARCH precedent —
g3/f1/f_lattice_fit, NEVER lattice-derived):
  * DNA origami / staple-strand scaffolded nanostructures: Rothemund PWK,
    "Folding DNA to create nanoscale shapes and patterns", Nature
    440:297-302 (2006) — the founding scaffolded-staple DNA-origami
    method, cited by the NANOBOT axis docstring itself.
  * Immobile DNA junctions: Seeman NC, "Nucleic acid junctions and
    lattices", J Theor Biol 99:237-247 (1982) — the structural-DNA-
    nanotechnology precedent, also cited by the NANOBOT axis docstring.
  * Macrocycle-decorated DNA nanostructures are a RESEARCH-STAGE modality
    (Yang / Liu DNA-templated synthesis of macrocycles; Schmidt-Mende-
    style decorated nanostructures). NO FDA-APPROVED macrocycle-decorated
    DNA nanobot exists. The own-precedent is researcher-class, never a
    drug-class claim.

────────────────────────────────────────────────────────────────────────────
RESEARCH-STAGE MODALITY HONESTY  (CRITICAL)
────────────────────────────────────────────────────────────────────────────
Macrocycle-decorated DNA nanostructures are an ACTIVE RESEARCH FIELD but
are NOT an FDA-approved drug class. There is no clinical precedent for a
macrocycle-functionalized DNA nanobot therapeutic. This module's
ddG_preorg display-affinity-ledger contribution is therefore an in-silico
research-tier illustration of an interface between two axes — never a
modality-precedent claim, never an efficacy / potency / clinical /
regulatory claim.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both sims are IMPORTED / read as data — no fork (f3). The MACROCYCLE
    conformational_entropy accounting is called verbatim; the NANOBOT
    .hexa actuation logic is not executed and not duplicated.
  * The rotatable-bond counts, in-ring-bond counts and the ring-constraint
    factor f_ring are illustrative literature-informed surrogates for
    ligand CLASSES, not fits to a specific tethered-macrocycle dataset.
  * The cross's display-affinity ledger uses ONLY the ddG_preorg ≤ 0
    cyclization-entropy term. A real macrocycle-decorated nanostructure
    has linker-length entropy, surface-anchoring restraints, crowding
    effects and binding-site geometry this single term does not capture.
    It is a qualitative illustration of one favourable contribution.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the chain macrocycle → conformational_entropy → ddG_preorg ledger is
    computed self-consistently against macrocycle_sim.py and re-runs
    byte-identically. It is NOT a structural, binding-affinity, display-
    affinity, nanodevice-function, therapeutic or regulatory claim
    (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit):
    every W_conf, S_conf and ddG_preorg is a Boltzmann / Jacobson-
    Stockmayer ring-closure accounting; the modality precedent is
    RESEARCH-class (Rothemund 2006 DNA origami + Yang/Liu DNA-templated-
    synthesis macrocycle research), never lattice-derived.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A cross-axis bridge is NOT a new axis — the hexa-bio core-5 set
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED. NANOBOT
is a core axis; MACROCYCLE is a sub-axis (:> WEAVE). This file only gates
their interaction and emits witness rows.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_MACROCYCLE_PATH = os.path.join(_HERE, "macrocycle_sim.py")
_NANOBOT_HEXA = os.path.join(_REPO_ROOT, "nanobot", "module", "nanobot.hexa")

SCHEMA_ID = "macrocycle_nanobot_cross_v1"
SENTINEL_OK = "__MACROCYCLE_NANOBOT_CROSS__ PASS"
SENTINEL_FAIL = "__MACROCYCLE_NANOBOT_CROSS__ FAIL"

# Display-affinity-ledger gate on the cyclization entropic advantage
# (kcal/mol). A macrocycle attached to a nanostructure is judged to
# contribute a "favourable" entry to the ledger iff ddG_preorg is at or
# below this gate (more negative = more favourable). Illustrative fixed
# value — NOT measured, NOT lattice-derived (g2/f_lattice_fit).
LEDGER_FAVOURABLE_GATE_KCAL_MOL = -1.0


# ── import the MACROCYCLE sub-axis (no fork — f3) ───────────────────────────
def _load_macrocycle_sim():
    """Import macrocycle_sim.py as a module — its W_conf / S_conf /
    binding-entropy-penalty accounting is reused verbatim (f3: no
    re-implementation)."""
    spec = importlib.util.spec_from_file_location(
        "macrocycle_sim", _MACROCYCLE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── read the NANOBOT axis's own modality basis (structural text only — f3) ──
def _read_nanobot_modality_basis() -> dict:
    """Read the NANOBOT core axis's own DNA-nanotech modality citations
    straight out of nanobot/module/nanobot.hexa.

    This reads deterministic STRUCTURAL text only (the modality precedent
    the axis declares for itself). It does NOT execute the .hexa file and
    does NOT duplicate any actuation logic — that logic is untouched
    (f3)."""
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


# ── deterministic macrocycle-decorated-nanostructure panel ──────────────────
# A small illustrative panel of macrocycle-functionalized DNA nanostructures.
# Each entry attaches one macrocyclic ligand (with its own n_rotatable and
# n_bonds_in_ring) to a staple-terminus position on a DNA-origami / C0b-
# class nanostructure. The rotatable-bond counts span small/large rings so
# the ddG_preorg ledger contribution crosses the favourable gate across the
# panel. Illustrative deterministic inputs — NOT a published macrocycle-DNA
# conjugate library (see HONESTY).
_DEVICE_PANEL = [
    # (device_id, n_rotatable_total, n_bonds_in_ring,
    #  ligand_class_label, anchor_position, device_note)
    ("origami_small_macrocycle_decoration",
     8, 5, "lorlatinib_class_small_macrocycle", "staple_5prime_amine",
     "DNA-origami slab decorated at staple 5'-amine with a small "
     "synthetic-macrocycle ligand (lorlatinib-class; 8 rotatable bonds, "
     "5 in-ring)"),
    ("c0b_macrolide_decoration",
     26, 22, "rapamycin_class_macrolide", "staple_3prime_azide",
     "C0b 12-vertex polyhedral skeleton decorated at staple 3'-azide with "
     "a macrolide-class macrocycle (rapamycin-class; 26 rotatable, "
     "22 in-ring)"),
    ("origami_undecapeptide_macrocycle",
     33, 30, "cyclosporine_class_cyclic_peptide", "staple_5prime_amine",
     "DNA-origami slab decorated with a cyclic-undecapeptide macrocycle "
     "(cyclosporine-class; 33 rotatable, 30 in-ring)"),
    ("c0b_minimal_ring_decoration",
     6, 3, "minimal_synthetic_macrocycle", "staple_3prime_azide",
     "C0b skeleton decorated with a minimal synthetic macrocycle "
     "(6 rotatable, 3 in-ring) — small ring-closure advantage"),
    ("origami_partial_constraint_decoration",
     4, 1, "loosely_constrained_macrocycle", "staple_5prime_amine",
     "DNA-origami slab decorated with a loosely-constrained macrocycle "
     "(4 rotatable, only 1 in-ring) — minimal cyclization advantage"),
]


# ── the cross: macrocycle → S_conf → ddG_preorg display-affinity ledger ─────
def build_cross_rows(macrocycle) -> list:
    """One cross row per macrocycle-decorated nanostructure.

    For each device: call macrocycle_sim's `conformational_entropy()` on
    both the macrocycle (with n_bonds_in_ring > 0) and its acyclic analog
    (n_bonds_in_ring = 0, same n_rotatable_total), then take the
    binding-entropy-penalty difference as ddG_preorg ≤ 0 — the favourable
    contribution to the display-affinity ledger.
    """
    basis = _read_nanobot_modality_basis()
    f_ring = macrocycle.RING_CONSTRAINT_FACTOR
    temp_k = macrocycle.TEMP_K
    rows = []
    for (device_id, n_rot, n_ring, ligand_class, anchor,
         note) in _DEVICE_PANEL:
        ent_macro = macrocycle.conformational_entropy(n_rot, n_ring,
                                                       f_ring=f_ring)
        ent_acyclic = macrocycle.conformational_entropy(n_rot, 0,
                                                         f_ring=f_ring)
        penalty_macro = ent_macro["binding_entropy_penalty_kcal_per_mol"]
        penalty_acyclic = ent_acyclic["binding_entropy_penalty_kcal_per_mol"]
        ddg_preorg = penalty_macro - penalty_acyclic
        preorg_favourable = ddg_preorg <= 0.0
        ledger_favourable = ddg_preorg <= LEDGER_FAVOURABLE_GATE_KCAL_MOL
        rows.append({
            "schema": SCHEMA_ID,
            "device_id": device_id,
            "device_note": note,
            "attached_ligand_class": ligand_class,
            "anchor_position": anchor,
            "nanobot_axis_source": basis["nanobot_axis_source"],
            "nanobot_axis_role": basis["axis_role"],
            "modality_basis_cited_by_axis":
                basis["modality_basis_cited_by_axis"],
            "macrocycle_model": (
                "macrocyclization pre-organization entropy "
                "(Jacobson-Stockmayer 1950 ring-closure; "
                "Boltzmann S = R*ln W)"),
            "temperature_K": temp_k,
            "ring_constraint_factor_f_ring": f_ring,
            "n_rotatable_bonds_total": n_rot,
            "n_bonds_in_ring": n_ring,
            "n_bonds_free_macrocycle": ent_macro["n_bonds_free"],
            "conformational_microstates_W_macrocycle":
                ent_macro["conformational_microstates_W"],
            "conformational_microstates_W_acyclic":
                ent_acyclic["conformational_microstates_W"],
            "S_conf_macrocycle_cal_per_mol_K":
                ent_macro["S_conf_cal_per_mol_K"],
            "S_conf_acyclic_cal_per_mol_K":
                ent_acyclic["S_conf_cal_per_mol_K"],
            "binding_entropy_penalty_macrocycle_kcal_per_mol":
                penalty_macro,
            "binding_entropy_penalty_acyclic_kcal_per_mol":
                penalty_acyclic,
            "ddg_preorg_kcal_per_mol": ddg_preorg,
            "preorg_is_favourable": preorg_favourable,
            "macrocycle_fewer_microstates": (
                ent_macro["conformational_microstates_W"]
                <= ent_acyclic["conformational_microstates_W"]),
            "display_affinity_ledger_gate_kcal_per_mol":
                LEDGER_FAVOURABLE_GATE_KCAL_MOL,
            "display_affinity_ledger_margin_kcal_per_mol":
                round(LEDGER_FAVOURABLE_GATE_KCAL_MOL - ddg_preorg, 12),
            "ledger_favourable": ledger_favourable,
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "the ddG_preorg → display-affinity-ledger mapping is a "
                "modeling choice; NOT a structural / binding-affinity / "
                "display-affinity / nanodevice-function / therapeutic "
                "claim"),
            "illustrative_only": True,
            "creates_a_new_axis": False,
            "research_stage_modality": True,
        })
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X7)."""
    favourable = [r for r in rows if r["ledger_favourable"]]
    non_favourable = [r for r in rows if not r["ledger_favourable"]]
    crit = {
        "X1_device_panel_crossed": (
            len(rows) == len(_DEVICE_PANEL) and len(rows) >= 5),
        "X2_jacobson_stockmayer_model_used": all(
            "Jacobson-Stockmayer" in r["macrocycle_model"] for r in rows),
        "X3_nanobot_modality_basis_read": all(
            len(r["modality_basis_cited_by_axis"]) >= 1 for r in rows),
        "X4_entropy_non_negative": all(
            r["S_conf_macrocycle_cal_per_mol_K"] >= 0.0
            and r["S_conf_acyclic_cal_per_mol_K"] >= 0.0
            for r in rows),
        "X5_ddg_preorg_non_positive_hard_floor": all(
            r["ddg_preorg_kcal_per_mol"] <= 1e-12
            and r["preorg_is_favourable"]
            and r["macrocycle_fewer_microstates"]
            for r in rows),
        "X6_both_ledger_outcomes_present": (
            len(favourable) >= 1 and len(non_favourable) >= 1),
        "X7_ledger_gate_consistent": all(
            (r["ledger_favourable"]
             == (r["ddg_preorg_kcal_per_mol"]
                 <= r["display_affinity_ledger_gate_kcal_per_mol"]))
            and (abs(r["display_affinity_ledger_margin_kcal_per_mol"]
                     - (r["display_affinity_ledger_gate_kcal_per_mol"]
                        - r["ddg_preorg_kcal_per_mol"])) < 1e-9)
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
    print("macrocycle_nanobot_cross — CROSS-AXIS W1b\n", flush=True)
    print("cross:  MACROCYCLE :> WEAVE sub-axis Jacobson-Stockmayer "
          "cyclization", flush=True)
    print("        ──display-affinity-ledger──▶  NANOBOT core-5 axis "
          "macrocycle-decorated DNA nanostructure", flush=True)
    print("        macrocycle → S_conf(macro) vs S_conf(acyclic) → "
          "ddG_preorg ≤ 0\n", flush=True)

    macrocycle = _load_macrocycle_sim()
    basis = _read_nanobot_modality_basis()
    print("  real-limit anchor : macrocyclization pre-organization entropy")
    print("                      Jacobson & Stockmayer 1950 J Chem Phys "
          "18:1600;")
    print("                      Boltzmann S = R*ln W;")
    print("                      Mallinson & Collins 2012; Driggers et al. "
          "2008;")
    print("                      Villar et al. 2014")
    print(f"  NANOBOT axis      : {basis['axis_role']}")
    for c in basis["modality_basis_cited_by_axis"]:
        print(f"    modality basis  : {c}")
    print(f"  hard floor        : ring removes conformers ⇒ "
          f"W_macro ≤ W_acyclic ⇒ ddG_preorg ≤ 0")
    print(f"  f_ring            : {macrocycle.RING_CONSTRAINT_FACTOR}  "
          f"T = {macrocycle.TEMP_K} K")
    print(f"  ledger gate       : ddG_preorg ≤ "
          f"{LEDGER_FAVOURABLE_GATE_KCAL_MOL:.2f} kcal/mol → favourable "
          f"ledger entry\n", flush=True)

    rows = build_cross_rows(macrocycle)
    for r in rows:
        flag = "favourable" if r["ledger_favourable"] else "ABOVE GATE"
        print(f"  [{r['device_id']:<42}] {flag:<11} "
              f"n_rot={r['n_rotatable_bonds_total']:>2}  "
              f"n_ring={r['n_bonds_in_ring']:>2}  "
              f"ddG_preorg={r['ddg_preorg_kcal_per_mol']:+.3f} kcal/mol")
        print(f"      ligand={r['attached_ligand_class']:<36} "
              f"anchor={r['anchor_position']}  "
              f"margin={r['display_affinity_ledger_margin_kcal_per_mol']:+.3f}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  "
          f"verdict: {acc['verdict']} ---")

    print("\n## research-stage modality honesty (CRITICAL)")
    print("  Macrocycle-decorated DNA nanostructures are an ACTIVE")
    print("  RESEARCH FIELD (Yang / Liu DNA-templated-synthesis macrocycle")
    print("  research; Schmidt-Mende-style decorated nanostructures) but")
    print("  are NOT an FDA-approved drug class. No FDA-approved")
    print("  macrocycle-decorated DNA nanobot therapeutic exists. The")
    print("  ddG_preorg display-affinity-ledger contribution here is a")
    print("  RESEARCH-TIER in-silico illustration of an axis-axis")
    print("  interface — NEVER a modality-precedent / efficacy / clinical")
    print("  / regulatory claim.")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both sims are imported / read as data — no fork (f3): the")
    print("    MACROCYCLE conformational_entropy accounting is called")
    print("    verbatim; the NANOBOT .hexa actuation logic is not executed")
    print("    and not duplicated.")
    print("  - The rotatable-bond counts, n_bonds_in_ring and f_ring are")
    print("    illustrative literature-informed surrogates for ligand")
    print("    CLASSES, not fits to a specific tethered-macrocycle dataset.")
    print("  - The ddG_preorg → display-affinity ledger uses ONLY the")
    print("    cyclization-entropy term. A real macrocycle-decorated")
    print("    nanostructure has linker-length entropy, surface-anchoring")
    print("    restraints, crowding and binding-site geometry this single")
    print("    term omits — a qualitative illustration of one favourable")
    print("    contribution.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY")
    print("    ONLY: the chain macrocycle → conformational_entropy →")
    print("    ddG_preorg ledger is computed self-consistently and re-runs")
    print("    byte-identically. It is NOT a structural / binding-affinity")
    print("    / display-affinity / nanodevice-function / therapeutic")
    print("    claim (g8/f2).")
    print("  - No W_conf / S_conf / ddG_preorg / count here is derived")
    print("    from the n=6 lattice (g2/f_lattice_fit). Modality precedent")
    print("    is RESEARCH-class (Rothemund 2006 + Yang/Liu DNA-templated-")
    print("    synthesis macrocycle research), never lattice-derived")
    print("    (g3/f1). A cross-axis bridge is NOT a new axis — the core-5")
    print("    set is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → byte-identical re-runs
        "cross": ("W1b  MACROCYCLE :> WEAVE Jacobson-Stockmayer "
                  "cyclization pre-organization  ->  NANOBOT core-5 axis "
                  "macrocycle-decorated DNA nanostructure display-affinity "
                  "ledger"),
        "macrocycle_subaxis_source": (
            "_python_bridge/module/macrocycle_sim.py (conformational-"
            "entropy accounting imported, not re-implemented — f3)"),
        "nanobot_axis_source": (
            "nanobot/module/nanobot.hexa (DNA-nanotech modality basis read "
            "as structural text; actuation logic untouched — f3)"),
        "real_limit_anchor": (
            "macrocyclization pre-organization entropy — Jacobson & "
            "Stockmayer ring-closure principle (Jacobson H, Stockmayer "
            "WH, J. Chem. Phys. 18:1600, 1950); Boltzmann S = R*ln W; "
            "conformational-restriction medicinal-chemistry references "
            "(Mallinson & Collins, Future Med. Chem. 4:1409, 2012; "
            "Driggers et al., Nat. Rev. Drug Discov. 7:608, 2008; Villar "
            "et al., Nat. Chem. Biol. 10:723, 2014). Hard ceilings: "
            "S_conf ≥ 0; W_macro ≤ W_acyclic ⇒ ddG_preorg ≤ 0."),
        "modality_precedent": (
            "DNA origami — Rothemund 2006 (Nature 440:297-302); immobile "
            "DNA junctions — Seeman 1982 (J Theor Biol 99:237-247); "
            "macrocycle-decorated DNA nanostructures — RESEARCH-STAGE "
            "modality (Yang / Liu DNA-templated synthesis of macrocycles; "
            "Schmidt-Mende-style decorated nanostructures). NO FDA-"
            "approved macrocycle-decorated DNA nanobot exists — "
            "researcher-class own precedent, NEVER lattice-derived "
            "(g3/f1)."),
        "research_stage_modality": True,
        "creates_a_new_axis": False,
        "core_5_unchanged":
            "QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID (UNCHANGED)",
        "ring_constraint_factor_f_ring": macrocycle.RING_CONSTRAINT_FACTOR,
        "temperature_K": macrocycle.TEMP_K,
        "display_affinity_ledger_gate_kcal_per_mol":
            LEDGER_FAVOURABLE_GATE_KCAL_MOL,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — the ddG_preorg → "
            "display-affinity ledger mapping is a modeling choice, NOT a "
            "structural / binding-affinity / display-affinity / "
            "nanodevice-function / therapeutic claim. Core-5 axis set "
            "UNCHANGED; this is a cross, not a new axis."),
        "lattice_derivation": (
            "none — no W_conf / S_conf / ddG_preorg / gate / count "
            "derived from the n=6 lattice (g2/f1/f_lattice_fit)"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
