#!/usr/bin/env python3
"""lvad_shear_reduced_order.py — drylab #9 · reduced-order LVAD wall-shear.

A REDUCED-ORDER ANALYTICAL estimator (annular-Couette thin-gap kernel +
pump-affinity scaling cross-check) that transparently BRACKETS the
LVAD-scenario asserted "70-150 dyn/cm² impeller wall-shear"
(`LVAD/SHEAR_GATED_NANOBOT.tape` §3, re-used by the ① Langevin work). It is
NOT a CFD field and NOT a HeartMate-3 model.

═══ real-limit anchor ═══
Plane/annular Couette + Newton's law of viscosity (the textbook
continuum-mechanics limit on viscous wall-shear in a sheared gap):
  τ = μ·U/δ = μ·Ω·R_i/δ          (thin-gap δ ≪ R_i limit; eq. C of research)
verified verbatim against *Couette flow* (Wikipedia: plane Couette
u(y)=U y/h, τ=μU/h constant; circular Couette v_θ=a r+b/r) 2026-05-16.
Published continuous-flow-LVAD operating envelope (Bartoli & Dowling, Cardiac
Interventions Today 13(1):53-59, 2019, open access, verbatim): impeller
1,500-30,000 rpm; blood gaps 50-500 µm; physiologic shear 2-8 Pa; HeartMate
II peak shear > 1,500 Pa. The asserted 70-150 dyn/cm² = 7-15 Pa is the
LVAD-scenario's own asserted band (primary attribution UNVERIFIED here); only
the unit identity 1 dyn/cm² = 0.1 Pa is asserted as fact. This file BRACKETS
that band; it does NOT validate it.

═══ honest scope (g8/f2/g3/g1) ═══
REDUCED-ORDER ANALYTICAL — NOT validated CFD, NOT a HeartMate-3 model, NOT a
hemolysis / vWF / thrombosis / device / clinical claim. HeartMate-3 rotor
dimensions are NOT openly published; the rotor radius is an EXPLICIT ASSUMED
BAND (R_i ∈ [3,12] mm, labelled), the rpm/gap envelopes are the GENERIC
published LVAD ranges — no HM3 dimension is fabricated (g3). The bracket
verdict is whatever the cited equations + published/assumed bands produce;
NO geometry was tuned toward 70-150 (g1). Sentinel PASS = the reduced-order
model is internally self-consistent AND the bracket was computed — it does
NOT mean "70-150 is validated" or "this is CFD-accurate".
Cross-ref ../research/lvad_shear_reduced_order.md.
"""

from __future__ import annotations

import math
import sys

# ── cited / asserted constants ───────────────────────────────────────
MU_PLASMA_PA_S = 1.2e-3          # plasma μ ≈ 1.2 mPa·s, T=310 K (① Langevin value)
DYN_CM2_PER_PA = 10.0            # 1 Pa = 10 dyn/cm²  (1 dyn/cm² = 0.1 Pa)

# Published continuous-flow-LVAD operating envelope — Bartoli & Dowling 2019
# (open access, verbatim 2026-05-16). NOT HeartMate-3-specific.
RPM_PUBLISHED = (1500.0, 30000.0)        # "impeller … rotates at 1,500 to 30,000 rpm"
GAP_PUBLISHED_M = (50e-6, 500e-6)        # "narrow gaps (50-500 µm)"
PHYSIOLOGIC_PA = (2.0, 8.0)              # "normal physiologic … approximately 2-8 Pa"
HM2_PEAK_PA = 1500.0                     # "HeartMate II … peak shear stress > 1,500 Pa"

# HeartMate-3 rotor diameter is NOT openly published → EXPLICIT ASSUMED BAND
# (clinical centrifugal-LVAD rotors are sub-cm to ~cm scale; order-of-mag
# band, NOT a fabricated HM3 dimension — g3).
R_I_ASSUMED_BAND_M = (3e-3, 12e-3)       # assumed_param = "R_i"
ASSUMED_PARAM = "R_i (HM3 rotor radius NOT openly published — assumed band)"

# The LVAD-scenario's own asserted band (SHEAR_GATED_NANOBOT.tape §3).
# Primary attribution UNVERIFIED here; bracketed as-is, NOT tuned-to (g1).
ASSERTED_DYN_CM2 = (70.0, 150.0)


def omega_rad_s(rpm: float) -> float:
    """Angular speed Ω = 2π·rpm/60."""
    return 2.0 * math.pi * rpm / 60.0


def couette_wall_shear_Pa(R_i_m: float, delta_m: float, rpm: float,
                          mu: float = MU_PLASMA_PA_S) -> float:
    """Reduced-order thin-gap annular-Couette wall shear τ = μ·Ω·R_i/δ (Pa).

    Load-bearing kernel (eq. C). Exact only as δ/R_i → 0; for LVAD gaps this
    truncates curvature at O(δ/R_i) ≈ 10-20 % (see couette_exact_inner_shear).
    """
    U = omega_rad_s(rpm) * R_i_m            # inner-wall surface speed Ω·R_i
    return mu * U / delta_m


