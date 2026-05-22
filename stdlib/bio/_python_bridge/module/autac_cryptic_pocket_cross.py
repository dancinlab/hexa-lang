#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
autac_cryptic_pocket_cross.py — CROSS-AXIS integration J2.

CROSS:  AUTAC sub-axis (autophagic-flux partition)  ──gated-by──▶
        CRYPTIC-POCKET sub-axis (apo open-state Boltzmann population).

An AUTAC is a bifunctional molecule: one end is a target-binding warhead, the
other an S-guanylation autophagy tag (autac_sim.py). The AUTAC can only TAG
target molecules whose warhead-binding site is geometrically present — i.e.
only those in the binding-competent conformation. For a target whose
warhead-binding site is a CRYPTIC pocket (absent in the apo crystal, opens
only under dynamics; cryptic_pocket_sim.py), that binding-competent
sub-population is fixed by the conformational equilibrium:

      closed  ⇌(ΔG_open)  open           P_open(apo) = Boltzmann fraction

This module couples the two sub-axes by GATING the AUTAC's autophagic
degradation flux on P_open of a cryptic-pocket target. The downstream
autophagy-tag → K63-Ub → p62 → LC3 → autophagosome → autolysosome chain
(modelled in autac_sim.py with the flux-completion partition
flux_partition = k_fusion/(k_fusion + k_stall)) operates only on the
sub-population the AUTAC was able to TAG in the first place. So the
steady-state AUTAC degradation rate carries a hard CONFORMATIONAL UPPER BOUND:

      degradation_rate_ceiling
          =  P_open(target)
          ·  autac_sim.lc3_recruitment
          ·  autac_sim.k_seq
          ·  autac_sim.flux_partition

      ≡   P_open(target)  ·  autac_sim.degradation_flux_per_min

The AUTAC cannot exceed cryptic-gated engagement: even a flux-competent AUTAC
(high k_fusion, high tag_competence) is BOUNDED by the fraction of target
that is currently in the open (warhead-binding-competent) state. A genuine
cryptic pocket with P_open ≪ 1 imposes an order-of-magnitude ceiling on the
attainable autophagic-flux degradation rate, irrespective of how flux-
competent the AUTAC is.

────────────────────────────────────────────────────────────────────────────
WHAT THE CROSS DEMONSTRATES (the bound is a hard inequality, not a fit)
────────────────────────────────────────────────────────────────────────────
The cross is a model-level UPPER BOUND. For each pocket–AUTAC pair the row
makes the inequality explicit:

      degradation_rate_ceiling  ≤  autac_sim.degradation_flux_per_min

with equality if and only if P_open = 1 (no cryptic gating — i.e. the target
is constitutively open in the apo state). This is a strict identity from
conformational selection: the AUTAC needs the open state to bind, and the
fraction in the open state is fixed by the conformational free-energy ledger
already conserved by cryptic_pocket_sim. The cross is NOT a quantitative
degradation-rate prediction — only the inequality is asserted.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Two coincident real limits anchor every row:
  - Conformational free-energy / Boltzmann population statistics: the open-
    state apo population obeys P_open = exp(−ΔG_open/RT)/(1+exp(−ΔG_open/RT))
    and is bounded in (0,1). The conformational-selection thermodynamic cycle
    (Hammes, Chang & Oas, *PNAS* 106:13737, 2009) FIXES the ledger
    ΔG_bind_obs = ΔG_bind_open + ΔG_open — the AUTAC cannot escape paying
    the opening cost when tagging a cryptic target.
  - Autophagic-flux kinetics (turnover RATE, not a static autophagosome
    count): a tagged cargo's productive degradation is the partition
    flux_partition = k_fusion/(k_fusion + k_stall) layered on the law of
    mass action (Mizushima & Yoshimori, "How to interpret LC3 immunoblotting",
    *Autophagy* 3:542, 2007; Klionsky et al., consensus autophagy-flux
    guidelines, *Autophagy* 17:1, 2021; Loos, du Toit & Hofmeyr, *Autophagy*
    10:2087, 2014). Both partitions are bounded in [0,1] and combine
    multiplicatively.

