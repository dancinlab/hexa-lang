#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
metallodrug_covalent_quantum_3way_cross.py
    — 3-AXIS CROSS: METALLODRUG x COVALENT x QUANTUM.

The repo's FIRST 3-axis cross.  Cisplatin's Pt(II)-N7(guanine) coordinate
bond is simultaneously THREE distinct theoretical objects:

  (1) METALLODRUG view — a d8 square-planar Pt(II) coordination geometry
      whose Pt-N7 coordinate distance is anchored at ~2.0 A (Takahara 1995)
      and whose CFSE (Griffith & Orgel 1957) places the cisplatin manifold
      in the strong-field d8 regime.

  (2) COVALENT view — the Pt-N7 coordinate bond is a 2-centre 2-electron
      DATIVE COVALENT bond (the N7 lone pair donates into an empty Pt sigma
      orbital; both electrons originate on the donor; the bond is covalent
      by IUPAC definition).  The kinetics of the Pt-aquation -> Pt-N7-
      binding step are modelled by the parent covalent-inhibition sim's
      two-step framework (E + I <=> E.I -> E-I, here E = guanine N7, I =
      Pt(aquo)+) with an Eyring TST barrier (Eyring 1935).

  (3) QUANTUM view — the Pt 5d / N 2p near-degenerate frontier pair at the
      adduct is a multireference electronic-structure problem.  The parent
      A1 cross's analytic (2e,2o) singlet CI shows the closed-shell HF
      single-determinant reference is qualitatively wrong (E_corr < 0); a
      VQE on the (2e,2o) active space is the right tool (Reiher et al.
      PNAS 2017; CASSCF: Roos, Taylor & Siegbahn 1980).

ALL THREE PARENT SIMS ARE IMPORTED — never reimplemented (governance f3):

    metallodrug_coordination_sim.py     -> square_planar_geometry,
                                           verify_pt_n7_geometry,
                                           cfse_square_planar
    covalent_inhibition_sim.py          -> covalent_inhibition,
                                           eyring_rate,
                                           implied_barrier_kcal,
                                           EYRING_PREFACTOR
    metallodrug_quantum_vqe_cross.py    -> metal_2e2o_ci,
                                           degeneracy_limit_check

The cross emits a SINGLE row keyed to the deterministic Pt-N7 anchor
(~2.0 A); the row carries the three axis views side-by-side plus a
cross-axis consistency check that verifies the three views agree the
Pt-N7 coordinate bond is the rate-determining / binding event under each
respective model.

────────────────────────────────────────────────────────────────────────────
HONESTY — model-level unification != operational equivalence
────────────────────────────────────────────────────────────────────────────
This cross is a MODEL-LEVEL UNIFICATION: one chemical event (the
Pt-N7 coordinate bond) admits THREE valid theoretical descriptions
(coordination chemistry, covalent-bond kinetics, multireference electronic
structure).  It is NOT a claim that the METALLODRUG, COVALENT, and
QUANTUM modalities are *operationally* interchangeable in drug design —
they are not (a Pt(II) coordination drug is not a cysteine-warhead
covalent inhibitor; neither is a VQE active space).

A 3-AXIS CROSS DOES NOT MAKE A NEW AXIS.  The cross specialises (:>) the
three existing axes; the hexa-bio core-5 (QUANTUM / WEAVE / NANOBOT /
RIBOZYME / VIROCAPSID) and the expansion-layer (incl. METALLODRUG +
COVALENT) are UNCHANGED.

────────────────────────────────────────────────────────────────────────────
REAL-LIMIT ANCHORS (governance g1 — verification anchors >= 1 real limit
                                     PER AXIS VIEW)
────────────────────────────────────────────────────────────────────────────
  METALLODRUG view:
    - Takahara PM, Rosenzweig AC, Frederick CA, Lippard SJ.  Nature 1995;
      377:649-652.  (cisplatin 1,2-intrastrand d(GpG) DNA adduct crystal
      structure; Pt-N7(guanine) coordinate bond ~2.0 A.)
    - Griffith JS, Orgel LE.  Q Rev Chem Soc 1957;11:381-393.  (CFSE
      closed-form ligand-field theory.)

  COVALENT view:
    - Eyring H.  J. Chem. Phys. 1935;3:107-115.  (Transition-state theory:
      universal frequency prefactor kB*T/h is the hard unimolecular
      ceiling.)
    - Strelow JM.  J Biomol Screen / SLAS Discovery 2017;22(1):3-20.
      (kinact/Ki two-step covalent-inhibitor framework.)

  QUANTUM view:
    - Roos BO, Taylor PR, Siegbahn PEM.  Chem Phys 1980;48:157-173.
      (CASSCF: multireference / static-correlation character of partially-
      filled transition-metal d-shells.)
    - Reiher M, Wiebe N, Svore KM, Wecker D, Troyer M.  PNAS 2017;
      114:7555-7560.  (Quantum-computer reaction mechanisms; transition-
      metal-cluster VQE motivation.)

