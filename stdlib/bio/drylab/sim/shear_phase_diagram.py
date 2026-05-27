#!/usr/bin/env python3
"""shear_phase_diagram.py — drylab #4 · shear-mechanotransduction phase map.

Generalizes the F_mid ∝ C_T·τ·L² + Bell physics into one reusable tool and
locates the LVAD ① (compact nanobot) and ② (vWF multimer) anchor points.

═══ Zhang-2009-corrected 2026-05-16 (g1/g3) ═══
An earlier build classified UNFOLD against the THERMODYNAMIC equilibrium
force (~0.5-1.4 pN, from an OUTDATED ΔG 7-10 kcal/mol). That conflated the
equilibrium force with the mechanically-relevant rupture force and
overstated ②. Corrected to the scenario's OWN cited primary (Zhang X 2009
Science 324:1330, verified verbatim PMC2753189):
  • A2 ΔG = 3.9 ± 0.9 kcal/mol ; unfolded contour 57 nm
  • A2 MEASURED single-molecule rupture ≈ 11 pN (7-14, loading-rate dep.)
Classification now uses the MEASURED rupture as the mechanically-relevant
threshold; the thermodynamic force is reported as an informational LOW
bound only. Honest consequence: the ② anchor at LVAD 70 dyn/cm² is
MARGINAL (8.75 pN < 11 pN at conservative C_T), NOT a robust UNFOLD.
Mirrors `_python_bridge/module/a2_shear_unfolding_anchor.py` (corrected).

Honest scope (g8/f2): in-silico simulator-consistency only. Boundaries are
cited Bell(1978)/Alexander-Katz(2006) scaling; C_T is an order-of-magnitude
band (g1, NOT fitted). NO device/drug claim — this maps a physics
feasibility landscape; it neither validates ① nor advances ②.
"""

from __future__ import annotations

import math
import sys

# ── cited constants (mirror a2_shear_unfolding_anchor.py, Zhang-corrected) ──
KCAL_MOL_TO_PN_NM = 4184.0 / 6.02214076e23 / 1e-21   # 6.9477 pN·nm/molecule
DYN_CM2_TO_PA = 0.1
K_B = 1.380649e-23
T_KELVIN = 310.0
KT_PN_NM = K_B * T_KELVIN * 1e21                       # ≈ 4.28 pN·nm

A2_DG_KCAL_MOL = 3.9                                   # Zhang 2009 (was 7-10)
A2_CONTOUR_NM = 57.0                                   # Zhang 2009
A2_FOLDED_NM = 4.0
A2_DELTA_X_NM = A2_CONTOUR_NM - A2_FOLDED_NM           # ≈ 53 nm
A2_MEASURED_RUPTURE_PN = 11.0                          # Zhang 2009 most-prob (7-14)
BELL_K0_PER_S = 1e-3
BELL_X_BETA_NM = 0.4
C_T_BAND = (0.05, 0.2)
ANCHOR_NANOBOT_L_UM = 0.1
ANCHOR_VWF_L_UM = 5.0
LVAD_REF_SHEAR = 70.0


def midpoint_tension_pN(shear_dyn_cm2: float, L_um: float, C_T: float) -> float:
    tau_Pa = shear_dyn_cm2 * DYN_CM2_TO_PA
    L_m = L_um * 1e-6
    return (C_T * tau_Pa * L_m * L_m) * 1e12


def bell_k_open(F_pN: float, k0: float = BELL_K0_PER_S,
                x_beta_nm: float = BELL_X_BETA_NM) -> float:
    expo = max(min((F_pN * x_beta_nm) / KT_PN_NM, 80.0), -80.0)
    return k0 * math.exp(expo)


def a2_thermo_force_pN() -> float:
    """Informational LOW bound F=ΔG/Δx (NOT the classification threshold)."""
    return (A2_DG_KCAL_MOL * KCAL_MOL_TO_PN_NM) / A2_DELTA_X_NM


def classify(L_um: float, shear_dyn_cm2: float) -> dict:
    """Regime at (L, shear), robust across the C_T band.

      UNFOLD   : F_mid(low C_T) ≥ MEASURED rupture ≈ 11 pN → robust A2
                 mechano-cleavage exposure (the only robust-positive label)
      MARGINAL : thermo(~0.5 pN) ≤ F_mid(low C_T) < 11 pN → exceeds the
                 equilibrium force but BELOW the measured rupture;
                 loading-rate-dependent, NOT a robust positive (the honest
                 ② regime at LVAD 70)
      INERT    : Bell amplification negligible, k_open ≈ k0 (the robust ①
                 compact-nanobot negative)
      PARTIAL  : amplified but below thermo (transitional)
    """
    f_thermo = a2_thermo_force_pN()
    t_lo = midpoint_tension_pN(shear_dyn_cm2, L_um, C_T_BAND[0])  # conservative
    t_hi = midpoint_tension_pN(shear_dyn_cm2, L_um, C_T_BAND[1])
    k_lo = bell_k_open(t_lo)
    inert = k_lo <= BELL_K0_PER_S * 1.01
    if t_lo >= A2_MEASURED_RUPTURE_PN:
        regime = "UNFOLD"
    elif t_lo >= f_thermo:
        regime = "MARGINAL"
    elif inert:
        regime = "INERT"
    else:
        regime = "PARTIAL"
    return {
        "L_um": L_um, "shear_dyn_cm2": shear_dyn_cm2,
        "tension_pN_band": (t_lo, t_hi),
        "a2_thermo_pN": f_thermo,
        "a2_measured_rupture_pN": A2_MEASURED_RUPTURE_PN,
        "regime": regime,
    }