The combined ceiling

      degradation_rate_ceiling  =  P_open · (autophagic-flux degradation)

is therefore a strict upper bound — the multiplicative product of two
real-limit-bounded fractions and a non-negative kinetic prefactor.

Modality precedent (described ONLY by its own precedent — g3/f1, never
lattice-derived):
  - AUTAC modality: Takahashi, Moriya, Hara, Ichimura, Abe, Nishino, Aoki,
    Mizushima & Arimoto, "AUTACs: Cargo-Specific Degraders Using Selective
    Autophagy", *Mol. Cell* 76:797 (2019) — the founding AUTAC work
    (Arimoto lab, Tohoku Univ.); mito-AUTACs in the same paper.
    RESEARCH-STAGE — there is no approved AUTAC drug.
  - CRYPTIC-POCKET modality: the KRAS-G12C switch-II pocket — a cryptic
    pocket absent in early apo KRAS structures, revealed under dynamics
    and exploited by sotorasib (Ostrem et al., *Nature* 503:548, 2013;
    Canon et al., *Nature* 575:217, 2019; sotorasib FDA-approved 2021).
    The TEM-1 β-lactamase cryptic allosteric site (Horn & Shoichet,
    *J. Mol. Biol.* 336:1283, 2004; Bowman & Geissler, *PNAS* 109:11681,
    2012) is a second precedent for cryptic-pocket dynamics.

NOTE: no approved AUTAC-against-a-cryptic-pocket therapeutic exists. The
two modality precedents are CITED INDEPENDENTLY for their own sub-axis
real limits — the cross is a model-level combination, never claimed to
be backed by a real clinical AUTAC-cryptic-pocket compound.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g3 / g8 / forbidden-patterns f1 / f2 / f3 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
  * The cross is a MODEL-LEVEL UPPER BOUND. It asserts the inequality
    degradation_rate_ceiling ≤ autac_sim.degradation_flux_per_min only —
    it is NOT a quantitative degradation-rate prediction, NOT a binding-
    affinity claim, NOT a potency/selectivity claim, NOT a therapeutic-
    efficacy claim.
  * AUTAC is itself a RESEARCH-STAGE modality — there is no approved AUTAC
    drug; nothing here is a clinical or regulatory claim (g8/f2).
  * The ΔG_open / ΔG_bind_open / autac panel values are illustrative
    literature-informed surrogates for the pocket / AUTAC CLASS, not fits
    to a specific compound or protein. The pairing of an AUTAC class with
    a cryptic pocket is a model-level coupling exercise, not a real
    compound–target match.
  * Both sub-axis sources are IMPORTED via importlib (governance f3 — no
    fork of sister logic; cryptic_pocket_sim.open_population and the AUTAC
    autophagy_profile are reused verbatim, never re-implemented here).
  * Modality precedents are described ONLY by their own sub-axis
    references (g3/f1 — AUTAC: Arimoto lab Mol. Cell 2019; CRYPTIC: KRAS-
    G12C / Ostrem 2013, sotorasib 2021). NEVER lattice-derived — no n=6
    invariant is used to justify any biological quantity here
    (f_lattice_fit).
  * Pure stdlib, no network / time / random → byte-identical re-runs.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the chain (P_open · autac_sim degradation flux) is bounded above by
    autac_sim.degradation_flux_per_min, the conformational ledger is
    conserved, both partitions are bounded in [0,1], and the cross runs
    byte-identically. It is NOT an efficacy / potency / clinical claim.

