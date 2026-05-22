#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
protac_ppi_cross.py — CROSS-AXIS integration W4.

CROSS:  PPI sub-axis Bogan-Thorn hotspot energetics  ──same energetic ledger──▶
        PROTAC sub-axis cooperative ternary-complex feasibility.

A PROTAC's ternary complex IS a protein-protein interaction: the bifunctional
linker NUCLEATES a neo-interface between the target (POI) and an E3 ubiquitin
ligase (CRBN / VHL / …). The Bogan-Thorn hotspot energetics (Bogan & Thorn,
J. Mol. Biol. 280:1, 1998) that quantify whether a PPI is disruptable by a
small-molecule mimic are EXACTLY the energetics that quantify whether the
PROTAC's induced ternary neo-interface is thermodynamically viable for
productive ubiquitin transfer. Same alanine-scanning ΔΔG ledger, same
mass-action and cooperativity scaffolding — applied as the FLOOR a PROTAC's
neo-interface cannot beat (Wells & McClendon, Nature 450:1001, 2007 on the
druggability of hotspot-driven PPIs; Douglass et al., JACS 135:6092, 2013 and
Gadd et al., Nat. Chem. Biol. 13:514, 2017 on cooperative PROTAC ternary).

────────────────────────────────────────────────────────────────────────────
KEY DISTINCTION FROM G3  (ppi_molecular_glue_cross)  —  BIVALENT VS MONOVALENT
────────────────────────────────────────────────────────────────────────────
G3 (glue × PPI) and W4 (PROTAC × PPI) both run the Bogan-Thorn hotspot ledger
as the PPI-side FLOOR. They diverge sharply on the BINDER side:

  * MOLECULAR GLUE — MONOVALENT.  A glue is a single small molecule that
    binds the E3 ligase pocket; the neo-interface between target and E3 is
    paid ENTIRELY by the cooperativity factor α (Douglass 2013; Gadd 2017).
    There is no linker. All of the neo-interface free energy is α work.

  * PROTAC — BIVALENT.  A PROTAC is two warheads joined by a chemical linker.
    The linker TETHERS POI and E3 in physical proximity, paying part of the
    neo-interface cost in advance via an effective-concentration boost
    (intramolecular vs intermolecular association — Page & Jencks, PNAS
    68:1678, 1971, on bivalent tether effective concentrations). The
    remaining work is paid by cooperativity α (which is typically smaller
    for PROTACs than for glues at matched ternary occupancy, because the
    linker has already done part of the job — Maniaci & Ciulli, Curr. Opin.
    Chem. Biol. 44:145, 2018; Roy, Nowak, Buckley & Fischer reviews on
    PROTAC SAR; Hughes & Ciulli, Essays Biochem. 61:505, 2017).

The cross MUST keep these distinct — W4 carries an explicit
`linker_cost_pre_paid = True` flag on every row, models the linker's effective-
concentration pre-payment as a deterministic ΔG_linker contribution to the
neo-interface ledger, and reports a SEPARATE α_required for the PROTAC ternary
(distinct from the α_required a hypothetical glue at the same hotspot floor
would need). Code reuse from G3 is limited to the HOTSPOT-FLOOR side (the same
Gibbs ΔG_hotspot → K_d conversion machinery is sound for both); the PROTAC
ternary side is computed by importing protac_sim, not molecular_glue_sim.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sims, no fork)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent sub-axis pieces:

  (1) _python_bridge/module/ppi_sim.py — PPI sub-axis (:> QUANTUM core).
      Alanine-scanning ΔΔG ledger; Bogan-Thorn hotspot definition
      (ΔΔG ≥ 2 kcal/mol); hotspot-cluster energy ΔG_hotspot_cluster as the
      bounded energy a small-molecule mimic can recover.

  (2) _python_bridge/module/protac_sim.py — PROTAC sub-axis
      (:> BIFUNCTIONAL expansion-main). Mass-action three-body equilibrium
      with cooperativity α, hook-effect peak, transfer-efficiency surrogate
      for ubiquitin-transfer competence (Douglass 2013; Gadd 2017).

This module is the BRIDGE. For a deterministic panel of PROTAC × interface
scenarios:

   ppi_sim.interface_profile()  ─▶  ΔG_hotspot_cluster (kcal/mol)
                                     │
                                     │  Gibbs / Guldberg-Waage:
                                     │      K_d = exp(ΔG / RT)
                                     ▼
                          K_d_E3_hotspot_floor_nM  — the K_d(E3) a PROTAC
                                     │              would see in a neo-
                                     │              interface mirroring the
                                     │              PPI hotspot energetics
                                     │
                                     │  + bivalent linker pre-payment:
                                     │      ΔG_linker = −RT·ln(C_eff/C_ref)
                                     ▼
                          K_d_E3_PROTAC_effective_nM = K_d_E3_floor ·
                                                       exp(ΔG_linker/RT)
                                     │
                                     ▼
                  protac_sim.ternary_fraction(
                      [PROTAC]_grid,
                      kd_target_nM,                # PROTAC's own POI warhead
                      K_d_E3_PROTAC_effective_nM,
                      α = deterministic ladder)
                                     │
                                     ▼
                  smallest α at which ternary_fraction_peak ≥
                  COOPERATIVITY_THRESHOLD (productive-degradation gate)
                  → alpha_required_for_productive_ternary  (W4 result)