_GLYPH = {"UNFOLD": "U", "MARGINAL": "m", "PARTIAL": "p", "INERT": "."}


def phase_diagram(L_grid_um, shear_grid) -> list:
    return [[classify(L, s)["regime"] for L in L_grid_um] for s in shear_grid]


def _log_grid(lo, hi, n):
    return [lo * (hi / lo) ** (i / (n - 1)) for i in range(n)]


def _selfcheck() -> int:
    print("shear_phase_diagram — drylab #4 · ①↔② map (Zhang-2009-corrected)\n")

    f_t = a2_thermo_force_pN()
    assert 0.3 < f_t < 0.8, f"thermo force off: {f_t}"
    print(f"  [PASS] A2 thermo force {f_t:.3f} pN (informational LOW bound; ΔG=3.9, Δx≈53)")
    print(f"  [INFO] A2 MEASURED rupture = {A2_MEASURED_RUPTURE_PN} pN (Zhang 2009; classification threshold)")

    t1 = midpoint_tension_pN(70, 1.0, 0.1)
    t2 = midpoint_tension_pN(70, 2.0, 0.1)
    assert abs(t2 / t1 - 4.0) < 1e-9, "L² scaling broken"
    print(f"  [PASS] F_mid ∝ L²  (2× length → {t2/t1:.1f}× tension)")

    a = phase_diagram(_log_grid(0.01, 20, 8), [1, 10, 70, 150])
    b = phase_diagram(_log_grid(0.01, 20, 8), [1, 10, 70, 150])
    assert a == b, "non-deterministic"
    print("  [PASS] phase_diagram deterministic\n")

    n_cls = classify(ANCHOR_NANOBOT_L_UM, LVAD_REF_SHEAR)
    v_cls = classify(ANCHOR_VWF_L_UM, LVAD_REF_SHEAR)
    ratio = (ANCHOR_VWF_L_UM / ANCHOR_NANOBOT_L_UM) ** 2
    print(f"  ① nanobot  L={ANCHOR_NANOBOT_L_UM} µm @ {LVAD_REF_SHEAR:.0f}  "
          f"→ tension≈{n_cls['tension_pN_band'][0]:.4f} pN  regime={n_cls['regime']}")
    print(f"  ② vWF mult L={ANCHOR_VWF_L_UM} µm @ {LVAD_REF_SHEAR:.0f}  "
          f"→ tension≈{v_cls['tension_pN_band'][0]:.3f} pN  regime={v_cls['regime']}")
    print(f"  duality: same equation, L²={ratio:.0f}×.  ① = ROBUST NEGATIVE (INERT). "
          f"② = MARGINAL at LVAD 70 (8.75 pN < measured 11 pN) — NOT a robust\n"
          f"  positive; asymmetric. Rigorous ② verdict needs DHS force-clamp (#6).\n")

    L_grid = _log_grid(0.01, 20.0, 13)
    shear_grid = [1, 5, 10, 30, 70, 100, 150, 200]
    grid = phase_diagram(L_grid, shear_grid)
    print("  phase diagram (rows=τ dyn/cm²↓, cols=L µm→; U=unfold m=marginal p=partial .=inert)")
    print("        L:  " + " ".join(f"{L:>5.2g}" for L in L_grid))
    for s, row in zip(shear_grid, grid):
        print(f"  τ={s:>4.0f}    " + "     ".join(_GLYPH[r] for r in row))
    print()

    # HONEST assertions: ① robust INERT; ② NOT robust UNFOLD (must be MARGINAL
    # at LVAD 70 under the corrected measured threshold).
    ok = (n_cls["regime"] == "INERT"
          and v_cls["regime"] == "MARGINAL"
          and 0.3 < f_t < 0.8
          and a == b)
    print(f"  ① INERT (robust negative) confirmed:        {n_cls['regime']=='INERT'}")
    print(f"  ② MARGINAL (NOT robust positive) confirmed: {v_cls['regime']=='MARGINAL'}")
    print("  [honesty] in-silico simulator-consistency only (g8/f2); classification "
          "uses Zhang-2009 MEASURED rupture (~11 pN), not the equilibrium force; "
          "C_T order-of-mag band (g1, not fitted). Mirrors corrected "
          "a2_shear_unfolding_anchor.py. No device/drug claim. See ../README.md.")
    print("\n__DRYLAB_SHEAR_PHASE_DIAGRAM__ PASS" if ok
          else "\n__DRYLAB_SHEAR_PHASE_DIAGRAM__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