A CROSS is NOT a new axis. AUTAC remains a SUB-AXIS (:> BIFUNCTIONAL
expansion-main) and CRYPTIC-POCKET remains a SUB-AXIS (:> QUANTUM core)
per AXIS/HIERARCHY.tape. The hexa-bio core-5 axes QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID are UNCHANGED.
"""
from __future__ import annotations
import importlib.util
import json
import os
import sys

# ── locate the two sister sub-axis sources (no fork — f3) ───────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_AUTAC_PATH = os.path.join(_HERE, "autac_sim.py")
_CRYPTIC_PATH = os.path.join(_HERE, "cryptic_pocket_sim.py")

SCHEMA_ID = "autac_cryptic_pocket_cross_v1"


def _load(name: str, path: str):
    """Import a sister sub-axis module by absolute path (no shadow — f3)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── deterministic pocket → AUTAC pairing ────────────────────────────────────
# Each cryptic_pocket_sim panel entry (target) is paired with one autac_sim
# panel entry (degrader class) for a 1-to-1 deterministic cross. The pairing
# is a MODEL-LEVEL coupling for illustration — it is NOT a real compound–
# target match and not a claim about any specific therapeutic programme
# (honesty: g8/f2). The pairing covers both cryptic and non-cryptic pockets
# and both flux-competent and flux-stalled AUTAC classes so the bound
# inequality is exercised across regimes.
_POCKET_AUTAC_PAIRING = [
    # pocket_name (from cryptic_pocket_sim.POCKET_PANEL),
    # autac_name (from autac_sim.AUTAC_PANEL),
    ("kras_g12c_switch_II",        "AUTAC_MetAP2_like"),
    ("tem1_betalactamase_cryptic", "AUTAC_FKBP12_like"),
    ("deep_cryptic_transient",     "mito_AUTAC_like"),
    ("shallow_cryptic_groove",     "flux_competent_AUTAC_like"),
    ("constitutive_open_site",     "low_tag_AUTAC_like"),
    ("uncompensated_cryptic",      "stall_dominant_AUTAC_like"),
]


def _index_panel(panel_rows, key):
    """Return {name: row} for an indexed lookup of a sister-sim row list."""
    return {r[key]: r for r in panel_rows}


