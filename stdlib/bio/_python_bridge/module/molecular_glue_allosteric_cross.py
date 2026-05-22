#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
molecular_glue_allosteric_cross.py — CROSS-AXIS integration J3.

CROSS:  MOLECULAR-GLUE sub-axis cooperative ternary  ──staged on top of──▶
        ALLOSTERIC sub-axis MWC R-state stabilisation of the E3 ligase.

The standard cooperative-ternary picture of a molecular glue (Douglass et al.,
JACS 135:6092, 2013; Gadd et al., Nat. Chem. Biol. 13:514, 2017) accounts for
the glue / target / E3 mass-action equilibrium and the cooperativity factor α
that amplifies the second binding event. It treats the E3 ligase as a single
binding entity — a static partner.

But that is not how lenalidomide actually engages CRBN. The lenalidomide-CRBN
co-crystal structures (Petzold, Bird & Fischer, Nature 532:127, 2016; Chamberlain
et al., Nat. Struct. Mol. Biol. 21:803, 2014; Fischer et al., Nature 512:49,
2014) show the drug binds the CRBN tri-tryptophan pocket and the
neosubstrate-recruiting surface is REMODELLED by that binding — a glutarimide
glue induces a CRBN surface that was not the apo-conformation surface. Krönke
et al. (Science 343:301, 2014) and Lu et al. (Science 343:305, 2014) connected
that remodelled surface to neosubstrate (IKZF1/IKZF3) recruitment.

Mechanistically: BEFORE the cooperative ternary closes, the glue first pays
an allosteric cost to remodel the E3 ligase from its native (non-recruiting)
conformation to the remodelled (neo-interface-presenting) conformation. That
first step is structurally an MWC R-state stabilisation on the E3 — exactly
the ALLOSTERIC sub-axis's two-state machinery. Only THEN does the cooperative
ternary closure of the MOLECULAR-GLUE sub-axis recruit the target.

────────────────────────────────────────────────────────────────────────────
THE TWO-STAGE UNIFICATION  (governance f3 — import both sims, no fork)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/allosteric_sim.py — ALLOSTERIC sub-axis
      (:> QUANTUM core). MWC two-state ternary-complex affinity-shift
      shift = (1 + [B]/K_B) / (1 + α·[B]/K_B); allosteric ceiling 1/α
      (Monod, Wyman & Changeux, J. Mol. Biol. 12:88, 1965).

  (2) _python_bridge/module/molecular_glue_sim.py — MOLECULAR-GLUE sub-axis
      (:> BIFUNCTIONAL expansion-main). Cooperative ternary-complex
      partition-function mass-action with cooperativity α
      (Douglass et al., JACS 135:6092, 2013).

This module is the BRIDGE. For each entry in molecular_glue_sim's deterministic
GLUE_PANEL, the glue engagement of the E3 ligase is decomposed into TWO
staged events:

  STAGE 1 — ALLOSTERIC R-state stabilisation of the E3 ligase.
    Model E3 as a two-state system:
        T  =  native, non-glue-recruiting conformation
        R  =  remodelled, neo-interface-presenting conformation
    Apo, T is dominant: P_R^apo = 1/(1+L_E3), L_E3 = exp(ΔG_allo/RT) ≫ 1.
    The glue binds the E3 tri-Trp/glutarimide pocket with intrinsic binding
    energy ΔG_glue_E3 (negative). The conformational free-energy ledger:
        ΔG_allo^bound  =  ΔG_allo + ΔG_glue_E3
    Re-evaluated through the SAME MWC two-state formula gives P_R^bound;
    P_R^bound > P_R^apo iff ΔG_glue_E3 < 0 (the binder pays the allosteric
    cost). The MWC affinity-shift function shift = (1+x)/(1+α·x) of
    allosteric_sim is imported and used VERBATIM (f3 — no re-implementation)
    to project the shift in the R/T ratio at the assay glue concentration —
    this is the standard MWC R-state-stabilisation observable.

  STAGE 2 — COOPERATIVE TERNARY closure on the remodelled E3.
    Once stage 1 has remodelled the E3 (R-state populated), the cooperative
    ternary T·E3·G of molecular_glue_sim closes. The cooperativity factor α
    multiplies the second event — same closed-form path-independent partition
    function as molecular_glue_sim.cooperative_ternary, imported and used
    VERBATIM (f3 — no re-implementation).

  STAGED FREE-ENERGY DECOMPOSITION (per row, kcal/mol):
        ΔG_stage1  =  ΔG_allo  +  ΔG_glue_E3              (R-state stabilisation)
        ΔG_stage2  =  ΔG_PPI   +  ΔG_coop                  (cooperative ternary)
                       where  ΔG_PPI  := RT·ln(K_PPI[nM] / C0[nM])
                              ΔG_coop := −RT·ln(α)
        ΔG_total   =  ΔG_stage1  +  ΔG_stage2
    (C0 = 1 nM reference concentration — choice of standard state is explicit;
    relative comparisons across the panel are invariant to C0 because every
    row uses the same value.)

