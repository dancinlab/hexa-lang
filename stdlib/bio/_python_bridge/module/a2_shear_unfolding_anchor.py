#!/usr/bin/env python3
"""a2_shear_unfolding_anchor.py — LVAD scenario ② real-limit anchor.

Anchors LVAD/A2_STABILIZER.tape §3 limits #1-#3 by a deterministic stdlib
force-balance: hydrodynamic tension on a µm-scale vWF multimer under wall
shear vs the A2 unfolding threshold.

═══ HONEST RECONSTRUCTION 2026-05-16 (g1/g3 correction) ═══
An earlier build used §3 anchor numbers (ΔG 7-10 kcal/mol, k_cat 2.5/s,
thermodynamic unfold force ~1 pN) that DISAGREE with the scenario's OWN
cited primary source. Verified verbatim from the primary literature
(fetched PMC2753189 / PMC2695068):

  • A2 unfolding ΔG       = 6.6 ± 1.5 k_BT = 3.9 ± 0.9 kcal/mol
  • A2 unfolded contour   = 57 ± 5 nm  (persistence ≈ 1.1 nm)
  • A2 most-probable      ≈ 11 pN  (range 7-14 pN, LOADING-RATE dependent)
    mechanical rupture force
  • ADAMTS13 k_cat        = 0.14 s⁻¹  (single-molecule, on unfolded A2)
  • A2 domain size        ≈ 177 aa ; scissile Tyr1605-Met1606
  Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA. "Mechanoenzymatic
  cleavage of the ultralarge vascular protein von Willebrand factor."
  Science 2009;324:1330-1334.  Zhang Q et al. PNAS 2009;106:9226 (A2
  structure / scissile bond).  Crawley JT et al. Blood 2011;118:3212.

═══ HONEST VERDICT CHANGE ═══
The earlier build claimed "② UNFOLD robust across the prefactor band". With
the CORRECT measured rupture force (~11 pN), that robustness DOES NOT HOLD:
at the conservative prefactor a 5 µm multimer at 70 dyn/cm² develops only
~8.75 pN < 11 pN. The simple threshold model is therefore PREFACTOR- and
LOADING-RATE-sensitive — a rigorous verdict needs a force-clamp lifetime
(Dudko-Hummer-Szabo) treatment (drylab catalog #6, not yet built).
What HOLDS honestly: (a) the disease (aVWS = shear-driven A2 cleavage) is
established biology; (b) the cleavage-LIMITED kinetic regime is robust
(t_unfold ≪ 1/k_cat). What is NOT claimed: a robust in-silico "UNFOLD"
positive — it is explicitly marginal under the measured force.

Honest scope (g8/f2): in-silico simulator-consistency only. Evaluates NO
chaperone, makes NO therapeutic claim. Prefactor C_T is an
order-of-magnitude band (g1, NOT fitted). White-space (0 approved A2
stabilizers) unchanged.
"""

from __future__ import annotations

import math
import sys

# ── physical constants ──────────────────────────────────────────────────────
KCAL_MOL_TO_PN_NM = 4184.0 / 6.02214076e23 / 1e-21   # 6.9477 pN·nm/molecule
DYN_CM2_TO_PA = 0.1
K_B = 1.380649e-23
T_KELVIN = 310.0
KT_PN_NM = K_B * T_KELVIN * 1e21                       # ≈ 4.28 pN·nm

# §3 limits — Zhang 2009 verified (NOT the old wrong tape numbers)
A2_DG_KCAL_MOL = (3.0, 4.8)            # 3.9 ± 0.9 kcal/mol
A2_CONTOUR_NM = 57.0                    # 57 ± 5 nm unfolded contour
A2_FOLDED_NM = 4.0                      # folded extent (order-of-mag)
A2_DELTA_X_NM = A2_CONTOUR_NM - A2_FOLDED_NM   # ≈ 53 nm extension gain
A2_MEASURED_RUPTURE_PN = (7.0, 14.0)   # most-probable ≈ 11, loading-rate dep.
A2_RUPTURE_MOSTPROB_PN = 11.0
ADAMTS13_KCAT_PER_S = 0.14             # single-molecule, on unfolded A2