def couette_exact_inner_shear_Pa(R_i_m: float, delta_m: float, rpm: float,
                                 mu: float = MU_PLASMA_PA_S) -> float:
    """EXACT circular-Couette inner-wall shear τ_rθ(R_i), stationary housing.

    From the verified v_θ = a·r + b/r profile with Ω₂=0, R₂=R_i+δ:
      a = -Ω₁·R₁²/(R₂²-R₁²) ,  b =  Ω₁·R₁²·R₂²/(R₂²-R₁²)
      τ_rθ(r) = μ·r·d(v_θ/r)/dr = μ·(-2 b / r²)
    Reported alongside the thin-gap kernel so the curvature truncation of
    couette_wall_shear_Pa is VISIBLE, not hidden.
    """
    R1 = R_i_m
    R2 = R_i_m + delta_m
    Om1 = omega_rad_s(rpm)
    denom = R2 * R2 - R1 * R1
    b = Om1 * R1 * R1 * R2 * R2 / denom
    # τ_rθ(r) = μ · r · d/dr(a + b/r²) = μ · r · (-2b/r³) = -2 μ b / r²
    return abs(-2.0 * mu * b / (R1 * R1))


def affinity_scaled_shear_Pa(tau_ref_Pa: float, N_ref: float, N: float) -> float:
    """Pump-affinity cross-check: tip speed ∝ N (Q∝N) ⇒ τ = τ_ref·(N/N_ref).

    Used ONLY to confirm the Couette τ ∝ Ω scaling agrees with pump
    similarity — not an independent shear formula.
    """
    return tau_ref_Pa * (N / N_ref)


def pa_to_dyn_cm2(pa: float) -> float:
    return pa * DYN_CM2_PER_PA


def envelope_shear_band(mu: float = MU_PLASMA_PA_S) -> dict:
    """Reduced-order wall-shear band over the PUBLISHED rpm/gap envelope and
    the EXPLICIT ASSUMED rotor-radius band, in dyn/cm².

    τ = μ·Ω·R_i/δ is monotone: ↑ in rpm, ↑ in R_i, ↓ in δ. So
      τ_min corner = (min rpm, max gap, min R_i)
      τ_max corner = (max rpm, min gap, max R_i)
    No geometry is selected to land on 70-150 (g1).
    """
    rpm_lo, rpm_hi = RPM_PUBLISHED
    gap_lo, gap_hi = GAP_PUBLISHED_M
    Ri_lo, Ri_hi = R_I_ASSUMED_BAND_M

    tau_min_pa = couette_wall_shear_Pa(Ri_lo, gap_hi, rpm_lo, mu)
    tau_max_pa = couette_wall_shear_Pa(Ri_hi, gap_lo, rpm_hi, mu)
    return {
        "tau_min_pa": tau_min_pa,
        "tau_max_pa": tau_max_pa,
        "tau_min_dyn_cm2": pa_to_dyn_cm2(tau_min_pa),
        "tau_max_dyn_cm2": pa_to_dyn_cm2(tau_max_pa),
        "min_corner": {"rpm": rpm_lo, "gap_um": gap_hi * 1e6, "R_i_mm": Ri_lo * 1e3},
        "max_corner": {"rpm": rpm_hi, "gap_um": gap_lo * 1e6, "R_i_mm": Ri_hi * 1e3},
        "assumed_param": ASSUMED_PARAM,
        "published_rpm": RPM_PUBLISHED,
        "published_gap_um": (gap_lo * 1e6, gap_hi * 1e6),
    }


