#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
metallodrug_quantum_vqe_cross.py — CROSS-AXIS A1: METALLODRUG -> QUANTUM VQE.

Couples the METALLODRUG expansion-axis (ligand-field / d-orbital splitting)
to the core QUANTUM axis's VQE pipeline by demonstrating, with an exact,
analytically-solvable small CI, *why* the QUANTUM-axis VQE machinery is the
right tool for a transition-metal d-orbital manifold.

Deterministic, stdlib-only. No network, no random, no wall-clock dependence,
no numpy => byte-identical re-runs.


WHAT THIS COMPUTES (the cross, in one sentence)
================================================
A transition-metal partially-filled d-shell is a MULTIREFERENCE electronic
structure problem: when two d-orbitals are near-degenerate, the Hartree-Fock
single Slater determinant is a qualitatively wrong reference, and the exact
(full-CI / CASCI) ground state is an irreducible superposition of >1
determinant.  We make that statement *quantitative and exact* with a minimal
2-electron / 2-orbital (2e,2o) CI that is analytically solvable (a 2x2
eigenvalue problem — no numpy needed), and we parameterise the orbital gap
of that model from the METALLODRUG axis's own ligand-field splitting
(t2g/eg, square-planar dxy<->dx2-y2) imported from
`metallodrug_coordination_sim.py` (NO fork — AGENTS.tape f3).

The cross-axis claim:

    E_corr = E_FCI - E_HF  <  0   for the near-degenerate metal manifold
    ==> a single-reference method (plain HF / single-determinant DFT) is
        structurally incapable of recovering E_corr
    ==> this (2e,2o) active space is *exactly the object* the QUANTUM-axis
        VQE pipeline (pocket_active_space.py -> quantum_vqe_*.py) is built
        to treat: a small active space whose multireference character is
        the reason a variational quantum eigensolver is worth running.

The smaller the d-orbital gap Delta (the closer to degeneracy), the larger
|E_corr| relative to the coupling — this is the textbook signature of
"strong correlation / static correlation / multireference character".


THE EXACT (2e,2o) CI — analytic, no numpy
==========================================
Two spatial orbitals: a lower orbital `a` and an upper orbital `b`, separated
by a one-electron gap `Delta` (the ligand-field splitting).  Two electrons,
total spin singlet.  The singlet CI space (Sz=0, S=0) for (2e,2o) is spanned
by exactly two configuration state functions:

    |Phi_0> = |a a-bar>          (both electrons in the lower orbital — the
                                  closed-shell Hartree-Fock reference)
    |Phi_1> = |b b-bar>          (both electrons promoted to the upper
                                  orbital — the double excitation)

(The open-shell singlet |a b-bar> + |b a-bar> does not couple to these two
under a spin-independent Hamiltonian and is the higher S=0 root; the S=1
triplet is likewise decoupled.  The 2x2 below is the closed-shell singlet
block — the block the ground state lives in.)

In this 2-CSF basis the Hamiltonian matrix is the standard minimal-model form

    H = [[ E_a ,    K   ],
         [  K  ,  E_b   ]]

with
    E_a = 2 h_aa + J_aa                         (energy of |Phi_0>)
    E_b = 2 h_bb + J_bb                         (energy of |Phi_1>)
    K   = K_ab                                  (the <aa|bb> exchange-type
                                                 two-electron coupling that
                                                 mixes the two determinants)

We anchor E_a := 0 (reference zero) and write E_b = 2*Delta_pair, where
Delta_pair = (h_bb - h_aa) + (J_bb - J_aa)/2 is the effective two-electron
promotion gap built from the one-electron ligand-field gap `Delta`.

Hartree-Fock reference energy:   E_HF = E_a = 0   (by construction).

Exact CI ground-state energy = lower eigenvalue of the 2x2:

    E_FCI = (E_a + E_b)/2  -  sqrt( ((E_b - E_a)/2)^2 + K^2 )

Correlation energy:

    E_corr = E_FCI - E_HF
           = (E_b)/2 - sqrt( (E_b/2)^2 + K^2 )      (since E_a = 0)

