#!/usr/bin/env python3
"""vwf_multimer_kinetics.py — drylab #5 · vWF multimer-size population-balance.

Anchors LVAD/A2_STABILIZER.tape §3 limit #4 ("vWF multimer MW range
500 kDa – 20 MDa · HMW = >10 MDa lost first") by a deterministic stdlib
size-resolved steady-state scission balance. #4 was dismissed as a
"descriptive constant, no in-substrate consistency relation" — a FALSE
boundary: Zhang X 2009 derives a *dynamical* size-regulation law
(mid-multimer tension ∝ N², so per-multimer ADAMTS13-cleavage rate is
size-dependent → a shear-dependent steady-state size distribution). This
module is the steady state of that law.

═══ Real-limit anchor (Zhang-2009-corrected, g1/g3) ═══
Constants verified verbatim from the scenario's OWN cited primary
(Zhang X, Halvorsen K, Zhang C-Z, Wong WP, Springer TA. "Mechanoenzymatic
cleavage of the ultralarge vascular protein von Willebrand factor."
Science 2009;324:1330-1334; fetched PMC2753189):
  • ADAMTS13 single-molecule k_cat (unfolded A2) = 0.14 s⁻¹  (NOT 2.5/s)
  • A2 unfolding ΔG = 6.6±1.5 k_BT = 3.9±0.9 kcal/mol  (NOT 7-10)
  • A2 unfolding rate, zero force k_u0 = 0.0007 s⁻¹  (band 0.0002-0.003)
  • A2 Bell force scale f_β = 1.1 ± 0.2 pN ; k_u = k_u0·exp(F/f_β)
  • A2 unfolded-state lifetime (0 force) = 1.9 s → refold-rate upper bound
  • mid-multimer tension ∝ N² ("square of multimer length, highest at the
    middle"); ≈ 10 pN at N=200, τ=100 dyn/cm² (single cited calibration pt)
  • predicted in-vivo upper size limit ≈ 200 monomers
Mechanism (Crawley JTB 2011 Blood 118:3212, PMID 21715306; Springer TA
2014 Blood 124:1412, PMC4148764): elevated shear unravels A2 (extracts the
Cys1669-Cys1670 vicinal disulfide plug), exposing Tyr1605-Met1606 + cryptic
exosites; only unfolded A2 is cleaved. vWF subunit ≈220-250 kDa, dimer
≈500 kDa, max multimer >20 MDa (PMC3969155) — anchors #4's MW range.

═══ HONEST APPROXIMATION LABEL ═══
This is a REDUCED population-balance: a discretised birth-death balance with
a single mid-chain scission (N → ⌊N/2⌋ + ⌈N/2⌉) and NO re-multimerisation.
It is NOT a full polymer-scission PDE / coagulation-fragmentation solver. It
omits bond-position-resolved scission profiles, vWF self-association /
tubular-storage size effects, collagen/platelet tension modulation, and the
globule→stretch transition (only the elongated ∝τ·N² regime is used). It is
a hypothesis generator for the DIRECTION and ORDERING of size loss, not a
quantitative size-distribution predictor. The lumped tension prefactor is
fixed by ONE cited Zhang-2009 calibration point — NOT fitted to a desired
output distribution (g1, no fit-to-convenient-number).

Honest scope (g8/f2): in-silico simulator-consistency only. aVWS in LVAD
patients is established clinical biology cited as the DIRECTION the model
must reproduce — the model neither validates a device nor advances the A2
stabilizer drug (white-space, 0 approved A2 stabilizers, unchanged). NO
therapeutic / clinical / regulatory / efficacy / immunogenicity claim.

Cross-ref: ../research/vwf_multimer_kinetics.md ;
_python_bridge/module/a2_shear_unfolding_anchor.py (same constant set,
F_mid ∝ C_T·τ·L²) ; drylab/research/a2_cg_unfolding.md .
"""

from __future__ import annotations

import math
import sys

# ── Zhang-2009-corrected cited constants (verbatim PMC2753189) ──────────────
ADAMTS13_KCAT_PER_S = 0.14          # single-molecule, on unfolded A2 (NOT 2.5)
A2_DG_KCAL_MOL = 3.9                # 6.6±1.5 k_BT = 3.9±0.9 kcal/mol (NOT 7-10)
A2_KU0_PER_S = 0.0007               # zero-force unfolding rate (0.0002-0.003)
A2_FBETA_PN = 1.1                   # Bell force scale; k_u = k_u0·exp(F/f_β)
A2_UNFOLDED_LIFETIME_S = 1.9        # zero-force unfolded-state lifetime
A2_REFOLD_PER_S = 1.0 / A2_UNFOLDED_LIFETIME_S   # ≈ 0.526 /s (refold rate)

