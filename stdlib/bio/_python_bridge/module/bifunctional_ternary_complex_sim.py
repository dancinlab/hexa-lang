#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bifunctional_ternary_complex_sim.py — BIFUNCTIONAL axis (EXPANSION-MAIN,
NOT core-5) three-body ternary-complex equilibrium model.

Deterministic, stdlib-only. No network, no random, no wall-clock dependence
=> byte-identical re-runs.

WHAT THIS COMPUTES (the targeted-protein-degradation ternary equilibrium):

  A bifunctional degrader D bridges a target protein T and an E3 ubiquitin
  ligase E into a productive TERNARY complex T.D.E (target - degrader - E3),
  which drives target poly-ubiquitination and proteasomal degradation.

  Three coupled equilibria (three-body binding model, Douglass et al. 2013):
      T  + D   <=>  T.D       dissociation constant  K_d,T
      D  + E   <=>  D.E       dissociation constant  K_d,E
      T.D + E  <=>  T.D.E     effective K = K_d,E / alpha
      D.E + T  <=>  T.D.E     effective K = K_d,T / alpha   (same species)
  where alpha is the COOPERATIVITY factor: alpha > 1 = positive cooperativity
  (the ternary complex is more stable than the binary affinities alone
  predict, from a favourable target-E3 protein-protein interaction at the
  ternary interface), alpha = 1 = non-cooperative, alpha < 1 = negative.

  (A) Cooperativity scan -- the equilibrium ternary-complex concentration
      [T.D.E] is recomputed at a fixed degrader dose for a range of alpha.
      Thermodynamics requires the peak ternary concentration to be
      MONOTONE non-decreasing in alpha (Gadd et al. 2017 measured strongly
      positive cooperativity for the VHL-MZ1-BRD4 PROTAC ternary complex).

  (B) Dose scan -- the HOOK EFFECT. [T.D.E] as a function of total degrader
      dose [D]_total is a BELL-SHAPED (hook) curve: it rises from a low-dose
      value, reaches a single interior maximum, then DECAYS at high dose.
      The high-dose autoinhibitory arm is forced: excess degrader saturates
      BOTH binary equilibria SEPARATELY (nearly every T in T.D, nearly every
      E in D.E, but on distinct degrader molecules), competitively depleting
      the bridged ternary species. This is the established hook effect of
      every bifunctional / bivalent recruitment system.

REAL-LIMIT ANCHORS (hexa-bio AGENTS.tape g1 real-limits-first):
  - the hook effect -- the non-monotonic bell-shaped ternary-complex dose
    response. Douglass EF Jr, Miller CJ, Sparer G, Shapiro H, Spiegel DA.
    A comprehensive mathematical model for three-body binding equilibria.
    J Am Chem Soc 2013;135(16):6092-6099.  Han B. A suite of mathematical
    solutions to describe ternary complex formation ... J Biol Chem 2020;
    295(45):15280-15291.
  - the ternary-complex cooperativity factor alpha. Gadd MS, Testa A,
    Lucas X, et al. Structural basis of PROTAC cooperative recognition for
    selective targeted protein degradation. Nat Chem Biol 2017;13(5):514-521.

n=6 LATTICE STANCE (g2 lattice-is-tool, g3/f1 honesty-external,
HEXA-BIFUNCTIONAL.tape f_lattice_fit + n6_honest_stance):
  A ternary complex has three bodies because a heterobifunctional degrader
  bridges exactly one target and one E3 ligase -- the modality's definition.
  The cooperativity alpha and the hook-effect dose maximum are
  chemical-equilibrium / mass-action results.  Neither alpha, nor any
  K_d, nor any concentration, nor the count of clinical PROTACs is derived
  from the n=6 lattice (sigma=12, tau=4, phi=2, J2=24).  This module
  performs NO lattice arithmetic.

IN-SILICO SCOPE (g8_in_silico_only / f2):
  A PASS here verifies IN-SILICO simulator + metadata internal consistency
  ONLY -- that the mass-action ternary-equilibrium algebra is internally
  consistent, the cooperativity-alpha dependence is monotone, and the
  dose response is the bell-shaped hook curve.  It is NOT a therapeutic,
  degradation-efficacy, DC50, Dmax, immunogenic, or regulatory claim.
  The BIFUNCTIONAL axis is scientifically UNPROVEN at the wet-lab
  boundary.  See HEXA-BIFUNCTIONAL.tape lim_in_silico_boundary +
  CLOSURE_RESIDUAL_BACKLOG.md section 0.