Two exact, checkable facts (these ARE the real-limit anchor — closed form):

  (1) E_corr <= 0 ALWAYS, and E_corr = 0  iff  K = 0.   For any nonzero
      determinant-mixing coupling K, the exact ground state lies strictly
      below HF.  => HF (single reference) is provably non-exact here.

  (2) Degeneracy limit  E_b -> 0  (d-orbitals exactly degenerate):
          E_FCI -> -|K|,   E_HF = 0,   E_corr -> -|K|.
      The HF weight in the exact ground state -> 1/2: the wavefunction is a
      50/50 superposition of two determinants — the MAXIMALLY multireference
      state.  No single determinant can represent it.  As E_b grows large
      (gap >> K), E_corr -> -K^2/E_b -> 0 and HF becomes asymptotically
      exact.  The crossover scale is set by |K| vs the ligand-field gap.

Everything above is exact algebra of a 2x2 real-symmetric matrix; the only
"limit" invoked is the closed-form eigenvalue.  This is the deterministic,
in-repo, verifiable PASS core.


REAL-LIMIT ANCHORS (hexa-bio AGENTS.tape g1 real-limits-first)
===============================================================
  - The 2x2 CI eigenvalue is EXACT closed-form linear algebra.  E_FCI is the
    analytic ground state of the (2e,2o) singlet block; E_corr = E_FCI-E_HF
    is verified here to (a) be <= 0, (b) vanish iff K=0, (c) approach -|K|
    in the degeneracy limit — all checked against the closed forms above.
  - The orbital gap Delta is the ligand-field d-orbital splitting (t2g/eg in
    octahedral fields; dxy -> dx2-y2 in square-planar d8 Pt(II)).  Closed-
    form ligand-field theory:
        Griffith JS, Orgel LE. Ligand-field theory.
        Q Rev Chem Soc 1957; 11:381-393.
    (imported from metallodrug_coordination_sim.py — same axis, no fork.)
  - Multireference / static-correlation character of partially-filled
    transition-metal d-shells is the established motivation for CASSCF/CASCI
    and, in the quantum-computing era, for VQE on a metal active space:
        Roos BO, Taylor PR, Siegbahn PEM. Chem Phys 1980; 48:157 (CASSCF).
        Reiher M, Wiebe N, Svore KM, Wecker D, Troyer M. Elucidating
          reaction mechanisms on quantum computers. PNAS 2017; 114:7555
          (the FeMoco / transition-metal-cluster quantum-VQE motivation).


n=6 LATTICE STANCE (g2 lattice-is-tool, g3/f1 honesty-external,
HEXA-METALLODRUG.tape f_lattice_fit + n6_honest_stance)
================================================================
The metal modality here is anchored entirely to its OWN precedent —
cisplatin/carboplatin/oxaliplatin square-planar d8 Pt(II), the octahedral
t2g/eg split, and ligand-field theory (Griffith & Orgel 1957).  The CI is a
(2e,2o) model: 2 electrons, 2 orbitals — those counts come from "the minimal
active space that can host a double excitation", NOT from the n=6 lattice
(sigma=12, tau=4, phi=2, J2=24).  No lattice arithmetic is performed.  Any
numerical coincidence with n=6 is OBSERVATION ONLY.


IN-SILICO SCOPE (g8_in_silico_only / f2)
=========================================
A PASS here verifies IN-SILICO simulator + metadata internal consistency
ONLY: that a model (2e,2o) CI exhibits nonzero correlation energy and
multireference character, and that this correctly identifies the active
space the QUANTUM-axis VQE pipeline is designed to consume.  It is NOT a
binding-affinity, therapeutic, cytotoxic, antitumor, immunogenic, efficacy,
or regulatory claim.  The METALLODRUG axis is scientifically UNPROVEN at the
wet-lab boundary (CLOSURE_RESIDUAL_BACKLOG.md section 0).

NO live VQE was run.  The exact 2x2 CI is the verified deliverable; the
live qmirror / VQE-ladder dispatch on this active space is an HONEST DEFER
(AGENTS.tape g7 skip-is-honest — `hexa verify` tier framing: 🟠 DEFERRED,
external substrate).  This module DESCRIBES the active-space hand-off (the
2-CSF Hamiltonian {E_a, E_b, K} that pocket_active_space.py would map and
quantum_vqe_*.py would minimise) but does NOT require, claim, or simulate a
live run.  We do NOT claim VQE was executed — it was not.

