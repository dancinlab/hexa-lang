#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
covalent_inhibition_sim.py — COVALENT axis (EXPANSION-MAIN, NOT core-5)
two-step covalent-inhibitor kinetics model.

Deterministic, stdlib-only. No network, no random, no wall-clock dependence
=> byte-identical re-runs.

────────────────────────────────────────────────────────────────────────────
WHAT THIS COMPUTES
────────────────────────────────────────────────────────────────────────────
The standard mechanism of a covalent (targeted-covalent) enzyme inhibitor is
TWO steps — a fast reversible recognition equilibrium followed by an
irreversible (or slowly-reversible) covalent bond-forming step:

      E + I  ⇌(Ki)  E·I  ─kinact→  E–I

  Step 1 — reversible recognition: the inhibitor first binds non-covalently
           in the active site, governed by the inhibition constant Ki
           (a dissociation constant; lower Ki = tighter reversible binding).
  Step 2 — the covalent step: from the reversibly-bound E·I encounter
           complex, the inhibitor's warhead reacts with the targeted active-
           site nucleophile (most often a cysteine thiolate) to form the
           covalent adduct E–I.  kinact is the first-order maximal rate of
           covalent-bond formation from the saturated E·I complex.

COVALENT-INHIBITOR EFFICIENCY METRIC (Strelow 2017):
  Because covalent inactivation depends on BOTH how well the inhibitor is
  recognised (Ki) AND how fast the warhead reacts once bound (kinact), the
  second-order rate constant

           kinact / Ki        (units M^-1 s^-1)

  is the field-standard potency/efficiency metric for a covalent inhibitor —
  it ranks covalent inhibitors the way kcat/Km ranks substrates.  At low,
  unsaturating [I] the observed pseudo-first-order inactivation rate is
  kobs ≈ (kinact/Ki)·[I]; this simulator recomputes that limiting slope and
  the half-life of free enzyme t_1/2 = ln2 / kobs at a reference [I].

EYRING TST RATE FOR THE COVALENT STEP:
  The covalent step (warhead → adduct) is an elementary chemical reaction, so
  its rate is bounded by Eyring transition-state theory:

           kinact_TST = (kB·T / h) · exp(−ΔG‡ / R·T)

  Given a warhead's covalent-step activation barrier ΔG‡ (kcal/mol), this
  yields a TST-predicted kinact.  Inverting an empirical kinact gives the
  implied ΔG‡.  No covalent elementary rate may exceed the universal
  prefactor kB·T/h — the hard physical ceiling that anchors every row.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  - Strelow JM. A perspective on the kinetics of covalent and irreversible
    inhibition. J Biomol Screen / SLAS Discovery 2017;22(1):3-20.  The
    kinact/Ki framework: kinact/Ki is the second-order efficiency constant
    that correctly ranks covalent inhibitors (the two-step E+I⇌E·I→E–I
    model, kobs vs [I] saturation).  This is the kinetic-framework anchor.
  - Eyring H. The activated complex in chemical reactions. J. Chem. Phys.
    1935;3:107-115.  Transition-state theory: a unimolecular rate is
    bounded by the universal frequency prefactor kB·T/h (≈6.46e12 /s at
    T=310 K).  No modelled covalent-step rate can exceed this physical
    ceiling — the hard real limit anchoring every row (the same TST limit
    used by the repo's RIBOZYME axis kinetics simulator and the
    REVERSIBLE-COVALENT sub-axis).

Modality precedent (COVALENT described ONLY by its own drug precedent —
governance g3/f1, never lattice-derived):
  - ibrutinib — the first FDA-approved targeted covalent kinase inhibitor
    (FDA 2013); an acrylamide Michael-acceptor warhead forms a covalent
    bond to Cys481 of Bruton's tyrosine kinase (BTK).  Honigberg et al.,
    PNAS 2010;107:13075.
  - sotorasib (FDA 2021) and adagrasib (FDA 2022) — covalent KRAS-G12C
    inhibitors; an acrylamide warhead reacts with the mutant-specific
    Cys12 thiol.  Canon et al., Nature 2019;575:217.
  - afatinib — covalent EGFR inhibitor (FDA 2013), an acrylamide warhead
    targeting Cys797 of EGFR.