# Zhang's single cited tension calibration point: F_mid ≈ 10 pN at
# N = 200 monomers, τ = 100 dyn/cm² ("force ∝ N², highest at the middle").
# Lumped prefactor K_TENSION (= C_T·ℓ_mono² in the F_mid∝C_T·τ·L² form) is
# FIXED by this ONE literature point — a cited anchor, NOT a free fit (g1).
ZHANG_CAL_FORCE_PN = 10.0
ZHANG_CAL_N = 200
ZHANG_CAL_SHEAR_DYN_CM2 = 100.0
K_TENSION_PN_PER_DYNCM2_N2 = ZHANG_CAL_FORCE_PN / (
    ZHANG_CAL_SHEAR_DYN_CM2 * ZHANG_CAL_N * ZHANG_CAL_N)   # ≈ 2.5e-6

# Multimer molecular-weight axis (#4): subunit ≈ 220-250 kDa; dimer ≈ 500 kDa
# (N=2); max multimer > 20 MDa (PMC3969155). Use 250 kDa/monomer.
SUBUNIT_KDA = 250.0
HMW_MW_THRESHOLD_KDA = 10_000.0     # #4: HMW = > 10 MDa (literal #4 metric)
# Ultralarge (ULVWF) band: monomer count above Zhang's cited ~200-monomer
# in-vivo upper size limit — the species the N² tension law trims FIRST. This
# is the discriminating "HMW lost first" observable for this reduced model
# (the fixed >10 MDa cutoff is a weak discriminator because the single-
# midpoint-scission cascade concentrates mass below N≈125 quickly — see
# §honesty-caveat). Threshold = Zhang's literature upper limit, NOT tuned.
ULVWF_N_THRESHOLD = 200             # Zhang 2009 cited in-vivo upper size limit
N_MAX = 250                         # straddles Zhang ~200-monomer upper limit
SECRETION_AT_NMAX = 1.0             # ultralarge vWF secreted then trimmed
K_CLEAR_PER_S = 1.0e-3              # slow size-independent clearance (flux sink)


def mid_multimer_tension_pN(n_monomers: int, shear_dyn_cm2: float) -> float:
    """F_mid(N, τ) = K_TENSION · τ · N²  (Zhang 2009: force ∝ N², mid-chain).

    Prefactor fixed by Zhang's cited point (10 pN @ N=200, τ=100). NOT fitted.
    """
    if n_monomers < 1 or shear_dyn_cm2 < 0:
        raise ValueError("N ≥ 1 and shear ≥ 0 required.")
    return K_TENSION_PN_PER_DYNCM2_N2 * shear_dyn_cm2 * n_monomers * n_monomers


def a2_unfold_rate_per_s(force_pN: float) -> float:
    """Bell force-accelerated A2 unfolding: k_u = k_u0·exp(F/f_β) (Zhang 2009)."""
    expo = min(force_pN / A2_FBETA_PN, 80.0)   # cap to avoid overflow
    return A2_KU0_PER_S * math.exp(expo)


def scission_rate_per_s(n_monomers: int, shear_dyn_cm2: float) -> float:
    """Per-multimer scission rate, cleavage-limited (Crawley 2011 mechanism).

    Only force-unfolded A2 is cleaved; the slower of (A2 unfolding, ADAMTS13
    turnover) caps the rate (with k_cat=0.14/s vs unfolded lifetime 1.9 s the
    enzymatic step is rate-limiting — the honest cleavage-limited regime).
    """
    k_u = a2_unfold_rate_per_s(mid_multimer_tension_pN(n_monomers, shear_dyn_cm2))
    p_unfolded = k_u / (k_u + A2_REFOLD_PER_S)            # 2-state occupancy
    return min(k_u, ADAMTS13_KCAT_PER_S) * p_unfolded