A2_SHEAR_THRESHOLD_DYN_CM2 = 30.0      # cleavage-exposure threshold (tape §3)
LVAD_SHEAR_GRID_DYN_CM2 = (70.0, 100.0, 150.0)
C_T_RANGE = (0.05, 0.2)                # midpoint-tension prefactor band
NANOBOT_EFFECTIVE_LENGTH_UM = 0.1      # ①↔② duality contrast scale
HMW_MULTIMER_CONTOUR_UM = 5.0


def a2_unfold_force_thermo_pN(dG_kcal_mol: float, delta_x_nm: float) -> float:
    """Thermodynamic (equilibrium) unfold force F = ΔG/Δx — the LOW bound.

    This is NOT the mechanically-relevant rupture force; Zhang 2009 directly
    MEASURED ~11 pN single-molecule. Reported for completeness/contrast only.
    """
    if dG_kcal_mol <= 0 or delta_x_nm <= 0:
        raise ValueError("ΔG and Δx must be > 0.")
    return (dG_kcal_mol * KCAL_MOL_TO_PN_NM) / delta_x_nm


def vwf_midpoint_tension_pN(shear_dyn_cm2: float, contour_um: float,
                            C_T: float) -> float:
    """F_mid ≈ C_T·τ·L² (Alexander-Katz 2006 PRL 97:138101 stress form)."""
    if shear_dyn_cm2 < 0 or contour_um <= 0 or C_T <= 0:
        raise ValueError("inputs must be positive.")
    tau_Pa = shear_dyn_cm2 * DYN_CM2_TO_PA
    L_m = contour_um * 1e-6
    return (C_T * tau_Pa * L_m * L_m) * 1e12


def adamts13_timescale_consistency(shear_dyn_cm2: float,
                                   contour_um: float = HMW_MULTIMER_CONTOUR_UM,
                                   C_T: float = C_T_RANGE[0]) -> dict:
    """§3 #1 anchor: cleavage-LIMITED regime (Crawley 2011 mechanism).

    With k_cat = 0.14/s, t_cleave = 1/k_cat ≈ 7.1 s. Shear-driven A2 unfolding
    under supra-barrier tension is sub-ms. t_unfold ≪ t_cleave ⇒ the enzymatic
    step is rate-limiting (matches the aVWS observed regime). The corrected
    (slower) k_cat makes this MORE robust, not less.
    """
    tension = vwf_midpoint_tension_pN(shear_dyn_cm2, contour_um, C_T)
    # Tension-tilted Kramers escape; worst-case full ΔG barrier, ν0 = 1e6 /s.
    dG_pNnm = A2_DG_KCAL_MOL[1] * KCAL_MOL_TO_PN_NM
    barrier_kT = max((dG_pNnm - tension * A2_DELTA_X_NM) / KT_PN_NM, 0.0)
    t_unfold_s = (1.0 / 1.0e6) * math.exp(min(barrier_kT, 80.0))
    t_cleave_s = 1.0 / ADAMTS13_KCAT_PER_S
    return {
        "shear_dyn_cm2": shear_dyn_cm2,
        "tension_pN": round(tension, 3),
        "t_unfold_s_upper_bound": t_unfold_s,
        "t_cleave_s": round(t_cleave_s, 3),
        "adamts13_kcat_per_s": ADAMTS13_KCAT_PER_S,
        "regime_is_cleavage_limited": t_unfold_s < t_cleave_s,
    }