def bracket_vs_asserted(band: dict,
                        asserted=ASSERTED_DYN_CM2) -> dict:
    """Does the reduced-order envelope BRACKET (contain) the asserted band?

    Verdict ∈ {CONTAINS, OVERLAPS, BELOW_ASSERTED, ABOVE_ASSERTED}. Honest:
    a band that lies within a wide attainable envelope is NECESSARY-
    CONSISTENT, NOT confirmation. Computed, never tuned (g1).
    """
    lo, hi = band["tau_min_dyn_cm2"], band["tau_max_dyn_cm2"]
    a_lo, a_hi = asserted
    contains = lo <= a_lo and hi >= a_hi
    overlaps = not (hi < a_lo or lo > a_hi)
    if contains:
        verdict = "CONTAINS"
        note = ("reduced-order envelope CONTAINS the asserted band — "
                "necessary-consistency, NOT a unique prediction nor a "
                "validation")
    elif overlaps:
        verdict = "OVERLAPS"
        note = "reduced-order envelope partially overlaps the asserted band"
    elif hi < a_lo:
        verdict = "BELOW_ASSERTED"
        note = ("reduced-order envelope sits ENTIRELY BELOW 70-150 — honest "
                "negative, reported as-is")
    else:
        verdict = "ABOVE_ASSERTED"
        note = ("reduced-order envelope sits ENTIRELY ABOVE 70-150 — honest "
                "negative, reported as-is")
    # where does the asserted band sit within the (log) envelope span?
    span_decades = math.log10(hi / lo) if lo > 0 else float("inf")
    a_mid = math.sqrt(a_lo * a_hi)
    pos_decades_from_lo = math.log10(a_mid / lo) if lo > 0 else float("inf")
    return {
        "envelope_dyn_cm2": (lo, hi),
        "asserted_dyn_cm2": asserted,
        "verdict": verdict,
        "note": note,
        "envelope_span_decades": span_decades,
        "asserted_mid_decades_above_min": pos_decades_from_lo,
    }


def _approx(a: float, b: float, rel: float = 1e-9) -> bool:
    return abs(a - b) <= rel * max(abs(a), abs(b), 1.0)


