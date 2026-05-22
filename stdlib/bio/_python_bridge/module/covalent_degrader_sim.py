#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
covalent_degrader_sim.py — COVALENT-DEGRADER sub-axis :> BIFUNCTIONAL
(expansion-main).

Deterministic, stdlib-only real-limits model of a COVALENT DEGRADER: a
bifunctional degrader (one warhead binds the target, one recruits an E3
ubiquitin ligase) in which ONE of the two warheads is a COVALENT warhead — it
forms an irreversible bond, removing the off-rate of that engagement. This is
the in-silico simulator-consistency layer for the COVALENT-DEGRADER sub-axis
registered in AXIS/HIERARCHY.tape `@D sub_under_bifunctional` — see the sibling
note `covalent_degrader_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A bifunctional degrader nucleates the productive ternary complex

      Target · Degrader · E3

A REVERSIBLE degrader holds each end by a non-covalent equilibrium — every
engagement has a finite off-rate koff, so the bound fraction saturates at the
mass-action equilibrium occupancy. A COVALENT degrader replaces ONE engagement
(the target warhead, OR the E3 recruiter) with a covalent warhead:

  (1) Covalent engagement kinetics — the irreversible step.
      The covalent warhead first forms a reversible encounter complex (K_i)
      and then commits an irreversible covalent bond at rate k_inact. The
      pseudo-first-order covalent-engagement rate is

            k_obs = k_inact · [L] / (K_i + [L])

      and over an exposure window t the covalently-engaged fraction is

            f_cov(t) = 1 − exp(−k_obs · t)        (irreversible accumulation)

      Because the bond does not break (koff → 0), f_cov → 1 as t grows — the
      covalent step REMOVES the off-rate of that engagement. A reversible
      engagement at the same site instead plateaus at the mass-action value
      f_rev = [L]/(K_d + [L]) < 1.

  (2) Ternary-complex coupling.
      The productive ternary fraction is the product of the two engagement
      occupancies (one covalent, one reversible), with a linker cooperativity
      factor α ≥ 1 on the reversible second site:

            f_ternary = f_cov(t) · f2,   f2 = [E3]/(K_d_E3/α + [E3])

      The covalent contrast: f_ternary(covalent) vs f_ternary(all-reversible)
      with the SAME affinities — the covalent end drives its occupancy to ~1.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
1. MASS-ACTION LAW (Guldberg & Waage, 1864). Every reversible engagement
   occupancy and the ternary fraction are closed-form mass-action solutions of
   the dissociation equilibria; no modelled fraction may exceed 1.0 — the unit
   ceiling is the hard real-limit gate (acceptance C2).
2. IRREVERSIBLE-INACTIVATION KINETICS — the kinact/K_i framework for covalent
   inhibitors (Copeland, *Evaluation of Enzyme Inhibitors in Drug Discovery*,
   2nd ed., 2013, ch. 8; Strelow, *SLAS Discov.* 22:3, 2017). A covalent
   warhead's engaged fraction is f_cov(t) = 1 − exp(−k_obs·t) and APPROACHES
   1.0 monotonically — the off-rate is removed. The model's covalent fraction
   must be a monotone-increasing, [0,1)-bounded function of exposure time that
   strictly exceeds the matched reversible plateau (acceptance C3/C5).

────────────────────────────────────────────────────────────────────────────
OWN PRECEDENT (governance g3 / forbidden-patterns f1, f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
COVALENT-DEGRADER is described ONLY by its own modality precedent, never
lattice-derived: covalent CRBN- and DCAF16-recruiting bifunctional degraders —
covalent recruiters of the E3 substrate-receptor DCAF16 (Zhang et al.,
*Nat. Chem. Biol.* 15:737, 2019), and covalent-handle degraders against
covalently-engaged targets such as covalent BTK degraders (Tinworth et al.,
*ACS Chem. Biol.* 14:342, 2019). COVALENT-DEGRADER is a RESEARCH / EARLY-CLINICAL
modality: it is not an established approved class. No quantity in this module is
derived from the n=6 lattice.

Cross note (→ COVALENT expansion-main): the covalent-warhead engagement step
here is the same irreversible-covalent chemistry treated by the COVALENT
expansion-main axis (`reversible_covalent_sim.py`). COVALENT-DEGRADER sits under
BIFUNCTIONAL (its degrader architecture) but its warhead chemistry is the
COVALENT axis's domain — a deliberate cross-axis relationship, not a fork.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The `__COVALENT_DEGRADER__ PASS` sentinel certifies IN-SILICO simulator+metadata
internal consistency ONLY: that the irreversible-engagement kinetics, the
mass-action reversible occupancies and the ternary coupling are computed
self-consistently and reproduce byte-identically. It is a kinetics/equilibrium
MODEL — NOT an affinity measurement, NOT a degradation (DC50/Dmax) claim, NOT a
therapeutic-efficacy claim. COVALENT-DEGRADER is research/early-clinical;
nothing here is a clinical claim. K_i / k_inact / K_d / α values are
illustrative literature-informed surrogates for the modality, not fits to a
specific compound. Pure stdlib, no network/time/random → byte-identical re-runs.

COVALENT-DEGRADER is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it
is NOT one of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape
`@D sub_under_bifunctional`.
"""
from __future__ import annotations
import json
import math
import sys

SCHEMA_ID = "covalent_degrader_v1"

# ── deterministic COVALENT-DEGRADER panel ───────────────────────────────────
# (name, covalent_end, K_i_nM, k_inact_per_s, K_d_other_nM, alpha,
#  t_exposure_s, precedent)
#   covalent_end : which warhead is covalent — "target" or "E3".
#   K_i          : reversible encounter-complex dissociation constant of the
#                  COVALENT warhead before the irreversible step (nM).
#   k_inact      : irreversible covalent-commitment rate of that warhead (1/s).
#   K_d_other    : dissociation constant of the OTHER (reversible) warhead (nM).
#   alpha        : ternary cooperativity factor (>= 1) on the reversible site.
#   t_exposure   : exposure window over which covalent engagement accumulates (s).
# Values are illustrative literature-informed surrogates for the modality,
# not fits to a specific compound (see module honesty note).
COVALENT_DEGRADER_PANEL = [
    ("covdeg_DCAF16_recruiter",
     "E3", 150.0, 0.002, 60.0, 18.0, 7200.0,
     "covalent DCAF16-recruiting degrader (Zhang et al., Nat. Chem. Biol. 2019)"),
    ("covdeg_covalent_BTK_handle",
     "target", 90.0, 0.0035, 80.0, 12.0, 7200.0,
     "covalent-handle BTK degrader (Tinworth et al., ACS Chem. Biol. 2019)"),
    ("covdeg_CRBN_covalent",
     "E3", 200.0, 0.0015, 50.0, 22.0, 7200.0,
     "covalent CRBN-recruiting bifunctional degrader (research-stage)"),
    ("covdeg_slow_warhead",
     "target", 250.0, 0.0006, 120.0, 8.0, 7200.0,
     "covalent degrader with a slow-committing warhead"),
]

# Matched all-reversible degrader reference: SAME affinities, but the covalent
# end is replaced by a reversible engagement with K_d = K_i (no covalent step).
# Its occupancy plateaus at the mass-action value < 1.


def covalent_engagement(k_i_nM: float, k_inact_per_s: float,
                        conc_ligand_nM: float, t_exposure_s: float) -> dict:
    """
    Irreversible covalent-engagement kinetics (Copeland kinact/K_i framework).

        k_obs    = k_inact * [L] / (K_i + [L])      pseudo-first-order rate
        f_cov(t) = 1 - exp(-k_obs * t)              covalently-engaged fraction

    f_cov is monotone-increasing in t and asymptotes to 1.0 — the covalent
    step removes the off-rate (koff -> 0).
    """
    k_obs = k_inact_per_s * conc_ligand_nM / (k_i_nM + conc_ligand_nM)
    f_cov = 1.0 - math.exp(-k_obs * t_exposure_s)
    return {
        "k_i_nM": k_i_nM,
        "k_inact_per_s": k_inact_per_s,
        "k_obs_per_s": k_obs,
        "t_exposure_s": t_exposure_s,
        "covalent_engaged_fraction": f_cov,
    }


def reversible_engagement(k_d_nM: float, conc_ligand_nM: float) -> float:
    """Mass-action equilibrium occupancy of a reversible engagement."""
    return conc_ligand_nM / (k_d_nM + conc_ligand_nM)


def ternary(f_covalent: float, k_d_other_nM: float, conc_other_nM: float,
            alpha: float) -> dict:
    """
    Ternary-complex coupling: covalent engagement occupancy times the
    reversible second-site occupancy (with linker cooperativity alpha).
    """
    k_d_eff = k_d_other_nM / alpha
    f2 = conc_other_nM / (k_d_eff + conc_other_nM)
    f_ternary = f_covalent * f2
    return {
        "k_d_other_nM": k_d_other_nM,
        "alpha": alpha,
        "k_d_other_effective_nM": k_d_eff,
        "reversible_site_fraction": f2,
        "ternary_fraction": f_ternary,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per covalent degrader in the panel."""
    # Fixed deterministic assay concentrations (nM).
    conc_degrader_nM = 100.0
    conc_other_partner_nM = 75.0
    rows = []
    for (name, cov_end, k_i, k_inact, k_d_other, alpha, t_exp,
         precedent) in COVALENT_DEGRADER_PANEL:
        cov = covalent_engagement(k_i, k_inact, conc_degrader_nM, t_exp)
        tern = ternary(cov["covalent_engaged_fraction"], k_d_other,
                       conc_other_partner_nM, alpha)
        # Matched all-reversible reference: covalent end -> reversible with
        # K_d = K_i; its plateau occupancy is the mass-action value < 1.
        f_rev_match = reversible_engagement(k_i, conc_degrader_nM)
        tern_rev = ternary(f_rev_match, k_d_other, conc_other_partner_nM, alpha)
        row = {
            "schema": SCHEMA_ID,
            "covalent_degrader": name,
            "covalent_end": cov_end,
            "drug_precedent": precedent,
            "modality_stage": "research/early-clinical (not an approved class)",
            "conc_degrader_nM": conc_degrader_nM,
            "conc_other_partner_nM": conc_other_partner_nM,
        }
        row.update(cov)
        row.update(tern)
        row["reversible_match_engaged_fraction"] = f_rev_match
        row["reversible_match_ternary_fraction"] = tern_rev["ternary_fraction"]
        # Covalent advantage: covalent ternary divided by matched reversible.
        row["covalent_ternary_advantage"] = (
            tern["ternary_fraction"] / tern_rev["ternary_fraction"])
        # The covalent step removes the off-rate: engaged fraction strictly
        # exceeds the reversible plateau at the same affinity.
        row["off_rate_removed"] = (
            cov["covalent_engaged_fraction"] > f_rev_match)
        rows.append(row)
    return rows


def time_course(row_panel_index: int = 0) -> dict:
    """
    Monotonicity witness: covalent-engaged fraction sampled over an increasing
    exposure grid. f_cov(t) = 1 - exp(-k_obs*t) must be strictly increasing and
    bounded in [0, 1) — the irreversible-accumulation real-limit signature.
    """
    name, cov_end, k_i, k_inact, _kd, _a, _t, _prec = \
        COVALENT_DEGRADER_PANEL[row_panel_index]
    conc = 100.0
    k_obs = k_inact * conc / (k_i + conc)
    grid_s = [0.0, 600.0, 1800.0, 3600.0, 7200.0, 14400.0, 28800.0]
    fracs = [1.0 - math.exp(-k_obs * t) for t in grid_s]
    monotone = all(fracs[i + 1] > fracs[i] for i in range(len(fracs) - 1))
    bounded = all(0.0 <= f < 1.0 for f in fracs)
    return {
        "degrader": name,
        "k_obs_per_s": k_obs,
        "exposure_grid_s": grid_s,
        "covalent_engaged_fraction_grid": fracs,
        "monotone_increasing": monotone,
        "bounded_unit_interval": bounded,
    }


def acceptance(rows: list, tc: dict) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    crit = {
        "C1_panel_non_empty": len(rows) >= 4,
        "C2_mass_action_fractions_bounded": all(
            0.0 <= r["covalent_engaged_fraction"] < 1.0
            and 0.0 <= r["reversible_site_fraction"] <= 1.0
            and 0.0 <= r["ternary_fraction"] <= 1.0
            for r in rows),
        "C3_ternary_is_product_of_sites": all(
            abs(r["ternary_fraction"]
                - r["covalent_engaged_fraction"] * r["reversible_site_fraction"])
            <= 1e-12 for r in rows),
        "C4_covalent_beats_matched_reversible": all(
            r["covalent_ternary_advantage"] > 1.0 and r["off_rate_removed"]
            for r in rows),
        "C5_covalent_engagement_monotone_bounded": (
            tc["monotone_increasing"] and tc["bounded_unit_interval"]),
        "C6_covalent_end_labelled": all(
            r["covalent_end"] in ("target", "E3") for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("covalent_degrader_sim — COVALENT-DEGRADER sub-axis :> BIFUNCTIONAL "
          "(expansion-main)\n", flush=True)
    print("model:  Target · Degrader · E3  ternary complex; ONE warhead is "
          "covalent (target OR E3)")
    print("        f_cov(t) = 1 − exp(−k_obs·t),  k_obs = k_inact·[L]/(K_i+[L])"
          "   (irreversible — koff→0)")
    print("        f_ternary = f_cov · [E3]/(K_d_E3/α + [E3])   (covalent end "
          "removes its off-rate)\n", flush=True)
    print("  real-limit 1 : mass-action law (Guldberg & Waage 1864) — every "
          "bound fraction ≤ 1.0")
    print("  real-limit 2 : irreversible-inactivation kinetics (Copeland 2013, "
          "kinact/K_i) —")
    print("                 f_cov(t)=1−exp(−k_obs·t), monotone & bounded, "
          "asymptotes to 1.0")
    print("  cross-axis   : the covalent-warhead step → COVALENT expansion-main "
          "(reversible_covalent_sim)\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['covalent_degrader']:<26}] covalent end={r['covalent_end']:<7}"
              f"  K_i={r['k_i_nM']:.0f}nM  k_inact={r['k_inact_per_s']:.4f}/s")
        print(f"      k_obs={r['k_obs_per_s']:.3e}/s  f_cov={r['covalent_engaged_fraction']:.4f}"
              f"  (reversible match={r['reversible_match_engaged_fraction']:.4f})")
        print(f"      ternary={r['ternary_fraction']:.4f}  "
              f"reversible-match ternary={r['reversible_match_ternary_fraction']:.4f}"
              f"  covalent advantage={r['covalent_ternary_advantage']:.2f}×")

    tc = time_course(0)
    print(f"\n## covalent-engagement time course (monotonicity witness — {tc['degrader']})")
    for t, f in zip(tc["exposure_grid_s"], tc["covalent_engaged_fraction_grid"]):
        print(f"  t={t:>8.0f} s   f_cov={f:.6f}")
    print(f"  monotone-increasing={tc['monotone_increasing']}  "
          f"bounded[0,1)={tc['bounded_unit_interval']}")

    acc = acceptance(rows, tc)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — irreversible-engagement kinetics,")
    print("  mass-action reversible occupancies and ternary coupling computed")
    print("  self-consistently. NOT an affinity, degradation (DC50/Dmax) or")
    print("  therapeutic claim. COVALENT-DEGRADER is RESEARCH/EARLY-CLINICAL,")
    print("  not an approved class. K_i/k_inact/K_d/α are literature-informed")
    print("  surrogates, not compound fits. COVALENT-DEGRADER is a SUB-AXIS")
    print("  (:> BIFUNCTIONAL expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "COVALENT-DEGRADER",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "cross_axis_note": ("the covalent-warhead engagement step is the "
                            "domain of the COVALENT expansion-main axis "
                            "(reversible_covalent_sim.py)"),
        "real_limit_anchors": [
            "mass-action law (Guldberg & Waage, 1864) — bound fractions <= 1.0",
            ("irreversible-inactivation kinetics, kinact/K_i framework "
             "(Copeland, Evaluation of Enzyme Inhibitors in Drug Discovery, "
             "2nd ed., 2013, ch. 8; Strelow, SLAS Discov. 22:3, 2017) — "
             "f_cov(t)=1-exp(-k_obs*t), monotone & unit-bounded"),
        ],
        "rows": rows,
        "covalent_engagement_time_course": tc,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency "
                                   "ONLY (g8/f2) — COVALENT-DEGRADER is "
                                   "research/early-clinical, not a therapeutic "
                                   "or degradation-potency claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__COVALENT_DEGRADER__ PASS" if ok else "\n__COVALENT_DEGRADER__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