def anchor_grid() -> dict:
    f_thermo = a2_unfold_force_thermo_pN(
        sum(A2_DG_KCAL_MOL) / 2, A2_DELTA_X_NM)            # ≈ 0.5 pN (low bound)
    f_meas_lo, f_meas_hi = A2_MEASURED_RUPTURE_PN          # 7-14 pN measured
    grid = []
    thermo_all_unfold = True
    measured_all_unfold = True
    for shear in (A2_SHEAR_THRESHOLD_DYN_CM2,) + LVAD_SHEAR_GRID_DYN_CM2:
        t_lo = vwf_midpoint_tension_pN(shear, HMW_MULTIMER_CONTOUR_UM, C_T_RANGE[0])
        t_hi = vwf_midpoint_tension_pN(shear, HMW_MULTIMER_CONTOUR_UM, C_T_RANGE[1])
        vs_thermo = t_lo >= f_thermo                       # robust vs equilibrium
        vs_measured_robust = t_lo >= A2_RUPTURE_MOSTPROB_PN  # robust vs ~11 pN
        vs_measured_possible = t_hi >= f_meas_lo           # possible at high C_T
        grid.append({
            "shear_dyn_cm2": shear,
            "is_published_threshold": shear == A2_SHEAR_THRESHOLD_DYN_CM2,
            "vwf_tension_pN_band": [round(t_lo, 3), round(t_hi, 3)],
            "unfold_vs_thermo_0p5pN": vs_thermo,
            "unfold_robust_vs_measured_11pN": vs_measured_robust,
            "unfold_possible_vs_measured_band": vs_measured_possible,
        })
        if shear in LVAD_SHEAR_GRID_DYN_CM2:
            thermo_all_unfold = thermo_all_unfold and vs_thermo
            measured_all_unfold = measured_all_unfold and vs_measured_robust

    # ①↔② duality (same equation, length-scale only).
    v70 = vwf_midpoint_tension_pN(70.0, HMW_MULTIMER_CONTOUR_UM, C_T_RANGE[0])
    n70 = vwf_midpoint_tension_pN(70.0, NANOBOT_EFFECTIVE_LENGTH_UM, C_T_RANGE[0])
    adamts13 = [adamts13_timescale_consistency(s) for s in LVAD_SHEAR_GRID_DYN_CM2]

    # Honest criteria:
    #  C_A2_1  thermodynamic-threshold consistency (LOW bound) — informational
    #  C_A2_2  cleavage-limited kinetic regime — the robust positive
    #  C_A2_3  EXPLICIT honesty flag: UNFOLD is NOT robust vs measured ~11 pN
    c_a2_1 = thermo_all_unfold
    c_a2_2 = all(a["regime_is_cleavage_limited"] for a in adamts13)
    c_a2_3_marginal = not measured_all_unfold      # True = honestly marginal
    return {
        "real_limit": ("vWF A2 mechano-cleavage — Zhang X 2009 Science 324:1330 "
                       "(PMC2753189); Zhang Q 2009 PNAS 106:9226 (PMC2695068); "
                       "Crawley 2011 Blood 118:3212; Alexander-Katz 2006 PRL 97:138101"),
        "a2_unfold_force_thermo_pN": round(f_thermo, 3),
        "a2_unfold_force_measured_pN": [f_meas_lo, f_meas_hi],
        "a2_unfold_force_mostprob_pN": A2_RUPTURE_MOSTPROB_PN,
        "adamts13_kcat_per_s": ADAMTS13_KCAT_PER_S,
        "hmw_multimer_contour_um": HMW_MULTIMER_CONTOUR_UM,
        "grid": grid,
        "adamts13_timescale": adamts13,
        "duality": {
            "vwf_5um_at_70_pN": round(v70, 3),
            "nanobot_0p1um_at_70_pN": round(n70, 6),
            "L2_ratio": (HMW_MULTIMER_CONTOUR_UM / NANOBOT_EFFECTIVE_LENGTH_UM) ** 2,
        },
        "C_A2_1_thermo_threshold_consistent": c_a2_1,
        "C_A2_2_adamts13_cleavage_limited": c_a2_2,
        "C_A2_3_unfold_marginal_vs_measured_force": c_a2_3_marginal,
        "anchors_tape_section3": ["#1 ADAMTS13 k_cat 0.14/s", "#2 ΔG 3.9 kcal/mol",
                                  "#3 shear threshold"],
        "honest_verdict": ("②'s in-silico UNFOLD is ROBUST only against the "
                           "thermodynamic equilibrium force (~0.5 pN, the wrong "
                           "threshold for a dwell-time process); against the "
                           "Zhang-2009 MEASURED rupture force (~11 pN) it is "
                           "MARGINAL/prefactor-dependent. Rigorous verdict needs "
                           "the DHS force-clamp model (drylab #6). The aVWS "
                           "mechanism premise is established biology; the "
                           "cleavage-limited kinetic regime IS robust. NO "
                           "therapeutic claim (g8/f2)."),
    }


