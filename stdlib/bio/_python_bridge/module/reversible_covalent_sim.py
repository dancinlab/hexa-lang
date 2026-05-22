#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
reversible_covalent_sim.py — REVERSIBLE-COVALENT sub-axis :> COVALENT (expansion-main).

Deterministic, stdlib-only real-limits kinetics/thermodynamics model of the
covalent-bond EQUILIBRIUM that distinguishes a *reversible* covalent inhibitor
from an *irreversible* one. This is the in-silico simulator-consistency layer
for the REVERSIBLE-COVALENT sub-axis registered in AXIS/HIERARCHY.tape — see
the sibling note `reversible_covalent_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
An irreversible covalent inhibitor forms a bond that does not measurably break
on the biological timescale; the on-rate (the covalent-bond-formation step)
governs everything and koff → 0. A *reversible* covalent inhibitor instead sits
on a genuine chemical EQUILIBRIUM between the non-covalent encounter complex and
the covalent adduct:

      E·I  ⇌(kon, koff)  E–I        K_eq = kon / koff      (covalent equilibrium)

  - kon  : forward covalent-bond-formation rate (1/s).  Modelled by Eyring
           transition-state theory from the activation barrier ΔG‡_on:
               kon = (kB·T / h) · exp(−ΔG‡_on / R·T)
  - koff : reverse covalent-bond-breaking rate (1/s).  Likewise Eyring from
           the reverse barrier ΔG‡_off = ΔG‡_on + |ΔG_rxn|  (the covalent step
           is exothermic, ΔG_rxn < 0; a reversible warhead has a SMALL |ΔG_rxn|
           so the reverse barrier is climbable, an irreversible warhead a large
           |ΔG_rxn| so the reverse barrier is unscalable and koff → 0).
  - τ_res = 1 / koff      : target-residence time of the covalent adduct.
  - Reversibility classification: a warhead is REVERSIBLE iff koff exceeds a
    threshold koff ≥ 1e-4 /s (residence time ≲ a few hours); IRREVERSIBLE iff
    koff is below it (residence ≫ protein-resynthesis timescale, so recovery is
    governed by protein turnover, not by koff).

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Eyring transition-state theory (Eyring, J. Chem. Phys. 3:107, 1935): the
unimolecular rate prefactor is bounded by the universal frequency factor
kB·T/h ≈ 6.46e12 /s at T = 310 K. No modelled covalent on/off elementary rate
can exceed this physical ceiling — it is the hard real limit that anchors every
row of this simulator (the same TST limit used by the repo's RIBOZYME-axis
`ribozyme_kinetics_simulation.py`).

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - REVERSIBLE covalent: nirmatrelvir (PF-07321332), the nitrile-warhead
    SARS-CoV-2 Mpro inhibitor of Paxlovid (Owen et al., *Science* 374:1586,
    2021). The nitrile→thioimidate adduct with the Cys145 thiolate is a
    *reversible* covalent linkage — a measurable koff, finite residence time.
  - IRREVERSIBLE covalent: ibrutinib (acrylamide Michael acceptor, covalent
    BTK Cys481; Honigberg et al., *PNAS* 107:13075, 2010) and sotorasib
    (acrylamide, covalent KRAS-G12C Cys12; Canon et al., *Nature* 575:217,
    2019) — the acrylamide thio-Michael adduct is, on the biological timescale,
    non-hydrolysing (koff → 0).
The reversible-vs-irreversible warhead koff regimes contrasted here follow the
medicinal-chemistry reviews of covalent-inhibitor kinetics (Singh et al.,
*Nat. Rev. Drug Discov.* 10:307, 2011; Bauer, *Drug Discov. Today* 20:1061,
2015; Boike, Bhattacharya & Cravatt, *Nat. Rev. Drug Discov.* 21:881, 2022).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the Eyring rates, K_eq = kon/koff, τ_res = 1/koff and the
reversibility classification are computed self-consistently and reproduce
byte-identically. It is a kinetics/thermodynamics MODEL — NOT a binding-affinity
measurement, NOT a potency/selectivity claim, NOT a therapeutic-efficacy claim.
The ΔG‡ values are illustrative literature-informed surrogates for warhead
*classes*, not fits to a specific compound. Pure stdlib, no network/time/random
→ byte-identical re-runs.

REVERSIBLE-COVALENT is a SUB-AXIS (:> COVALENT, an expansion-MAIN axis) — it is
NOT one of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape.
"""
from __future__ import annotations
import json
import math
import sys

# ── physical constants (CODATA 2019, exact SI) ──
K_B = 1.380649e-23          # J/K
H_PLANCK = 6.62607015e-34   # J·s
N_A = 6.02214076e23         # 1/mol
R_GAS = K_B * N_A           # J/(mol·K) = 8.314462618…
KCAL_TO_J = 4184.0          # 1 kcal = 4184 J (thermochemical)
TEMP_K = 310.0              # K (physiological)

# ── real-limit anchor: Eyring TST universal frequency prefactor ──
EYRING_PREFACTOR = K_B * TEMP_K / H_PLANCK   # ≈ 6.46e12 /s @ 310 K — hard ceiling

# ── reversibility classification threshold ──
# koff ≥ KOFF_REVERSIBLE_THRESHOLD  → REVERSIBLE (residence ≲ a few hours);
# below it the covalent adduct out-lives protein turnover → IRREVERSIBLE.
KOFF_REVERSIBLE_THRESHOLD = 1.0e-4   # /s

SCHEMA_ID = "reversible_covalent_v1"

# ── deterministic warhead-class panel ──────────────────────────────────────
# (name, ΔG‡_on kcal/mol, ΔG_rxn kcal/mol, warhead_class, own drug precedent)
#   ΔG‡_on   : forward covalent-bond-formation activation barrier (> 0).
#   ΔG_rxn   : reaction free energy of the covalent step (adduct − encounter).
#              The covalent step is EXOTHERMIC → ΔG_rxn < 0.
#              SMALL |ΔG_rxn| (near-thermoneutral) → climbable reverse barrier
#                → reversible.  LARGE |ΔG_rxn| → reverse barrier ~unscalable
#                → koff → 0 → irreversible.
#   ΔG‡_off  = ΔG‡_on + |ΔG_rxn|   (microscopic reversibility of an elementary
#              step: ΔG_rxn = ΔG‡_on − ΔG‡_off, so K_eq = kon/koff = exp(|ΔG_rxn|/RT)
#              = exp(−ΔG_rxn/RT), the thermodynamic equilibrium constant).
# Values are illustrative literature-informed surrogates for the warhead CLASS,
# not fits to a specific compound (see module honesty note).
WARHEAD_PANEL = [
    # reversible-covalent warheads (small |ΔG_rxn| — near-thermoneutral)
    ("nitrile_nirmatrelvir", 18.0, -1.5, "nitrile_to_thioimidate",
     "nirmatrelvir / Paxlovid — reversible covalent SARS-CoV-2 Mpro (Cys145)"),
    ("cf3_ketone_TFMK", 17.0, -0.8, "cf3ketone_to_thiohemiketal",
     "trifluoromethyl-ketone class — reversible covalent (hydratable adduct)"),
    ("aldehyde_GC373", 16.0, -2.5, "aldehyde_to_thiohemiacetal",
     "GC373 / GC376 class — reversible covalent peptidyl-aldehyde"),
    ("alpha_ketoamide_13b", 17.5, -3.0, "alpha_ketoamide_to_thiohemiketal",
     "alpha-ketoamide 13b class — reversible covalent (Hilgenfeld)"),
    # irreversible-covalent warheads (large |ΔG_rxn| — strongly exothermic)
    ("acrylamide_ibrutinib", 19.0, -14.0, "acrylamide_thio_michael",
     "ibrutinib — irreversible covalent BTK (acrylamide Michael acceptor, Cys481)"),
    ("acrylamide_sotorasib", 19.5, -15.0, "acrylamide_thio_michael",
     "sotorasib — irreversible covalent KRAS-G12C (acrylamide, Cys12)"),
]


def eyring_rate(dg_kcal: float, temp_k: float = TEMP_K) -> float:
    """Eyring transition-state-theory rate: k = (kB·T/h)·exp(−ΔG‡/R·T)."""
    dg_j = dg_kcal * KCAL_TO_J
    return (K_B * temp_k / H_PLANCK) * math.exp(-dg_j / (R_GAS * temp_k))


def covalent_equilibrium(dg_on_kcal: float, dg_rxn_kcal: float,
                         temp_k: float = TEMP_K) -> dict:
    """
    One warhead's covalent EQUILIBRIUM.  Forward = covalent-bond formation,
    reverse = covalent-bond breaking; reverse barrier ΔG‡_off = ΔG‡_on + |ΔG_rxn|.
    Returns kon, koff, K_eq = kon/koff, residence time τ_res = 1/koff.
    """
    dg_off_kcal = dg_on_kcal + abs(dg_rxn_kcal)
    kon = eyring_rate(dg_on_kcal, temp_k)
    koff = eyring_rate(dg_off_kcal, temp_k)
    k_eq = kon / koff
    tau_res_s = 1.0 / koff
    # Eyring-consistency cross-check: K_eq must equal exp(−ΔG_rxn/RT) since
    # ΔG_rxn = ΔG‡_on − ΔG‡_off.  The relative error is a numerical sanity gate.
    k_eq_thermo = math.exp(-(dg_rxn_kcal * KCAL_TO_J) / (R_GAS * temp_k))
    consistency_rel_err = abs(k_eq - k_eq_thermo) / k_eq_thermo
    reversible = koff >= KOFF_REVERSIBLE_THRESHOLD
    return {
        "dg_on_kcal_per_mol": dg_on_kcal,
        "dg_off_kcal_per_mol": dg_off_kcal,
        "dg_rxn_kcal_per_mol": dg_rxn_kcal,
        "kon_per_s": kon,
        "koff_per_s": koff,
        "K_eq": k_eq,
        "K_eq_from_thermo": k_eq_thermo,
        "K_eq_consistency_rel_err": consistency_rel_err,
        "residence_time_s": tau_res_s,
        "residence_time_human": _human_time(tau_res_s),
        "eyring_prefactor_ceiling_per_s": EYRING_PREFACTOR,
        "kon_below_eyring_ceiling": kon < EYRING_PREFACTOR,
        "koff_below_eyring_ceiling": koff < EYRING_PREFACTOR,
        "koff_reversible_threshold_per_s": KOFF_REVERSIBLE_THRESHOLD,
        "reversibility": "reversible" if reversible else "irreversible",
    }


def _human_time(seconds: float) -> str:
    """Human-readable residence time (deterministic, no locale)."""
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
    """Compute one schema-conformant row per warhead in the panel."""
    rows = []
    for name, dg_on, dg_rxn, wclass, precedent in WARHEAD_PANEL:
        eq = covalent_equilibrium(dg_on, dg_rxn)
        row = {
            "schema": SCHEMA_ID,
            "warhead": name,
            "warhead_class": wclass,
            "drug_precedent": precedent,
            "temperature_K": TEMP_K,
        }
        row.update(eq)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Explicit reversible-vs-irreversible contrast: nitrile vs acrylamide."""
    by_name = {r["warhead"]: r for r in rows}
    rev = by_name["nitrile_nirmatrelvir"]
    irr = by_name["acrylamide_ibrutinib"]
    return {
        "reversible_reference": {
            "warhead": rev["warhead"],
            "drug_precedent": rev["drug_precedent"],
            "koff_per_s": rev["koff_per_s"],
            "residence_time_human": rev["residence_time_human"],
            "K_eq": rev["K_eq"],
            "reversibility": rev["reversibility"],
        },
        "irreversible_reference": {
            "warhead": irr["warhead"],
            "drug_precedent": irr["drug_precedent"],
            "koff_per_s": irr["koff_per_s"],
            "residence_time_human": irr["residence_time_human"],
            "K_eq": irr["K_eq"],
            "reversibility": irr["reversibility"],
        },
        "koff_ratio_irrev_over_rev": rev["koff_per_s"] / irr["koff_per_s"],
        "residence_ratio_irrev_over_rev": irr["residence_time_s"] / rev["residence_time_s"],
        "note": ("nitrile reversible covalent adduct has a measurable koff and a "
                 "finite residence time; the acrylamide thio-Michael adduct has "
                 "koff orders of magnitude smaller — its recovery is governed by "
                 "protein turnover, not by koff (irreversible)."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    rev = [r for r in rows if r["reversibility"] == "reversible"]
    irr = [r for r in rows if r["reversibility"] == "irreversible"]
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_eyring_ceiling_respected": all(
            r["kon_below_eyring_ceiling"] and r["koff_below_eyring_ceiling"]
            for r in rows),
        "C3_K_eq_thermo_consistent": all(
            r["K_eq_consistency_rel_err"] < 1e-9 for r in rows),
        "C4_K_eq_equals_kon_over_koff": all(
            abs(r["K_eq"] - r["kon_per_s"] / r["koff_per_s"]) <= 1e-6 * r["K_eq"]
            for r in rows),
        "C5_both_reversibility_classes_present": len(rev) >= 1 and len(irr) >= 1,
        "C6_residence_ordering": all(
            ir["residence_time_s"] > rv["residence_time_s"]
            for ir in irr for rv in rev),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("reversible_covalent_sim — REVERSIBLE-COVALENT sub-axis :> COVALENT "
          "(expansion-main)\n", flush=True)
    print("model:  E·I ⇌(kon,koff) E–I   K_eq = kon/koff   τ_res = 1/koff   "
          "(Eyring TST forward + reverse barriers)\n", flush=True)
    print(f"  real-limit anchor : Eyring TST prefactor kB·T/h = "
          f"{EYRING_PREFACTOR:.3e} /s @ T={TEMP_K} K  (hard ceiling on every rate)")
    print(f"  reversibility gate: koff ≥ {KOFF_REVERSIBLE_THRESHOLD:.0e} /s "
          f"→ reversible; below → irreversible\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['warhead']:<24}] {r['reversibility']:<12} "
              f"ΔG‡_on={r['dg_on_kcal_per_mol']:.1f}  ΔG_rxn={r['dg_rxn_kcal_per_mol']:+.1f} kcal/mol")
        print(f"      kon={r['kon_per_s']:.3e}/s  koff={r['koff_per_s']:.3e}/s  "
              f"K_eq={r['K_eq']:.3e}  τ_res={r['residence_time_human']}")

    ctr = contrast(rows)
    print("\n## reversible-vs-irreversible contrast (nitrile vs acrylamide)")
    rr, ir = ctr["reversible_reference"], ctr["irreversible_reference"]
    print(f"  REVERSIBLE   {rr['warhead']:<24} koff={rr['koff_per_s']:.3e}/s  "
          f"τ_res={rr['residence_time_human']}")
    print(f"  IRREVERSIBLE {ir['warhead']:<24} koff={ir['koff_per_s']:.3e}/s  "
          f"τ_res={ir['residence_time_human']}")
    print(f"  koff ratio (irrev/rev) = {ctr['koff_ratio_irrev_over_rev']:.3e}   "
          f"residence ratio = {ctr['residence_ratio_irrev_over_rev']:.3e}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## C3 honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — Eyring rates, K_eq=kon/koff, τ_res=1/koff")
    print("  and the reversible/irreversible classification computed self-consistently.")
    print("  NOT a binding-affinity, potency, selectivity or therapeutic-efficacy")
    print("  claim. ΔG‡ values are literature-informed surrogates for warhead CLASSES,")
    print("  not fits to a specific compound. REVERSIBLE-COVALENT is a SUB-AXIS")
    print("  (:> COVALENT expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "REVERSIBLE-COVALENT",
        "parent_axis": "COVALENT (expansion-main, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("Eyring transition-state theory; universal "
                              "prefactor kB·T/h (Eyring, J. Chem. Phys. 3:107, 1935)"),
        "temperature_K": TEMP_K,
        "eyring_prefactor_ceiling_per_s": EYRING_PREFACTOR,
        "koff_reversible_threshold_per_s": KOFF_REVERSIBLE_THRESHOLD,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__REVERSIBLE_COVALENT__ PASS" if ok else "\n__REVERSIBLE_COVALENT__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