def steady_state_distribution(shear_dyn_cm2: float) -> dict:
    """Deterministic top-down birth-death steady state (no PRNG, no iteration).

    Scission only moves mass DOWN in size (N → ⌊N/2⌋ + ⌈N/2⌉), so a single
    sweep N_MAX→1 solves the steady state exactly: at each N,
    n[N] = inflow[N] / (k_scission(N) + k_clear).
    """
    inflow = [0.0] * (N_MAX + 1)
    inflow[N_MAX] += SECRETION_AT_NMAX
    n = [0.0] * (N_MAX + 1)
    for N in range(N_MAX, 0, -1):
        if inflow[N] <= 0.0:
            continue
        k_sc = scission_rate_per_s(N, shear_dyn_cm2) if N >= 2 else 0.0
        n[N] = inflow[N] / (k_sc + K_CLEAR_PER_S)
        if N >= 2 and k_sc > 0.0:
            split_flux = k_sc * n[N]            # multimers/s leaving size N
            lo, hi = N // 2, N - N // 2         # ⌊N/2⌋, ⌈N/2⌉
            # one scission of an N-mer yields one lo-mer + one hi-mer
            inflow[lo] += split_flux
            inflow[hi] += split_flux

    # observables -----------------------------------------------------------
    count_tot = sum(n[1:])
    mono_tot = sum(N * n[N] for N in range(1, N_MAX + 1))   # total monomer mass
    n_avg = (mono_tot / count_tot) if count_tot > 0 else 0.0
    mass_avg = (sum(N * N * n[N] for N in range(1, N_MAX + 1)) / mono_tot
                if mono_tot > 0 else 0.0)
    hmw_mono = sum(N * n[N] for N in range(1, N_MAX + 1)
                   if N * SUBUNIT_KDA > HMW_MW_THRESHOLD_KDA)
    hmw_frac = (hmw_mono / mono_tot) if mono_tot > 0 else 0.0
    # ultralarge (ULVWF) band — N above Zhang's cited ~200-monomer in-vivo
    # upper limit: the species the N² law trims first; the unambiguous
    # "HMW lost first" (#4) signature for this reduced model.
    ulvwf_mono = sum(N * n[N] for N in range(1, N_MAX + 1)
                     if N > ULVWF_N_THRESHOLD)
    ulvwf_frac = (ulvwf_mono / mono_tot) if mono_tot > 0 else 0.0

    # mass-conservation flux residual (MONOMER mass — the conserved quantity).
    # Scission preserves monomer count exactly (lo+hi=N), so it is an internal
    # redistribution; at steady state the secreted monomer flux must equal the
    # cleared monomer flux:  S·N_MAX  ==  k_clear · Σ_N N·n[N].
    monomer_in = SECRETION_AT_NMAX * N_MAX
    monomer_out = sum(K_CLEAR_PER_S * N * n[N] for N in range(1, N_MAX + 1))
    mass_residual = abs(monomer_in - monomer_out)

    return {
        "shear_dyn_cm2": shear_dyn_cm2,
        "mid_tension_at_Nmax_pN": round(
            mid_multimer_tension_pN(N_MAX, shear_dyn_cm2), 4),
        "mean_monomer_count": round(n_avg, 4),
        "mass_avg_monomer_count": round(mass_avg, 4),
        "hmw_mass_fraction_gt_10MDa": round(hmw_frac, 6),
        "ulvwf_mass_fraction_N_gt_200": round(ulvwf_frac, 6),
        "total_monomer_mass": round(mono_tot, 6),
        "mass_flux_residual": mass_residual,
    }


def shear_sweep(shears=(0.0, 10.0, 30.0, 70.0, 100.0, 150.0)) -> list:
    return [steady_state_distribution(s) for s in shears]