def _selfcheck() -> int:
    print("a2_shear_unfolding_anchor — LVAD ② §3 anchor (Zhang-2009-corrected)\n")
    f_t = a2_unfold_force_thermo_pN(3.9, A2_DELTA_X_NM)
    assert 0.3 < f_t < 0.8, f"thermo force off: {f_t}"
    print(f"  [PASS] thermo unfold force {f_t:.3f} pN (ΔG=3.9 kcal/mol, Δx={A2_DELTA_X_NM:.0f} nm)")
    print(f"  [INFO] Zhang-2009 MEASURED rupture force = {A2_RUPTURE_MOSTPROB_PN} pN "
          f"(range {A2_MEASURED_RUPTURE_PN[0]}-{A2_MEASURED_RUPTURE_PN[1]}, loading-rate dep.)")
    t1 = vwf_midpoint_tension_pN(70, 1.0, 0.1)
    t2 = vwf_midpoint_tension_pN(70, 2.0, 0.1)
    assert abs(t2 / t1 - 4.0) < 1e-9
    print(f"  [PASS] F_mid ∝ L² ({t2/t1:.1f}× for 2× length)")
    a, b = anchor_grid(), anchor_grid()
    assert a == b
    print("  [PASS] anchor_grid deterministic\n")

    g = anchor_grid()
    print(f"  A2 force: thermo≈{g['a2_unfold_force_thermo_pN']} pN  |  "
          f"MEASURED {g['a2_unfold_force_measured_pN']} pN (most-prob "
          f"{g['a2_unfold_force_mostprob_pN']})  |  k_cat {g['adamts13_kcat_per_s']}/s")
    for r in g["grid"]:
        tag = " (PUB.THRESH)" if r["is_published_threshold"] else ""
        print(f"   τ={r['shear_dyn_cm2']:>5.0f}{tag}  vWF {r['vwf_tension_pN_band']} pN  "
              f"thermo={r['unfold_vs_thermo_0p5pN']}  "
              f"robust@11pN={r['unfold_robust_vs_measured_11pN']}  "
              f"poss@band={r['unfold_possible_vs_measured_band']}")
    for adt in g["adamts13_timescale"]:
        print(f"   ADAMTS13 τ={adt['shear_dyn_cm2']:>5.0f}  t_unfold≤{adt['t_unfold_s_upper_bound']:.2e}s "
              f"≪ t_cleave={adt['t_cleave_s']}s → cleavage-limited={adt['regime_is_cleavage_limited']}")
    d = g["duality"]
    print(f"\n  ①↔② duality: vWF(5µm)@70={d['vwf_5um_at_70_pN']} pN vs "
          f"nanobot(0.1µm)@70={d['nanobot_0p1um_at_70_pN']} pN  L²={d['L2_ratio']:.0f}×")
    print(f"  C_A2_1 thermo-consistent:        {g['C_A2_1_thermo_threshold_consistent']}")
    print(f"  C_A2_2 cleavage-limited:         {g['C_A2_2_adamts13_cleavage_limited']}")
    print(f"  C_A2_3 marginal-vs-measured(⚠):  {g['C_A2_3_unfold_marginal_vs_measured_force']}  "
          f"(True = honestly NOT a robust positive)")
    print(f"\n  [honest verdict] {g['honest_verdict']}")
    # PASS = the HONEST set: thermo-consistent + cleavage-limited + the
    # marginal flag correctly raised (honesty self-check, not a hope-fit).
    ok = (g["C_A2_1_thermo_threshold_consistent"]
          and g["C_A2_2_adamts13_cleavage_limited"]
          and g["C_A2_3_unfold_marginal_vs_measured_force"])
    print("\n__A2_SHEAR_UNFOLDING_ANCHOR__ PASS" if ok
          else "\n__A2_SHEAR_UNFOLDING_ANCHOR__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