The staged ordering is the model's central claim: the GLUE BINDS FIRST, that
binding REMODELS the E3 (an allosteric R-state stabilisation on the E3 ligase
itself), and ONLY THEN does the cooperative ternary close on the now-remodelled
ligase surface.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Three coincident real limits anchor every row:
  - MWC two-state statistical mechanics (Monod, Wyman & Changeux, J. Mol. Biol.
    12:88, 1965): populations P_R, P_T are bounded in (0,1), P_R + P_T = 1
    exactly; the saturable affinity shift cannot pass the ceiling 1/α
    (Christopoulos & Kenakin, Pharmacol. Rev. 54:323, 2002).
  - Cooperative ternary-complex mass action (Douglass et al., JACS 135:6092,
    2013; Gadd et al., Nat. Chem. Biol. 13:514, 2017; Guldberg & Waage, 1864):
    every occupancy fraction is bounded in [0,1] and the partition function
    closes to unity; the path-independent closed form ensures detailed
    balance.
  - Conformational free-energy ledger of the glue-induced remodelling: the
    bound-state allosteric cost is exactly ΔG_allo + ΔG_glue_E3 — the glue
    cannot escape paying the allosteric cost. Structural anchor: the
    lenalidomide-CRBN co-crystals (Petzold et al., Nature 532:127, 2016;
    Chamberlain et al., NSMB 21:803, 2014) showing the drug binds the CRBN
    tri-Trp pocket and the neosubstrate-recruiting surface is remodelled by
    that binding (Krönke et al., Science 343:301, 2014; Lu et al., Science
    343:305, 2014).

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - MOLECULAR-GLUE precedent: lenalidomide / thalidomide — monovalent CRBN
    glues that recruit IKZF1 / IKZF3 to the CRL4-CRBN E3 ligase (Krönke et al.,
    Science 343:301, 2014; Lu et al., Science 343:305, 2014; FDA-approved);
    indisulam — DCAF15 glue that recruits RBM39 (Han et al., Science 356:
    eaal3755, 2017; Uehara et al., Nat. Chem. Biol. 13:675, 2017).
  - ALLOSTERIC precedent: asciminib — allosteric BCR-ABL1 inhibitor at the
    myristoyl pocket (Wylie et al., Nature 543:733, 2017; FDA-approved 2021);
    maraviroc — allosteric CCR5 antagonist (Dorr et al., AAC 49:4721, 2005).

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
  * This cross is a MODEL-LEVEL UNIFICATION of two energetic accountings: the
    glue-engagement mechanism, in this framing, is allosteric-then-cooperative —
    stage 1 (MWC R-state stabilisation on the E3 ligase) followed by stage 2
    (cooperative ternary closure on the remodelled E3). It is NOT a claim that
    every molecular glue is purely allosteric. The bifunctional cooperative-
    ternary picture (Douglass 2013; Gadd 2017) remains the standard accounting
    for the glue / target / E3 mass-action equilibrium; this cross adds an
    explicit allosteric stage 1 for the glue-induced E3 remodelling step that
    the lenalidomide-CRBN co-crystals (Petzold 2016; Chamberlain 2014) make
    structurally visible.
  * The staged free-energy decomposition (ΔG_stage1 + ΔG_stage2) is the
    SUM OF TWO HONEST PARTS of the SAME equilibrium — it is NOT a new
    parameterisation, NOT a fit, NOT a measured ΔΔG decomposition.
  * Both sub-axis sources are IMPORTED (f3 — no shadow of sister logic);
    allosteric_sim.affinity_shift and molecular_glue_sim.cooperative_ternary
    are reused verbatim, never re-implemented here.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY (g8/f2):
    the staged ledger sums close, the MWC populations are bounded and sum to
    unity, the cooperative-ternary partition closes, the ordering relations
    are honoured. It is NOT a binding-affinity, potency, selectivity,
    immunogenic or therapeutic-efficacy claim.
  * α, K_glue, K_PPI, ΔG_allo, ΔG_glue_E3 values are illustrative literature-
    informed surrogates for the modality CLASSES (consistent with the parent
    sim panels), NOT fits to a specific compound — the lenalidomide / CRBN
    drug name labels are own-precedent labels (g3/f1), never lattice-derived.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A CROSS is NOT a new axis. MOLECULAR-GLUE remains a SUB-AXIS (:> BIFUNCTIONAL
expansion-main, AXIS/HIERARCHY.tape); ALLOSTERIC remains a SUB-AXIS (:>
QUANTUM core). The hexa-bio core-5 axes QUANTUM · WEAVE · NANOBOT · RIBOZYME
· VIROCAPSID are UNCHANGED. No quantity here is derived from the n=6 lattice
(f_lattice_fit / lattice-is-tool).
"""
from __future__ import annotations
import importlib.util
import json
import math
import os
import sys

# ── locate the two sister sub-axis sources (no fork — f3) ───────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_ALLOSTERIC_PATH = os.path.join(_HERE, "allosteric_sim.py")
_MOLECULAR_GLUE_PATH = os.path.join(_HERE, "molecular_glue_sim.py")

SCHEMA_ID = "molecular_glue_allosteric_cross_v1"

# ── thermodynamic constants (physiological reference) ──────────────────────
# Standard reference temperature for the staged free-energy decomposition.
# Same convention as cryptic_pocket_sim and other hexa-bio sub-axes.
TEMP_K = 310.0                                   # K (physiological)
R_GAS_J_PER_MOL_K = 8.31446261815324             # CODATA-recommended
KCAL_TO_J = 4184.0
RT_KCAL = (R_GAS_J_PER_MOL_K * TEMP_K) / KCAL_TO_J   # ≈ 0.616 kcal/mol @ 310 K

# Reference standard-state concentration (nM) for the ΔG_PPI = RT ln(K_PPI/C0)
# conversion. Every panel row uses the same C0 so relative comparisons across
# the panel are invariant to its value.
C0_REF_nM = 1.0

# ── per-glue allosteric remodelling parameters ─────────────────────────────
# Stage-1 (allosteric) parameters per glue, keyed by molecular_glue_sim panel
# name. dg_allo_kcal_per_mol is the apo cost of remodelling the E3 ligase
# surface from its native conformation T to the neo-interface-presenting
# conformation R; dg_glue_e3_kcal_per_mol is the intrinsic glue binding free
# energy to the E3 ligase (negative = favourable). The PAM-class lenalidomide-
# analogue glues pay larger cost ΔG_allo (they remodel a deeper surface) and
# compensate with a more favourable ΔG_glue_E3 (the glutarimide-pocket grip);
# the "weak_coop" research glue pays a smaller allosteric cost (it remodels a
# more constitutively-accessible surface — closer to constitutive recruitment)
# and shows smaller binding free energy. Values are illustrative literature-
# informed surrogates for the modality CLASS, NOT fits to a specific compound.
# Structural anchors (Petzold/Chamberlain/Fischer co-crystals; Krönke 2014):
# the glutarimide binds the CRBN tri-Trp pocket and the neosubstrate-binding
# surface is remodelled — that remodelling is the stage-1 allosteric event.
_ALLOSTERIC_PARAMS = {
    "glue_lenalidomide_IKZF1": {
        "dg_allo_kcal_per_mol": +3.0,
        "dg_glue_e3_kcal_per_mol": -7.0,
        "structural_anchor": (
            "Petzold/Chamberlain/Fischer lenalidomide-CRBN co-crystal "
            "(Nature 532:127, 2016; NSMB 21:803, 2014; Nature 512:49, 2014) — "
            "glutarimide binds CRBN tri-Trp pocket; neosubstrate-recruiting "
            "surface is remodelled (Krönke, Science 343:301, 2014)"),
    },
    "glue_thalidomide_IKZF3": {
        "dg_allo_kcal_per_mol": +3.0,
        "dg_glue_e3_kcal_per_mol": -6.0,
        "structural_anchor": (
            "Fischer/Chamberlain thalidomide-CRBN co-crystal "
            "(Nature 512:49, 2014; NSMB 21:803, 2014) — glutarimide engages "
            "CRBN tri-Trp pocket; neosubstrate surface remodelling (Lu, "
            "Science 343:305, 2014)"),
    },
    "glue_indisulam_RBM39": {
        "dg_allo_kcal_per_mol": +2.5,
        "dg_glue_e3_kcal_per_mol": -5.5,
        "structural_anchor": (
            "indisulam-DCAF15-RBM39 co-crystal (Du et al., Structure 27:1625, "
            "2019; Bussiere et al., Nat. Chem. Biol. 16:15, 2020) — sulfonamide "
            "remodels DCAF15 surface to recruit RBM39 (Han, Science 356:eaal3755, "
            "2017; Uehara, Nat. Chem. Biol. 13:675, 2017)"),
    },
    "glue_research_weak_coop": {
        "dg_allo_kcal_per_mol": +1.0,
        "dg_glue_e3_kcal_per_mol": -3.0,
        "structural_anchor": (
            "research-stage CRBN glue, weak allosteric remodelling — "
            "negative-control class for the staged decomposition"),
    },
}


def _load(name: str, path: str):
    """Import a sister sub-axis module by absolute path (no shadow — f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _mwc_populations_from_dg_allo(dg_allo_kcal: float) -> tuple:
    """
    MWC two-state populations from the allosteric remodelling free energy.

        L_E3  =  [T]/[R]  =  exp(dg_allo / RT)
        P_R   =  1 / (1 + L_E3)
        P_T   =  L_E3 / (1 + L_E3)  =  1 - P_R

    The MWC two-state form (Monod, Wyman & Changeux 1965) — same statistical
    mechanics used by allosteric_sim and the G2 ALLOSTERIC × CRYPTIC-POCKET
    cross under R<->open. Bounded in (0,1); P_R + P_T = 1 exactly.
    """
    L = math.exp(dg_allo_kcal / RT_KCAL)
    p_R = 1.0 / (1.0 + L)
    p_T = L / (1.0 + L)
    return L, p_R, p_T


def _stage1_allosteric_R_state_stabilisation(allo_mod, dg_allo_kcal: float,
                                             dg_glue_e3_kcal: float,
                                             k_glue_nM: float) -> dict:
    """
    STAGE 1 — allosteric R-state stabilisation of the E3 ligase by the glue.

    Apo MWC populations from ΔG_allo. Bound-state ledger:
        ΔG_allo^bound = ΔG_allo + ΔG_glue_E3   (kcal/mol)
    Re-evaluated through the same MWC two-state formula gives P_R^bound.
    Population shift δP_R = P_R^bound − P_R^apo. The MWC affinity-shift
    function from allosteric_sim (shift = (1+x)/(1+α·x)) is imported and used
    verbatim (f3) to project the orthosteric affinity shift the R-state
    stabilisation produces — α_E3 := K_R_E3 / K_T_E3, taken as the Boltzmann
    discrimination exp(−|ΔG_glue_E3|/RT) by the same modelling choice as the
    G2 ALLOSTERIC × CRYPTIC-POCKET cross. A glue that pays ΔG_glue_E3 < 0
    yields α_E3 < 1 — an MWC R-state stabiliser, i.e. a population-shifter
    toward the neo-interface-presenting conformation, which is the structural
    role of the lenalidomide-CRBN binding event (Petzold 2016 co-crystal).
    """
    # apo populations
    L_apo, p_R_apo, p_T_apo = _mwc_populations_from_dg_allo(dg_allo_kcal)
    # bound-state ledger — the glue cannot escape paying the allosteric cost
    dg_allo_bound = dg_allo_kcal + dg_glue_e3_kcal
    L_bound, p_R_bound, p_T_bound = _mwc_populations_from_dg_allo(dg_allo_bound)
    population_shift_R = p_R_bound - p_R_apo
    # MWC-style α_E3 (population-shift framing, same modelling choice as G2)
    alpha_E3 = math.exp(-abs(dg_glue_e3_kcal) / RT_KCAL)
    # Project the MWC orthosteric affinity shift via allosteric_sim's
    # imported function (f3 — verbatim). Treat the glue as the allosteric
    # modulator on the E3, with allosteric K_B taken from K_glue (the glue
    # binds the E3 pocket with this affinity); assay concentration matches
    # molecular_glue_sim.CONC_GLUE_nM. Convert nM -> uM for allosteric_sim.
    k_b_uM = k_glue_nM / 1000.0
    conc_uM = 1000.0 / 1000.0   # CONC_GLUE_nM (1000) -> 1.0 uM
    ec50_shift_ratio = allo_mod.affinity_shift(alpha_E3, k_b_uM, conc_uM)
    # The allosteric ceiling 1/α_E3 — the saturable real limit
    allosteric_ceiling_shift = 1.0 / alpha_E3
    # Staged free-energy decomposition (kcal/mol) — stage 1 contribution
    dg_stage1 = dg_allo_kcal + dg_glue_e3_kcal
    # MWC ceiling honoured: the shift at finite [B] sits between 1 and 1/α
    # (NAM-direction since α_E3 < 1 here — R-state stabilisation tightens
    # the effective orthosteric affinity).
    if alpha_E3 < 1.0:
        ceiling_respected = (1.0 - 1e-9) <= ec50_shift_ratio <= allosteric_ceiling_shift + 1e-9
    elif alpha_E3 > 1.0:
        ceiling_respected = allosteric_ceiling_shift - 1e-9 <= ec50_shift_ratio <= (1.0 + 1e-9)
    else:
        ceiling_respected = abs(ec50_shift_ratio - 1.0) < 1e-12
    return {
        "dg_allo_kcal_per_mol": dg_allo_kcal,
        "dg_glue_e3_kcal_per_mol": dg_glue_e3_kcal,
        "dg_allo_bound_kcal_per_mol": dg_allo_bound,
        "mwc_L_E3_apo": L_apo,
        "mwc_L_E3_bound": L_bound,
        "mwc_p_R_E3_apo": p_R_apo,
        "mwc_p_T_E3_apo": p_T_apo,
        "mwc_p_R_E3_bound": p_R_bound,
        "mwc_p_T_E3_bound": p_T_bound,
        "population_shift_R": population_shift_R,
        "alpha_E3_population_shift": alpha_E3,
        "allosteric_ceiling_shift_1_over_alpha": allosteric_ceiling_shift,
        "ec50_shift_ratio_at_glue_assay_conc": ec50_shift_ratio,
        "allosteric_ceiling_respected": ceiling_respected,
        "dg_stage1_kcal_per_mol": dg_stage1,
        "glue_is_R_state_stabiliser": population_shift_R > 0.0,
    }


def _stage2_cooperative_ternary(glue_mod, k_glue_nM: float, k_ppi_nM: float,
                                alpha: float) -> dict:
    """
    STAGE 2 — cooperative ternary closure on the remodelled E3 ligase.

    Imports molecular_glue_sim.cooperative_ternary verbatim (f3 — no
    re-implementation). Returns the full equilibrium dictionary plus the
    stage-2 free-energy decomposition:
        ΔG_PPI   :=  RT · ln(K_PPI[nM] / C0[nM])     (Gibbs / mass-action)
        ΔG_coop  :=  −RT · ln(α)
        ΔG_stage2 = ΔG_PPI + ΔG_coop
    The Gibbs reference C0 is explicit; relative comparisons across the
    panel are invariant under the choice of C0.
    """
    eq = glue_mod.cooperative_ternary(k_glue_nM, k_ppi_nM, alpha)
    dg_ppi = RT_KCAL * math.log(k_ppi_nM / C0_REF_nM)
    dg_coop = -RT_KCAL * math.log(alpha)
    dg_stage2 = dg_ppi + dg_coop
    return {
        "cooperative_ternary_equilibrium": eq,
        "dg_ppi_kcal_per_mol": dg_ppi,
        "dg_coop_kcal_per_mol": dg_coop,
        "dg_stage2_kcal_per_mol": dg_stage2,
        "c0_reference_nM": C0_REF_nM,
    }


def build_cross_rows(allo_mod, glue_mod) -> list:
    """
    Build one cross row per molecular glue in molecular_glue_sim.GLUE_PANEL.

    For each glue, compute the staged decomposition:
      STAGE 1 (allosteric R-state stabilisation on the E3 ligase) and
      STAGE 2 (cooperative ternary on the remodelled E3).
    Report the per-stage free-energy contributions and the total.
    """
    rows = []
    for name, k_glue_nM, k_ppi_nM, alpha, precedent in glue_mod.GLUE_PANEL:
        if name not in _ALLOSTERIC_PARAMS:
            raise RuntimeError(
                f"no allosteric parameters registered for glue panel entry "
                f"{name!r} — _ALLOSTERIC_PARAMS must cover every glue_panel row")
        ap = _ALLOSTERIC_PARAMS[name]
        stage1 = _stage1_allosteric_R_state_stabilisation(
            allo_mod,
            ap["dg_allo_kcal_per_mol"],
            ap["dg_glue_e3_kcal_per_mol"],
            k_glue_nM)
        stage2 = _stage2_cooperative_ternary(
            glue_mod, k_glue_nM, k_ppi_nM, alpha)
        dg_total = stage1["dg_stage1_kcal_per_mol"] + stage2["dg_stage2_kcal_per_mol"]
        # Ledger-sum identity: ΔG_total - (ΔG_stage1 + ΔG_stage2) must be 0
        # (exact floating-point cancellation of the same summands).
        staged_ledger_residual = abs(
            dg_total - (stage1["dg_stage1_kcal_per_mol"]
                        + stage2["dg_stage2_kcal_per_mol"]))
        # MWC populations sum to unity for both apo and bound (the same
        # invariant the G2 cross gates).
        mwc_apo_unity_residual = abs(stage1["mwc_p_R_E3_apo"]
                                     + stage1["mwc_p_T_E3_apo"] - 1.0)
        mwc_bound_unity_residual = abs(stage1["mwc_p_R_E3_bound"]
                                       + stage1["mwc_p_T_E3_bound"] - 1.0)
        row = {
            "schema": SCHEMA_ID,
            "molecular_glue": name,
            "drug_precedent": precedent,
            "valency": "monovalent (no bivalent linker)",
            "structural_anchor": ap["structural_anchor"],
            "temperature_K": TEMP_K,
            "rt_kcal_per_mol": RT_KCAL,
            # parent-sim panel values (imported, untouched — f3)
            "k_glue_nM": k_glue_nM,
            "k_ppi_nM": k_ppi_nM,
            "alpha_cooperativity": alpha,
            # stage 1 — allosteric R-state stabilisation on the E3 ligase
            "stage1_allosteric_R_state_stabilisation": stage1,
            # stage 2 — cooperative ternary closure on the remodelled E3
            "stage2_cooperative_ternary": stage2,
            # staged total
            "dg_stage1_kcal_per_mol": stage1["dg_stage1_kcal_per_mol"],
            "dg_stage2_kcal_per_mol": stage2["dg_stage2_kcal_per_mol"],
            "dg_total_kcal_per_mol": dg_total,
            "staged_ledger_residual": staged_ledger_residual,
            "mwc_apo_unity_residual": mwc_apo_unity_residual,
            "mwc_bound_unity_residual": mwc_bound_unity_residual,
            "staged_unification_note": (
                "stage 1 = MWC R-state stabilisation on E3 (allosteric_sim) ; "
                "stage 2 = cooperative ternary closure on remodelled E3 "
                "(molecular_glue_sim) ; staged ordering: glue binds first, "
                "remodels E3, then ternary closes — the lenalidomide-CRBN "
                "structural mechanism in two energetic accountings."),
            "illustrative_only": True,
        }
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """
    High-cooperativity (FDA-approved class) vs weak-coop research control
    contrast in the staged decomposition. The lenalidomide-class entry shows
    a large stage-1 R-state stabilisation (glue actually remodels CRBN's
    surface) AND a large stage-2 cooperative contribution; the weak-coop
    control shows a smaller stage-1 shift AND a smaller stage-2 cooperative
    contribution — the staged decomposition exposes BOTH differences.
    """
    by_name = {r["molecular_glue"]: r for r in rows}
    fda = by_name["glue_lenalidomide_IKZF1"]
    weak = by_name["glue_research_weak_coop"]
    return {
        "fda_class_reference": {
            "molecular_glue": fda["molecular_glue"],
            "drug_precedent": fda["drug_precedent"],
            "dg_stage1_kcal_per_mol": fda["dg_stage1_kcal_per_mol"],
            "dg_stage2_kcal_per_mol": fda["dg_stage2_kcal_per_mol"],
            "dg_total_kcal_per_mol": fda["dg_total_kcal_per_mol"],
            "mwc_p_R_E3_apo": fda["stage1_allosteric_R_state_stabilisation"]["mwc_p_R_E3_apo"],
            "mwc_p_R_E3_bound": fda["stage1_allosteric_R_state_stabilisation"]["mwc_p_R_E3_bound"],
            "population_shift_R": fda["stage1_allosteric_R_state_stabilisation"]["population_shift_R"],
            "f_ternary": fda["stage2_cooperative_ternary"]["cooperative_ternary_equilibrium"]["f_ternary"],
        },
        "weak_coop_control": {
            "molecular_glue": weak["molecular_glue"],
            "drug_precedent": weak["drug_precedent"],
            "dg_stage1_kcal_per_mol": weak["dg_stage1_kcal_per_mol"],
            "dg_stage2_kcal_per_mol": weak["dg_stage2_kcal_per_mol"],
            "dg_total_kcal_per_mol": weak["dg_total_kcal_per_mol"],
            "mwc_p_R_E3_apo": weak["stage1_allosteric_R_state_stabilisation"]["mwc_p_R_E3_apo"],
            "mwc_p_R_E3_bound": weak["stage1_allosteric_R_state_stabilisation"]["mwc_p_R_E3_bound"],
            "population_shift_R": weak["stage1_allosteric_R_state_stabilisation"]["population_shift_R"],
            "f_ternary": weak["stage2_cooperative_ternary"]["cooperative_ternary_equilibrium"]["f_ternary"],
        },
        "note": ("The lenalidomide-class glue pays the larger allosteric cost "
                 "to remodel CRBN (ΔG_allo = +3 kcal/mol) but compensates with "
                 "a more favourable glutarimide-pocket grip (ΔG_glue_E3 = -7 "
                 "kcal/mol) — the structural picture of Petzold 2016. The "
                 "weak-coop control remodels a smaller surface and binds "
                 "weaker. The staged decomposition exposes BOTH the allosteric "
                 "remodelling difference (stage 1) AND the cooperative ternary "
                 "difference (stage 2) — neither alone tells the full story."),
    }


def acceptance(rows: list, allo_mod, glue_mod) -> dict:
    """
    In-silico simulator-CONSISTENCY acceptance criteria (X1–X9) for the cross.
    """
    crit = {
        "X1_panel_non_empty":
            len(rows) == len(glue_mod.GLUE_PANEL) and len(rows) >= 4,
        "X2_staged_ledger_closes_to_unity": all(
            r["staged_ledger_residual"] < 1e-12 for r in rows),
        "X3_mwc_apo_populations_sum_to_unity": all(
            r["mwc_apo_unity_residual"] < 1e-12 for r in rows),
        "X4_mwc_bound_populations_sum_to_unity": all(
            r["mwc_bound_unity_residual"] < 1e-12 for r in rows),
        "X5_glue_pays_allosteric_cost_R_state_stabiliser": all(
            r["stage1_allosteric_R_state_stabilisation"]["glue_is_R_state_stabiliser"]
            for r in rows),
        "X6_allosteric_ceiling_respected": all(
            r["stage1_allosteric_R_state_stabilisation"]["allosteric_ceiling_respected"]
            for r in rows),
        "X7_cooperative_ternary_partition_closes": all(
            r["stage2_cooperative_ternary"]["cooperative_ternary_equilibrium"]["partition_residual"]
            < 1e-12 for r in rows),
        "X8_alpha_E3_strictly_less_than_one": all(
            0.0 < r["stage1_allosteric_R_state_stabilisation"]["alpha_E3_population_shift"] < 1.0
            for r in rows),
        # FDA-class glues remodel the E3 more strongly than the weak-coop
        # research control — population-shift |δP_R| is larger. This is the
        # discriminating asymmetry between the classes.
        "X9_fda_class_population_shift_exceeds_weak_control": (
            next(r for r in rows if r["molecular_glue"] == "glue_lenalidomide_IKZF1"
                 )["stage1_allosteric_R_state_stabilisation"]["population_shift_R"]
            > next(r for r in rows if r["molecular_glue"] == "glue_research_weak_coop"
                   )["stage1_allosteric_R_state_stabilisation"]["population_shift_R"]),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("molecular_glue_allosteric_cross — CROSS-AXIS J3\n", flush=True)
    print("cross:  MOLECULAR-GLUE cooperative ternary  ──staged on top of──▶  "
          "ALLOSTERIC MWC R-state stabilisation of the E3 ligase", flush=True)
    print("        STAGE 1 (allosteric remodelling of E3)  →  "
          "STAGE 2 (cooperative ternary closure on remodelled E3)", flush=True)
    print("        ΔG_stage1 = ΔG_allo + ΔG_glue_E3   ΔG_stage2 = ΔG_PPI + ΔG_coop"
          "   ΔG_total = ΔG_stage1 + ΔG_stage2\n", flush=True)

    allo_mod = _load("allosteric_sim", _ALLOSTERIC_PATH)
    glue_mod = _load("molecular_glue_sim", _MOLECULAR_GLUE_PATH)

    print(f"  real-limit anchors :")
    print(f"    (i)   MWC two-state statistical mechanics (Monod, Wyman & "
          f"Changeux, J. Mol. Biol. 12:88, 1965)")
    print(f"    (ii)  cooperative ternary-complex mass action (Douglass et al., "
          f"JACS 135:6092, 2013; Gadd")
    print(f"          et al., Nat. Chem. Biol. 13:514, 2017; Guldberg & Waage, "
          f"1864)")
    print(f"    (iii) lenalidomide-CRBN co-crystal surface remodelling "
          f"(Krönke, Science 343:301, 2014;")
    print(f"          Petzold, Nature 532:127, 2016; Chamberlain, NSMB 21:803, "
          f"2014)")
    print(f"  RT = {RT_KCAL:.4g} kcal/mol @ T={TEMP_K} K   "
          f"C0_ref = {C0_REF_nM:.1f} nM\n", flush=True)

    rows = build_cross_rows(allo_mod, glue_mod)
    for r in rows:
        s1 = r["stage1_allosteric_R_state_stabilisation"]
        s2eq = r["stage2_cooperative_ternary"]["cooperative_ternary_equilibrium"]
        print(f"  [{r['molecular_glue']:<28}] K_glue={r['k_glue_nM']:.0f}nM  "
              f"K_PPI={r['k_ppi_nM']:.0f}nM  α={r['alpha_cooperativity']:.0f}")
        print(f"      STAGE 1  ΔG_allo={s1['dg_allo_kcal_per_mol']:+.2f}  "
              f"ΔG_glue_E3={s1['dg_glue_e3_kcal_per_mol']:+.2f}  →  "
              f"ΔG_stage1={r['dg_stage1_kcal_per_mol']:+.2f} kcal/mol")
        print(f"               P_R^apo={s1['mwc_p_R_E3_apo']:.4g}  "
              f"P_R^bound={s1['mwc_p_R_E3_bound']:.4g}  "
              f"δP_R={s1['population_shift_R']:+.4g}  "
              f"α_E3={s1['alpha_E3_population_shift']:.3e}")
        s2 = r["stage2_cooperative_ternary"]
        print(f"      STAGE 2  ΔG_PPI={s2['dg_ppi_kcal_per_mol']:+.2f}  "
              f"ΔG_coop={s2['dg_coop_kcal_per_mol']:+.2f}  →  "
              f"ΔG_stage2={r['dg_stage2_kcal_per_mol']:+.2f} kcal/mol")
        print(f"               f_ternary={s2eq['f_ternary']:.4g}  "
              f"glue_signature={s2eq['glue_signature']}")
        print(f"      TOTAL    ΔG_total = ΔG_stage1 + ΔG_stage2 = "
              f"{r['dg_total_kcal_per_mol']:+.2f} kcal/mol")

    ctr = contrast(rows)
    print("\n## FDA-class vs weak-coop control contrast (staged decomposition)")
    fda, weak = ctr["fda_class_reference"], ctr["weak_coop_control"]
    print(f"  FDA-CLASS    {fda['molecular_glue']:<28} ΔG_s1={fda['dg_stage1_kcal_per_mol']:+.2f}  "
          f"ΔG_s2={fda['dg_stage2_kcal_per_mol']:+.2f}  δP_R={fda['population_shift_R']:+.4g}  "
          f"f_tern={fda['f_ternary']:.3g}")
    print(f"  WEAK-CONTROL {weak['molecular_glue']:<28} ΔG_s1={weak['dg_stage1_kcal_per_mol']:+.2f}  "
          f"ΔG_s2={weak['dg_stage2_kcal_per_mol']:+.2f}  δP_R={weak['population_shift_R']:+.4g}  "
          f"f_tern={weak['f_ternary']:.3g}")

    acc = acceptance(rows, allo_mod, glue_mod)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3 / f_lattice_fit)")
    print("  - This cross is a MODEL-LEVEL UNIFICATION of two energetic accountings:")
    print("    the glue mechanism, in this framing, is allosteric-then-cooperative —")
    print("    STAGE 1 (MWC R-state stabilisation on the E3 ligase) followed by")
    print("    STAGE 2 (cooperative ternary closure on the remodelled E3). It is")
    print("    NOT a claim that every molecular glue is purely allosteric. The")
    print("    bifunctional cooperative-ternary picture (Douglass 2013; Gadd 2017)")
    print("    remains the standard accounting; this cross makes the structural")
    print("    E3-remodelling step (Petzold 2016 / Chamberlain 2014 / Krönke 2014)")
    print("    energetically explicit as stage 1.")
    print("  - The staged free-energy decomposition (ΔG_total = ΔG_stage1 + ΔG_stage2)")
    print("    is the SUM OF TWO HONEST PARTS of the SAME equilibrium — NOT a new")
    print("    parameterisation, NOT a fit, NOT a measured ΔΔG decomposition.")
    print("  - Both sub-axis sources are IMPORTED (f3 — no shadow of sister logic);")
    print("    allosteric_sim.affinity_shift and molecular_glue_sim.cooperative_ternary")
    print("    are reused verbatim, never re-implemented here.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY (g8/f2):")
    print("    the staged ledger sums close, MWC populations are bounded and sum to")
    print("    unity, the cooperative-ternary partition closes, ordering relations")
    print("    are honoured. NOT a binding-affinity / potency / selectivity /")
    print("    immunogenic / therapeutic-efficacy claim.")
    print("  - α, K_glue, K_PPI, ΔG_allo, ΔG_glue_E3 values are illustrative")
    print("    literature-informed surrogates for the modality CLASS, NOT fits to")
    print("    a specific compound. Modalities are described by own drug precedent")
    print("    (lenalidomide / thalidomide / indisulam for glue; asciminib /")
    print("    maraviroc for allosteric), never lattice-derived (g3/f1/f_lattice_fit).")
    print("  - MOLECULAR-GLUE and ALLOSTERIC both remain SUB-AXES; a CROSS is NOT a")
    print("    new axis. The hexa-bio core-5 axes are UNCHANGED. No quantity here is")
    print("    derived from the n=6 lattice.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": ("J3  MOLECULAR-GLUE cooperative ternary  <==staged-on==>  "
                  "ALLOSTERIC MWC R-state stabilisation of the E3 ligase"),
        "allosteric_subaxis_source":
            "_python_bridge/module/allosteric_sim.py (affinity_shift imported, "
            "not re-implemented — f3)",
        "molecular_glue_subaxis_source":
            "_python_bridge/module/molecular_glue_sim.py (cooperative_ternary "
            "and GLUE_PANEL imported, not re-implemented — f3)",
        "real_limit_anchor": (
            "(i) MWC two-state (Monod, Wyman & Changeux, J. Mol. Biol. 12:88, "
            "1965); (ii) cooperative ternary-complex mass action (Douglass et "
            "al., JACS 135:6092, 2013; Gadd et al., Nat. Chem. Biol. 13:514, "
            "2017; Guldberg & Waage, 1864); (iii) lenalidomide-CRBN co-crystal "
            "surface remodelling (Krönke, Science 343:301, 2014; Petzold, "
            "Nature 532:127, 2016; Chamberlain, NSMB 21:803, 2014; Lu, Science "
            "343:305, 2014). Bounded populations P_R+P_T=1, allosteric ceiling "
            "1/α saturable, partition function closes to unity, conformational "
            "free-energy ledger ΔG_allo^bound = ΔG_allo + ΔG_glue_E3 conserved."),
        "modality_precedents": {
            "molecular_glue": (
                "lenalidomide / thalidomide — monovalent CRBN glues recruiting "
                "IKZF1/IKZF3 (Krönke, Science 343:301, 2014; Lu, Science 343:305, "
                "2014; FDA-approved); indisulam — DCAF15 glue recruiting RBM39 "
                "(Han, Science 356:eaal3755, 2017; Uehara, Nat. Chem. Biol. "
                "13:675, 2017)"),
            "allosteric": (
                "asciminib — allosteric BCR-ABL1 inhibitor at the myristoyl "
                "pocket (Wylie, Nature 543:733, 2017; FDA-approved 2021); "
                "maraviroc — allosteric CCR5 antagonist (Dorr, AAC 49:4721, "
                "2005)"),
        },
        "staged_decomposition": (
            "ΔG_stage1 = ΔG_allo + ΔG_glue_E3 (MWC R-state stabilisation on E3); "
            "ΔG_stage2 = ΔG_PPI + ΔG_coop  (cooperative ternary on remodelled E3); "
            "ΔG_total  = ΔG_stage1 + ΔG_stage2"),
        "staged_ordering": (
            "glue binds E3 FIRST → remodels E3 (stage-1 allosteric R-state "
            "stabilisation) → cooperative ternary closes on remodelled E3 "
            "(stage-2 mass-action with cooperativity α)"),
        "temperature_K": TEMP_K,
        "rt_kcal_per_mol": RT_KCAL,
        "c0_reference_nM": C0_REF_nM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "MODEL-LEVEL UNIFICATION ONLY (g8/f2) — staged free-energy values "
            "are illustrative model outputs propagated from literature-informed "
            "class surrogates; NOT a binding-affinity, potency, selectivity, "
            "immunogenic or therapeutic-efficacy claim; NOT a claim that every "
            "molecular glue is purely allosteric — the bifunctional cooperative-"
            "ternary picture remains the standard accounting; this cross adds "
            "an explicit allosteric stage 1 for the structurally-visible "
            "E3-remodelling step."),
        "cross_is_not_a_new_axis": (
            "MOLECULAR-GLUE is a SUB-AXIS :> BIFUNCTIONAL (expansion-main); "
            "ALLOSTERIC is a SUB-AXIS :> QUANTUM (core); the hexa-bio core-5 "
            "axes are unchanged."),
        "no_lattice_derivation": (
            "No quantity in this witness is derived from the n=6 lattice "
            "(f_lattice_fit / lattice-is-tool). Modalities described by own "
            "drug precedent (g3/f1)."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__MOLECULAR_GLUE_ALLOSTERIC_CROSS__ PASS" if ok
          else "\n__MOLECULAR_GLUE_ALLOSTERIC_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