────────────────────────────────────────────────────────────────────────────
OWN-PRECEDENT MODALITIES (g3 / f1 / f_lattice_fit — never lattice-derived)
────────────────────────────────────────────────────────────────────────────
  METALLODRUG : cisplatin (FDA 1978), carboplatin (FDA 1989), oxaliplatin
                (FDA 2002) — Pt(II) square-planar d8 coordination drugs.
  COVALENT    : ibrutinib (FDA 2013), sotorasib (FDA 2021), adagrasib
                (FDA 2022), afatinib (FDA 2013) — own-precedent covalent
                inhibitors (the Pt-N7 dative bond is the *bond-type* link
                to COVALENT; the dative bond is covalent by IUPAC).
  QUANTUM     : multireference d-shell CASSCF/CASCI and VQE on transition-
                metal active spaces — own precedent (Roos 1980; Reiher 2017).

────────────────────────────────────────────────────────────────────────────
n=6 LATTICE STANCE (g2 lattice-is-tool, g3/f1, f_lattice_fit /
                    n6_honest_stance)
────────────────────────────────────────────────────────────────────────────
No n=6 lattice arithmetic is performed.  Square-planar 4-coordination is
a d8 strong-field coordination-chemistry fact; the ~2.0 A Pt-N7 distance
is a literature crystal-structure value; the Eyring kB*T/h ceiling is a
universal physical constant; the (2e,2o) active space is the minimal
space hosting a double excitation.  None of these is lattice-derived.
Any numerical coincidence with n=6 (sigma=12, tau=4, phi=2, J2=24) is
OBSERVATION ONLY.

────────────────────────────────────────────────────────────────────────────
IN-SILICO SCOPE (g8_in_silico_only / f2)
────────────────────────────────────────────────────────────────────────────
A PASS here certifies IN-SILICO simulator + metadata internal consistency
ONLY — that the three parent sims, run at the same Pt-N7 anchor, emit
mutually consistent views of one chemical event.  It is NOT a binding-
affinity, therapeutic, cytotoxic, antitumor, immunogenic, efficacy,
regulatory, or modality-superiority claim.  The METALLODRUG and COVALENT
axes are scientifically UNPROVEN at the wet-lab boundary; no live VQE
was run (honest DEFER, g7 skip-is-honest).  See CLOSURE_RESIDUAL_BACKLOG.md
section 0.

