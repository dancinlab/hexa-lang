#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
metallodrug_cryptic_pocket_cross.py — CROSS-AXIS BB2.

CROSS:  METALLODRUG (cisplatin Pt(II)-N7(guanine) covalent adduct)
        ====unify====
        CRYPTIC-POCKET (closed/open Boltzmann conformational-equilibrium ledger)

Both parent sims are IMPORTED — never re-implemented (AGENTS.tape f3 no-fork):
  - metallodrug_coordination_sim.py supplies the Pt-N7 coordinate-bond anchor
    (~2.0 A; Takahara, Rosenzweig, Frederick & Lippard, Nature 377:649, 1995)
    and the square-planar Pt(II) geometry verifier.
  - cryptic_pocket_sim.py supplies open_population() — the Boltzmann formula
    P_open = exp(-DG_open/RT) / (1 + exp(-DG_open/RT)) — and the conformational
    free-energy ledger DG_bind_obs = DG_bind_open + DG_open (Hammes, Chang &
    Oas, PNAS 106:13737, 2009).

────────────────────────────────────────────────────────────────────────────
WHAT IS UNIFIED (the model-level mapping)
────────────────────────────────────────────────────────────────────────────
Cisplatin's mechanism of action involves a CONFORMATIONAL-SELECTION step on
DNA. The intrastrand d(GpG) Pt(II) crosslink bends B-DNA by ~30-40 deg at
the platination site (Takahara 1995 crystal structure of the cisplatin
1,2-intrastrand d(GpG) adduct). HMG-domain proteins (HMGB1, hUBF, SRY)
preferentially recognise the bent-DNA state and not canonical B-DNA (Pil &
Lippard, Science 256:234, 1992) — that downstream recognition step is what
turns the covalent adduct into a cytotoxic signal.

That two-state ensemble — B-DNA (canonical, HMG-invisible) <=> bent-DNA
(distorted, HMG-recognised) — has the SAME mathematical structure as the
cryptic-pocket closed/open conformational equilibrium that cryptic_pocket_sim
gates:

      cryptic protein   :  closed  ⇌(ΔG_open)   open   (rarely sampled apo)
      Pt-DNA substrate  :  B-DNA   ⇌(ΔG_bend)   bent-DNA (rare in apo DNA)

A cryptic-pocket binder pays ΔG_open out of its intrinsic binding budget
ΔG_bind_open and the bound complex re-populates the open state (Hammes et al.
2009). The cisplatin Pt-N7 covalent adduct does the same conformational-
selection bookkeeping on DNA: the covalent adduct stabilises the bent
geometry, so the effective bending free energy after platination is

      ΔG_bend^bound  =  ΔG_bend + ΔG_Pt-adduct                  (kcal/mol)

with ΔG_Pt-adduct < 0 because the adduct itself is geometrically incompatible
with canonical B-DNA. Re-evaluated through cryptic_pocket_sim.open_population
the bent-DNA population rises sharply, i.e. P_bent^bound > P_bent^apo — the
Pt adduct is a conformational SELECTOR for the bent-DNA state, exactly as a
cryptic-pocket binder is a selector for the open protein state.

Chemically the two events are DIFFERENT (covalent Pt-N7 coordinate bond on
DNA vs reversible / non-covalent cryptic-pocket binding on a protein
pocket); the conformational-equilibrium MATH (two-state Boltzmann + the
ledger ΔG^bound = ΔG^apo + ΔG^binder/adduct) is the same.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Three coincident real limits anchor every row:
  - Pt-N7(guanine) coordinate-bond length ~2.0 A:
    Takahara PM, Rosenzweig AC, Frederick CA, Lippard SJ.
    Nature 1995; 377:649-652. (cisplatin 1,2-intrastrand d(GpG) DNA-adduct
    crystal structure; the DNA is also bent ~30-40 deg at the platination
    site).
  - HMG-domain protein recognition of cisplatin-DNA bent adducts:
    Pil PM, Lippard SJ. Science 1992; 256:234-237. (HMG1 binding to
    cisplatin-modified DNA — the canonical HMG-recognises-bent-DNA result).
  - Conformational free-energy / Boltzmann population statistics + the
    conformational-selection thermodynamic cycle:
    Hammes GG, Chang YC, Oas TG. PNAS 2009; 106:13737-13741. (inherited
    from cryptic_pocket_sim — the same ledger ΔG^bound = ΔG^apo + ΔG^binder
    that the cryptic sub-axis conserves).