Sentinel:  __BIFUNCTIONAL_TERNARY_COMPLEX__ PASS   (or FAIL).
"""
from __future__ import annotations
import json
import sys

# -- module identity --
VERSION = "1.0.0"
AXIS = "BIFUNCTIONAL"
AXIS_LAYER = "expansion-main (NOT core-5)"

# -- citations (real-limit anchors) --
DOUGLASS_2013 = "Douglass et al., J Am Chem Soc 2013;135:6092-6099"
GADD_2017 = "Gadd et al., Nat Chem Biol 2017;13:514-521"
HAN_2020 = "Han, J Biol Chem 2020;295:15280-15291"

# -- illustrative model parameters (concentrations in micromolar) --
# These are modeling magnitudes, NOT measured constants for any named drug
# (g3/f1 -- the named PROTACs are described by their own precedent only).
TARGET_TOTAL_UM = 1.0      # total target protein  [T]_total
E3_TOTAL_UM = 1.0          # total E3 ligase       [E]_total
KD_TARGET_UM = 0.1         # binary  T + D  <=> T.D    dissociation constant
KD_E3_UM = 0.1             # binary  D + E  <=> D.E    dissociation constant


# ---------------------------------------------------------------------
# three-body ternary-complex equilibrium solver
# ---------------------------------------------------------------------

def _free_degrader_equilibrium(d_total, t_total, e3_total,
                               kd_t, kd_e, alpha):
    """Solve for free degrader concentration [D] by deterministic bisection.

    Conservation of degrader:
        D_total = D + [T.D] + [D.E] + [T.D.E]
    With free target/E3 expressed via their own conservation laws.  For a
    given free degrader D, the binary and ternary species are closed-form:

        Let the target partition between free T, binary T.D, and ternary.
        Define for the target arm  a_T = D / kd_t  (binary propensity) and
        for the E3 arm             a_E = D / kd_e.
        A target molecule is: free, in T.D (no E3), or in T.D.E (with E3).
        The ternary uses the cooperativity-scaled second-event affinity:
        binding E to T.D has effective Kd = kd_e / alpha.

    We use the standard three-body partition-function form (Douglass 2013):
        free target fraction-weight  : 1
        T.D weight                   : a_T
        T.D.E weight                 : a_T * (E_free / kd_e) * alpha
    and symmetrically for E3.  Because target and E3 conservation couple
    through the shared ternary term, we nest a bisection on free E3 inside
    the outer bisection on free D.  All deterministic, no random.
    """
    def species_for(d_free):
        # inner solve: free E3 given free D, by bisection on e3_free
        lo_e, hi_e = 0.0, e3_total
        for _ in range(200):
            e3_free = 0.5 * (lo_e + hi_e)
            # target partition given d_free and e3_free
            w_td = d_free / kd_t
            w_tde = (d_free / kd_t) * (e3_free / kd_e) * alpha
            denom_t = 1.0 + w_td + w_tde
            t_free = t_total / denom_t
            tde = t_free * w_tde
            # E3 conservation: E_total = E_free + [D.E] + [T.D.E]
            # [D.E] = e3_free * (d_free / kd_e)
            de_val = e3_free * (d_free / kd_e)
            e3_used = e3_free + de_val + tde
            if e3_used > e3_total:
                hi_e = e3_free
            else:
                lo_e = e3_free
        e3_free = 0.5 * (lo_e + hi_e)
        w_td = d_free / kd_t
        w_tde = (d_free / kd_t) * (e3_free / kd_e) * alpha
        denom_t = 1.0 + w_td + w_tde
        t_free = t_total / denom_t
        td = t_free * w_td
        tde = t_free * w_tde
        de = e3_free * (d_free / kd_e)
        return t_free, e3_free, td, de, tde

    # outer bisection on free degrader D
    lo_d, hi_d = 0.0, d_total
    for _ in range(200):
        d_free = 0.5 * (lo_d + hi_d)
        _, _, td, de, tde = species_for(d_free)
        d_used = d_free + td + de + tde
        if d_used > d_total:
            hi_d = d_free
        else:
            lo_d = d_free
    d_free = 0.5 * (lo_d + hi_d)
    t_free, e3_free, td, de, tde = species_for(d_free)
    return {
        "d_total": d_total,
        "d_free": d_free,
        "t_free": t_free,
        "e3_free": e3_free,
        "binary_TD": td,
        "binary_DE": de,
        "ternary_TDE": tde,
    }


def ternary_concentration(d_total, alpha,
                          t_total=TARGET_TOTAL_UM, e3_total=E3_TOTAL_UM,
                          kd_t=KD_TARGET_UM, kd_e=KD_E3_UM):
    """Equilibrium [T.D.E] (micromolar) for total degrader dose `d_total`."""
    sol = _free_degrader_equilibrium(d_total, t_total, e3_total,
                                     kd_t, kd_e, alpha)
    return sol["ternary_TDE"], sol


# ---------------------------------------------------------------------
# (A) cooperativity scan
# ---------------------------------------------------------------------

def cooperativity_scan(alphas, d_total_fixed):
    """Peak ternary concentration at a fixed dose, for a range of alpha."""
    rows = []
    for a in alphas:
        tde, sol = ternary_concentration(d_total_fixed, a)
        rows.append({
            "alpha": a,
            "degrader_dose_um": d_total_fixed,
            "ternary_TDE_um": tde,
            "binary_TD_um": sol["binary_TD"],
            "binary_DE_um": sol["binary_DE"],
        })
    return rows


def verify_cooperativity_monotone(rows):
    """alpha-monotonicity: ternary conc must be non-decreasing in alpha."""
    monotone = True
    violations = []
    for i in range(1, len(rows)):
        prev = rows[i - 1]["ternary_TDE_um"]
        cur = rows[i]["ternary_TDE_um"]
        # tolerance for the deterministic bisection residual
        if cur < prev - 1e-6:
            monotone = False
            violations.append(
                f"alpha {rows[i-1]['alpha']}->{rows[i]['alpha']}: "
                f"ternary {prev:.6f}->{cur:.6f} decreased")
    return {
        "monotone_non_decreasing_in_alpha": monotone,
        "violations": violations,
        "alpha_one_is_reference": any(abs(r["alpha"] - 1.0) < 1e-12
                                      for r in rows),
        "pass": monotone,
    }


# ---------------------------------------------------------------------
# (B) dose scan -- the hook effect
# ---------------------------------------------------------------------

def _dose_grid():
    """Deterministic log-spaced total-degrader dose grid (micromolar)."""
    # decades 1e-3 .. 1e3 uM, 7 points per decade -> spans below, at, and
    # far above the binary K_d so the high-dose hook arm is reached.
    grid = []
    for decade in range(-3, 4):           # -3 .. 3
        for step in range(7):
            val = (10.0 ** decade) * (10.0 ** (step / 7.0))
            grid.append(val)
    grid.append(10.0 ** 3)
    return grid


def dose_scan(alpha):
    """[T.D.E] vs total degrader dose -- the bell-shaped hook curve."""
    rows = []
    for d in _dose_grid():
        tde, sol = ternary_concentration(d, alpha)
        rows.append({
            "degrader_dose_um": d,
            "ternary_TDE_um": tde,
            "binary_TD_um": sol["binary_TD"],
            "binary_DE_um": sol["binary_DE"],
            "free_degrader_um": sol["d_free"],
        })
    return rows


def verify_hook_effect(rows):
    """Detect the hook effect: a single interior maximum (rise then fall)."""
    concs = [r["ternary_TDE_um"] for r in rows]
    n = len(concs)
    peak_idx = max(range(n), key=lambda i: concs[i])
    peak_conc = concs[peak_idx]
    first_conc = concs[0]
    last_conc = concs[-1]

    # interior maximum: not at either endpoint of the scanned range
    interior_max = 0 < peak_idx < n - 1
    # rising arm: peak strictly above the low-dose value
    rises = peak_conc > first_conc * 1.05
    # falling arm: high-dose tail strictly below the peak (autoinhibition)
    falls = last_conc < peak_conc * 0.95
    # high-dose binary saturation -- the mechanistic cause of the hook
    last = rows[-1]
    binary_saturated = (last["binary_TD_um"] > 0.5 * TARGET_TOTAL_UM
                        and last["binary_DE_um"] > 0.5 * E3_TOTAL_UM)

    non_monotonic = interior_max and rises and falls
    return {
        "peak_index": peak_idx,
        "n_dose_points": n,
        "peak_dose_um": rows[peak_idx]["degrader_dose_um"],
        "peak_ternary_TDE_um": peak_conc,
        "low_dose_ternary_um": first_conc,
        "high_dose_ternary_um": last_conc,
        "interior_maximum": interior_max,
        "rising_arm": rises,
        "falling_arm_hook": falls,
        "high_dose_binary_saturation": binary_saturated,
        "non_monotonic_bell_shaped": non_monotonic,
        "pass": non_monotonic and binary_saturated,
    }


# ---------------------------------------------------------------------
# orchestration
# ---------------------------------------------------------------------

def run():
    # (A) cooperativity scan at a fixed, near-optimal dose
    alphas = [0.5, 1.0, 2.0, 5.0, 20.0]
    fixed_dose = 0.1   # uM -- near the binary K_d, in the productive regime
    coop_rows = cooperativity_scan(alphas, fixed_dose)
    coop_check = verify_cooperativity_monotone(coop_rows)

    # (B) dose scan -- the hook effect -- at positive cooperativity
    hook_alpha = 5.0
    dose_rows = dose_scan(hook_alpha)
    hook_check = verify_hook_effect(dose_rows)

    # representative bifunctional degraders by their OWN precedent
    # (g3/f1 honesty-external -- NOT lattice-derived, NOT efficacy claims).
    degraders = [
        {"name": "ARV-471 (vepdegestrant)", "modality": "PROTAC",
         "target": "estrogen receptor (ER)", "e3_ligase": "CRBN",
         "status": "clinical development", "developer": "Arvinas / Pfizer"},
        {"name": "ARV-110 (bavdegalutamide)", "modality": "PROTAC",
         "target": "androgen receptor (AR)", "e3_ligase": "CRBN",
         "status": "clinical development", "developer": "Arvinas"},
        {"name": "lenalidomide", "modality": "molecular glue",
         "target": "IKZF1 / IKZF3 (neo-substrate)", "e3_ligase": "CRBN",
         "status": "marketed (multiple myeloma)", "developer": "(IMiD class)"},
        {"name": "thalidomide", "modality": "molecular glue",
         "target": "CRBN neo-substrates", "e3_ligase": "CRBN",
         "status": "marketed (IMiD class)", "developer": "(IMiD class)"},
        {"name": "RIBOTAC (class)", "modality": "bifunctional RNA degrader",
         "target": "RNA (recruits RNase L)", "e3_ligase": "n/a (RNase L)",
         "status": "research stage", "developer": "(research)"},
    ]

    # F-BIFUNCTIONAL falsifier checks
    falsifiers = {
        "F-BIFUNCTIONAL-1_cooperativity_monotonicity": coop_check["pass"],
        "F-BIFUNCTIONAL-2_hook_effect_non_monotonic": hook_check["pass"],
        "F-BIFUNCTIONAL-3_ternary_is_mass_action_not_lattice": True,
    }

    # acceptance criteria
    crit = {
        "C1_cooperativity_monotone_non_decreasing_in_alpha":
            coop_check["monotone_non_decreasing_in_alpha"],
        "C2_alpha_one_non_cooperative_reference_present":
            coop_check["alpha_one_is_reference"],
        "C3_dose_curve_has_interior_maximum":
            hook_check["interior_maximum"],
        "C4_dose_curve_rising_arm":
            hook_check["rising_arm"],
        "C5_dose_curve_falling_hook_arm":
            hook_check["falling_arm_hook"],
        "C6_hook_caused_by_high_dose_binary_saturation":
            hook_check["high_dose_binary_saturation"],
        "C7_ternary_dose_response_non_monotonic_bell_shaped":
            hook_check["non_monotonic_bell_shaped"],
    }
    n_pass = sum(1 for v in crit.values() if v)
    verdict = "PASS" if n_pass == len(crit) else "FAIL"

    return {
        "schema": "bifunctional_ternary_complex_v1",
        "ts": "2026-05-16T00:00:00Z",   # fixed -> deterministic witness
        "axis": AXIS,
        "axis_layer": AXIS_LAYER,
        "version": VERSION,
        "real_limit_anchors": {
            "hook_effect_citation": DOUGLASS_2013,
            "hook_effect_thermodynamics_citation": HAN_2020,
            "cooperativity_alpha_citation": GADD_2017,
        },
        "model_parameters": {
            "target_total_um": TARGET_TOTAL_UM,
            "e3_total_um": E3_TOTAL_UM,
            "kd_target_um": KD_TARGET_UM,
            "kd_e3_um": KD_E3_UM,
            "note": ("illustrative modeling magnitudes -- NOT measured "
                     "constants for any named drug (g3/f1)"),
        },
        "cooperativity_scan": coop_rows,
        "cooperativity_verification": coop_check,
        "dose_scan_hook": dose_rows,
        "hook_verification": hook_check,
        "degrader_metadata": degraders,
        "falsifiers": falsifiers,
        "acceptance_criteria": crit,
        "pass_count": n_pass,
        "total_criteria": len(crit),
        "verdict": verdict,
        "lattice_stance": ("No n=6 lattice arithmetic is performed. A ternary "
                           "complex has three bodies because a heterobifunctional "
                           "degrader bridges exactly one target and one E3 ligase "
                           "(the modality definition); the cooperativity alpha and "
                           "the hook-effect dose maximum are chemical-equilibrium / "
                           "mass-action results, NOT lattice derivations. Any "
                           "numerical coincidence with n=6 is OBSERVATION ONLY "
                           "(HEXA-BIFUNCTIONAL.tape f_lattice_fit / n6_honest_stance)."),
        "in_silico_scope": ("PASS verifies IN-SILICO simulator+metadata consistency "
                            "ONLY -- the mass-action ternary-equilibrium algebra, the "
                            "cooperativity-alpha dependence, and the bell-shaped hook "
                            "curve. NOT a therapeutic/degradation-efficacy/DC50/Dmax/"
                            "regulatory claim. The BIFUNCTIONAL axis is UNPROVEN at "
                            "the wet-lab boundary (AGENTS.tape g8_in_silico_only / f2)."),
    }


def main():
    print("bifunctional_ternary_complex_sim — BIFUNCTIONAL axis "
          f"(EXPANSION-MAIN, NOT core-5) v{VERSION}\n", flush=True)
    w = run()

    coop = w["cooperativity_scan"]
    coop_chk = w["cooperativity_verification"]
    dose = w["dose_scan_hook"]
    hook = w["hook_verification"]

    print("  (A) Cooperativity scan -- ternary-complex [T.D.E] vs alpha")
    print("      at fixed degrader dose; ternary thermodynamics (Gadd 2017)")
    print(f"      fixed degrader dose = {coop[0]['degrader_dose_um']} uM")
    print("      alpha   | ternary [T.D.E] (uM) | binary [T.D] | binary [D.E]")
    for r in coop:
        print(f"      {r['alpha']:6.2f}  | {r['ternary_TDE_um']:18.6f}   "
              f"| {r['binary_TD_um']:10.5f}   | {r['binary_DE_um']:10.5f}")
    print(f"      ternary conc monotone non-decreasing in alpha: "
          f"{coop_chk['monotone_non_decreasing_in_alpha']}")
    print()

    print("  (B) Dose scan -- the HOOK EFFECT (bell-shaped ternary response)")
    print("      three-body ternary equilibrium (Douglass 2013; Han 2020)")
    print(f"      alpha = 5.0; {hook['n_dose_points']} log-spaced dose points")
    print("      degrader dose (uM) | ternary [T.D.E] (uM)")
    # print a readable subset: every 4th point + the peak
    for i, r in enumerate(dose):
        if i % 4 == 0 or i == hook["peak_index"]:
            mark = "  <-- peak (hook maximum)" if i == hook["peak_index"] else ""
            print(f"      {r['degrader_dose_um']:18.4f} | "
                  f"{r['ternary_TDE_um']:18.6f}{mark}")
    print(f"      low-dose  [T.D.E] = {hook['low_dose_ternary_um']:.6f} uM")
    print(f"      peak      [T.D.E] = {hook['peak_ternary_TDE_um']:.6f} uM "
          f"at dose {hook['peak_dose_um']:.4f} uM")
    print(f"      high-dose [T.D.E] = {hook['high_dose_ternary_um']:.6f} uM "
          f"(autoinhibitory hook arm)")
    print(f"      non-monotonic bell-shaped (hook effect): "
          f"{hook['non_monotonic_bell_shaped']}")
    print()

    print("  falsifiers:")
    for k, v in w["falsifiers"].items():
        print(f"    [{'HOLD' if v else 'FALSIFIED'}] {k}")
    print()

    print("  acceptance criteria:")
    for k, v in w["acceptance_criteria"].items():
        print(f"    [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- BIFUNCTIONAL ternary-complex: {w['pass_count']}/"
          f"{w['total_criteria']}  ->  verdict: {w['verdict']} ---")

    print()
    print("  n=6 lattice stance: " + w["lattice_stance"])
    print()
    print("  IN-SILICO SCOPE (g8/f2): " + w["in_silico_scope"])

    emit = "--emit-witness" in sys.argv
    if emit:
        import io, os
        path = os.path.join(os.path.dirname(__file__), "runs",
                            "bifunctional_ternary_complex_events.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with io.open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        print(f"\n  [emit] appended bifunctional_ternary_complex_v1 witness "
              f"-> {path}")

    ok = w["verdict"] == "PASS"
    print("\n## witness JSON")
    print(json.dumps(w, indent=2, ensure_ascii=False))
    print("\n__BIFUNCTIONAL_TERNARY_COMPLEX__ PASS" if ok
          else "\n__BIFUNCTIONAL_TERNARY_COMPLEX__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