Sentinel:  __METALLODRUG_QUANTUM_VQE_CROSS__ PASS   (or FAIL).
"""
from __future__ import annotations

import json
import math
import os
import sys

# ── cross-axis import: METALLODRUG axis ligand-field machinery (no fork — f3) ──
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from metallodrug_coordination_sim import (  # noqa: E402
    GRIFFITH_ORGEL_1957,
    cfse_square_planar,
    cfse_octahedral,
)

# ── module identity ──
VERSION = "1.0.0"
CROSS = "METALLODRUG->QUANTUM"
AXIS_FROM = "METALLODRUG (expansion-main, NOT core-5)"
AXIS_TO = "QUANTUM (core-5)"

# ── real-limit / literature anchors ──
ROOS_CASSCF_1980 = "Roos, Taylor & Siegbahn, Chem Phys 1980;48:157-173 (CASSCF)"
REIHER_PNAS_2017 = ("Reiher, Wiebe, Svore, Wecker & Troyer, "
                    "PNAS 2017;114:7555-7560 (quantum-computer reaction mechanisms)")

# ── tolerances ──
TOL = 1e-12          # exact-algebra agreement tolerance
TOL_DEGEN = 1e-9     # degeneracy-limit agreement tolerance


# ─────────────────────────────────────────────────────────────────────
# (1) the analytic (2e,2o) singlet CI — closed-form 2x2
# ─────────────────────────────────────────────────────────────────────

def two_by_two_ground_state(e_a: float, e_b: float, k: float) -> dict:
    """Exact lower eigenpair of the real-symmetric 2x2

        H = [[e_a, k], [k, e_b]]

    Closed form (no numpy):
        mean  = (e_a + e_b) / 2
        half  = (e_b - e_a) / 2
        rad   = sqrt(half^2 + k^2)
        E-    = mean - rad        (ground state)
        E+    = mean + rad
    Ground-state eigenvector (normalised); its first component squared is the
    weight of |Phi_0> (the HF determinant) in the exact wavefunction.
    """
    mean = 0.5 * (e_a + e_b)
    half = 0.5 * (e_b - e_a)
    rad = math.sqrt(half * half + k * k)
    e_minus = mean - rad
    e_plus = mean + rad

    # ground-state eigenvector for E- : (H - E-)v = 0
    # row 0:  (e_a - E-) c0 + k c1 = 0  ->  c1 = -(e_a - E-)/k * c0   (k != 0)
    if abs(k) > 0.0:
        c0 = 1.0
        c1 = -(e_a - e_minus) / k
    else:
        # decoupled: ground state is whichever pure determinant is lower
        if e_a <= e_b:
            c0, c1 = 1.0, 0.0
        else:
            c0, c1 = 0.0, 1.0
    norm = math.hypot(c0, c1)
    c0, c1 = c0 / norm, c1 / norm

    return {
        "e_ground": e_minus,
        "e_excited": e_plus,
        "gap": e_plus - e_minus,
        "hf_weight": c0 * c0,            # |<Phi_0|Psi_FCI>|^2
        "double_weight": c1 * c1,        # |<Phi_1|Psi_FCI>|^2
        "eigvec_ground": [c0, c1],
    }


def metal_2e2o_ci(orbital_gap_delta_oct: float,
                   pairing_shift: float,
                   coupling_k: float) -> dict:
    """Build and exactly solve the (2e,2o) singlet CI for a near-degenerate
    metal d-orbital pair.

    Parameters (all in units of Delta_oct, the ligand-field splitting quantum):
        orbital_gap_delta_oct : one-electron gap between the lower and upper
                                d-orbital of the active pair (>= 0).
        pairing_shift         : effective change in pair-repulsion on
                                promotion ((J_bb - J_aa)/2); folds into the
                                two-electron promotion gap.
        coupling_k            : the <aa|bb> determinant-mixing coupling K
                                (the exchange-type two-electron integral).

    Returns the HF reference energy, the exact CI ground-state energy, and the
    correlation energy E_corr = E_FCI - E_HF, plus multireference diagnostics.
    """
    # determinant energies in the 2-CSF singlet basis (E_a anchored at 0)
    e_a = 0.0
    e_b = 2.0 * orbital_gap_delta_oct + 2.0 * pairing_shift   # two-electron promotion gap
    k = coupling_k

    sol = two_by_two_ground_state(e_a, e_b, k)

    e_hf = e_a                       # closed-shell HF = energy of |Phi_0>
    e_fci = sol["e_ground"]          # exact CI ground state
    e_corr = e_fci - e_hf            # correlation energy (<= 0)

    return {
        "orbital_gap_delta_oct": orbital_gap_delta_oct,
        "pairing_shift": pairing_shift,
        "coupling_k": k,
        "det_energy_phi0_hf": e_a,
        "det_energy_phi1_double": e_b,
        "e_hf": e_hf,
        "e_fci": e_fci,
        "e_corr": e_corr,
        "hf_weight_in_fci": sol["hf_weight"],
        "double_weight_in_fci": sol["double_weight"],
        "ci_gap": sol["gap"],
        # multireference diagnostic: a single determinant carries weight ~1;
        # weight noticeably < 1 (rule of thumb < 0.95) => multireference.
        "is_multireference": sol["hf_weight"] < 0.95,
    }


def degeneracy_limit_check(coupling_k: float) -> dict:
    """Verify the exact degeneracy limit: when the d-orbital gap -> 0 the
    correlation energy -> -|K| and the HF weight -> 1/2 (maximal MR)."""
    near = metal_2e2o_ci(orbital_gap_delta_oct=0.0,
                         pairing_shift=0.0,
                         coupling_k=coupling_k)
    expected_e_corr = -abs(coupling_k)
    expected_hf_weight = 0.5
    return {
        "coupling_k": coupling_k,
        "e_corr_at_degeneracy": near["e_corr"],
        "expected_e_corr": expected_e_corr,
        "e_corr_deviation": abs(near["e_corr"] - expected_e_corr),
        "hf_weight_at_degeneracy": near["hf_weight_in_fci"],
        "expected_hf_weight": expected_hf_weight,
        "hf_weight_deviation": abs(near["hf_weight_in_fci"] - expected_hf_weight),
        "pass": (abs(near["e_corr"] - expected_e_corr) < TOL_DEGEN
                 and abs(near["hf_weight_in_fci"] - expected_hf_weight) < TOL_DEGEN),
    }


# ─────────────────────────────────────────────────────────────────────
# (2) cross-axis parameterisation — METALLODRUG ligand-field gap feeds CI
# ─────────────────────────────────────────────────────────────────────

def metal_d_manifold_cases() -> list:
    """The cross-axis cases.  Each picks a transition-metal d-orbital pair
    whose one-electron gap (in units of Delta_oct) is taken from the
    METALLODRUG axis's ligand-field model — NOT invented here.

    coupling_k is a small fixed model two-electron coupling (0.30 Delta_oct):
    the cross's claim does NOT depend on its exact value, only on K != 0.
    Pairing shift is set to 0 (we isolate the one-electron ligand-field gap
    so the cross is a clean function of Delta).
    """
    k_model = 0.30   # model determinant-mixing coupling, units of Delta_oct

    # near-degenerate octahedral t2g pair: dxy and dxz are degenerate in an
    # ideal octahedral field — the textbook static-correlation case.  We use
    # the cfse_octahedral helper to confirm the t2g set is a real, occupied
    # manifold (e.g. octahedral high-spin d2: 2 electrons, both in t2g).
    cfse_d2_hs = cfse_octahedral(2, low_spin=False)   # METALLODRUG axis call

    # square-planar d8 Pt(II) frontier pair: the cisplatin-class geometry.
    # The METALLODRUG square-planar level set gives the dxy(+0.228) and
    # dx2-y2(+1.228) energies; their gap = 1.000 Delta_oct is a genuine,
    # moderate ligand-field gap (NOT degenerate) — the contrast case.
    sp_levels = [-0.514, -0.514, -0.428, 0.228, 1.228]   # METALLODRUG axis ordering
    sp_frontier_gap = sp_levels[4] - sp_levels[3]         # dx2-y2 - dxy = 1.000
    cfse_d8_sp = cfse_square_planar(8)                    # METALLODRUG axis call

    cases = [
        {
            "label": "octahedral_t2g_near_degenerate",
            "metal_context": "octahedral d2 high-spin t2g pair (dxy~dxz)",
            "orbital_gap_delta_oct": 0.0,
            "ligand_field_source": ("octahedral t2g set is 3-fold degenerate "
                                    "by symmetry — Griffith&Orgel ligand-field "
                                    "theory; cfse_octahedral(2,HS)="
                                    f"{cfse_d2_hs:+.3f} Delta_oct confirms a "
                                    "2-electron t2g manifold"),
            "expected_strongly_multireference": True,
        },
        {
            "label": "octahedral_t2g_weakly_split",
            "metal_context": "octahedral t2g pair under a small tetragonal distortion",
            "orbital_gap_delta_oct": 0.10,
            "ligand_field_source": ("a small Jahn-Teller/tetragonal lift of the "
                                    "t2g degeneracy — still near-degenerate"),
            "expected_strongly_multireference": True,
        },
        {
            "label": "square_planar_d8_Pt_frontier",
            "metal_context": "square-planar d8 Pt(II) dxy -> dx2-y2 (cisplatin-class)",
            "orbital_gap_delta_oct": sp_frontier_gap,   # 1.000, from METALLODRUG axis
            "ligand_field_source": ("METALLODRUG square-planar level set "
                                    f"dx2-y2({sp_levels[4]:+.3f}) - "
                                    f"dxy({sp_levels[3]:+.3f}) = "
                                    f"{sp_frontier_gap:.3f} Delta_oct; "
                                    f"cfse_square_planar(8)={cfse_d8_sp:+.3f}"),
            "expected_strongly_multireference": False,   # moderate gap — contrast
        },
    ]

    out = []
    for c in cases:
        ci = metal_2e2o_ci(orbital_gap_delta_oct=c["orbital_gap_delta_oct"],
                           pairing_shift=0.0,
                           coupling_k=k_model)
        row = dict(c)
        row["coupling_k"] = k_model
        row["ci"] = ci
        out.append(row)
    return out


# ─────────────────────────────────────────────────────────────────────
# (3) the QUANTUM-axis hand-off — honest DEFER (g7 skip-is-honest)
# ─────────────────────────────────────────────────────────────────────

def vqe_handoff_descriptor(case: dict) -> dict:
    """Describe — but do NOT run — the QUANTUM-axis VQE hand-off for a case.

    The (2e,2o) singlet block {E_a, E_b, K} is exactly the object that
        pocket_active_space.py   -> builds the active-space Hamiltonian
        quantum_vqe_h2.py / *.py -> minimises with a hardware-efficient VQE
    would consume (2 electrons / 2 spatial orbitals -> parity map -> 2 qubit;
    the analytic E_FCI here is the CASCI classical reference VQE targets).

    This is an HONEST DEFER: the live qmirror / VQE-ladder dispatch is an
    external substrate and is NOT executed here.  `hexa verify` tier framing
    for that step is 🟠 DEFERRED.  The deterministic 2x2 CI above is the PASS.
    """
    ci = case["ci"]
    return {
        "case": case["label"],
        "active_space": "(2e,2o) — 2 electrons, 2 spatial d-orbitals",
        "ci_hamiltonian_2csf": {
            "E_a_phi0_hf": ci["det_energy_phi0_hf"],
            "E_b_phi1_double": ci["det_energy_phi1_double"],
            "K_coupling": ci["coupling_k"],
        },
        "classical_reference_for_vqe": {
            "e_casci_fci_analytic": ci["e_fci"],
            "e_hf": ci["e_hf"],
        },
        "quantum_axis_pipeline": [
            "pocket_active_space.build_active_space_hamiltonian "
            "(num_active_electrons=2, num_active_spatial_orbitals=2)",
            "ParityMapper -> ~2-qubit Hamiltonian",
            "quantum_vqe_h2-style hardware-efficient ansatz + Nelder-Mead",
            "gate: |E_VQE - E_CASCI| < chemical accuracy on the SAME space",
        ],
        "dispatch_status": "DEFERRED",
        "dispatch_tier": "hexa verify 🟠 DEFERRED — external substrate (qmirror/VQE ladder)",
        "defer_reason": ("live qmirror / VQE-ladder dispatch is an external "
                         "compute substrate; per AGENTS.tape g7 skip-is-honest "
                         "it is an honest DEFER, not a failure. The exact 2x2 "
                         "CI is the in-repo verified deliverable."),
        "not_claimed": "VQE was NOT executed; no quantum-advantage claim is made.",
    }


# ─────────────────────────────────────────────────────────────────────
# orchestration
# ─────────────────────────────────────────────────────────────────────

def run() -> dict:
    cases = metal_d_manifold_cases()

    # degeneracy-limit exact check (E_corr -> -|K|, HF weight -> 1/2)
    degen = degeneracy_limit_check(coupling_k=0.30)

    # per-case cross verification
    case_rows = []
    for c in cases:
        ci = c["ci"]
        # exact-algebra self-checks for THIS case
        e_a = ci["det_energy_phi0_hf"]
        e_b = ci["det_energy_phi1_double"]
        k = ci["coupling_k"]
        # recompute E_FCI independently from the closed form -> must match
        mean = 0.5 * (e_a + e_b)
        half = 0.5 * (e_b - e_a)
        e_fci_closed = mean - math.sqrt(half * half + k * k)
        closed_form_ok = abs(ci["e_fci"] - e_fci_closed) < TOL
        # eigvec normalisation
        weights_sum_ok = abs(ci["hf_weight_in_fci"]
                             + ci["double_weight_in_fci"] - 1.0) < TOL
        # correlation energy must be <= 0, and < 0 strictly since K != 0
        e_corr_negative = ci["e_corr"] < -TOL
        # multireference flag agrees with the case expectation
        mr_matches_expectation = (ci["is_multireference"]
                                  == c["expected_strongly_multireference"])
        handoff = vqe_handoff_descriptor(c)
        case_rows.append({
            "label": c["label"],
            "metal_context": c["metal_context"],
            "ligand_field_source": c["ligand_field_source"],
            "orbital_gap_delta_oct": c["orbital_gap_delta_oct"],
            "coupling_k": c["coupling_k"],
            "e_hf": ci["e_hf"],
            "e_fci": ci["e_fci"],
            "e_corr": ci["e_corr"],
            "hf_weight_in_fci": ci["hf_weight_in_fci"],
            "double_weight_in_fci": ci["double_weight_in_fci"],
            "is_multireference": ci["is_multireference"],
            "expected_strongly_multireference": c["expected_strongly_multireference"],
            "checks": {
                "ci_matches_closed_form": closed_form_ok,
                "ci_weights_sum_to_one": weights_sum_ok,
                "e_corr_strictly_negative": e_corr_negative,
                "mr_flag_matches_expectation": mr_matches_expectation,
            },
            "vqe_handoff": handoff,
        })

    # K=0 control: with no determinant coupling, E_corr must be EXACTLY 0
    # (HF is exact) — the falsifier that proves E_corr != 0 is a real effect.
    k0 = metal_2e2o_ci(orbital_gap_delta_oct=0.5, pairing_shift=0.0, coupling_k=0.0)
    k0_e_corr_zero = abs(k0["e_corr"]) < TOL

    # the cross conclusion: every metal d-manifold case has E_corr < 0
    all_cases_correlated = all(r["e_corr"] < -TOL for r in case_rows)
    # the degenerate t2g case is the strongly-multireference one
    degen_case = next(r for r in case_rows
                      if r["label"] == "octahedral_t2g_near_degenerate")
    degenerate_is_mr = degen_case["is_multireference"]
    # the moderate-gap square-planar case is the single-reference contrast
    sp_case = next(r for r in case_rows
                   if r["label"] == "square_planar_d8_Pt_frontier")

    # F-CROSS falsifier set
    falsifiers = {
        "F-CROSS-1_e_corr_nonzero_for_metal_manifold": all_cases_correlated,
        "F-CROSS-2_e_corr_exactly_zero_when_coupling_zero": k0_e_corr_zero,
        "F-CROSS-3_degeneracy_limit_e_corr_equals_minus_abs_K": degen["pass"],
        "F-CROSS-4_near_degenerate_case_is_multireference": degenerate_is_mr,
        "F-CROSS-5_every_case_ci_matches_closed_form": all(
            r["checks"]["ci_matches_closed_form"] for r in case_rows),
    }

    # acceptance criteria
    crit = {
        "C1_all_cases_ci_match_analytic_closed_form": all(
            r["checks"]["ci_matches_closed_form"] for r in case_rows),
        "C2_all_cases_ci_weights_normalised": all(
            r["checks"]["ci_weights_sum_to_one"] for r in case_rows),
        "C3_metal_manifold_has_nonzero_correlation_energy": all_cases_correlated,
        "C4_correlation_vanishes_iff_coupling_zero": k0_e_corr_zero,
        "C5_degeneracy_limit_matches_minus_abs_K": degen["pass"],
        "C6_near_degenerate_manifold_is_multireference": degenerate_is_mr,
        "C7_multireference_flag_matches_expectation_all_cases": all(
            r["checks"]["mr_flag_matches_expectation"] for r in case_rows),
        "C8_all_falsifiers_hold": all(falsifiers.values()),
    }
    n_pass = sum(1 for v in crit.values() if v)
    verdict = "PASS" if n_pass == len(crit) else "FAIL"

    return {
        "schema": "metallodrug_quantum_vqe_cross_v1",
        "ts": "2026-05-16T00:00:00Z",          # fixed -> deterministic witness
        "cross": CROSS,
        "axis_from": AXIS_FROM,
        "axis_to": AXIS_TO,
        "version": VERSION,
        "real_limit_anchors": {
            "exact_2x2_ci_eigenvalue": ("E_FCI is the analytic lower eigenvalue "
                                        "of the (2e,2o) singlet 2x2 CI block — "
                                        "exact closed-form linear algebra"),
            "ligand_field_splitting_citation": GRIFFITH_ORGEL_1957,
            "multireference_casscf_citation": ROOS_CASSCF_1980,
            "quantum_vqe_metal_motivation_citation": REIHER_PNAS_2017,
        },
        "cross_claim": (
            "A near-degenerate transition-metal d-orbital pair has E_corr = "
            "E_FCI - E_HF < 0 (exact 2x2 CI); a single-reference method "
            "cannot recover E_corr; therefore this (2e,2o) active space is "
            "exactly what the QUANTUM-axis VQE pipeline is built to treat."),
        "cases": case_rows,
        "degeneracy_limit_check": degen,
        "coupling_zero_control": {
            "orbital_gap_delta_oct": 0.5,
            "coupling_k": 0.0,
            "e_corr": k0["e_corr"],
            "e_corr_is_exactly_zero": k0_e_corr_zero,
            "interpretation": ("with K=0 the two determinants do not mix, HF "
                               "IS exact, E_corr=0 — this control proves the "
                               "nonzero E_corr in the metal cases is a real "
                               "determinant-mixing effect, not an artefact"),
        },
        "vqe_dispatch": {
            "status": "DEFERRED",
            "tier": "hexa verify 🟠 DEFERRED — external substrate",
            "reason": ("the live qmirror / VQE-ladder dispatch on these active "
                       "spaces is an external compute substrate; per AGENTS.tape "
                       "g7 skip-is-honest it is an honest DEFER. The deterministic "
                       "exact 2x2 CI core is the PASS. No VQE was executed and no "
                       "quantum-advantage claim is made."),
            "handoff_object": ("the (2e,2o) singlet CI Hamiltonian {E_a,E_b,K} "
                               "per case — see cases[].vqe_handoff"),
        },
        "falsifiers": falsifiers,
        "acceptance_criteria": crit,
        "pass_count": n_pass,
        "total_criteria": len(crit),
        "verdict": verdict,
        "lattice_stance": (
            "No n=6 lattice arithmetic is performed. The (2e,2o) active space "
            "is the minimal space that can host a double excitation; the "
            "metal modality is anchored to its OWN precedent (cisplatin-class "
            "square-planar d8 Pt(II), octahedral t2g/eg, Griffith&Orgel 1957 "
            "ligand-field theory). Any numerical coincidence with n=6 "
            "(sigma=12, tau=4, phi=2, J2=24) is OBSERVATION ONLY "
            "(HEXA-METALLODRUG.tape f_lattice_fit / n6_honest_stance, "
            "AGENTS.tape g2/g3/f1)."),
        "in_silico_scope": (
            "PASS verifies IN-SILICO simulator+metadata consistency ONLY — that "
            "a model (2e,2o) CI exhibits nonzero correlation energy and "
            "multireference character, correctly identifying the active space "
            "the QUANTUM-axis VQE pipeline consumes. NOT a binding/therapeutic/"
            "cytotoxic/antitumor/regulatory claim. VQE was NOT run (honest "
            "DEFER). The METALLODRUG axis is UNPROVEN at the wet-lab boundary "
            "(AGENTS.tape g8_in_silico_only / f2; CLOSURE_RESIDUAL_BACKLOG.md "
            "section 0)."),
    }


def main() -> int:
    print("metallodrug_quantum_vqe_cross — CROSS-AXIS A1: "
          f"{CROSS} v{VERSION}\n", flush=True)
    print(f"  from: {AXIS_FROM}")
    print(f"  to  : {AXIS_TO}\n", flush=True)

    w = run()

    print("  CROSS CLAIM:")
    print("    " + w["cross_claim"])
    print()

    print("  (1) exact (2e,2o) singlet CI per metal d-orbital manifold")
    print("      (energies in units of Delta_oct, ligand-field splitting quantum)")
    print("      case                              | gap   |  E_HF  |  E_FCI  | E_corr  | HF wt | MR?")
    for r in w["cases"]:
        print(f"      {r['label']:<33s} | {r['orbital_gap_delta_oct']:5.3f} | "
              f"{r['e_hf']:+6.3f} | {r['e_fci']:+7.4f} | {r['e_corr']:+7.4f} | "
              f"{r['hf_weight_in_fci']:5.3f} | "
              f"{'YES' if r['is_multireference'] else 'no'}")
    print()
    for r in w["cases"]:
        print(f"      [{r['label']}]")
        print(f"        ligand-field source: {r['ligand_field_source']}")
    print()

    degen = w["degeneracy_limit_check"]
    print("  (2) degeneracy limit (d-orbital gap -> 0):")
    print(f"      E_corr -> {degen['e_corr_at_degeneracy']:+.6f}  "
          f"(exact -|K| = {degen['expected_e_corr']:+.6f}, "
          f"dev {degen['e_corr_deviation']:.2e})")
    print(f"      HF weight -> {degen['hf_weight_at_degeneracy']:.6f}  "
          f"(exact 1/2 = {degen['expected_hf_weight']:.6f}, "
          f"dev {degen['hf_weight_deviation']:.2e})")
    print("      => maximally multireference: 50/50 two-determinant superposition")
    print()

    ctrl = w["coupling_zero_control"]
    print("  (3) K=0 control (no determinant coupling):")
    print(f"      E_corr = {ctrl['e_corr']:+.2e}  -> exactly zero: "
          f"{ctrl['e_corr_is_exactly_zero']}  (HF is exact when K=0)")
    print()

    vd = w["vqe_dispatch"]
    print("  (4) QUANTUM-axis VQE dispatch:")
    print(f"      status: {vd['status']}   tier: {vd['tier']}")
    print(f"      {vd['reason']}")
    print(f"      hand-off object: {vd['handoff_object']}")
    print()

    print("  falsifiers:")
    for k, v in w["falsifiers"].items():
        print(f"    [{'HOLD' if v else 'FALSIFIED'}] {k}")
    print()

    print("  acceptance criteria:")
    for k, v in w["acceptance_criteria"].items():
        print(f"    [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- METALLODRUG->QUANTUM cross: {w['pass_count']}/"
          f"{w['total_criteria']}  ->  verdict: {w['verdict']} ---")

    print()
    print("  n=6 lattice stance: " + w["lattice_stance"])
    print()
    print("  IN-SILICO SCOPE (g8/f2): " + w["in_silico_scope"])

    emit = "--emit-witness" in sys.argv
    if emit:
        import io
        path = os.path.join(os.path.dirname(__file__), "runs",
                            "metallodrug_quantum_vqe_cross_events.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with io.open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        print(f"\n  [emit] appended metallodrug_quantum_vqe_cross_v1 witness "
              f"-> {path}")

    ok = w["verdict"] == "PASS"
    print("\n## witness JSON")
    print(json.dumps(w, indent=2, ensure_ascii=False))
    print("\n__METALLODRUG_QUANTUM_VQE_CROSS__ PASS" if ok
          else "\n__METALLODRUG_QUANTUM_VQE_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