def _selfcheck() -> int:
    print("lvad_shear_reduced_order — drylab #9 · reduced-order annular-"
          "Couette wall-shear bracket of the asserted 70-150 dyn/cm²\n")

    ok = True

    # ── deductive: τ ∝ ω (linear in rpm at fixed geometry) ──
    R_i, delta = 6e-3, 100e-6
    t1 = couette_wall_shear_Pa(R_i, delta, 3000.0)
    t2 = couette_wall_shear_Pa(R_i, delta, 6000.0)
    lin = _approx(t2 / t1, 2.0)
    ok &= lin
    print(f"  [{'PASS' if lin else 'FAIL'}] τ ∝ ω   (2× rpm → {t2/t1:.6f}× shear)")

    # ── deductive: τ ∝ 1/δ ──
    g1 = couette_wall_shear_Pa(R_i, 100e-6, 5000.0)
    g2 = couette_wall_shear_Pa(R_i, 200e-6, 5000.0)
    inv = _approx(g1 / g2, 2.0)
    ok &= inv
    print(f"  [{'PASS' if inv else 'FAIL'}] τ ∝ 1/δ  (2× gap → {g2/g1:.6f}× shear)")

    # ── deductive: τ ∝ R_i ──
    r1 = couette_wall_shear_Pa(3e-3, delta, 5000.0)
    r2 = couette_wall_shear_Pa(6e-3, delta, 5000.0)
    prop = _approx(r2 / r1, 2.0)
    ok &= prop
    print(f"  [{'PASS' if prop else 'FAIL'}] τ ∝ R_i  (2× R_i → {r2/r1:.6f}× shear)")

    # ── affinity-law cross-check agrees with Couette ∝Ω ──
    base = couette_wall_shear_Pa(R_i, delta, 4000.0)
    aff = affinity_scaled_shear_Pa(base, 4000.0, 9000.0)
    cou = couette_wall_shear_Pa(R_i, delta, 9000.0)
    agree = _approx(aff, cou)
    ok &= agree
    print(f"  [{'PASS' if agree else 'FAIL'}] affinity τ∝N == Couette τ∝Ω "
          f"(affinity {aff:.4f} Pa vs Couette {cou:.4f} Pa)")

    # ── thin-gap kernel vs exact circular-Couette (truncation visible) ──
    thin = couette_wall_shear_Pa(R_i, delta, 5000.0)
    exact = couette_exact_inner_shear_Pa(R_i, delta, 5000.0)
    trunc = abs(exact - thin) / exact
    trunc_ok = trunc < 0.05            # δ/R_i ≈ 0.017 here → ~few-% truncation
    ok &= trunc_ok
    print(f"  [{'PASS' if trunc_ok else 'FAIL'}] thin-gap vs exact circular-"
          f"Couette: {thin:.4f} vs {exact:.4f} Pa "
          f"(curvature truncation {trunc*100:.2f} %, expected small at δ/R_i="
          f"{delta/R_i:.3f})")

    # ── determinism ──
    b1 = bracket_vs_asserted(envelope_shear_band())
    b2 = bracket_vs_asserted(envelope_shear_band())
    det = (b1 == b2)
    ok &= det
    print(f"  [{'PASS' if det else 'FAIL'}] deterministic (run()==run())\n")

    # ── the bracket (computed, NOT tuned — g1) ──
    band = envelope_shear_band()
    br = bracket_vs_asserted(band)
    lo, hi = br["envelope_dyn_cm2"]
    print("  ── reduced-order envelope over PUBLISHED rpm/gap + ASSUMED R_i ──")
    print(f"    rpm  band (Bartoli 2019, verbatim) : "
          f"{RPM_PUBLISHED[0]:.0f}-{RPM_PUBLISHED[1]:.0f} rpm")
    print(f"    gap  band (Bartoli 2019, verbatim) : "
          f"{GAP_PUBLISHED_M[0]*1e6:.0f}-{GAP_PUBLISHED_M[1]*1e6:.0f} µm")
    print(f"    R_i  band (ASSUMED — HM3 NOT openly published) : "
          f"{R_I_ASSUMED_BAND_M[0]*1e3:.0f}-{R_I_ASSUMED_BAND_M[1]*1e3:.0f} mm")
    print(f"    μ (plasma, T=310 K)                : "
          f"{MU_PLASMA_PA_S*1e3:.1f} mPa·s")
    print(f"    τ_min corner {band['min_corner']}")
    print(f"    τ_max corner {band['max_corner']}")
    print(f"    reduced-order τ band : {lo:.3g} … {hi:.3g} dyn/cm²")
    print(f"                         = {band['tau_min_pa']:.3g} … "
          f"{band['tau_max_pa']:.3g} Pa   "
          f"(envelope spans {br['envelope_span_decades']:.1f} decades)")
    print(f"    asserted (scenario)  : {ASSERTED_DYN_CM2[0]:.0f}-"
          f"{ASSERTED_DYN_CM2[1]:.0f} dyn/cm² = "
          f"{ASSERTED_DYN_CM2[0]/DYN_CM2_PER_PA:.0f}-"
          f"{ASSERTED_DYN_CM2[1]/DYN_CM2_PER_PA:.0f} Pa")
    print(f"    Bartoli physiologic  : {PHYSIOLOGIC_PA[0]:.0f}-"
          f"{PHYSIOLOGIC_PA[1]:.0f} Pa ; HM2 peak > {HM2_PEAK_PA:.0f} Pa\n")
    print(f"    BRACKET VERDICT      : {br['verdict']}")
    print(f"      {br['note']}")
    print(f"      asserted-band midpoint sits "
          f"{br['asserted_mid_decades_above_min']:.1f} decades above the "
          f"envelope minimum (of {br['envelope_span_decades']:.1f} total) — "
          f"i.e. {'LOW' if br['asserted_mid_decades_above_min'] < br['envelope_span_decades']/2 else 'HIGH'} "
          f"within the attainable reduced-order range.")
    print(f"      honest context: 70-150 dyn/cm² = 7-15 Pa is only ~1-7× the "
          f"physiologic 2-8 Pa and ~100-200× BELOW the HM2 peak >1500 Pa →\n"
          f"      consistent with a LOW / secondary-flow-path wall-shear, NOT "
          f"the peak blade-tip shear (corroborates research §F).\n")

    # The sentinel: PASS = reduced-order model self-consistent (deductive
    # scalings + affinity cross-check + curvature truncation small +
    # determinism) AND the bracket was computed. It is NOT a claim that
    # 70-150 is correct, that this is CFD-accurate, or a device claim.
    bracket_computed = br["verdict"] in (
        "CONTAINS", "OVERLAPS", "BELOW_ASSERTED", "ABOVE_ASSERTED")
    ok &= bracket_computed

    print("  ── ① reinforcement (input-regime conditioning, NOT a ② revival) ──")
    print("    The ① shear-gated-nanobot Bell negative "
          "(SHEAR_GATED_NANOBOT.tape §8) takes 70-150 dyn/cm² as its INPUT.")
    print("    This file independently shows that band is (a) a LOW wall-shear "
          "(7-15 Pa) and (b) inside but at the LOW end of the physically")
    print("    attainable reduced-order envelope — so 'we just used too low a "
          "shear' is NOT an escape for ①; the compact-nanobot force-")
    print("    collection failure (~500× short at 150 dyn/cm²) stands. Does "
          "NOT revive ②; conditions ①'s input only.\n")

    print("  [honesty] REDUCED-ORDER ANALYTICAL — NOT validated CFD, NOT a "
          "HeartMate-3 model, NOT a hemolysis/vWF/thrombosis/device/clinical")
    print("  claim (g8/f2). HM3 rotor radius is an EXPLICIT ASSUMED BAND "
          "(g3); rpm/gap are the GENERIC published LVAD envelope (Bartoli")
    print("  2019, verbatim). Bracket computed, geometry NOT tuned toward "
          "70-150 (g1). Sentinel PASS = model self-consistent + bracket")
    print("  computed; it does NOT validate 70-150 nor claim CFD accuracy. "
          "See ../research/lvad_shear_reduced_order.md.")

    print("\n__DRYLAB_LVAD_SHEAR_REDUCED_ORDER__ PASS" if ok
          else "\n__DRYLAB_LVAD_SHEAR_REDUCED_ORDER__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