def _selfcheck() -> int:
    print("vwf_multimer_kinetics — drylab #5 · vWF size population-balance "
          "(Zhang-2009-corrected)\n")
    print(f"  cited constants: k_cat={ADAMTS13_KCAT_PER_S}/s  "
          f"ΔG={A2_DG_KCAL_MOL} kcal/mol  k_u0={A2_KU0_PER_S}/s  "
          f"f_β={A2_FBETA_PN} pN  unfolded-τ={A2_UNFOLDED_LIFETIME_S}s")
    print(f"  K_TENSION fixed by Zhang point (10 pN @ N=200, τ=100) = "
          f"{K_TENSION_PN_PER_DYNCM2_N2:.3e} pN/(dyn·cm⁻²·N²)\n")

    # D1 sanity: Zhang calibration point round-trips to ≈10 pN.
    f_cal = mid_multimer_tension_pN(ZHANG_CAL_N, ZHANG_CAL_SHEAR_DYN_CM2)
    assert abs(f_cal - ZHANG_CAL_FORCE_PN) < 1e-9, f_cal
    print(f"  [PASS] D1 tension calibration round-trip: F_mid(200,100)="
          f"{f_cal:.3f} pN (Zhang ≈10)")

    # D2 tension ∝ N² (Zhang law): doubling N → 4× force.
    n2_ratio = (mid_multimer_tension_pN(100, 70.0)
                / mid_multimer_tension_pN(50, 70.0))
    assert abs(n2_ratio - 4.0) < 1e-9, n2_ratio
    print(f"  [PASS] D2 mid-tension ∝ N²  ({n2_ratio:.2f}× for 2× monomer count)")

    sweep = shear_sweep()
    print("\n  steady-state size vs shear:")
    print("   τ(dyn/cm²)  F_mid@Nmax(pN)   ⟨N⟩   mass-avg-N  "
          "HMW(>10MDa)  ULVWF(N>200)")
    for row in sweep:
        print(f"   {row['shear_dyn_cm2']:>9.0f}  "
              f"{row['mid_tension_at_Nmax_pN']:>13.3f}"
              f"  {row['mean_monomer_count']:>7.2f}"
              f"  {row['mass_avg_monomer_count']:>9.2f}"
              f"     {row['hmw_mass_fraction_gt_10MDa']:>0.4f}"
              f"       {row['ulvwf_mass_fraction_N_gt_200']:>0.4f}")

    # D3 mass conservation: secretion in = clearance out (flux steady state).
    max_resid = max(r["mass_flux_residual"] for r in sweep)
    assert max_resid < 1e-9, f"mass not conserved: residual {max_resid}"
    print(f"\n  [PASS] D3 mass-conservation (flux residual {max_resid:.2e} < 1e-9)")

    # D4 determinism: identical inputs ⇒ bitwise-identical output.
    a, b = shear_sweep(), shear_sweep()
    assert a == b
    print("  [PASS] D4 deterministic (no PRNG; bitwise-identical re-run)")

    # D5 higher shear → smaller mean multimer (aVWS direction, Zhang law).
    means = [r["mean_monomer_count"] for r in sweep]
    mono_decreasing = all(means[i] >= means[i + 1] for i in range(len(means) - 1))
    assert mono_decreasing, f"⟨N⟩ not monotone-decreasing in shear: {means}"
    print(f"  [PASS] D5 higher shear → smaller ⟨N⟩  "
          f"(τ=0:{means[0]:.1f} → τ=150:{means[-1]:.1f} monomers)")

    # D6 the §3#4 aVWS SIGNATURE: HMW preferentially lost as shear ↑ (both the
    #    literal #4 >10 MDa band AND the >15 MDa ultralarge band monotone ↓;
    #    ULVWF must be lost MORE than the >10 MDa band — "lost FIRST").
    hmw = [r["hmw_mass_fraction_gt_10MDa"] for r in sweep]
    ulv = [r["ulvwf_mass_fraction_N_gt_200"] for r in sweep]
    hmw_decreasing = all(hmw[i] >= hmw[i + 1] for i in range(len(hmw) - 1))
    ulv_decreasing = all(ulv[i] >= ulv[i + 1] for i in range(len(ulv) - 1))
    hmw_actually_lost = hmw[0] > hmw[-1]
    # "lost FIRST": the ultralarge band (N>200, Zhang's cited upper limit)
    # loses a far GREATER fraction than the >10 MDa band over the same shear
    # rise — the directional aVWS signature the N² kernel produces.
    ulvwf_lost_more = (ulv[0] - ulv[-1]) > (hmw[0] - hmw[-1])
    assert hmw_decreasing and ulv_decreasing and hmw_actually_lost \
        and ulvwf_lost_more, \
        f"HMW not preferentially lost: hmw={hmw} ulv={ulv}"
    print(f"  [PASS] D6 §3#4 aVWS signature — ultralarge lost FIRST: "
          f">10MDa {hmw[0]:.4f}→{hmw[-1]:.4f} (Δ{hmw[0]-hmw[-1]:.4f}); "
          f"N>200 {ulv[0]:.4f}→{ulv[-1]:.4f} (Δ{ulv[0]-ulv[-1]:.4f}) "
          f"— ultralarge depleted ~{ulv[0]/max(ulv[-1],1e-9):.0f}×")

    ok = (abs(f_cal - ZHANG_CAL_FORCE_PN) < 1e-9
          and abs(n2_ratio - 4.0) < 1e-9
          and max_resid < 1e-9
          and a == b
          and mono_decreasing
          and hmw_decreasing and ulv_decreasing
          and hmw_actually_lost and ulvwf_lost_more)

    print("\n  [honesty] REDUCED population-balance (single mid-chain scission, "
          "no re-multimerisation) — NOT a full polymer-scission PDE. K_TENSION "
          "fixed by ONE cited Zhang-2009 point, NOT fitted to a desired "
          "distribution (g1). Zhang-corrected k_cat 0.14/s & ΔG 3.9 used (g3). "
          "In-silico simulator-consistency only; aVWS cited as the DIRECTION to "
          "reproduce — NO device/drug/clinical claim (g8/f2). See "
          "../research/vwf_multimer_kinetics.md.")
    print("\n__DRYLAB_VWF_MULTIMER_KINETICS__ PASS" if ok
          else "\n__DRYLAB_VWF_MULTIMER_KINETICS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