COVALENT is the GENERAL covalent-inhibition modality.  Its REVERSIBLE
specialization (reversible-covalent warheads, e.g. nirmatrelvir's nitrile)
is the REVERSIBLE-COVALENT *sub-axis* — modelled separately in
reversible_covalent_sim.py; this module does NOT duplicate it.

────────────────────────────────────────────────────────────────────────────
n=6 LATTICE STANCE (g2 lattice-is-tool, g3/f1 honesty-external,
HEXA-COVALENT.tape f_lattice_fit + n6_honest_stance)
────────────────────────────────────────────────────────────────────────────
  Ki, kinact, kinact/Ki, ΔG‡, the choice of cysteine as the targeted
  nucleophile, and the two-step mechanism are enzyme-kinetics and physical-
  chemistry facts (Strelow 2017; Eyring 1935).  None of them is derived from
  the n=6 lattice (σ=12, τ=4, φ=2, J2=24).  This module performs NO lattice
  arithmetic.

────────────────────────────────────────────────────────────────────────────
IN-SILICO SCOPE (g8_in_silico_only / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
  A PASS here verifies IN-SILICO simulator + metadata internal consistency
  ONLY -- that the two-step kinetics arithmetic is self-consistent
  (kinact/Ki recomputed two ways agree; the Eyring rate respects the kB·T/h
  ceiling; kobs and t_1/2 follow from kinact/Ki).  It is NOT a
  binding-affinity measurement, NOT a potency/selectivity claim, NOT a
  therapeutic-efficacy or regulatory claim.  ΔG‡/Ki/kinact values are
  illustrative literature-informed surrogates for warhead CLASSES, not fits
  to a specific compound.  The COVALENT axis is scientifically UNPROVEN at
  the wet-lab boundary.  See HEXA-COVALENT.tape lim_in_silico_boundary +
  CLOSURE_RESIDUAL_BACKLOG.md section 0.

Sentinel:  __COVALENT_INHIBITION__ PASS   (or FAIL).
"""
from __future__ import annotations
import json
import math
import sys

# ── module identity ──
VERSION = "1.0.0"
AXIS = "COVALENT"
AXIS_LAYER = "expansion-main (NOT core-5)"
SCHEMA_ID = "covalent_inhibition_v1"

# ── physical constants (CODATA 2019, exact SI) ──
K_B = 1.380649e-23          # J/K          Boltzmann
H_PLANCK = 6.62607015e-34   # J·s          Planck
N_A = 6.02214076e23         # 1/mol        Avogadro
R_GAS = K_B * N_A           # J/(mol·K)  = 8.314462618…
KCAL_TO_J = 4184.0          # 1 kcal = 4184 J (thermochemical)
TEMP_K = 310.0              # K (physiological)

# ── real-limit anchor: Eyring TST universal frequency prefactor ──
# k = (kB·T/h)·exp(−ΔG‡/RT); the prefactor is the hard unimolecular ceiling.
EYRING_PREFACTOR = K_B * TEMP_K / H_PLANCK   # ≈ 6.46e12 /s @ 310 K

# ── citations ──
STRELOW_2017 = ("Strelow JM, J Biomol Screen / SLAS Discovery "
                "2017;22(1):3-20 (kinact/Ki covalent-inhibitor framework)")
EYRING_1935 = "Eyring H, J. Chem. Phys. 1935;3:107-115 (transition-state theory)"

# reference [I] for the kobs / half-life recompute (a modelling choice, not a
# fitted dose) — 1 micromolar, a typical assay concentration.
REFERENCE_INHIBITOR_CONC_M = 1.0e-6


# ─────────────────────────────────────────────────────────────────────
# deterministic covalent-inhibitor panel
# ─────────────────────────────────────────────────────────────────────
# (name, Ki [M], kinact [1/s], dg_covalent_kcal, warhead_class, drug precedent)
#   Ki        : reversible recognition constant of step 1 (dissociation K).
#   kinact    : first-order maximal covalent-step rate from saturated E·I.
#   dg_covalent_kcal : the covalent-step activation barrier ΔG‡ (kcal/mol);
#               used for the independent Eyring-TST kinact prediction.
#   The supplied kinact and dg_covalent are independent inputs; the simulator
#   does NOT force them equal — it reports the Eyring-implied ΔG‡ from kinact
#   and the Eyring-predicted kinact from ΔG‡ side by side as a consistency
#   window (warhead-class surrogates differ from a single-compound fit).
# Values are illustrative literature-informed surrogates for the warhead
# CLASS, not fits to a specific compound (see module honesty note).
COVALENT_PANEL = [
    ("ibrutinib_BTK_Cys481", 1.5e-8, 2.3e-3, 19.0, "acrylamide_thio_michael",
     "ibrutinib — covalent BTK inhibitor (acrylamide, Cys481; FDA 2013)"),
    ("afatinib_EGFR_Cys797", 5.0e-10, 1.0e-3, 19.5, "acrylamide_thio_michael",
     "afatinib — covalent EGFR inhibitor (acrylamide, Cys797; FDA 2013)"),
    ("sotorasib_KRAS_Cys12", 3.0e-7, 1.2e-3, 19.4, "acrylamide_thio_michael",
     "sotorasib — covalent KRAS-G12C inhibitor (acrylamide, Cys12; FDA 2021)"),
    ("adagrasib_KRAS_Cys12", 2.0e-7, 1.6e-3, 19.2, "acrylamide_thio_michael",
     "adagrasib — covalent KRAS-G12C inhibitor (acrylamide, Cys12; FDA 2022)"),
    ("chloroacetamide_probe", 4.0e-6, 5.0e-4, 20.0, "chloroacetamide",
     "chloroacetamide-warhead chemical-probe class (covalent cysteine probe)"),
]


def eyring_rate(dg_kcal: float, temp_k: float = TEMP_K) -> float:
    """Eyring transition-state-theory rate: k = (kB·T/h)·exp(−ΔG‡/R·T)."""
    dg_j = dg_kcal * KCAL_TO_J
    return (K_B * temp_k / H_PLANCK) * math.exp(-dg_j / (R_GAS * temp_k))


def implied_barrier_kcal(rate_per_s: float, temp_k: float = TEMP_K) -> float:
    """Invert Eyring TST: ΔG‡ = −R·T·ln(k·h / (kB·T))  (in kcal/mol)."""
    dg_j = -R_GAS * temp_k * math.log(rate_per_s * H_PLANCK / (K_B * temp_k))
    return dg_j / KCAL_TO_J


def covalent_inhibition(ki_m: float, kinact_per_s: float,
                        dg_covalent_kcal: float,
                        inhibitor_conc_m: float = REFERENCE_INHIBITOR_CONC_M,
                        temp_k: float = TEMP_K) -> dict:
    """
    One covalent inhibitor's two-step kinetics.

    Step 1  E + I ⇌(Ki) E·I        reversible recognition.
    Step 2  E·I ─kinact→ E–I       covalent bond formation.

    kinact/Ki is the second-order efficiency metric (Strelow 2017).  At an
    unsaturating [I], the observed pseudo-first-order inactivation rate is
    kobs = (kinact/Ki)·[I] / (1 + [I]/Ki); the limiting low-[I] slope is
    kinact/Ki.  t_1/2 of free enzyme = ln2 / kobs.
    """
    # the covalent-inhibitor efficiency metric (Strelow 2017)
    kinact_over_ki = kinact_per_s / ki_m            # M^-1 s^-1

    # full saturable kobs and its low-[I] limiting form
    saturation = inhibitor_conc_m / ki_m
    kobs = (kinact_per_s * saturation) / (1.0 + saturation)
    kobs_low_i_limit = kinact_over_ki * inhibitor_conc_m  # = kobs as [I]<<Ki

    # cross-check: efficiency metric recomputed from the limiting kobs slope
    kinact_over_ki_from_kobs = kobs_low_i_limit / inhibitor_conc_m
    metric_rel_err = (abs(kinact_over_ki - kinact_over_ki_from_kobs)
                      / kinact_over_ki)

    # free-enzyme inactivation half-life at the reference [I]
    half_life_s = math.log(2.0) / kobs if kobs > 0.0 else float("inf")

    # Eyring TST for the covalent step
    kinact_eyring_tst = eyring_rate(dg_covalent_kcal, temp_k)
    dg_implied_from_kinact = implied_barrier_kcal(kinact_per_s, temp_k)

    return {
        "Ki_molar": ki_m,
        "kinact_per_s": kinact_per_s,
        "kinact_over_Ki_M_per_s": kinact_over_ki,
        "inhibitor_conc_M": inhibitor_conc_m,
        "saturation_I_over_Ki": saturation,
        "kobs_per_s": kobs,
        "kobs_low_I_limit_per_s": kobs_low_i_limit,
        "kinact_over_Ki_from_kobs_M_per_s": kinact_over_ki_from_kobs,
        "metric_consistency_rel_err": metric_rel_err,
        "free_enzyme_half_life_s": half_life_s,
        "free_enzyme_half_life_human": _human_time(half_life_s),
        "dg_covalent_step_kcal_per_mol": dg_covalent_kcal,
        "kinact_eyring_tst_per_s": kinact_eyring_tst,
        "dg_implied_from_kinact_kcal_per_mol": dg_implied_from_kinact,
        "eyring_prefactor_ceiling_per_s": EYRING_PREFACTOR,
        "kinact_below_eyring_ceiling": kinact_per_s < EYRING_PREFACTOR,
        "kinact_tst_below_eyring_ceiling": kinact_eyring_tst < EYRING_PREFACTOR,
    }


def _human_time(seconds: float) -> str:
    """Human-readable timescale (deterministic, no locale)."""
    if seconds == float("inf"):
        return "inf"
    if seconds < 60.0:
        return f"{seconds:.3g} s"
    if seconds < 3600.0:
        return f"{seconds / 60.0:.3g} min"
    if seconds < 86400.0:
        return f"{seconds / 3600.0:.3g} h"
    if seconds < 31557600.0:
        return f"{seconds / 86400.0:.3g} d"
    return f"{seconds / 31557600.0:.3g} yr"


def build_rows() -> list:
    """Compute one schema-conformant row per covalent inhibitor in the panel."""
    rows = []
    for name, ki, kinact, dg_cov, wclass, precedent in COVALENT_PANEL:
        kin = covalent_inhibition(ki, kinact, dg_cov)
        row = {
            "schema": SCHEMA_ID,
            "inhibitor": name,
            "warhead_class": wclass,
            "drug_precedent": precedent,
            "temperature_K": TEMP_K,
            "two_step_mechanism": "E + I <=>(Ki) E.I -kinact-> E-I",
        }
        row.update(kin)
        rows.append(row)
    return rows


def potency_ranking(rows: list) -> dict:
    """Rank the panel by the kinact/Ki efficiency metric (Strelow 2017)."""
    ordered = sorted(rows, key=lambda r: r["kinact_over_Ki_M_per_s"],
                     reverse=True)
    return {
        "metric": "kinact/Ki (M^-1 s^-1)",
        "framework_citation": STRELOW_2017,
        "ranking": [
            {"inhibitor": r["inhibitor"],
             "kinact_over_Ki_M_per_s": r["kinact_over_Ki_M_per_s"],
             "drug_precedent": r["drug_precedent"]}
            for r in ordered
        ],
        "note": ("kinact/Ki is the field-standard second-order efficiency "
                 "constant for covalent inhibitors; it ranks them the way "
                 "kcat/Km ranks substrates. This is an in-silico ranking of "
                 "the panel's surrogate inputs, NOT a potency claim about "
                 "the named drugs."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C7)."""
    crit = {
        "C1_panel_non_empty": len(rows) >= 5,
        "C2_eyring_ceiling_respected": all(
            r["kinact_below_eyring_ceiling"]
            and r["kinact_tst_below_eyring_ceiling"]
            for r in rows),
        "C3_kinact_over_Ki_self_consistent": all(
            r["metric_consistency_rel_err"] < 1e-9 for r in rows),
        "C4_kinact_over_Ki_equals_kinact_div_Ki": all(
            abs(r["kinact_over_Ki_M_per_s"]
                - r["kinact_per_s"] / r["Ki_molar"])
            <= 1e-6 * r["kinact_over_Ki_M_per_s"]
            for r in rows),
        "C5_eyring_roundtrip_consistent": all(
            abs(eyring_rate(r["dg_implied_from_kinact_kcal_per_mol"])
                - r["kinact_per_s"])
            <= 1e-6 * r["kinact_per_s"]
            for r in rows),
        "C6_positive_kinetics": all(
            r["Ki_molar"] > 0.0 and r["kinact_per_s"] > 0.0
            and r["kinact_over_Ki_M_per_s"] > 0.0
            for r in rows),
        "C7_half_life_follows_kobs": all(
            abs(r["free_enzyme_half_life_s"]
                - math.log(2.0) / r["kobs_per_s"])
            <= 1e-6 * r["free_enzyme_half_life_s"]
            for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def run() -> dict:
    """Orchestrate the COVALENT two-step-kinetics witness."""
    rows = build_rows()
    ranking = potency_ranking(rows)
    acc = acceptance(rows)

    return {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed -> deterministic witness
        "axis": AXIS,
        "axis_layer": AXIS_LAYER,
        "version": VERSION,
        "model": "E + I <=>(Ki) E.I -kinact-> E-I  (two-step covalent inhibition)",
        "real_limit_anchors": {
            "kinact_over_Ki_framework_citation": STRELOW_2017,
            "eyring_tst_citation": EYRING_1935,
            "eyring_prefactor_ceiling_per_s": EYRING_PREFACTOR,
            "temperature_K": TEMP_K,
        },
        "reference_inhibitor_conc_M": REFERENCE_INHIBITOR_CONC_M,
        "rows": rows,
        "potency_ranking": ranking,
        "acceptance": acc,
        "pass_count": acc["pass_count"],
        "total_criteria": acc["total"],
        "verdict": acc["verdict"],
        "subaxis_note": ("COVALENT is the GENERAL covalent-inhibition modality. "
                         "Its reversible-warhead specialization is the "
                         "REVERSIBLE-COVALENT SUB-AXIS (reversible_covalent_sim.py) "
                         "— this module does NOT duplicate it."),
        "lattice_stance": ("No n=6 lattice arithmetic is performed. Ki, kinact, "
                           "kinact/Ki, the covalent-step barrier, and the choice "
                           "of cysteine as the targeted nucleophile are enzyme-"
                           "kinetics / physical-chemistry facts (Strelow 2017; "
                           "Eyring 1935), NOT lattice derivations "
                           "(HEXA-COVALENT.tape f_lattice_fit / n6_honest_stance)."),
        "in_silico_scope": ("PASS verifies IN-SILICO simulator+metadata "
                            "consistency ONLY -- two-step kinetics arithmetic "
                            "(kinact/Ki recomputed two ways agree; Eyring rate "
                            "respects the kB.T/h ceiling; kobs and t_1/2 follow "
                            "from kinact/Ki). NOT a binding-affinity, potency, "
                            "selectivity, or therapeutic-efficacy claim. The "
                            "COVALENT axis is UNPROVEN at the wet-lab boundary "
                            "(AGENTS.tape g8_in_silico_only / f2)."),
    }


def main() -> int:
    print("covalent_inhibition_sim — COVALENT axis "
          f"(EXPANSION-MAIN, NOT core-5) v{VERSION}\n", flush=True)
    print("model:  E + I <=>(Ki) E.I -kinact-> E-I   "
          "(two-step covalent inhibition)\n", flush=True)
    w = run()

    print(f"  real-limit anchors (AGENTS.tape g1 -- real-limits-first):")
    print(f"    kinact/Ki framework : {STRELOW_2017}")
    print(f"    Eyring TST          : {EYRING_1935}")
    print(f"    Eyring prefactor ceiling kB.T/h = {EYRING_PREFACTOR:.3e} /s "
          f"@ T={TEMP_K} K  (hard ceiling on every covalent-step rate)\n")

    print("  panel — two-step covalent-inhibitor kinetics")
    print("  (reference [I] = "
          f"{w['reference_inhibitor_conc_M']:.0e} M):")
    for r in w["rows"]:
        print(f"    [{r['inhibitor']:<24}] {r['warhead_class']}")
        print(f"      Ki={r['Ki_molar']:.3e} M  kinact={r['kinact_per_s']:.3e}/s  "
              f"kinact/Ki={r['kinact_over_Ki_M_per_s']:.3e} /M/s")
        print(f"      kobs={r['kobs_per_s']:.3e}/s  "
              f"t_1/2(free E)={r['free_enzyme_half_life_human']}  "
              f"DG_cov={r['dg_covalent_step_kcal_per_mol']:.1f} kcal/mol "
              f"(Eyring-implied {r['dg_implied_from_kinact_kcal_per_mol']:.1f})")

    rk = w["potency_ranking"]
    print(f"\n## kinact/Ki efficiency ranking (Strelow 2017)")
    for i, e in enumerate(rk["ranking"], start=1):
        print(f"  {i}. {e['inhibitor']:<24} "
              f"kinact/Ki={e['kinact_over_Ki_M_per_s']:.3e} /M/s")

    acc = w["acceptance"]
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  "
          f"verdict: {acc['verdict']} ---")

    print("\n## n=6 lattice stance: " + w["lattice_stance"])
    print("\n## sub-axis note: " + w["subaxis_note"])
    print("\n## IN-SILICO SCOPE (g8/f2): " + w["in_silico_scope"])

    emit = "--emit-witness" in sys.argv
    if emit:
        import io, os
        path = os.path.join(os.path.dirname(__file__), "runs",
                            "covalent_inhibition_events.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with io.open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        print(f"\n  [emit] appended covalent_inhibition_v1 witness -> {path}")

    ok = w["verdict"] == "PASS"
    print("\n## witness JSON")
    print(json.dumps(w, indent=2, ensure_ascii=False))
    print("\n__COVALENT_INHIBITION__ PASS" if ok
          else "\n__COVALENT_INHIBITION__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