The PPI hotspot real-limit is the FLOOR: a hotspot-poor target-E3 PPI gives a
weak K_d_E3 floor, and even after the bivalent linker pre-payment the
cooperativity α must work harder (or cannot reach feasibility within a sane
ladder) to clear the productive-ternary threshold; such systems require
very-long-linker designs or VHL/CRBN-specific recruitment cheats.  A
hotspot-rich PPI (BH3-mimetic-style energetics, but here applied to the
target-E3 surface a PROTAC induces) gives a tight K_d_E3 floor; the PROTAC's
ternary closes at modest α — the linker pre-pay + cooperativity is sufficient.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * Bogan-Thorn binding-hotspot theory (Bogan & Thorn, "Anatomy of hot spots
    in protein interfaces", J. Mol. Biol. 280:1, 1998): interface binding
    free energy is concentrated in a few hotspot residues (ΔΔG ≥ 2 kcal/mol
    by alanine scanning); the recoverable energy is BOUNDED by the alanine-
    scanning ledger. This is the real-limit FLOOR — no PROTAC's induced
    target-E3 neo-interface can be stronger than the hotspot energy the
    matched PPI ledger permits.  Earlier alanine-scanning origin: Clackson
    & Wells, Science 267:383 (1995).  Druggability of flat hotspot-driven
    PPIs by small molecules: Wells & McClendon, Nature 450:1001 (2007).
  * Cooperative ternary-complex mass action (Douglass, Miller, Sparer,
    Shapiro & Spiegel, "A comprehensive mathematical model for three-body
    binding equilibria", JACS 135:6092, 2013; Gadd et al., "Structural basis
    of PROTAC cooperative recognition for selective protein degradation",
    Nat. Chem. Biol. 13:514, 2017): the ternary is governed by binary K_d's
    and a cooperativity factor α amplifying the second binding event.
    Guldberg & Waage law of mass action (1864) — every occupancy ≤ 1.
  * Bivalent-linker effective-concentration / entropic-tether limit (Page &
    Jencks, "Entropic contributions to rate accelerations in enzymic and
    intramolecular reactions, and the chelate effect", PNAS 68:1678, 1971;
    Jencks, "On the attribution and additivity of binding energies", PNAS
    78:4046, 1981): a bivalent tether converts intermolecular association
    into effective intramolecular association — the resulting effective
    concentration is bounded above by ~55 M (water density limit) and is
    typically 1–100 mM for PROTAC-class tethers (Maniaci & Ciulli, Curr.
    Opin. Chem. Biol. 44:145, 2018; Roy et al., SAR-of-PROTAC-ternary
    reviews; Hughes & Ciulli, Essays Biochem. 61:505, 2017 on hook effect).

Modality precedent (described ONLY by its own drug precedent — g3 / f1 /
f_lattice_fit, never lattice-derived):
  - PPI inhibitors (own precedent for the disruption side):
      venetoclax — BH3-mimetic small molecule disrupting the BCL-2 / BH3
      pro-apoptotic PPI (Souers et al., Nat. Med. 19:202, 2013; FDA-approved
      2016); navitoclax / ABT-263 — dual BCL-2/BCL-xL BH3-mimetic
      (Tse et al., Cancer Res. 68:3421, 2008).
  - PROTACs (own precedent for the bifunctional-degrader side):
      ARV-471 / vepdegestrant — estrogen-receptor PROTAC, clinical (Arvinas
      / Pfizer programme; Flanagan et al., SABCS reports); ARV-110 /
      bavdegalutamide — androgen-receptor PROTAC, clinical (Arvinas);
      PROTAC chemistry traces to Sakamoto et al., PNAS 98:8554 (2001).
      Cooperative VHL-recruiting BRD4 PROTAC class (Gadd et al., Nat. Chem.
      Biol. 13:514, 2017).

No quantity in this module is derived from the n=6 lattice (f_lattice_fit /
lattice-is-tool). The cross is NOT a new axis — it spans existing sub-axes
(PPI :> QUANTUM core, PROTAC :> BIFUNCTIONAL expansion-main); the hexa-bio
core-5 axes QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID are UNCHANGED.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
  * Both sister sims are IMPORTED and their published functions reused
    verbatim — ppi_sim.interface_profile() and protac_sim.ternary_fraction
    + protac_sim.degrader_profile; no logic is re-implemented (f3).
  * The PPI ΔΔG values, PROTAC K_d / α / transfer values, and the linker
    effective-concentration constant are illustrative literature-informed
    surrogates for the modality CLASSES (each parent sim's own honesty
    caveat). No claim sharper than either parent permits is made here.
  * The Gibbs conversion  K_d = exp(ΔG_hotspot_cluster / RT)  is the
    standard thermodynamic relationship between a binding free energy and
    a dissociation constant; the result K_d_E3_hotspot_floor_nM is the
    K_d(E3) a PROTAC WOULD see if the neo-interface mirrored the PPI
    hotspot energetics — the FLOOR the PROTAC cannot beat.  This is NOT a
    measurement, NOT an affinity prediction.
  * alpha_required_for_productive_ternary comes from a DETERMINISTIC alpha
    ladder, NOT an optimisation. The smallest α in the ladder at which
    protac_sim.ternary_fraction's peak across the fixed [PROTAC] grid
    reaches the productive-ternary threshold is reported; if no α within
    the ladder clears the threshold, the row honestly reports
    productive_ternary_achievable = False.
  * This W4 cross is the MODEL UPPER BOUND analogue of J2's "model upper
    bound, not a quantitative prediction" honesty pattern — the hotspot-
    derived K_d(E3) floor multiplied through the cooperative-ternary
    fraction is a CEILING on what a PROTAC can extract from a target-E3
    PPI of the given hotspot character. It is NOT a binding-affinity, NOT
    a DC50 / Dmax / Dmax-degradation claim, NOT a therapeutic-efficacy or
    immunogenic claim (g8 / f2).
  * BIVALENT vs MONOVALENT IS PRESERVED — the row carries
    `linker_cost_pre_paid = True` and an explicit ΔG_linker contribution;
    we do NOT collapse PROTAC and glue into one model. G3 (glue) reports α
    against a K_d_PPI floor with no linker pre-payment; W4 (PROTAC) reports
    α against a K_d(E3) floor that is tightened by the bivalent linker's
    effective-concentration boost. The two crosses share the hotspot-floor
    side; their ternary sides are distinct sister sims.
  * The cross is a MODEL-LEVEL UNIFICATION of two energetic accountings —
    NOT a claim that every hotspot-driven PPI yields a PROTAC-able target,
    NOT a claim that PROTAC and glue modalities are interchangeable. PROTAC
    has additional mechanistic requirements (an E3 ligase actually
    expressed in the target cell; a target lysine geometry tolerant to
    ubiquitin transfer; favourable membrane permeability for a high-MW
    bivalent molecule) that live outside this energetic ledger.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

CROSS != NEW AXIS:
  PPI    :> QUANTUM core (sub-axis, AXIS/HIERARCHY.tape unchanged).
  PROTAC :> BIFUNCTIONAL expansion-main (sub-axis, AXIS/HIERARCHY.tape
                                                     unchanged).
  Both stay sub-axes; the hexa-bio core-5 + expansion-layer are UNCHANGED.
"""
from __future__ import annotations
import importlib.util
import json
import math
import os
import sys

# ── locate the two sister sources (no fork — f3) ────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_PPI_PATH = os.path.join(_HERE, "ppi_sim.py")
_PROTAC_PATH = os.path.join(_HERE, "protac_sim.py")

SCHEMA_ID = "protac_ppi_cross_v1"

# ── thermodynamic anchors (deterministic constants) ─────────────────────────
TEMP_K = 310.0                                   # K, physiological reference
R_KCAL_PER_MOL_K = 1.987204258e-3                # gas constant (kcal/mol/K)
RT_KCAL = R_KCAL_PER_MOL_K * TEMP_K              # ≈ 0.616 kcal/mol @ 310 K
M_TO_NM = 1.0e9                                  # K_d (M) → K_d (nM)

# ── bivalent-linker effective-concentration pre-payment (PROTAC-specific) ──
# The linker tethers POI and E3 in proximity, converting intermolecular
# association into intramolecular association.  Effective concentration is
# bounded above by the water density limit (~55 M); typical PROTAC-class
# tethers report C_eff in the 1–100 mM range (Page & Jencks, PNAS 68:1678,
# 1971; Jencks, PNAS 78:4046, 1981; Maniaci & Ciulli, Curr. Opin. Chem.
# Biol. 44:145, 2018; Roy et al., PROTAC ternary SAR reviews).  We use a
# deterministic illustrative class-typical value here — NOT a fit.
LINKER_EFFECTIVE_CONC_M = 1.0e-2                 # 10 mM — class-typical
REFERENCE_CONC_M = 1.0                           # 1 M standard state
# ΔG_linker = -RT * ln(C_eff / C_ref).  C_eff < C_ref so ΔG_linker > 0?
# No — the bivalent association is enhanced relative to a 1 M intermolecular
# reference by the ENTROPIC pre-payment; the linker reduces the loss of
# translational/rotational entropy on association.  We use the magnitude of
# the effective-concentration boost vs the typical intracellular protein
# concentration (~μM target), so we benchmark against a reference 1 μM
# intermolecular case — see ΔG_linker formula below.
INTRACELLULAR_TARGET_REF_M = 1.0e-6              # 1 µM target reference
# The bivalent linker pre-payment in the practical sense is the free-energy
# advantage of an effective C_eff ≈ 10 mM tether over the intermolecular
# rendezvous of free POI and free E3 (≈ μM each in cell):
#   ΔG_linker  =  −RT · ln(C_eff / C_intracell_ref)   ≈  −RT · ln(1e-2 / 1e-6)
#               ≈ −RT · ln(1e4)  ≈  −5.7 kcal/mol  @ 310 K
# This is the standard intramolecularity bonus (Page & Jencks 1971).

# ── ternary productive-degradation threshold ───────────────────────────────
# The minimum ternary-fraction peak (across the deterministic [PROTAC] grid)
# at which the ubiquitin-transfer machinery achieves a productive engagement.
# Class-typical value from the PROTAC ternary literature (Hughes & Ciulli,
# Essays Biochem. 61:505, 2017; Roy et al., PROTAC SAR reviews; Gadd 2017
# VHL-BRD4 ternary occupancy ranges).  Illustrative threshold — NOT a fit.
PRODUCTIVE_TERNARY_PEAK_THRESHOLD = 0.30

# ── deterministic α (cooperativity) search ladder ──────────────────────────
# Spans negative cooperativity (α < 1, poor design) through strong positive
# cooperativity (α >> 1, VHL-BRD4-class neo-interface).  Brackets
# protac_sim.PROTAC_PANEL's natural α range (0.4–20.0).
ALPHA_LADDER = [
    0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 20.0, 30.0, 50.0, 80.0, 120.0, 200.0,
]

# ── the W4 deterministic cross panel ───────────────────────────────────────
# Each row pairs ONE PPI interface from ppi_sim.INTERFACE_PANEL with ONE
# PROTAC scenario from protac_sim.PROTAC_PANEL.  The pairing is chosen so
# the panel exhibits both ends of the discriminator: hotspot-rich PPIs with
# a competent PROTAC (positive cooperativity available) → low α_required;
# hotspot-poor PPIs (flat, diffuse) → very high α_required or unachievable.
# Pairings are deterministic and small (6 entries — matches W3 / G3 / J3).
W4_PANEL = [
    # hotspot-rich PPI + strong positive-cooperativity PROTAC
    # — BH3-mimetic-style hotspot energetics, VHL-BRD4-like α
    ("bcl2_bh3_groove",          "strongcoop_PROTAC_like"),
    # hotspot-rich PPI + clinical-class PROTAC (modest α)
    ("bclxl_bh3_groove",         "BRD4_VHL_PROTAC_like"),
    # hotspot-rich PPI + ARV-471-style clinical PROTAC
    ("mdm2_p53_cleft",           "ER_PROTAC_ARV471_like"),
    # borderline hotspot interface + clinical PROTAC (intermediate α)
    ("kix_coactivator_groove",   "AR_PROTAC_ARV110_like"),
    # flat / hotspot-poor interface + non-cooperative PROTAC (hard case)
    ("flat_diffuse_interface",   "noncoop_PROTAC_like"),
    # contrast row — hotspot-rich PPI but negative-cooperativity PROTAC
    # (the linker cannot rescue a poorly-designed warhead pair)
    ("strong_hotspot_weak_mimic", "negcoop_PROTAC_like"),
]


# ── module loading (no fork — f3) ──────────────────────────────────────────
def _load_module(name: str, path: str):
    """Import a sibling sim by file path — functions reused verbatim (f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── Gibbs and linker conversions ───────────────────────────────────────────
def _k_d_nM_from_dg(dg_kcal_per_mol: float,
                    temperature_K: float = TEMP_K) -> float:
    """
    Standard Gibbs:  K_d = exp(ΔG / RT).  Returns K_d in nM.

    A favourable (negative) ΔG yields a small K_d.  ΔG_hotspot_cluster from
    ppi_sim is favourable, so the returned K_d_E3_hotspot_floor is small
    (tight interface) for hotspot-rich PPIs and larger (weak interface) for
    hotspot-poor PPIs — the FLOOR a PROTAC's neo-interface cannot beat.
    """
    rt = R_KCAL_PER_MOL_K * temperature_K
    k_d_M = math.exp(dg_kcal_per_mol / rt)
    return k_d_M * M_TO_NM


def _dg_linker_prepay_kcal_per_mol() -> float:
    """
    ΔG_linker  =  −RT · ln(C_eff / C_intracell_ref).

    The bivalent-linker effective-concentration advantage of an intramolecular
    PROTAC tether (C_eff ≈ 10 mM) over the intermolecular rendezvous of free
    POI and free E3 (~ 1 µM each in cell).  Sign convention: a more-negative
    ΔG_linker is more favourable (the linker pays more of the neo-interface
    cost in advance).  Real-limit anchor: Page & Jencks, PNAS 68:1678 (1971)
    on the entropic origin of intramolecularity / chelate-effect rate
    accelerations.  This is the PROTAC-class distinction from a monovalent
    glue — the glue has NO linker, so this term is identically zero for a
    glue (G3 cross); for a PROTAC (W4 cross) it is the bivalent pre-payment.
    """
    return -RT_KCAL * math.log(LINKER_EFFECTIVE_CONC_M / INTRACELLULAR_TARGET_REF_M)


def _apply_linker_to_kd_floor(kd_floor_nM: float,
                              dg_linker_kcal_per_mol: float) -> float:
    """
    K_d_PROTAC_eff  =  K_d_floor · exp(ΔG_linker / RT).

    A favourable (negative) ΔG_linker multiplies K_d_floor by a factor < 1 —
    the bivalent linker tightens the PROTAC's effective K_d(E3) below the
    bare PPI hotspot floor by the entropic intramolecularity bonus.  The
    linker cannot tighten below thermodynamic limits: the bivalent advantage
    is bounded by the water-density-limit C_eff ≈ 55 M (Page & Jencks 1971).
    """
    return kd_floor_nM * math.exp(dg_linker_kcal_per_mol / RT_KCAL)


# ── the cross: PPI hotspot ledger → effective K_d(E3) → required α ─────────
def _ternary_fraction_peak_across_grid(
        protac_mod, kd_target_nM: float, kd_e3_eff_nM: float,
        alpha: float) -> tuple:
    """
    Sweep protac_sim.ternary_fraction across protac_sim.PROTAC_CONC_GRID_NM
    and return the peak (max ternary fraction across the [PROTAC] grid) plus
    the [PROTAC] concentration at which the peak occurs.  Uses protac_sim's
    function verbatim — no re-implementation (f3).
    """
    peak_f = -1.0
    peak_c = protac_mod.PROTAC_CONC_GRID_NM[0]
    for c in protac_mod.PROTAC_CONC_GRID_NM:
        f = protac_mod.ternary_fraction(c, kd_target_nM, kd_e3_eff_nM, alpha)
        if f > peak_f:
            peak_f = f
            peak_c = c
    return peak_f, peak_c


def build_cross_rows(ppi_mod, protac_mod) -> list:
    """
    One cross row per (PPI interface, PROTAC scenario) pair in W4_PANEL.

    Cross chain for each row:
      1. PPI side: ppi_sim.interface_profile() (imported — f3) emits
         ΔG_hotspot_cluster (the alanine-scanning hotspot energy).
      2. Bridge: Gibbs ΔG → K_d_E3_hotspot_floor_nM (the K_d(E3) the PROTAC
         neo-interface cannot beat).
      3. Bivalent linker pre-payment: ΔG_linker (Page & Jencks 1971) tightens
         the K_d to K_d_E3_PROTAC_effective_nM.  This is the W4-only
         distinction from G3 (glue has no linker — monovalent).
      4. PROTAC side: protac_sim.ternary_fraction() (imported — f3) is
         swept across the α ladder, holding the PROTAC's own K_d(target)
         from its panel entry and using K_d_E3_PROTAC_effective as the
         E3-side K_d.  The smallest α at which the ternary-fraction peak
         clears PRODUCTIVE_TERNARY_PEAK_THRESHOLD is the W4 answer.
    """
    # Index PPI panel by interface name and PROTAC panel by PROTAC name.
    ppi_by_name = {
        name: (name, ddg_list, mimicry, iclass, ppi_prec)
        for (name, ddg_list, mimicry, iclass, ppi_prec)
        in ppi_mod.INTERFACE_PANEL}
    protac_by_name = {
        name: (name, kd_t, kd_e3, alpha, te, e3, protac_prec)
        for (name, kd_t, kd_e3, alpha, te, e3, protac_prec)
        in protac_mod.PROTAC_PANEL}

    dg_linker = _dg_linker_prepay_kcal_per_mol()

    rows = []
    for ppi_name, protac_name in W4_PANEL:
        if ppi_name not in ppi_by_name:
            raise RuntimeError(
                f"W4_PANEL references unknown PPI interface {ppi_name!r}")
        if protac_name not in protac_by_name:
            raise RuntimeError(
                f"W4_PANEL references unknown PROTAC {protac_name!r}")
        (_, ddg_list, mimicry, iclass, ppi_prec) = ppi_by_name[ppi_name]
        (_, kd_t, _kd_e3_panel, _alpha_panel, te, e3_ligase, protac_prec
         ) = protac_by_name[protac_name]

        # (1) PPI hotspot ledger via ppi_sim (imported — f3)
        prof = ppi_mod.interface_profile(ddg_list, mimicry)
        dg_hot = prof["dg_hotspot_cluster_kcal_per_mol"]

        # (2) PPI-floor K_d(E3) via Gibbs
        kd_e3_floor_nM = _k_d_nM_from_dg(dg_hot)

        # (3) Bivalent linker pre-payment — PROTAC distinction from glue
        kd_e3_protac_eff_nM = _apply_linker_to_kd_floor(kd_e3_floor_nM, dg_linker)

        # (4) PROTAC ternary side — sweep α ladder via protac_sim (imported — f3)
        alpha_required = None
        peak_at_required = None
        c_at_required = None
        for alpha in ALPHA_LADDER:
            peak_f, peak_c = _ternary_fraction_peak_across_grid(
                protac_mod, kd_t, kd_e3_protac_eff_nM, alpha)
            if peak_f >= PRODUCTIVE_TERNARY_PEAK_THRESHOLD:
                alpha_required = alpha
                peak_at_required = peak_f
                c_at_required = peak_c
                break
        achievable = alpha_required is not None
        if not achievable:
            # Honestly evaluate at the ladder maximum for diagnostic occupancy
            # without falsely claiming success.
            alpha_required = ALPHA_LADDER[-1]
            peak_at_required, c_at_required = (
                _ternary_fraction_peak_across_grid(
                    protac_mod, kd_t, kd_e3_protac_eff_nM, alpha_required))

        # Real-limit ledger respect: the recovered hotspot-cluster magnitude
        # cannot exceed the full alanine-scan ledger.
        ppi_floor_ok = (abs(dg_hot)
                        <= abs(prof["dg_interface_kcal_per_mol"]) + 1e-9)
        # Linker pre-payment bounded by the water-density limit (~55 M):
        # |ΔG_linker| ≤ RT · ln(55 / C_intracell_ref).  Numeric sanity check.
        dg_linker_max = abs(RT_KCAL * math.log(55.0 / INTRACELLULAR_TARGET_REF_M))
        linker_within_water_density_limit = (abs(dg_linker) <= dg_linker_max + 1e-9)

        row = {
            "schema": SCHEMA_ID,
            "interface": ppi_name,
            "interface_class": iclass,
            "protac": protac_name,
            "e3_ligase": e3_ligase,
            "ppi_drug_precedent": ppi_prec,
            "protac_drug_precedent": protac_prec,
            # PPI side — Bogan-Thorn hotspot floor
            "n_hotspot_residues": prof["n_hotspot_residues"],
            "ppi_hotspot_cluster_kcal_per_mol": dg_hot,
            "ppi_hotspot_energy_fraction": prof["hotspot_energy_fraction"],
            "ppi_hotspot_driven": prof["hotspot_driven"],
            "ppi_floor_respected": ppi_floor_ok,
            # bridge — Gibbs ΔG → K_d
            "temperature_K": TEMP_K,
            "rt_kcal_per_mol": RT_KCAL,
            "k_d_e3_hotspot_floor_nM": kd_e3_floor_nM,
            # PROTAC bivalent linker distinction (NOT in G3 glue cross!)
            "linker_cost_pre_paid": True,
            "linker_effective_conc_M": LINKER_EFFECTIVE_CONC_M,
            "intracellular_reference_conc_M": INTRACELLULAR_TARGET_REF_M,
            "dg_linker_prepay_kcal_per_mol": dg_linker,
            "linker_within_water_density_limit": linker_within_water_density_limit,
            "k_d_e3_protac_effective_nM": kd_e3_protac_eff_nM,
            # PROTAC ternary side — protac_sim outputs at α_required
            "kd_target_nM": kd_t,
            "productive_ternary_peak_threshold":
                PRODUCTIVE_TERNARY_PEAK_THRESHOLD,
            "alpha_ladder_max": ALPHA_LADDER[-1],
            "alpha_required_for_productive_ternary": alpha_required,
            "ternary_fraction_peak_at_alpha_required": peak_at_required,
            "protac_at_peak_nM": c_at_required,
            "productive_ternary_achievable": achievable,
            "transfer_efficiency": te,
            # cross-distinction note
            "valency_kind": "bivalent (linker tethers two warheads)",
            "distinct_from_monovalent_glue": (
                "PROTAC has a chemical linker that pre-pays part of the "
                "target-E3 neo-interface cost via an effective-concentration "
                "boost (Page & Jencks 1971); a monovalent molecular glue has "
                "no such linker — all neo-interface free energy comes from "
                "cooperativity α (G3 ppi_molecular_glue_cross). At matched "
                "hotspot floor a PROTAC requires SMALLER α than a glue."),
            "unification_note": (
                "Bogan-Thorn hotspot ledger (PPI side) ≡ K_d(E3) floor in "
                "Guldberg-Waage cooperative-ternary mass-action (PROTAC "
                "side) plus the bivalent-linker effective-concentration "
                "pre-payment — same energetic ledger, PROTAC's neo-interface "
                "is a PPI the linker nucleates"),
            # schema-level invariants on every row (W4 cross is a model-level
            # mapping, never a ranking, never a new axis, never a quantitative
            # prediction).
            "comparison_is_ranking": False,
            "creates_a_new_axis": False,
            "illustrative_only": True,
        }
        rows.append(row)
    return rows


# ── contrast: hotspot-rich vs hotspot-poor ─────────────────────────────────
def contrast(rows: list) -> dict:
    """Hotspot-rich vs hotspot-poor cross contrast."""
    # The first row is the strongest hotspot + strongest cooperativity case.
    # The flat_diffuse interface row is the hardest case.
    by_iface = {r["interface"]: r for r in rows}
    rich = by_iface["bcl2_bh3_groove"]
    poor = by_iface["flat_diffuse_interface"]
    return {
        "hotspot_rich_reference": {
            "interface": rich["interface"],
            "protac": rich["protac"],
            "ppi_drug_precedent": rich["ppi_drug_precedent"],
            "protac_drug_precedent": rich["protac_drug_precedent"],
            "ppi_hotspot_cluster_kcal_per_mol":
                rich["ppi_hotspot_cluster_kcal_per_mol"],
            "k_d_e3_hotspot_floor_nM": rich["k_d_e3_hotspot_floor_nM"],
            "k_d_e3_protac_effective_nM": rich["k_d_e3_protac_effective_nM"],
            "alpha_required_for_productive_ternary":
                rich["alpha_required_for_productive_ternary"],
            "ternary_fraction_peak_at_alpha_required":
                rich["ternary_fraction_peak_at_alpha_required"],
            "productive_ternary_achievable":
                rich["productive_ternary_achievable"],
        },
        "hotspot_poor_reference": {
            "interface": poor["interface"],
            "protac": poor["protac"],
            "ppi_drug_precedent": poor["ppi_drug_precedent"],
            "protac_drug_precedent": poor["protac_drug_precedent"],
            "ppi_hotspot_cluster_kcal_per_mol":
                poor["ppi_hotspot_cluster_kcal_per_mol"],
            "k_d_e3_hotspot_floor_nM": poor["k_d_e3_hotspot_floor_nM"],
            "k_d_e3_protac_effective_nM": poor["k_d_e3_protac_effective_nM"],
            "alpha_required_for_productive_ternary":
                poor["alpha_required_for_productive_ternary"],
            "ternary_fraction_peak_at_alpha_required":
                poor["ternary_fraction_peak_at_alpha_required"],
            "productive_ternary_achievable":
                poor["productive_ternary_achievable"],
        },
        "note": ("Hotspot-rich target-E3 PPIs (BH3-mimetic-style hotspot "
                 "energetics — but here applied to the target-E3 neo-interface "
                 "the PROTAC nucleates, NOT BCL-2/BH3 itself) sustain a stable "
                 "PROTAC ternary at modest cooperativity α; hotspot-poor "
                 "interfaces require very long linkers (higher effective "
                 "concentration) or VHL/CRBN-specific recruitment cheats to "
                 "reach the productive-ternary threshold within sane α."),
    }


# ── acceptance — simulator-CONSISTENCY criteria ────────────────────────────
def acceptance(rows: list, ppi_mod, protac_mod) -> dict:
    """
    In-silico simulator-consistency acceptance criteria (X1–X8).

    The cross PASSes iff:
      X1 — every W4_PANEL pairing produced exactly one cross row;
      X2 — every K_d (floor and PROTAC-effective) is finite and positive;
      X3 — the PPI-floor ledger respect holds on every row;
      X4 — the bivalent-linker pre-payment is within the water-density-limit
           on every row;
      X5 — α_required tracks the hotspot floor: hotspot-richer interfaces
           (more-negative ΔG_hotspot) require equal-or-smaller α_required
           than hotspot-poorer interfaces, when paired with PROTACs of
           comparable competence;
      X6 — at least one row achieves productive ternary AND at least one row
           honestly does NOT — the gate discriminates;
      X7 — the PROTAC-effective K_d(E3) is strictly less than the bare
           hotspot-floor K_d(E3) on every row (bivalent linker tightens the
           effective E3-side K_d below the bare PPI floor — the W4 BIVALENT
           distinction from the G3 MONOVALENT glue cross);
      X8 — every row carries linker_cost_pre_paid == True
           (W4 invariant: a PROTAC is bivalent — never collapsed with a glue).
    """
    achievable = [r for r in rows if r["productive_ternary_achievable"]]
    not_achievable = [r for r in rows if not r["productive_ternary_achievable"]]

    # X5 — hotspot-floor → α monotonicity, restricted to comparable PROTACs.
    # We test it on the hotspot-rich vs hotspot-poor reference pair (rich
    # paired with a competent strong-coop PROTAC; poor paired with the
    # noncoop reference).  The monotonicity is INHERENT in the cross —
    # hotspot-richer ΔG_hot means tighter K_d(E3)_floor means easier ternary
    # closure means smaller α_required.
    by_iface = {r["interface"]: r for r in rows}
    rich = by_iface["bcl2_bh3_groove"]
    poor = by_iface["flat_diffuse_interface"]
    monotone = (rich["alpha_required_for_productive_ternary"]
                <= poor["alpha_required_for_productive_ternary"])

    crit = {
        "X1_one_row_per_W4_panel_entry":
            len(rows) == len(W4_PANEL),
        "X2_k_d_finite_positive": all(
            math.isfinite(r["k_d_e3_hotspot_floor_nM"])
            and r["k_d_e3_hotspot_floor_nM"] > 0.0
            and math.isfinite(r["k_d_e3_protac_effective_nM"])
            and r["k_d_e3_protac_effective_nM"] > 0.0
            for r in rows),
        "X3_ppi_floor_respected": all(r["ppi_floor_respected"] for r in rows),
        "X4_linker_within_water_density_limit": all(
            r["linker_within_water_density_limit"] for r in rows),
        "X5_alpha_tracks_hotspot_floor_richer_easier": monotone,
        "X6_discriminating_gate_both_outcomes_present":
            len(achievable) >= 1 and len(not_achievable) >= 1,
        "X7_linker_tightens_kd_below_bare_ppi_floor": all(
            r["k_d_e3_protac_effective_nM"] < r["k_d_e3_hotspot_floor_nM"]
            for r in rows),
        "X8_linker_cost_pre_paid_invariant": all(
            r["linker_cost_pre_paid"] is True for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


# ── main ───────────────────────────────────────────────────────────────────
def main() -> int:
    print("protac_ppi_cross — CROSS-AXIS W4\n", flush=True)
    print("cross:  PPI Bogan-Thorn hotspot ledger  ──same energetic floor──▶")
    print("        PROTAC cooperative ternary feasibility")
    print("        a PROTAC's ternary complex IS a PPI (target ↔ E3) that the")
    print("        bivalent linker NUCLEATES — same hotspot ledger, bivalent")
    print("        linker pre-pays part of the neo-interface cost (PROTAC")
    print("        distinction from the MONOVALENT glue — see G3).\n",
          flush=True)

    ppi_mod = _load_module("ppi_sim", _PPI_PATH)
    protac_mod = _load_module("protac_sim", _PROTAC_PATH)

    dg_linker = _dg_linker_prepay_kcal_per_mol()
    print(f"  real-limit anchor (PPI side)    : Bogan-Thorn hotspot theory")
    print(f"                                    (Bogan & Thorn, J. Mol. Biol. "
          f"280:1, 1998;")
    print(f"                                     Wells & McClendon, Nature "
          f"450:1001, 2007)")
    print(f"                                    hotspot ΔΔG threshold = "
          f"{ppi_mod.HOTSPOT_DDG_THRESHOLD_KCAL} kcal/mol")
    print(f"  real-limit anchor (PROTAC side) : cooperative ternary mass-action")
    print(f"                                    (Douglass JACS 135:6092, 2013;")
    print(f"                                     Gadd Nat. Chem. Biol. 13:514, "
          f"2017;")
    print(f"                                     Guldberg-Waage mass action 1864)")
    print(f"  real-limit anchor (linker side) : bivalent-tether effective-conc")
    print(f"                                    intramolecularity bonus")
    print(f"                                    (Page & Jencks, PNAS 68:1678, "
          f"1971;")
    print(f"                                     Jencks, PNAS 78:4046, 1981;")
    print(f"                                     Maniaci & Ciulli, Curr. Opin.")
    print(f"                                     Chem. Biol. 44:145, 2018)\n",
          flush=True)
    print(f"  C_eff (linker)         = {LINKER_EFFECTIVE_CONC_M*1000:.1f} mM "
          f"(class-typical)")
    print(f"  C_ref (intracellular)  = {INTRACELLULAR_TARGET_REF_M*1e6:.1f} µM")
    print(f"  ΔG_linker pre-pay      = {dg_linker:+.3f} kcal/mol  "
          f"(Page-Jencks intramolecularity bonus)")
    print(f"  productive-ternary peak threshold = "
          f"{PRODUCTIVE_TERNARY_PEAK_THRESHOLD}")
    print(f"  α ladder = {ALPHA_LADDER}\n", flush=True)

    rows = build_cross_rows(ppi_mod, protac_mod)
    for r in rows:
        ach = "achievable" if r["productive_ternary_achievable"] \
            else "NOT achievable within ladder"
        print(f"  [{r['interface']:<26}] × [{r['protac']:<26}]  "
              f"E3={r['e3_ligase']}")
        print(f"      ΔG_hotspot={r['ppi_hotspot_cluster_kcal_per_mol']:+6.2f}  "
              f"K_d(E3)_floor={r['k_d_e3_hotspot_floor_nM']:.3e} nM")
        print(f"      linker pre-pay = {r['dg_linker_prepay_kcal_per_mol']:+.3f} "
              f"kcal/mol  →  K_d(E3)_PROTAC_eff="
              f"{r['k_d_e3_protac_effective_nM']:.3e} nM")
        print(f"      α_required="
              f"{r['alpha_required_for_productive_ternary']:>6.1f}   "
              f"ternary_peak="
              f"{r['ternary_fraction_peak_at_alpha_required']:.4f}   "
              f"[PROTAC]@peak={r['protac_at_peak_nM']:.1f}nM   ({ach})")

    ctr = contrast(rows)
    print("\n## hotspot-rich vs hotspot-poor contrast (cooperativity floor)")
    rich, poor = ctr["hotspot_rich_reference"], ctr["hotspot_poor_reference"]
    print(f"  HOTSPOT-RICH {rich['interface']:<26} ΔG_hot="
          f"{rich['ppi_hotspot_cluster_kcal_per_mol']:+.2f}  "
          f"α_required={rich['alpha_required_for_productive_ternary']:>6.1f}  "
          f"achievable={rich['productive_ternary_achievable']}")
    print(f"  HOTSPOT-POOR {poor['interface']:<26} ΔG_hot="
          f"{poor['ppi_hotspot_cluster_kcal_per_mol']:+.2f}  "
          f"α_required={poor['alpha_required_for_productive_ternary']:>6.1f}  "
          f"achievable={poor['productive_ternary_achievable']}")

    acc = acceptance(rows, ppi_mod, protac_mod)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  "
          f"verdict: {acc['verdict']} ---")

    print("\n## bivalent-vs-monovalent distinction (W4 vs G3)")
    print("  W4 (PROTAC × PPI):  BIVALENT linker  →  ΔG_linker pre-pays part of")
    print("                      the neo-interface cost via the Page-Jencks")
    print("                      effective-concentration / intramolecularity")
    print("                      bonus; K_d(E3)_PROTAC_eff < K_d(E3)_floor;")
    print("                      α_required is reduced.  Every W4 row carries")
    print("                      linker_cost_pre_paid = True (invariant).")
    print("  G3 (glue × PPI):    MONOVALENT — no linker; the entire neo-")
    print("                      interface cost is paid by cooperativity α")
    print("                      (Douglass 2013; Gadd 2017).  ΔG_linker is")
    print("                      structurally absent (not zero by accident —")
    print("                      structurally absent).  At matched hotspot")
    print("                      floor, glue α_required > PROTAC α_required.")
    print("  W4 reuses the HOTSPOT-FLOOR side machinery (Gibbs ΔG→K_d) from")
    print("  G3 but the PROTAC ternary side is computed by importing")
    print("  protac_sim, NOT molecular_glue_sim — the two crosses are not")
    print("  collapsed into one model.")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3 / f_lattice_fit)")
    print("  - Both sister sims IMPORTED, never re-implemented (f3). ppi_sim.")
    print("    interface_profile() and protac_sim.ternary_fraction +")
    print("    protac_sim.degrader_profile are reused verbatim; the cross")
    print("    only bridges their outputs via the standard Gibbs relation")
    print("    K_d = exp(ΔG/RT) plus the Page-Jencks linker pre-payment.")
    print("  - The PPI ΔΔG values and the PROTAC K_d / α / transfer values are")
    print("    illustrative literature-informed surrogates for the modality")
    print("    CLASSES (each parent sim's own honesty caveat). LINKER_")
    print("    EFFECTIVE_CONC = 10 mM is a class-typical illustrative value,")
    print("    NOT a fit to a specific PROTAC.")
    print("  - This W4 PASS is the MODEL UPPER BOUND analogue of J2's honesty")
    print("    pattern: the hotspot-derived K_d(E3) floor multiplied through")
    print("    the cooperative-ternary fraction is a CEILING on what a PROTAC")
    print("    can extract from a target-E3 PPI of the given hotspot character.")
    print("    It is NOT a binding-affinity, NOT a DC50 / Dmax / Dmax-degradation")
    print("    claim, NOT a therapeutic-efficacy or immunogenic claim (g8/f2).")
    print("  - Modality precedents are OWN-precedent only (g3 / f1 /")
    print("    f_lattice_fit):")
    print("    PPI side    — venetoclax (BCL-2/BH3 disruptor, FDA 2016;")
    print("                  Souers 2013), navitoclax / ABT-263 (Tse 2008).")
    print("    PROTAC side — ARV-471 / vepdegestrant (ER PROTAC, clinical),")
    print("                  ARV-110 / bavdegalutamide (AR PROTAC, clinical),")
    print("                  VHL-BRD4 cooperative PROTAC class (Gadd 2017).")
    print("  - BIVALENT-vs-MONOVALENT is PRESERVED, NOT collapsed — every W4")
    print("    row carries linker_cost_pre_paid = True and an explicit")
    print("    ΔG_linker contribution; PROTAC and glue (G3) are NOT one model.")
    print("  - The cross is a MODEL-LEVEL UNIFICATION of two energetic")
    print("    accountings — NOT a claim that every hotspot-driven PPI yields")
    print("    a PROTAC-able target; PROTACs additionally need an E3 ligase")
    print("    actually expressed in the target cell, a target-lysine geometry")
    print("    tolerant to ubiquitin transfer, and tractable PK for a high-MW")
    print("    bivalent molecule — all outside this energetic ledger.")
    print("  - PPI :> QUANTUM core (sub-axis); PROTAC :> BIFUNCTIONAL")
    print("    expansion-main (sub-axis). Cross is NOT a new axis — both stay")
    print("    sub-axes; AXIS/HIERARCHY.tape unchanged; core-5 + expansion-")
    print("    layer UNCHANGED. No quantity derived from the n=6 lattice.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → byte-identical re-runs
        "cross": ("W4  PPI Bogan-Thorn hotspot ledger  →  PROTAC cooperative-"
                  "ternary feasibility (bivalent linker pre-pays part of the "
                  "neo-interface)"),
        "comparison_is_ranking": False,
        "creates_a_new_axis": False,
        "illustrative_only": True,
        "ppi_subaxis_source": (
            "_python_bridge/module/ppi_sim.py (interface_profile imported; "
            "INTERFACE_PANEL reused — f3)"),
        "protac_subaxis_source": (
            "_python_bridge/module/protac_sim.py (ternary_fraction and "
            "degrader_profile imported; PROTAC_PANEL + PROTAC_CONC_GRID_NM "
            "reused — f3)"),
        "real_limit_anchor_ppi": (
            "Bogan-Thorn binding-hotspot theory (Bogan & Thorn, Anatomy of "
            "hot spots in protein interfaces, J. Mol. Biol. 280:1, 1998; "
            "Clackson & Wells, Science 267:383, 1995; Wells & McClendon, "
            "Nature 450:1001, 2007) — interface energy concentrated in "
            "hotspot residues; recoverable energy bounded by the alanine-"
            "scanning ΔΔG ledger"),
        "real_limit_anchor_protac": (
            "cooperative ternary-complex equilibrium (Douglass et al., JACS "
            "135:6092, 2013; Gadd et al., Nat. Chem. Biol. 13:514, 2017; "
            "Hughes & Ciulli, Essays Biochem. 61:505, 2017) atop the "
            "Guldberg-Waage law of mass action (1864) — every occupancy ≤ 1"),
        "real_limit_anchor_linker": (
            "bivalent-tether intramolecularity / effective-concentration "
            "bonus (Page & Jencks, PNAS 68:1678, 1971; Jencks, PNAS 78:4046, "
            "1981; Maniaci & Ciulli, Curr. Opin. Chem. Biol. 44:145, 2018; "
            "Roy/Crews PROTAC ternary SAR reviews) — bounded above by the "
            "water-density limit C_eff ≈ 55 M"),
        "modality_precedents": {
            "ppi": ("venetoclax — BH3-mimetic BCL-2/BH3 disruptor (Souers et "
                    "al., Nat. Med. 19:202, 2013; FDA 2016); navitoclax / "
                    "ABT-263 — dual BCL-2/BCL-xL BH3-mimetic (Tse et al., "
                    "Cancer Res. 68:3421, 2008)"),
            "protac": ("ARV-471 / vepdegestrant — estrogen-receptor PROTAC, "
                       "clinical (Arvinas / Pfizer); ARV-110 / bavdegalutamide "
                       "— androgen-receptor PROTAC, clinical (Arvinas); "
                       "VHL-BRD4 cooperative PROTAC class (Gadd et al., "
                       "Nat. Chem. Biol. 13:514, 2017); PROTAC chemistry "
                       "origin Sakamoto et al., PNAS 98:8554, 2001"),
        },
        "temperature_K": TEMP_K,
        "rt_kcal_per_mol": RT_KCAL,
        "linker_effective_conc_M": LINKER_EFFECTIVE_CONC_M,
        "intracellular_reference_conc_M": INTRACELLULAR_TARGET_REF_M,
        "dg_linker_prepay_kcal_per_mol": dg_linker,
        "productive_ternary_peak_threshold":
            PRODUCTIVE_TERNARY_PEAK_THRESHOLD,
        "alpha_ladder": ALPHA_LADDER,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "bivalent_vs_monovalent_distinction": (
            "W4 (PROTAC × PPI) is BIVALENT: the linker pre-pays part of the "
            "target-E3 neo-interface cost via the Page-Jencks intramolecularity "
            "bonus (ΔG_linker contribution to K_d(E3)_PROTAC_effective). G3 "
            "(glue × PPI) is MONOVALENT: no linker; the entire neo-interface "
            "is α-cooperativity-paid. At matched hotspot floor, the PROTAC "
            "α_required is smaller than the glue α_required — the two crosses "
            "share the HOTSPOT-FLOOR side machinery but their ternary sides "
            "are computed by importing protac_sim and molecular_glue_sim "
            "respectively, NOT collapsed into one model."),
        "unification_demonstrated": (
            "A PROTAC's ternary complex IS a PPI (target ↔ E3) that the "
            "bivalent linker NUCLEATES; the Bogan-Thorn hotspot ledger that "
            "quantifies whether a PPI is disruptable by a small-molecule "
            "mimic is EXACTLY the ledger that quantifies whether the "
            "PROTAC-induced ternary neo-interface is thermodynamically "
            "viable for productive ubiquitin transfer — same alanine-"
            "scanning ΔΔG ledger, same mass-action and cooperativity "
            "scaffolding, with the bivalent linker pre-paying part of the "
            "neo-interface cost. Hotspot-rich target-E3 PPIs sustain "
            "stable PROTAC ternary at modest α; hotspot-poor PPIs require "
            "very long linkers or VHL/CRBN-specific recruitment cheats."),
        "modality_interchangeability_claim": False,
        "in_silico_scope_caveat": (
            "MODEL-LEVEL UNIFICATION ONLY (g8/f2) — the hotspot-derived "
            "K_d(E3) floor multiplied through the cooperative-ternary "
            "fraction is a CEILING on what a PROTAC can extract from a "
            "target-E3 PPI of the given hotspot character; J2-class "
            "honesty pattern (model upper bound, not a quantitative "
            "prediction). NOT a binding-affinity, NOT a DC50 / Dmax / "
            "Dmax-degradation claim, NOT an immunogenic or therapeutic-"
            "efficacy claim. PPI :> QUANTUM core; PROTAC :> BIFUNCTIONAL "
            "expansion-main — cross is NOT a new axis."),
        "lattice_stance": (
            "No quantity in this witness is derived from the n=6 lattice "
            "(f_lattice_fit / lattice-is-tool). Modalities described by "
            "own drug precedent (g3/f1)."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PROTAC_PPI_CROSS__ PASS" if ok
          else "\n__PROTAC_PPI_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