def build_cross_rows(autac_mod, cryptic_mod) -> list:
    """
    One cross row per pocket–AUTAC pair.

    For each pair:
      - Pull P_open(apo) from cryptic_pocket_sim.build_rows() — the apo
        open-state Boltzmann population of the target (the fraction in the
        warhead-binding-competent conformation).
      - Pull the AUTAC autophagy-flux profile from autac_sim.build_rows() —
        the lc3_recruitment, flux_partition and degradation_flux_per_min
        (the full-engagement upper signal).
      - Compute the cryptic-gated ceiling:
            degradation_rate_ceiling = P_open · degradation_flux_per_min
      - Assert the inequality (this is the cross's central claim):
            degradation_rate_ceiling  ≤  degradation_flux_per_min
        with equality iff P_open = 1.
    """
    cryptic_rows = _index_panel(cryptic_mod.build_rows(), "pocket")
    autac_rows = _index_panel(autac_mod.build_rows(), "autac")
    rows = []
    for pocket_name, autac_name in _POCKET_AUTAC_PAIRING:
        if pocket_name not in cryptic_rows:
            raise RuntimeError(
                f"pocket {pocket_name!r} not in cryptic_pocket_sim panel")
        if autac_name not in autac_rows:
            raise RuntimeError(
                f"autac {autac_name!r} not in autac_sim panel")
        cr = cryptic_rows[pocket_name]
        ar = autac_rows[autac_name]

        # ── conformational gating (from cryptic_pocket_sim, imported — f3) ──
        p_open = cr["apo_open_state_population"]
        # full-engagement autophagic-flux degradation (autac_sim, imported — f3)
        degradation_flux_full = ar["degradation_flux_per_min"]

        # ── the cross: cryptic gating bounds AUTAC degradation rate ──
        degradation_rate_ceiling = p_open * degradation_flux_full

        # bound inequality (must hold with equality iff p_open == 1.0)
        bound_holds = degradation_rate_ceiling <= degradation_flux_full + 1e-15
        equality_at_constitutive = (
            abs(degradation_rate_ceiling - degradation_flux_full) <= 1e-12
            if p_open >= 1.0 - 1e-12 else True
        )

        # downstream-only ceiling: even without cryptic gating, the AUTAC's
        # own flux partition is itself a [0,1] bounded fraction — exposed so
        # the row makes the two-stage bounding chain explicit.
        autophagic_flux_ceiling_fraction = ar["flux_partition"]

        # absolute reduction factor vs the full-engagement signal
        cryptic_gating_factor = p_open
        # the AUTAC's intrinsic flux-completion fraction (a [0,1] bound).

        row = {
            "schema": SCHEMA_ID,
            # cryptic-pocket (target) side
            "target_pocket": pocket_name,
            "pocket_class": cr["pocket_class"],
            "pocket_drug_precedent": cr["drug_precedent"],
            "dg_open_kcal_per_mol": cr["dg_open_kcal_per_mol"],
            "dg_bind_open_kcal_per_mol": cr["dg_bind_open_kcal_per_mol"],
            "dg_bind_obs_kcal_per_mol": cr["dg_bind_obs_kcal_per_mol"],
            "is_cryptic": cr["is_cryptic"],
            "pocket_state": cr["pocket_state"],
            "apo_open_state_population": p_open,
            "cryptic_popen_threshold": cr["cryptic_popen_threshold"],
            # autac (degrader) side
            "autac": autac_name,
            "autac_drug_precedent": ar["drug_precedent"],
            "cargo_type": ar["cargo_type"],
            "kd_target_nM": ar["kd_target_nM"],
            "tag_competence": ar["tag_competence"],
            "theta_target": ar["theta_target"],
            "lc3_recruitment": ar["lc3_recruitment"],
            "k_seq_per_min": ar["k_seq_per_min"],
            "flux_partition": ar["flux_partition"],
            "stalled_partition": ar["stalled_partition"],
            "flux_class": ar["flux_class"],
            "degradation_flux_full_per_min": degradation_flux_full,
            "autophagic_flux_ceiling_fraction":
                autophagic_flux_ceiling_fraction,
            # the cross — cryptic-gated ceiling
            "cryptic_gating_factor": cryptic_gating_factor,
            "degradation_rate_ceiling_per_min": degradation_rate_ceiling,
            "bound_inequality_holds": bound_holds,
            "equality_at_constitutive_open": equality_at_constitutive,
            "interpretation": (
                "the AUTAC can only tag the open-state sub-population; the "
                "autophagic-flux degradation rate is therefore bounded above "
                "by P_open · autac_sim.degradation_flux_per_min — a strict "
                "model-level inequality from conformational selection"),
            "illustrative_only": True,
        }
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """
    Cryptic-vs-constitutive AUTAC degradation-rate-ceiling contrast.

    A cryptic target (low P_open) imposes an order-of-magnitude ceiling on
    the attainable autophagic degradation rate even when paired with a
    flux-competent AUTAC. A constitutively-open target (P_open near 1)
    pays no cryptic penalty and the AUTAC operates at its full flux.
    """
    by_pocket = {r["target_pocket"]: r for r in rows}
    cryptic = by_pocket["kras_g12c_switch_II"]
    consti = by_pocket["constitutive_open_site"]
    deep = by_pocket["deep_cryptic_transient"]
    return {
        "cryptic_reference": {
            "target_pocket": cryptic["target_pocket"],
            "pocket_drug_precedent": cryptic["pocket_drug_precedent"],
            "apo_open_state_population": cryptic["apo_open_state_population"],
            "autac": cryptic["autac"],
            "autac_drug_precedent": cryptic["autac_drug_precedent"],
            "degradation_flux_full_per_min":
                cryptic["degradation_flux_full_per_min"],
            "degradation_rate_ceiling_per_min":
                cryptic["degradation_rate_ceiling_per_min"],
        },
        "constitutive_reference": {
            "target_pocket": consti["target_pocket"],
            "pocket_state": consti["pocket_state"],
            "apo_open_state_population": consti["apo_open_state_population"],
            "autac": consti["autac"],
            "degradation_flux_full_per_min":
                consti["degradation_flux_full_per_min"],
            "degradation_rate_ceiling_per_min":
                consti["degradation_rate_ceiling_per_min"],
        },
        "deep_cryptic_reference": {
            "target_pocket": deep["target_pocket"],
            "apo_open_state_population": deep["apo_open_state_population"],
            "autac": deep["autac"],
            "flux_class": deep["flux_class"],
            "degradation_flux_full_per_min":
                deep["degradation_flux_full_per_min"],
            "degradation_rate_ceiling_per_min":
                deep["degradation_rate_ceiling_per_min"],
        },
        "ceiling_ratio_cryptic_vs_constitutive": (
            cryptic["degradation_rate_ceiling_per_min"]
            / consti["degradation_rate_ceiling_per_min"]
            if consti["degradation_rate_ceiling_per_min"] > 0.0 else None),
        "note": ("a cryptic target gates the AUTAC at the conformational "
                 "level: the AUTAC cannot tag the closed sub-population, so "
                 "the autophagic-flux degradation rate is bounded by "
                 "P_open · autac.degradation_flux. A flux-competent AUTAC "
                 "paired with a deep cryptic target is still bounded by the "
                 "open-state fraction — the cross is a hard inequality."),
    }