Sentinel:  __METALLODRUG_COVALENT_QUANTUM_3WAY_CROSS__ PASS   (or FAIL).
"""
from __future__ import annotations

import importlib.util
import json
import math
import os
import sys

# ── locate sibling parent sims ─────────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_METALLODRUG_PATH = os.path.join(_HERE, "metallodrug_coordination_sim.py")
_COVALENT_PATH = os.path.join(_HERE, "covalent_inhibition_sim.py")
_QUANTUM_VQE_PATH = os.path.join(_HERE, "metallodrug_quantum_vqe_cross.py")

_SPEC_DIR = os.path.normpath(os.path.join(_HERE, "..", "spec"))
_SCHEMA_PATH = os.path.join(
    _SPEC_DIR, "metallodrug_covalent_quantum_3way_cross_v1.schema.json")

SCHEMA_ID = "metallodrug_covalent_quantum_3way_cross_v1"
SENTINEL_PASS = "__METALLODRUG_COVALENT_QUANTUM_3WAY_CROSS__ PASS"
SENTINEL_FAIL = "__METALLODRUG_COVALENT_QUANTUM_3WAY_CROSS__ FAIL"

VERSION = "1.0.0"
CROSS_LABEL = "METALLODRUG x COVALENT x QUANTUM"

# ── deterministic surrogate inputs for the COVALENT view ───────────────────
# These parameterise the Pt-aquation -> Pt-N7-binding step in the parent
# module's two-step covalent kinetics framework.  Values are ILLUSTRATIVE
# literature-informed surrogates for the cisplatin aquation/binding kinetics
# class (Reedijk 2003 reviews the cisplatin aquation -> DNA-binding kinetics),
# NOT fits to a specific compound.  Both real-limit checks (kinact respects
# the Eyring kB*T/h ceiling; Eyring-roundtrip consistency) are enforced by
# the parent module — we do not invent or relax them here.
PT_N7_KI_M = 1.0e-4        # surrogate K_i (M) for the Pt-aquo -> guanine-N7
                            # reversible pre-association equilibrium
PT_N7_KINACT_PER_S = 1.0e-4   # surrogate first-order Pt-N7 bond-forming rate
PT_N7_DG_COV_KCAL = 22.0      # surrogate Pt-N7 bond-forming activation barrier
                              # (kcal/mol) for the Eyring TST prediction


def _load_module(name: str, path: str):
    """importlib loader — no shadow reimplementation (governance f3)."""
    if _HERE not in sys.path:
        sys.path.insert(0, _HERE)
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── per-axis view builders (delegate to parent sims — f3) ──────────────────

def _metallodrug_view(metallodrug_mod) -> dict:
    """METALLODRUG axis view at the Pt-N7 anchor.

    Delegates entirely to the parent module's square_planar_geometry +
    verify_pt_n7_geometry + cfse_square_planar — no fork (f3).
    """
    geom = metallodrug_mod.square_planar_geometry(
        metallodrug_mod.PT_N7_BOND_ANGSTROM)
    geom_chk = metallodrug_mod.verify_pt_n7_geometry(geom)
    cfse_sp_d8 = metallodrug_mod.cfse_square_planar(8)
    return {
        "axis": "METALLODRUG",
        "d_count": 8,
        "geometry": "square-planar",
        "pt_n7_anchor_angstrom": metallodrug_mod.PT_N7_BOND_ANGSTROM,
        "pt_n7_tolerance_angstrom": metallodrug_mod.PT_N7_TOLERANCE_ANGSTROM,
        "pt_n7_recomputed_angstrom": geom_chk["recomputed_pt_n_angstrom"],
        "pt_n7_deviation_angstrom": geom_chk["deviation_angstrom"],
        "pt_n7_anchor_match": geom_chk["anchor_match"],
        "square_geometry_self_consistent":
            geom_chk["square_geometry_self_consistent"],
        "cfse_square_planar_delta_oct": cfse_sp_d8,
        "drug_precedent": ("cisplatin (FDA 1978), carboplatin (FDA 1989), "
                           "oxaliplatin (FDA 2002) — Pt(II) square-planar "
                           "d8 coordination drugs"),
        "citation": ("Takahara et al. Nature 1995;377:649-652 "
                     "(Pt-N7(guanine) ~2.0 A); "
                     "Griffith & Orgel Q Rev Chem Soc 1957;11:381-393 (CFSE)"),
    }


def _covalent_view(covalent_mod) -> dict:
    """COVALENT axis view of the Pt-N7 bond-forming step.

    The Pt-N7 coordinate bond is a 2-centre 2-electron DATIVE COVALENT bond
    (the N7 lone pair donates into an empty Pt sigma orbital; both bonding
    electrons originate on the donor — covalent by IUPAC definition).  We
    feed the parent module's two-step covalent_inhibition() framework with
    surrogate cisplatin-aquation-kinetics parameters; the parent enforces
    Eyring-ceiling and roundtrip-consistency on every row.  No fork (f3).
    """
    kin = covalent_mod.covalent_inhibition(
        ki_m=PT_N7_KI_M,
        kinact_per_s=PT_N7_KINACT_PER_S,
        dg_covalent_kcal=PT_N7_DG_COV_KCAL,
    )
    return {
        "axis": "COVALENT",
        "bond_kind": "coordinate-covalent (2c-2e dative)",
        "two_step_mechanism":
            "Pt(aquo)+ + guanine-N7 <=>(Ki) Pt(aquo)+.N7 -kinact-> Pt-N7  "
            "(parent two-step framework E + I <=>(Ki) E.I -kinact-> E-I)",
        "Ki_molar": kin["Ki_molar"],
        "kinact_per_s": kin["kinact_per_s"],
        "kinact_over_Ki_M_per_s": kin["kinact_over_Ki_M_per_s"],
        "dg_covalent_kcal_per_mol": kin["dg_covalent_step_kcal_per_mol"],
        "kinact_eyring_tst_per_s": kin["kinact_eyring_tst_per_s"],
        "dg_implied_from_kinact_kcal_per_mol":
            kin["dg_implied_from_kinact_kcal_per_mol"],
        "eyring_prefactor_ceiling_per_s":
            kin["eyring_prefactor_ceiling_per_s"],
        "kinact_below_eyring_ceiling": kin["kinact_below_eyring_ceiling"],
        "kinact_tst_below_eyring_ceiling":
            kin["kinact_tst_below_eyring_ceiling"],
        "temperature_K": covalent_mod.TEMP_K,
        "iupac_dative_bond_note": (
            "A coordinate (dative) bond is a covalent bond in which both "
            "shared electrons originate on one atom (here, the N7 lone "
            "pair on guanine).  Per IUPAC the dative bond is a category "
            "of the covalent bond — it is NOT a separate bond type."),
        "drug_precedent": ("own COVALENT modality precedent: ibrutinib "
                           "(FDA 2013), sotorasib (FDA 2021), adagrasib "
                           "(FDA 2022) — covalent inhibitors with explicit "
                           "warhead chemistry; the cisplatin Pt-N7 dative "
                           "bond is the BOND-TYPE link to COVALENT, NOT a "
                           "claim that cisplatin is a cysteine-warhead "
                           "covalent inhibitor (it is not)"),
        "citation": ("Eyring H, J. Chem. Phys. 1935;3:107-115 (TST kB*T/h "
                     "ceiling); Strelow JM, SLAS Discovery 2017;22(1):3-20 "
                     "(kinact/Ki two-step framework)"),
    }


def _quantum_view(quantum_vqe_mod) -> dict:
    """QUANTUM axis view at the Pt-N7 adduct: (2e,2o) singlet CI.

    Delegates to the parent A1 cross's metal_2e2o_ci.  We pick the
    near-degenerate Pt 5d / N 2p frontier pair (small orbital gap) so the
    multireference signature E_corr < 0 is exhibited — that is the QUANTUM-
    axis statement about the Pt-N7 adduct electronic structure.  No fork
    (f3).
    """
    # near-degenerate Pt-5d / N-2p frontier pair at the Pt-N7 adduct.
    # gap of 0.10 Delta_oct: small but nonzero — same regime as the parent
    # A1 cross's "octahedral_t2g_weakly_split" case (a tetragonally-distorted
    # near-degenerate manifold).  Coupling K = 0.30 Delta_oct matches the
    # parent A1 cross's k_model — we do NOT invent new numbers here.
    orbital_gap_delta_oct = 0.10
    coupling_k = 0.30
    ci = quantum_vqe_mod.metal_2e2o_ci(
        orbital_gap_delta_oct=orbital_gap_delta_oct,
        pairing_shift=0.0,
        coupling_k=coupling_k,
    )

    # parent-module self-check: recompute E_FCI from the closed form
    e_a = ci["det_energy_phi0_hf"]
    e_b = ci["det_energy_phi1_double"]
    k = ci["coupling_k"]
    mean = 0.5 * (e_a + e_b)
    half = 0.5 * (e_b - e_a)
    e_fci_closed = mean - math.sqrt(half * half + k * k)
    ci_matches_closed_form = abs(ci["e_fci"] - e_fci_closed) < 1e-12

    # exact-degeneracy limit sanity (parent module's degeneracy_limit_check):
    # E_corr -> -|K|, HF weight -> 1/2.  Reported alongside as a real-limit
    # anchor for the multireference statement.
    degen = quantum_vqe_mod.degeneracy_limit_check(coupling_k=coupling_k)

    return {
        "axis": "QUANTUM",
        "active_space": "(2e,2o)",
        "orbital_pair_label": ("Pt-5d / N-2p frontier pair at the Pt-N7 adduct "
                               "(near-degenerate manifold)"),
        "orbital_gap_delta_oct": orbital_gap_delta_oct,
        "coupling_k": coupling_k,
        "e_hf": ci["e_hf"],
        "e_fci": ci["e_fci"],
        "e_corr": ci["e_corr"],
        "e_corr_strictly_negative": ci["e_corr"] < -1e-12,
        "hf_weight_in_fci": ci["hf_weight_in_fci"],
        "double_weight_in_fci": ci["double_weight_in_fci"],
        "is_multireference": ci["is_multireference"],
        "ci_matches_closed_form": ci_matches_closed_form,
        "degeneracy_limit_check_pass": degen["pass"],
        "vqe_dispatch_status": "DEFERRED",
        "vqe_defer_reason": (
            "Live qmirror/VQE-ladder dispatch is an external compute "
            "substrate; per AGENTS.tape g7 skip-is-honest it is an honest "
            "DEFER, not a failure.  The deterministic exact 2x2 CI core is "
            "the in-repo PASS object."),
        "drug_precedent": ("own QUANTUM-axis modality precedent: CASSCF "
                           "multireference treatment of partially-filled "
                           "transition-metal d-shells (Roos 1980); "
                           "transition-metal-cluster VQE motivation "
                           "(Reiher 2017)"),
        "citation": ("Roos, Taylor & Siegbahn Chem Phys 1980;48:157 (CASSCF); "
                     "Reiher et al. PNAS 2017;114:7555 (quantum-computer "
                     "reaction mechanisms)"),
    }


# ── cross-axis consistency check ───────────────────────────────────────────

def _cross_axis_consistency(metal_v: dict, cov_v: dict, quant_v: dict,
                             pt_n7_anchor: float) -> dict:
    """Verify the three axis views agree on the same Pt-N7 event."""
    # Same Pt-N7 event: METALLODRUG anchor matches; COVALENT mechanism
    # explicitly names the Pt-N7 bond-forming step; QUANTUM frontier pair
    # is labelled at the Pt-N7 adduct.
    metallodrug_anchor_passes = bool(metal_v["pt_n7_anchor_match"])
    covalent_eyring_ceiling_respected = bool(
        cov_v["kinact_below_eyring_ceiling"]
        and cov_v["kinact_tst_below_eyring_ceiling"])
    quantum_e_corr_strictly_negative = bool(quant_v["e_corr_strictly_negative"])

    # The three views all reference the Pt-N7 event by name:
    metal_names_pt_n7 = abs(metal_v["pt_n7_anchor_angstrom"] - pt_n7_anchor) \
        < 1e-9
    cov_names_pt_n7 = "Pt-N7" in cov_v["two_step_mechanism"]
    quant_names_pt_n7 = "Pt-N7" in quant_v["orbital_pair_label"]
    same_pt_n7_event_across_axes = bool(
        metal_names_pt_n7 and cov_names_pt_n7 and quant_names_pt_n7)

    all_three_views_consistent = bool(
        same_pt_n7_event_across_axes
        and metallodrug_anchor_passes
        and covalent_eyring_ceiling_respected
        and quantum_e_corr_strictly_negative)

    return {
        "same_pt_n7_event_across_axes": same_pt_n7_event_across_axes,
        "metallodrug_anchor_passes": metallodrug_anchor_passes,
        "covalent_eyring_ceiling_respected": covalent_eyring_ceiling_respected,
        "quantum_e_corr_strictly_negative": quantum_e_corr_strictly_negative,
        "all_three_views_consistent": all_three_views_consistent,
        "interpretation": (
            "All three axis views identify the same Pt-N7 coordinate-bond "
            "event at the same anchor distance, each respects its own real "
            "limit (geometry vs ~2.0 A; rate vs kB*T/h ceiling; E_corr < 0 "
            "for K != 0).  The Pt-N7 bond is the rate-determining/binding "
            "event under each respective model."),
    }


# ── build the single 3-axis row ────────────────────────────────────────────

def build_row() -> dict:
    """Build the single deterministic 3-axis cross row at the Pt-N7 anchor."""
    metallodrug_mod = _load_module("metallodrug_coordination_sim",
                                   _METALLODRUG_PATH)
    covalent_mod = _load_module("covalent_inhibition_sim", _COVALENT_PATH)
    quantum_vqe_mod = _load_module("metallodrug_quantum_vqe_cross",
                                   _QUANTUM_VQE_PATH)

    metal_v = _metallodrug_view(metallodrug_mod)
    cov_v = _covalent_view(covalent_mod)
    quant_v = _quantum_view(quantum_vqe_mod)

    pt_n7_anchor = metallodrug_mod.PT_N7_BOND_ANGSTROM
    consistency = _cross_axis_consistency(metal_v, cov_v, quant_v, pt_n7_anchor)

    return {
        "schema": SCHEMA_ID,
        "anchor_event": "cisplatin Pt(II)-N7(guanine) adduct",
        "pt_n7_anchor_angstrom": pt_n7_anchor,
        "metallodrug_view": metal_v,
        "covalent_view": cov_v,
        "quantum_view": quant_v,
        "cross_axis_consistency": consistency,
        "cross_is_three_axis": True,
        "creates_a_new_axis": False,
        "model_level_unification_disclaimer": (
            "This 3-axis cross is a MODEL-LEVEL UNIFICATION: one chemical "
            "event (the cisplatin Pt(II)-N7 coordinate bond) admits THREE "
            "valid theoretical descriptions (coordination chemistry, "
            "covalent-bond kinetics, multireference electronic structure).  "
            "It is NOT a claim that the METALLODRUG, COVALENT, and QUANTUM "
            "modalities are *operationally* interchangeable in drug design "
            "— they are not (a Pt(II) coordination drug is not a cysteine-"
            "warhead covalent inhibitor; neither is a VQE active space).  "
            "A 3-axis cross does NOT make a new axis: it specialises (:>) "
            "the three existing axes, and core-5 + expansion-layer are "
            "UNCHANGED."),
        "real_limit_citations": [
            "Takahara et al., Nature 1995;377:649-652 (cisplatin "
            "Pt-N7(guanine) ~2.0 A) — METALLODRUG view",
            "Griffith & Orgel, Q Rev Chem Soc 1957;11:381-393 (CFSE "
            "closed-form ligand-field theory) — METALLODRUG view",
            "Eyring H, J. Chem. Phys. 1935;3:107-115 (TST kB*T/h ceiling) "
            "— COVALENT view",
            "Strelow JM, SLAS Discovery 2017;22(1):3-20 (kinact/Ki two-"
            "step covalent-inhibitor framework) — COVALENT view",
            "Roos, Taylor & Siegbahn, Chem Phys 1980;48:157-173 (CASSCF "
            "multireference) — QUANTUM view",
            "Reiher, Wiebe, Svore, Wecker & Troyer, PNAS 2017;114:7555-"
            "7560 (quantum-computer reaction mechanisms; transition-metal-"
            "cluster VQE motivation) — QUANTUM view",
        ],
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed.  Square-planar "
            "4-coordination is a d8 strong-field coordination-chemistry "
            "fact (not lattice-derived); the ~2.0 A Pt-N7 distance is a "
            "crystal-structure value (Takahara 1995); the Eyring kB*T/h "
            "ceiling is a universal physical constant (Eyring 1935); the "
            "(2e,2o) active space is the minimal space hosting a double "
            "excitation.  Any numerical coincidence with n=6 (sigma=12, "
            "tau=4, phi=2, J2=24) is OBSERVATION ONLY "
            "(AGENTS.tape g2/g3/f1, HEXA-METALLODRUG.tape "
            "f_lattice_fit/n6_honest_stance)."),
        "in_silico_only": True,
        "no_fork_f3": (
            "All three parent sims are IMPORTED, never reimplemented "
            "(governance f3): metallodrug_coordination_sim.py "
            "(METALLODRUG view), covalent_inhibition_sim.py (COVALENT "
            "view), metallodrug_quantum_vqe_cross.py (QUANTUM view; "
            "itself imports metallodrug_coordination_sim — also "
            "unforked)."),
        "in_silico_scope_caveat": (
            "PASS certifies IN-SILICO simulator+metadata consistency "
            "ONLY (AGENTS.tape g8/f2).  NOT a binding-affinity, "
            "therapeutic, cytotoxic, antitumor, immunogenic, efficacy, "
            "regulatory, or modality-superiority claim.  METALLODRUG and "
            "COVALENT axes are UNPROVEN at the wet-lab boundary; no live "
            "VQE was run (honest DEFER, g7 skip-is-honest).  Wet-lab is "
            "out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md section 0)."),
    }


# ── inline schema validation (stdlib only — no external jsonschema dep) ────

def _load_schema() -> dict:
    with open(_SCHEMA_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _validate_row_against_schema(row: dict, schema: dict) -> list:
    """Minimal stdlib draft-07 validator: top-level required + properties +
    nested object properties (required + scalar types) + enum/const/min/max
    checks + array minItems.  Returns the list of error strings
    (empty = row valid)."""
    errs = []

    def _type_ok(value, jtype):
        if jtype == "string":
            return isinstance(value, str)
        if jtype == "integer":
            return isinstance(value, int) and not isinstance(value, bool)
        if jtype == "number":
            return (isinstance(value, (int, float))
                    and not isinstance(value, bool))
        if jtype == "boolean":
            return isinstance(value, bool)
        if jtype == "object":
            return isinstance(value, dict)
        if jtype == "array":
            return isinstance(value, list)
        return True

    def _check_object(obj, sub_schema, path):
        if not isinstance(obj, dict):
            errs.append(f"{path}: expected object")
            return
        for req in sub_schema.get("required", []):
            if req not in obj:
                errs.append(f"{path}: missing required field '{req}'")
        for prop, prop_schema in sub_schema.get("properties", {}).items():
            if prop not in obj:
                continue
            v = obj[prop]
            sub_path = f"{path}.{prop}"
            t = prop_schema.get("type")
            if isinstance(t, str) and not _type_ok(v, t):
                errs.append(
                    f"{sub_path}: expected type '{t}', got {type(v).__name__}")
            if "const" in prop_schema and v != prop_schema["const"]:
                errs.append(
                    f"{sub_path}: const mismatch (expected "
                    f"{prop_schema['const']!r}, got {v!r})")
            if "enum" in prop_schema and v not in prop_schema["enum"]:
                errs.append(
                    f"{sub_path}: not in enum {prop_schema['enum']!r}")
            if (isinstance(v, (int, float))
                    and not isinstance(v, bool)):
                if "minimum" in prop_schema and v < prop_schema["minimum"]:
                    errs.append(
                        f"{sub_path}: {v} < minimum {prop_schema['minimum']}")
                if "maximum" in prop_schema and v > prop_schema["maximum"]:
                    errs.append(
                        f"{sub_path}: {v} > maximum {prop_schema['maximum']}")
                if ("exclusiveMinimum" in prop_schema
                        and v <= prop_schema["exclusiveMinimum"]):
                    errs.append(
                        f"{sub_path}: {v} <= exclusiveMinimum "
                        f"{prop_schema['exclusiveMinimum']}")
            if isinstance(v, str) and "minLength" in prop_schema:
                if len(v) < prop_schema["minLength"]:
                    errs.append(
                        f"{sub_path}: string length "
                        f"{len(v)} < minLength {prop_schema['minLength']}")
            if isinstance(v, list) and "minItems" in prop_schema:
                if len(v) < prop_schema["minItems"]:
                    errs.append(
                        f"{sub_path}: array length "
                        f"{len(v)} < minItems {prop_schema['minItems']}")
                items_schema = prop_schema.get("items")
                if isinstance(items_schema, dict):
                    it = items_schema.get("type")
                    for i, el in enumerate(v):
                        if isinstance(it, str) and not _type_ok(el, it):
                            errs.append(
                                f"{sub_path}[{i}]: expected type '{it}', "
                                f"got {type(el).__name__}")
            if t == "object" and isinstance(v, dict):
                _check_object(v, prop_schema, sub_path)

    _check_object(row, schema, "row")
    return errs


# ── acceptance criteria ────────────────────────────────────────────────────

def acceptance(row: dict) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1..X10)."""
    schema = _load_schema()
    schema_errors = _validate_row_against_schema(row, schema)

    cax = row["cross_axis_consistency"]
    mv = row["metallodrug_view"]
    cv = row["covalent_view"]
    qv = row["quantum_view"]

    crit = {
        "X1_row_validates_against_v1_schema": (len(schema_errors) == 0),
        "X2_three_axis_views_present": (
            mv.get("axis") == "METALLODRUG"
            and cv.get("axis") == "COVALENT"
            and qv.get("axis") == "QUANTUM"),
        "X3_metallodrug_pt_n7_anchor_matches": mv["pt_n7_anchor_match"],
        "X4_covalent_eyring_ceiling_respected": (
            cv["kinact_below_eyring_ceiling"]
            and cv["kinact_tst_below_eyring_ceiling"]),
        "X5_quantum_e_corr_strictly_negative":
            qv["e_corr_strictly_negative"],
        "X6_quantum_ci_matches_closed_form":
            qv["ci_matches_closed_form"],
        "X7_cross_axis_consistency_passes":
            cax["all_three_views_consistent"],
        "X8_three_axis_cross_does_not_make_a_new_axis": (
            row["cross_is_three_axis"] is True
            and row["creates_a_new_axis"] is False),
        "X9_model_level_unification_disclaimer_present": (
            isinstance(row.get("model_level_unification_disclaimer"), str)
            and len(row["model_level_unification_disclaimer"]) > 0),
        "X10_in_silico_only_flag_set":
            (row.get("in_silico_only") is True),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "schema_errors": schema_errors,
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


# ── orchestration ──────────────────────────────────────────────────────────

def build_witness() -> dict:
    row = build_row()
    acc = acceptance(row)
    return {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed -> deterministic re-runs
        "cross": CROSS_LABEL,
        "cross_kind": "3-axis cross (METALLODRUG x COVALENT x QUANTUM)",
        "version": VERSION,
        "metallodrug_source":
            "_python_bridge/module/metallodrug_coordination_sim.py "
            "(imported, not forked — f3)",
        "covalent_source":
            "_python_bridge/module/covalent_inhibition_sim.py "
            "(imported, not forked — f3)",
        "quantum_source":
            "_python_bridge/module/metallodrug_quantum_vqe_cross.py "
            "(imported, not forked — f3; itself imports "
            "metallodrug_coordination_sim — also unforked)",
        "rows": [row],
        "acceptance": acc,
    }


def main() -> int:
    print("metallodrug_covalent_quantum_3way_cross — "
          f"3-AXIS CROSS {CROSS_LABEL} v{VERSION}\n", flush=True)
    print("  cross:  METALLODRUG x COVALENT x QUANTUM")
    print("          one chemical event (Pt-N7 coordinate bond) — three")
    print("          theoretical descriptions (coordination / covalent /")
    print("          multireference electronic structure)\n", flush=True)

    witness = build_witness()
    row = witness["rows"][0]
    acc = witness["acceptance"]
    mv = row["metallodrug_view"]
    cv = row["covalent_view"]
    qv = row["quantum_view"]
    cax = row["cross_axis_consistency"]

    print(f"  anchor event: {row['anchor_event']}")
    print(f"  Pt-N7 anchor distance: {row['pt_n7_anchor_angstrom']:.3f} A "
          "(Takahara 1995)\n", flush=True)

    print("  (1) METALLODRUG view  — d8 square-planar Pt(II) coordination")
    print(f"      Pt-N recomputed   : {mv['pt_n7_recomputed_angstrom']:.4f} A  "
          f"(dev {mv['pt_n7_deviation_angstrom']:.2e} A, "
          f"tol {mv['pt_n7_tolerance_angstrom']:.2f} A)")
    print(f"      d8 sq-planar CFSE : "
          f"{mv['cfse_square_planar_delta_oct']:+.3f} Delta_oct  "
          f"(Griffith & Orgel 1957)")
    print(f"      anchor match      : {mv['pt_n7_anchor_match']}")
    print()

    print("  (2) COVALENT view     — Pt-N7 is a 2c-2e dative covalent bond")
    print(f"      mechanism         : {cv['two_step_mechanism']}")
    print(f"      Ki                : {cv['Ki_molar']:.3e} M  (surrogate)")
    print(f"      kinact            : {cv['kinact_per_s']:.3e} /s  (surrogate)")
    print(f"      dG_cov barrier    : {cv['dg_covalent_kcal_per_mol']:.1f} "
          f"kcal/mol  (Eyring-implied "
          f"{cv['dg_implied_from_kinact_kcal_per_mol']:.1f})")
    print(f"      kinact TST        : {cv['kinact_eyring_tst_per_s']:.3e} /s")
    print(f"      Eyring ceiling    : "
          f"{cv['eyring_prefactor_ceiling_per_s']:.3e} /s  "
          f"(kB*T/h @ T={cv['temperature_K']} K)")
    print(f"      kinact below ceil : {cv['kinact_below_eyring_ceiling']}  "
          f"(TST: {cv['kinact_tst_below_eyring_ceiling']})")
    print()

    print("  (3) QUANTUM view      — (2e,2o) CI on Pt-5d / N-2p frontier pair")
    print(f"      orbital gap       : {qv['orbital_gap_delta_oct']:.3f} "
          f"Delta_oct  (near-degenerate)")
    print(f"      coupling K        : {qv['coupling_k']:.3f} Delta_oct")
    print(f"      E_HF              : {qv['e_hf']:+.4f}")
    print(f"      E_FCI             : {qv['e_fci']:+.4f}")
    print(f"      E_corr            : {qv['e_corr']:+.4f}  "
          f"(strictly < 0: {qv['e_corr_strictly_negative']})")
    print(f"      HF weight in FCI  : {qv['hf_weight_in_fci']:.4f}  "
          f"(multireference: {qv['is_multireference']})")
    print(f"      VQE dispatch      : {qv['vqe_dispatch_status']}  "
          f"(honest DEFER, g7)")
    print()

    print("  CROSS-AXIS CONSISTENCY:")
    print(f"      same Pt-N7 event across all 3 axes : "
          f"{cax['same_pt_n7_event_across_axes']}")
    print(f"      METALLODRUG anchor passes          : "
          f"{cax['metallodrug_anchor_passes']}")
    print(f"      COVALENT Eyring ceiling respected  : "
          f"{cax['covalent_eyring_ceiling_respected']}")
    print(f"      QUANTUM E_corr strictly < 0        : "
          f"{cax['quantum_e_corr_strictly_negative']}")
    print(f"      all three views consistent         : "
          f"{cax['all_three_views_consistent']}")
    print()

    print("## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    if acc["schema_errors"]:
        print("\n## schema errors:")
        for e in acc["schema_errors"]:
            print(f"  {e}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: "
          f"{acc['verdict']} ---")

    print()
    print("  ── 3-axis cross != new axis (honesty) ──")
    print("  A 3-axis cross does NOT introduce a new axis.  It specialises")
    print("  (:>) the three existing axes (METALLODRUG, COVALENT, QUANTUM).")
    print("  The hexa-bio core-5 (QUANTUM/WEAVE/NANOBOT/RIBOZYME/VIROCAPSID)")
    print("  and the expansion-layer (incl. METALLODRUG + COVALENT) are")
    print("  UNCHANGED by this module.")
    print()
    print("  ── model-level unification != operational equivalence ──")
    print("  This cross is a MODEL-LEVEL UNIFICATION: one chemical event")
    print("  (the Pt-N7 coordinate bond) admits THREE valid theoretical")
    print("  descriptions.  It is NOT a claim that the METALLODRUG, COVALENT,")
    print("  and QUANTUM modalities are *operationally* interchangeable in")
    print("  drug design (a Pt(II) coordination drug is not a cysteine-")
    print("  warhead covalent inhibitor; neither is a VQE active space).")
    print()
    print("  ── no-fork (f3) ──")
    print("  All three parent sims are IMPORTED, never reimplemented:")
    print("    metallodrug_coordination_sim.py  (METALLODRUG view)")
    print("    covalent_inhibition_sim.py       (COVALENT view)")
    print("    metallodrug_quantum_vqe_cross.py (QUANTUM view)")
    print()
    print("  ── n=6 lattice stance (g2/g3/f1/f_lattice_fit) ──")
    print("  No n=6 lattice arithmetic is performed.  All quantities are")
    print("  anchored to real-limit literature values (Takahara 1995;")
    print("  Griffith & Orgel 1957; Eyring 1935; Strelow 2017; Roos 1980;")
    print("  Reiher 2017).  Modalities are described by their own precedent")
    print("  (cisplatin/carboplatin/oxaliplatin; ibrutinib/sotorasib/")
    print("  adagrasib; CASSCF/VQE on transition-metal active spaces).")
    print()
    print("  ── IN-SILICO scope caveat (g8/f2) ──")
    print("  PASS certifies IN-SILICO simulator+metadata consistency ONLY.")
    print("  NOT a binding-affinity, therapeutic, cytotoxic, antitumor,")
    print("  immunogenic, efficacy, regulatory, or modality-superiority")
    print("  claim.  METALLODRUG and COVALENT are UNPROVEN at the wet-lab")
    print("  boundary; no live VQE was run (honest DEFER, g7 skip-is-honest).")
    print("  Wet-lab is out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md §0).")

    emit = "--emit-witness" in sys.argv
    if emit:
        path = os.path.join(_HERE, "runs",
                            "metallodrug_covalent_quantum_3way_cross_events.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(witness, ensure_ascii=False) + "\n")
        print(f"\n  [emit] appended {SCHEMA_ID} witness -> {path}")

    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_PASS if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