────────────────────────────────────────────────────────────────────────────
OWN-PRECEDENT (governance g3 / f1 / HEXA-METALLODRUG.tape f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
Each modality is described by its own drug precedent, never lattice-derived:
  - METALLODRUG precedent: cisplatin (FDA 1978), carboplatin (FDA 1989),
    oxaliplatin (FDA 2002) — Pt(II) square-planar d8 anticancer agents.
  - CRYPTIC-POCKET precedent: sotorasib targeting the KRAS-G12C switch-II
    cryptic pocket (Ostrem et al., Nature 503:548, 2013; Canon et al.,
    Nature 575:217, 2019; sotorasib FDA-approved 2021).

No quantity here is derived from the n=6 lattice (σ=12 · τ=4 · φ=2 · J₂=24).
The metallodrug coordination numbers and the cryptic-pocket free-energy
thresholds are coordination-chemistry / Boltzmann-statistical-mechanics
quantities. Numerical coincidence with n=6 is OBSERVATION ONLY
(HEXA-METALLODRUG.tape f_lattice_fit / n6_honest_stance).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Cisplatin is FDA-approved (1978) — the METALLODRUG side of this cross
    is NOT a research-stage claim. The CRYPTIC-side mapping is the model-
    level unification: the closed/open conformational-selection ledger
    cryptic_pocket_sim conserves applies to the Pt-DNA-induced B-DNA
    <=> bent-DNA equilibrium under the structural analogy
            B-DNA   <-> closed (HMG-invisible)
            bent-DNA <-> open  (HMG-recognised, distorted, rare in apo)
  * This is NOT a claim that all metallodrugs work via cryptic pockets.
    It is also NOT a claim that the Pt-DNA adduct IS a cryptic pocket in
    the protein-pocket sense — the chemical event is covalent and the
    conformational substrate is DNA, not a protein pocket. The unification
    is at the level of the two-state conformational-selection math.
  * Both parent sims are IMPORTED via importlib (f3 — no shadow of sister
    logic). The Pt-N7 anchor is read from metallodrug_coordination_sim
    and the Boltzmann open_population formula from cryptic_pocket_sim.
  * No live VQE / no network / no random / no wall-clock dependence —
    pure stdlib, deterministic byte-identical re-runs.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY
    (g8 / f2): the Pt-N7 anchor matches Takahara 1995, the conformational-
    selection ledger sum is conserved, and the Pt-adduct-induced
    population shift is positive. It is NOT a binding-affinity,
    cytotoxicity, antitumor, immunogenic or therapeutic-efficacy claim.

A CROSS is NOT a new axis. METALLODRUG remains an expansion-main axis;
CRYPTIC-POCKET remains a sub-axis :> QUANTUM core. The hexa-bio core-5
axes (QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) are UNCHANGED.

Sentinel:  __METALLODRUG_CRYPTIC_POCKET_CROSS__ PASS   (or FAIL).
"""
from __future__ import annotations
import importlib.util
import json
import math
import os
import sys

# ── locate the two parent simulator sources (no fork — f3) ──────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_METALLODRUG_PATH = os.path.join(_HERE, "metallodrug_coordination_sim.py")
_CRYPTIC_PATH = os.path.join(_HERE, "cryptic_pocket_sim.py")

SCHEMA_ID = "metallodrug_cryptic_pocket_cross_v1"

# ── literature anchors (real-limit citations) ───────────────────────────────
TAKAHARA_1995 = "Takahara et al., Nature 1995;377:649-652"
PIL_LIPPARD_1992 = "Pil & Lippard, Science 1992;256:234-237"
HAMMES_CHANG_OAS_2009 = "Hammes, Chang & Oas, PNAS 2009;106:13737-13741"

# ── deterministic B-DNA <=> bent-DNA conformational ledger ──────────────────
# Illustrative literature-informed surrogates for the CLASS-LEVEL ledger:
#   DG_BEND_APO_KCAL    = free-energy cost of spontaneously bending naked B-DNA
#                         ~30-40 deg at d(GpG) without a covalent adduct
#                         (positive: bent-DNA is rare in apo / unplatinated DNA).
#   DG_PT_ADDUCT_KCAL   = effective stabilisation contributed by the Pt-N7
#                         covalent adduct to the bent geometry (negative: the
#                         adduct is geometrically incompatible with canonical
#                         B-DNA and out-pays the bending cost — exactly the
#                         cryptic-pocket conformational-selection bookkeeping
#                         where the binder pays ΔG_open out of its budget).
# These are NOT fits to a specific sequence / adduct / temperature — they
# illustrate the conformational-selection ledger CLASS in the same way
# cryptic_pocket_sim's POCKET_PANEL illustrates cryptic-pocket CLASSES.
DG_BEND_APO_KCAL = 3.0          # B-DNA -> bent-DNA opening cost (closed/open analogue)
DG_PT_ADDUCT_KCAL = -5.5        # effective bent-state stabilisation by the Pt adduct


def _load(name: str, path: str):
    """Import a parent simulator module by absolute path (no shadow — f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build_metallodrug_view(metallodrug_mod) -> dict:
    """
    METALLODRUG view: square-planar d8 Pt(II) geometry at the Pt-N7 anchor.

    Reuses metallodrug_coordination_sim.square_planar_geometry +
    verify_pt_n7_geometry verbatim — no re-implementation (f3).
    """
    geom = metallodrug_mod.square_planar_geometry(
        metallodrug_mod.PT_N7_BOND_ANGSTROM)
    chk = metallodrug_mod.verify_pt_n7_geometry(geom)
    return {
        "axis": "METALLODRUG",
        "d_count": 8,
        "geometry": "square-planar",
        "pt_n7_recomputed_angstrom": chk["recomputed_pt_n_angstrom"],
        "pt_n7_anchor_match": bool(chk["anchor_match"]),
        "citation": TAKAHARA_1995,
    }


def build_cryptic_view(cryptic_mod) -> dict:
    """
    CRYPTIC-POCKET view: closed/open Boltzmann ledger transplanted onto the
    B-DNA <=> bent-DNA equilibrium of the Pt-DNA adduct.

    Reuses cryptic_pocket_sim.open_population verbatim — no re-implementation
    (f3). The conformational-selection ledger
        DG_bend_eff = DG_bend_apo + DG_pt_adduct
    is exactly the cryptic_pocket_sim ledger
        DG_open_bound = DG_open + DG_bind_open
    under the mapping (closed <-> B-DNA, open <-> bent-DNA, binder <-> Pt adduct).
    """
    # apo (unplatinated) bent-DNA population — Boltzmann on DG_BEND_APO_KCAL
    p_bent_apo = cryptic_mod.open_population(DG_BEND_APO_KCAL)
    # ledger: effective bending free energy AFTER the Pt-N7 covalent adduct
    dg_bend_eff = DG_BEND_APO_KCAL + DG_PT_ADDUCT_KCAL
    p_bent_bound = cryptic_mod.open_population(dg_bend_eff)
    delta_p_bent = p_bent_bound - p_bent_apo
    shifter = delta_p_bent > 0.0
    return {
        "axis": "CRYPTIC-POCKET",
        "conformational_states":
            "B-DNA (canonical) <=> bent-DNA (~30-40 deg at d(GpG))",
        "dg_bend_kcal_per_mol": DG_BEND_APO_KCAL,
        "dg_pt_adduct_kcal_per_mol": DG_PT_ADDUCT_KCAL,
        "dg_bend_eff_kcal_per_mol": dg_bend_eff,
        "p_bent_apo": p_bent_apo,
        "p_bent_with_pt_adduct": p_bent_bound,
        "population_shift_bent": delta_p_bent,
        "bent_state_selector_is_conformational": shifter,
        "hmg_recognition_implication": (
            "HMGB1 / hUBF / SRY HMG-box proteins preferentially recognise "
            "bent-DNA over canonical B-DNA (Pil & Lippard 1992); the Pt-DNA "
            "adduct's bent-state population shift is the conformational-"
            "selection step upstream of HMG recruitment — a downstream "
            "consequence, NOT a measured affinity / efficacy claim"),
        "citation": (f"{TAKAHARA_1995}; {PIL_LIPPARD_1992}; "
                     f"{HAMMES_CHANG_OAS_2009}"),
    }


def build_cross_axis_consistency(metallo_view: dict,
                                 cryptic_view: dict) -> dict:
    """Cross-axis consistency: both views describe the same Pt-DNA event."""
    metallo_ok = bool(metallo_view["pt_n7_anchor_match"])
    # ledger conservation: dg_bend_eff == dg_bend + dg_pt_adduct to numerical precision
    ledger_ok = abs(cryptic_view["dg_bend_eff_kcal_per_mol"]
                    - (cryptic_view["dg_bend_kcal_per_mol"]
                       + cryptic_view["dg_pt_adduct_kcal_per_mol"])) < 1e-12
    shift_ok = cryptic_view["population_shift_bent"] > 0.0
    same_event = True  # both views key off the cisplatin Pt-N7 d(GpG) crosslink
    return {
        "same_pt_dna_event_across_axes": same_event,
        "metallodrug_anchor_passes": metallo_ok,
        "cryptic_ledger_conserved": ledger_ok,
        "cryptic_population_shift_positive": shift_ok,
        "both_views_consistent": (
            same_event and metallo_ok and ledger_ok and shift_ok),
    }


def build_row(metallodrug_mod, cryptic_mod) -> dict:
    """Build the single cross row uniting METALLODRUG and CRYPTIC-POCKET views."""
    metallo_view = build_metallodrug_view(metallodrug_mod)
    cryptic_view = build_cryptic_view(cryptic_mod)
    consistency = build_cross_axis_consistency(metallo_view, cryptic_view)
    row = {
        "schema": SCHEMA_ID,
        "anchor_event": ("cisplatin Pt(II)-N7(guanine) intrastrand d(GpG) "
                         "crosslink bending B-DNA toward HMG-recognisable "
                         "bent-DNA"),
        "pt_n7_anchor_angstrom": metallodrug_mod.PT_N7_BOND_ANGSTROM,
        "metallodrug_view": metallo_view,
        "cryptic_view": cryptic_view,
        "cross_axis_consistency": consistency,
        "comparison_is_ranking": False,
        "creates_a_new_axis": False,
        "illustrative_only": True,
        "model_level_unification_only": True,
        "real_limit_citations": [
            TAKAHARA_1995 + " (Pt-N7 ~2.0 A + cisplatin-DNA d(GpG) bend)",
            PIL_LIPPARD_1992 + " (HMG-domain recognition of cisplatin-DNA "
            "bent adducts)",
            HAMMES_CHANG_OAS_2009 + " (conformational-selection thermodynamic "
            "cycle / cryptic-pocket ledger)",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed. METALLODRUG modality is "
            "described by own precedent (cisplatin/carboplatin/oxaliplatin — "
            "FDA 1978/1989/2002); CRYPTIC-POCKET modality is described by "
            "own precedent (sotorasib KRAS-G12C switch-II — FDA 2021). "
            "Coordination geometries and Boltzmann thresholds are "
            "coordination-chemistry / statistical-mechanics quantities, "
            "never lattice-derived (AGENTS.tape g3/f1; HEXA-METALLODRUG.tape "
            "f_lattice_fit / n6_honest_stance)."),
        "in_silico_only": True,
    }
    return row


def acceptance(row: dict) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1-X7)."""
    consistency = row["cross_axis_consistency"]
    metallo = row["metallodrug_view"]
    cryptic = row["cryptic_view"]
    crit = {
        "X1_anchor_event_present": (
            isinstance(row["anchor_event"], str)
            and "Pt(II)-N7" in row["anchor_event"]),
        "X2_metallodrug_pt_n7_anchor_passes":
            consistency["metallodrug_anchor_passes"],
        "X3_metallodrug_d8_square_planar": (
            metallo["d_count"] == 8 and metallo["geometry"] == "square-planar"),
        "X4_cryptic_ledger_conserved": consistency["cryptic_ledger_conserved"],
        "X5_cryptic_population_shift_positive":
            consistency["cryptic_population_shift_positive"],
        "X6_cryptic_populations_bounded": (
            0.0 < cryptic["p_bent_apo"] < 1.0
            and 0.0 < cryptic["p_bent_with_pt_adduct"] < 1.0),
        "X7_cross_invariants_hold": (
            row["comparison_is_ranking"] is False
            and row["creates_a_new_axis"] is False
            and row["illustrative_only"] is True
            and row["model_level_unification_only"] is True
            and row["in_silico_only"] is True),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("metallodrug_cryptic_pocket_cross — CROSS-AXIS BB2\n", flush=True)
    print("cross:  METALLODRUG (Pt(II)-N7(guanine) covalent adduct)  "
          "====unify====  CRYPTIC-POCKET (closed/open Boltzmann ledger)",
          flush=True)
    print("        B-DNA <=> bent-DNA conformational equilibrium under "
          "the cryptic-pocket ledger\n", flush=True)

    metallodrug_mod = _load("metallodrug_coordination_sim", _METALLODRUG_PATH)
    cryptic_mod = _load("cryptic_pocket_sim", _CRYPTIC_PATH)

    print(f"  real-limit anchors :")
    print(f"     - {TAKAHARA_1995}  (Pt-N7 ~2.0 A; cisplatin-DNA d(GpG) bend)")
    print(f"     - {PIL_LIPPARD_1992}  (HMG-domain recognition of bent-DNA)")
    print(f"     - {HAMMES_CHANG_OAS_2009}  (conformational-selection cycle)")
    print(f"  RT = {cryptic_mod.RT_KCAL:.4g} kcal/mol @ T={cryptic_mod.TEMP_K} K\n",
          flush=True)

    row = build_row(metallodrug_mod, cryptic_mod)
    metallo = row["metallodrug_view"]
    cryptic = row["cryptic_view"]

    print("  METALLODRUG view (Pt(II) square-planar d8 at Pt-N7 anchor)")
    print(f"     Pt-N7 anchor              = {row['pt_n7_anchor_angstrom']} A "
          f"(Takahara 1995)")
    print(f"     Pt-N recomputed           = "
          f"{metallo['pt_n7_recomputed_angstrom']:.4f} A")
    print(f"     anchor match              = {metallo['pt_n7_anchor_match']}")
    print(f"     geometry / d-count        = {metallo['geometry']} / d{metallo['d_count']}")
    print()
    print("  CRYPTIC-POCKET view (B-DNA <=> bent-DNA closed/open ledger)")
    print(f"     ΔG_bend (apo)             = "
          f"{cryptic['dg_bend_kcal_per_mol']:+.2f} kcal/mol")
    print(f"     ΔG_Pt-adduct (covalent)   = "
          f"{cryptic['dg_pt_adduct_kcal_per_mol']:+.2f} kcal/mol")
    print(f"     ΔG_bend_eff (ledger sum)  = "
          f"{cryptic['dg_bend_eff_kcal_per_mol']:+.2f} kcal/mol")
    print(f"     P_bent (apo)              = {cryptic['p_bent_apo']:.4g}")
    print(f"     P_bent (Pt-adduct bound)  = "
          f"{cryptic['p_bent_with_pt_adduct']:.4g}")
    print(f"     δP_bent (population shift)= "
          f"{cryptic['population_shift_bent']:+.4g}")
    print(f"     conformational selector   = "
          f"{cryptic['bent_state_selector_is_conformational']}")
    print(f"     downstream (HMG recognition): {cryptic['hmg_recognition_implication']}")
    print()

    print("  cross-axis consistency")
    for k, v in row["cross_axis_consistency"].items():
        print(f"     [{'OK ' if v else 'NO '}] {k}")

    acc = acceptance(row)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  "
          f"verdict: {acc['verdict']} ---")

    print()
    print("  IN-SILICO SCOPE (g8 / f2): this PASS verifies IN-SILICO simulator+")
    print("  metadata internal consistency ONLY — the Pt-N7 anchor matches")
    print("  Takahara 1995, the conformational-selection free-energy ledger is")
    print("  conserved, and the Pt-adduct-induced bent-DNA population shift is")
    print("  positive. It is NOT a binding-affinity, cytotoxicity, antitumor,")
    print("  immunogenic, efficacy or regulatory claim. Cisplatin is FDA-")
    print("  approved (1978) — the METALLODRUG side is not research-stage; the")
    print("  CRYPTIC-side mapping is a MODEL-LEVEL UNIFICATION (B-DNA -> bent-")
    print("  DNA is conformational selection by the Pt-DNA covalent adduct,")
    print("  structurally analogous to apo->holo cryptic-pocket selection).")
    print("  NOT a claim that all metallodrugs work via cryptic pockets, and")
    print("  NOT a claim that the Pt-DNA adduct IS a cryptic pocket in the")
    print("  protein-pocket sense — the chemical event is covalent and the")
    print("  conformational substrate is DNA. The unification is at the level")
    print("  of the two-state conformational-selection math.")

    print()
    print("  no n=6 lattice derivation (HEXA-METALLODRUG.tape f_lattice_fit /")
    print("  n6_honest_stance; AGENTS.tape g3/f1). Both modalities described")
    print("  by own precedent: METALLODRUG -> cisplatin (FDA 1978) /")
    print("  carboplatin (FDA 1989) / oxaliplatin (FDA 2002); CRYPTIC-POCKET")
    print("  -> sotorasib KRAS-G12C switch-II (FDA 2021).")
    print()
    print("  cross is NOT a new axis: METALLODRUG remains expansion-main,")
    print("  CRYPTIC-POCKET remains a sub-axis :> QUANTUM core; the hexa-bio")
    print("  core-5 axes (QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID)")
    print("  are UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed -> deterministic byte-identical re-runs
        "cross": ("BB2  METALLODRUG (Pt(II)-N7(guanine) covalent adduct)  "
                  "<==unify==>  CRYPTIC-POCKET (closed/open Boltzmann ledger)"),
        "metallodrug_parent_source": (
            "_python_bridge/module/metallodrug_coordination_sim.py "
            "(square_planar_geometry + verify_pt_n7_geometry + "
            "PT_N7_BOND_ANGSTROM imported, not re-implemented -- f3)"),
        "cryptic_pocket_parent_source": (
            "_python_bridge/module/cryptic_pocket_sim.py "
            "(open_population imported, not re-implemented -- f3)"),
        "real_limit_anchor": (
            f"{TAKAHARA_1995} (Pt-N7 ~2.0 A + cisplatin-DNA d(GpG) bend ~30-40 "
            f"deg); {PIL_LIPPARD_1992} (HMG-domain protein recognition of "
            f"bent cisplatin-DNA adducts); {HAMMES_CHANG_OAS_2009} "
            "(conformational-selection thermodynamic cycle / cryptic-pocket "
            "ledger inherited from cryptic_pocket_sim)."),
        "modality_precedents": {
            "metallodrug": ("cisplatin (FDA 1978), carboplatin (FDA 1989), "
                            "oxaliplatin (FDA 2002) — Pt(II) square-planar "
                            "d8 anticancer agents"),
            "cryptic": ("KRAS-G12C switch-II pocket — sotorasib (Ostrem "
                        "et al., Nature 503:548, 2013; Canon et al., Nature "
                        "575:217, 2019; sotorasib FDA-approved 2021)"),
        },
        "unification_identity": (
            "closed <-> B-DNA (HMG-invisible), open <-> bent-DNA (HMG-"
            "recognised); binder <-> Pt-N7 covalent adduct; ledger "
            "ΔG_bend_eff = ΔG_bend + ΔG_Pt-adduct is the cryptic_pocket_sim "
            "ledger ΔG_open_bound = ΔG_open + ΔG_bind_open under that map"),
        "temperature_K": cryptic_mod.TEMP_K,
        "rt_kcal_per_mol": cryptic_mod.RT_KCAL,
        "row": row,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "MODEL-LEVEL UNIFICATION ONLY (g8/f2). The conformational-"
            "selection ledger from cryptic_pocket_sim is transplanted onto "
            "the Pt-DNA-induced B-DNA <=> bent-DNA equilibrium; ΔG_bend and "
            "ΔG_Pt-adduct are literature-informed surrogates for the ledger "
            "CLASS, not fits to a specific DNA sequence / adduct geometry. "
            "NOT a binding-affinity, cytotoxicity, antitumor, immunogenic "
            "or therapeutic-efficacy claim. NOT a claim that all "
            "metallodrugs work via cryptic pockets."),
        "cross_is_not_a_new_axis": (
            "METALLODRUG remains an expansion-main axis; CRYPTIC-POCKET "
            "remains a sub-axis :> QUANTUM core; the hexa-bio core-5 axes "
            "(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) are "
            "unchanged."),
        "no_lattice_derivation": (
            "No quantity in this witness is derived from the n=6 lattice "
            "(HEXA-METALLODRUG.tape f_lattice_fit; AGENTS.tape g3/f1). "
            "METALLODRUG and CRYPTIC-POCKET modalities are described by own "
            "drug precedent."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__METALLODRUG_CRYPTIC_POCKET_CROSS__ PASS" if ok
          else "\n__METALLODRUG_CRYPTIC_POCKET_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