def acceptance(rows: list, autac_mod, cryptic_mod) -> dict:
    """
    In-silico simulator-CONSISTENCY acceptance criteria (X1–X7) for the cross.
    """
    cryptic_targets = [r for r in rows if r["is_cryptic"]]
    non_cryptic_targets = [r for r in rows if not r["is_cryptic"]]
    crit = {
        "X1_pairing_non_empty":
            len(rows) >= len(_POCKET_AUTAC_PAIRING) and len(rows) >= 6,
        "X2_p_open_bounded_strictly":
            all(0.0 < r["apo_open_state_population"] < 1.0 for r in rows),
        "X3_autac_partitions_bounded":
            all(0.0 <= r["flux_partition"] <= 1.0
                and 0.0 <= r["stalled_partition"] <= 1.0
                and abs(r["flux_partition"] + r["stalled_partition"] - 1.0)
                <= 1e-12 for r in rows),
        "X4_ceiling_bound_holds":
            all(r["bound_inequality_holds"] for r in rows),
        "X5_ceiling_is_product":
            all(abs(r["degradation_rate_ceiling_per_min"]
                    - r["apo_open_state_population"]
                    * r["degradation_flux_full_per_min"]) <= 1e-12
                for r in rows),
        "X6_both_target_classes_present":
            len(cryptic_targets) >= 1 and len(non_cryptic_targets) >= 1,
        "X7_cryptic_strictly_below_full":
            all(r["degradation_rate_ceiling_per_min"]
                < r["degradation_flux_full_per_min"] - 1e-15
                if r["degradation_flux_full_per_min"] > 0.0 else True
                for r in cryptic_targets),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("autac_cryptic_pocket_cross — CROSS-AXIS J2\n", flush=True)
    print("cross:  CRYPTIC-POCKET P_open  ──gates──▶  AUTAC autophagic-flux "
          "degradation", flush=True)
    print("        the AUTAC can only TAG the open-state sub-population;",
          flush=True)
    print("        degradation_rate_ceiling = P_open · "
          "autac.degradation_flux_per_min\n", flush=True)

    autac_mod = _load("autac_sim", _AUTAC_PATH)
    cryptic_mod = _load("cryptic_pocket_sim", _CRYPTIC_PATH)

    print(f"  real-limit anchor (cryptic) : conformational free-energy / "
          f"Boltzmann population")
    print(f"                                statistics + conformational-"
          f"selection thermodynamic cycle")
    print(f"                                (Hammes, Chang & Oas, PNAS "
          f"106:13737, 2009).  T={cryptic_mod.TEMP_K} K")
    print(f"  real-limit anchor (autac)   : autophagic flux — autophagosome "
          f"formation vs")
    print(f"                                autophagosome-lysosome fusion "
          f"(Mizushima &")
    print(f"                                Yoshimori, Autophagy 3:542, 2007; "
          f"Klionsky et al.,")
    print(f"                                consensus autophagy guidelines)")
    print(f"  AUTAC modality precedent    : Takahashi et al., Mol. Cell "
          f"76:797 (2019) —")
    print(f"                                Arimoto lab AUTAC class "
          f"(RESEARCH-STAGE,")
    print(f"                                no approved AUTAC drug)")
    print(f"  CRYPTIC modality precedent  : KRAS-G12C switch-II / sotorasib "
          f"(Ostrem et al.,")
    print(f"                                Nature 503:548, 2013; Canon et "
          f"al., Nature 575:217,")
    print(f"                                2019)\n", flush=True)

    rows = build_cross_rows(autac_mod, cryptic_mod)
    for r in rows:
        print(f"  [{r['target_pocket']:<28}] {r['pocket_state']:<26} "
              f"P_open={r['apo_open_state_population']:.4g}")
        print(f"      paired AUTAC: {r['autac']:<28} ({r['flux_class']})")
        print(f"      full flux      = {r['degradation_flux_full_per_min']:.5f}"
              f"/min  (no cryptic gating)")
        print(f"      gated ceiling  = {r['degradation_rate_ceiling_per_min']:.5f}"
              f"/min  = P_open · full")
        print(f"      bound holds    = {r['bound_inequality_holds']}  "
              f"cryptic={r['is_cryptic']}")

    ctr = contrast(rows)
    print("\n## cryptic-vs-constitutive AUTAC-degradation-rate-ceiling contrast")
    cr, co, dp = (ctr["cryptic_reference"], ctr["constitutive_reference"],
                  ctr["deep_cryptic_reference"])
    print(f"  CRYPTIC      {cr['target_pocket']:<28} "
          f"P_open={cr['apo_open_state_population']:.4g}  "
          f"ceiling={cr['degradation_rate_ceiling_per_min']:.5f}/min")
    print(f"  CONSTITUTIVE {co['target_pocket']:<28} "
          f"P_open={co['apo_open_state_population']:.4g}  "
          f"ceiling={co['degradation_rate_ceiling_per_min']:.5f}/min")
    print(f"  DEEP-CRYPTIC {dp['target_pocket']:<28} "
          f"P_open={dp['apo_open_state_population']:.4g}  "
          f"ceiling={dp['degradation_rate_ceiling_per_min']:.5f}/min  "
          f"(AUTAC: {dp['flux_class']})")
    if ctr["ceiling_ratio_cryptic_vs_constitutive"] is not None:
        print(f"  ceiling ratio cryptic / constitutive = "
              f"{ctr['ceiling_ratio_cryptic_vs_constitutive']:.4g}")

    acc = acceptance(rows, autac_mod, cryptic_mod)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  "
          f"verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3 / f_lattice_fit)")
    print("  - The cross is a MODEL-LEVEL UPPER BOUND: degradation_rate_ceiling")
    print("    <= autac.degradation_flux_per_min, with equality iff P_open=1.")
    print("    It is NOT a quantitative degradation-rate prediction, NOT a")
    print("    binding-affinity / potency / selectivity / therapeutic claim.")
    print("  - AUTAC is itself a RESEARCH-STAGE modality (Arimoto lab, Mol.")
    print("    Cell 76:797, 2019) — there is no approved AUTAC drug. Nothing")
    print("    here is a clinical / regulatory claim (g8/f2).")
    print("  - The DG_open / DG_bind_open / autac panel values are literature-")
    print("    informed surrogates for the pocket / AUTAC CLASS, not fits to a")
    print("    specific compound or protein. The 1-to-1 pocket-AUTAC pairing")
    print("    is a model-level coupling for illustration, not a real")
    print("    compound-target match (g8/f2).")
    print("  - Both sub-axis sources are IMPORTED via importlib (f3 - no fork")
    print("    of sister logic; cryptic_pocket_sim.open_population and the")
    print("    autac_sim autophagy_profile are reused verbatim).")
    print("  - Modality precedents are described ONLY by their own sub-axis")
    print("    references (g3/f1) - AUTAC: Arimoto lab Mol. Cell 2019;")
    print("    CRYPTIC: KRAS-G12C switch-II / sotorasib (Ostrem 2013).")
    print("    NEVER lattice-derived - no n=6 invariant is used to justify")
    print("    any biological quantity here (f_lattice_fit).")
    print("  - AUTAC remains a SUB-AXIS (:> BIFUNCTIONAL expansion-main);")
    print("    CRYPTIC-POCKET remains a SUB-AXIS (:> QUANTUM core).")
    print("    A CROSS is NOT a new axis - core-5 is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed -> deterministic byte-identical re-runs
        "cross": ("J2  AUTAC autophagic-flux degradation  <-gated-by-  "
                  "CRYPTIC-POCKET open-state population"),
        "autac_subaxis_source": (
            "_python_bridge/module/autac_sim.py "
            "(autophagy_profile imported, not re-implemented - f3)"),
        "cryptic_pocket_subaxis_source": (
            "_python_bridge/module/cryptic_pocket_sim.py "
            "(open_population imported, not re-implemented - f3)"),
        "real_limit_anchor": (
            "(1) conformational free-energy / Boltzmann population statistics "
            "and the conformational-selection thermodynamic cycle (Hammes, "
            "Chang & Oas, PNAS 106:13737, 2009); (2) autophagic-flux kinetics "
            "as a turnover rate (Mizushima & Yoshimori, Autophagy 3:542, 2007; "
            "Klionsky et al. consensus autophagy guidelines, Autophagy 17:1, "
            "2021) - both bounded fractions in [0,1] combined multiplicatively"),
        "autac_modality_precedent": (
            "Takahashi et al., Mol. Cell 76:797 (2019) - Arimoto lab AUTAC; "
            "RESEARCH-STAGE, no approved AUTAC drug"),
        "cryptic_modality_precedent": (
            "KRAS-G12C switch-II pocket - sotorasib (Ostrem et al., Nature "
            "503:548, 2013; Canon et al., Nature 575:217, 2019; FDA-approved "
            "2021); TEM-1 cryptic allosteric site (Bowman & Geissler, PNAS "
            "109:11681, 2012)"),
        "ceiling_formula": (
            "degradation_rate_ceiling_per_min = P_open(target) * "
            "autac_sim.degradation_flux_per_min"),
        "bound_assertion": (
            "degradation_rate_ceiling <= autac.degradation_flux_per_min, "
            "equality iff P_open = 1 (constitutively-open target)"),
        "temperature_K": cryptic_mod.TEMP_K,
        "autac_conc_nM": autac_mod.AUTAC_CONC_NM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) - the cross asserts the "
            "inequality degradation_rate_ceiling <= autac.degradation_flux "
            "only; it is a MODEL-LEVEL UPPER BOUND, NOT a quantitative "
            "degradation-rate prediction. AUTAC is a research-stage modality; "
            "no approved AUTAC drug. The pocket-AUTAC pairing is a model "
            "coupling, not a real compound-target match."),
        "lattice_independence_note": (
            "no n=6 lattice invariant is used to justify any biological "
            "quantity in this cross (f_lattice_fit) - cryptic-pocket "
            "thermodynamics and AUTAC autophagic-flux kinetics are anchored "
            "to their own real limits"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__AUTAC_CRYPTIC_POCKET_CROSS__ PASS" if ok
          else "\n__AUTAC_CRYPTIC_POCKET_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
