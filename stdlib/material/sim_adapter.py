#!/usr/bin/env python3
# sim_adapter.py — `material + verify` Tier 1 thin adapter (D72 pattern).
#
# RTSC.md §8.7 Tier 1 — Computational synthesis (first-principles 시뮬레이션).
# Closed-form Tc / Hc2 predictors from the hexa-rtsc verify pillar, rewritten
# in pure Python so demiurge can spawn this without the .hexa runtime.
#
# Roll-out item #1 from §8.7: hexa-rtsc `calc_*.hexa` → `exports/material_sim/`
# typed JSON record. This is the lightest cohort (no install gate beyond the
# Python stdlib). Tier 1 → CLI / Swift loader wiring is a separate cohort.
#
# Source formulas (each is a closed-form algebraic identity, NOT a solver):
#   - BCS Tc        : Bardeen-Cooper-Schrieffer 1957, PR 108 1175
#                     Tc = 1.13 * Θ_D * exp(-1 / (N(0)·V))
#                     Weak-coupling. Valid only for λ = N(0)V ≲ 0.5.
#   - McMillan Tc   : McMillan 1968, PR 167 331
#                     Tc = (ω_log/1.2) · exp[ -1.04(1+λ) / (λ - μ*(1+0.62λ)) ]
#                     Intermediate-coupling extension.
#   - Allen-Dynes Tc: Allen & Dynes 1975, PRB 12 905
#                     same kernel × f1·f2 strong-coupling correction factors.
#   - Hc2(0) WHH    : Werthamer-Helfand-Hohenberg 1966, PR 147 295
#                     Hc2(0) = -0.69 · Tc · (dHc2/dT)|_Tc  (dirty-limit BCS).
#
# D61: substrate SSOT under `hexa-lang/stdlib/material/`. Demiurge spawns via
#      `python3 ~/core/hexa-lang/stdlib/material/sim_adapter.py <out_dir>`.
# D72: 1st material-domain consumer — single-file thin adapter. Promotion to
#      `kernels/sc_tc/` only at 2nd consumer (e.g. an Eliashberg full solver).
# D80: hexa-native-absent — closed-form only, NOT a self-consistent Eliashberg
#      Migdal-Eliashberg integral solve. provisional=True.
# g3:  absorbed = false 영원히 — Tier 1 is *prediction*, NOT *measurement*.
#      (RTSC.md §8.7 honest 한계 + §8.8 g3 stance.)

from __future__ import annotations

import json
import math
import sys
import time
from pathlib import Path


# ─── closed-form Tc / Hc2 formulas (pure Python, no .hexa runtime) ──────


def bcs_tc(theta_d_k: float, lam: float) -> dict:
    """BCS weak-coupling Tc.

    Tc = 1.13 · Θ_D · exp(-1 / λ_eff)   where λ_eff = N(0)·V.

    Honest scope: weak-coupling only. For λ ≳ 0.5 the exponential blows up
    and Tc becomes unphysically large — that's the published failure mode
    that motivated McMillan (1968) and Allen-Dynes (1975).
    """
    if lam <= 0.0:
        tc = 0.0
    else:
        tc = 1.13 * theta_d_k * math.exp(-1.0 / lam)
    return {
        "formula": "bcs_weak_coupling",
        "citation": "BCS 1957 PR 108 1175",
        "theta_d_K": theta_d_k,
        "lambda_eff_N0V": lam,
        "tc_K": tc,
        "valid_for": "lambda <= 0.5 (weak coupling); larger lambda diverges",
    }


def mcmillan_tc(omega_log_k: float, lam: float, mu_star: float) -> dict:
    """McMillan Tc (intermediate-coupling phonon-mediated SC).

    Tc = (ω_log / 1.2) · exp[ -1.04(1+λ) / (λ - μ*(1+0.62λ)) ]

    Denominator must be > 0 → λ > μ*(1+0.62λ). Otherwise the formula
    is outside its regime (no SC predicted at this μ*).
    """
    denom = lam - mu_star * (1.0 + 0.62 * lam)
    in_regime = denom > 0.0 and lam > 0.0 and omega_log_k > 0.0
    if in_regime:
        exponent = -1.04 * (1.0 + lam) / denom
        tc = (omega_log_k / 1.2) * math.exp(exponent)
    else:
        tc = 0.0
    return {
        "formula": "mcmillan_1968",
        "citation": "McMillan 1968 PR 167 331",
        "omega_log_K": omega_log_k,
        "lambda": lam,
        "mu_star": mu_star,
        "denom_lambda_minus_muprime": denom,
        "in_regime": in_regime,
        "tc_K": tc,
    }


def allen_dynes_tc(
    omega_log_k: float,
    lam: float,
    mu_star: float,
    omega2_k: float | None = None,
) -> dict:
    """Allen-Dynes Tc (McMillan kernel + f1·f2 strong-coupling correction).

    Tc = f1 · f2 · (ω_log/1.2) · exp[ -1.04(1+λ) / (λ - μ*(1+0.62λ)) ]

    f1 = (1 + (λ/Λ1)^(3/2))^(1/3),         Λ1 = 2.46 (1 + 3.8 μ*)
    f2 = 1 + λ²(ω₂/ω_log - 1) / (λ² + Λ2²), Λ2 = 1.82 (1 + 6.3 μ*)(ω₂/ω_log)

    First-cut: ω₂ ≈ ω_log → f2 = 1.
    """
    if omega2_k is None:
        omega2_k = omega_log_k

    base = mcmillan_tc(omega_log_k, lam, mu_star)
    if not base["in_regime"]:
        return {
            "formula": "allen_dynes_1975",
            "citation": "Allen & Dynes 1975 PRB 12 905",
            "omega_log_K": omega_log_k,
            "omega2_K": omega2_k,
            "lambda": lam,
            "mu_star": mu_star,
            "f1": 0.0,
            "f2": 0.0,
            "in_regime": False,
            "tc_K": 0.0,
        }

    lambda1 = 2.46 * (1.0 + 3.8 * mu_star)
    lambda2 = 1.82 * (1.0 + 6.3 * mu_star) * (omega2_k / omega_log_k)

    f1 = (1.0 + (lam / lambda1) ** 1.5) ** (1.0 / 3.0)
    f2_num = (lam * lam) * (omega2_k / omega_log_k - 1.0)
    f2_den = (lam * lam) + (lambda2 * lambda2)
    f2 = 1.0 + f2_num / f2_den

    tc = f1 * f2 * base["tc_K"]
    return {
        "formula": "allen_dynes_1975",
        "citation": "Allen & Dynes 1975 PRB 12 905",
        "omega_log_K": omega_log_k,
        "omega2_K": omega2_k,
        "lambda": lam,
        "mu_star": mu_star,
        "Lambda1": lambda1,
        "Lambda2": lambda2,
        "f1": f1,
        "f2": f2,
        "mcmillan_base_tc_K": base["tc_K"],
        "in_regime": True,
        "tc_K": tc,
    }


def whh_hc2_zero(tc_k: float, slope_T_per_K_at_tc: float) -> dict:
    """Werthamer-Helfand-Hohenberg Hc2(0) (dirty-limit BCS).

    Hc2(0) = -0.69 · Tc · (dHc2/dT)|_{T=Tc}

    Convention: the slope dHc2/dT near Tc is *negative* (Hc2 falls from Tc
    upward in T). The user typically passes the *magnitude* |slope| (positive
    T/K). We accept either sign and return positive Hc2(0).
    """
    slope_signed = -abs(slope_T_per_K_at_tc)
    hc2_0_T = -0.69 * tc_k * slope_signed
    return {
        "formula": "whh_1966_dirty_limit",
        "citation": "Werthamer-Helfand-Hohenberg 1966 PR 147 295",
        "tc_K": tc_k,
        "slope_dHc2_dT_T_per_K_magnitude": abs(slope_T_per_K_at_tc),
        "hc2_0_T": hc2_0_T,
    }


# ─── DEFAULTS table — small reference panel ─────────────────────────────
# Sources:
#   - Nb λ=0.82, μ*=0.13, ω_log≈262 K, Θ_D=275 K: Allen & Dynes 1975 PRB 12
#     905, Table I (Nb row). dHc2/dT|_Tc ≈ -0.5 T/K is a representative
#     Nb-alloy slope (sourced Nb single-crystal Hc2 is smaller; this entry
#     is a *reference panel* for the formula path, NOT a sourced Nb sample).
#   - LK-99: Lee et al. arxiv:2307.12008 — Tc>RT claim. INPUT PARAMS for
#     Eliashberg coupling on LK-99 are *not measured*: ω_log / λ / μ* of the
#     Cu-doped lead-apatite (allegedly hosted on a flat-band Cu-O channel)
#     have no first-principles consensus. Claim-only, replication failed at
#     Argonne / IISc / Beihang / Nanjing / Berkeley.
DEFAULTS = [
    {
        "family": "Nb",
        "note": (
            "Elemental Nb — BCS reference panel. Strong-coupling λ=0.82 "
            "from Allen & Dynes 1975 Table I. BCS weak-coupling formula "
            "intentionally uses a smaller lambda_bcs=0.32 to stay in its "
            "regime — illustrates the published BCS→McMillan motivation."
        ),
        "theta_d_K": 275.0,
        "omega_log_K": 262.0,
        "lambda_full": 0.82,
        "lambda_bcs_weak": 0.32,
        "mu_star": 0.13,
        "dHc2_dT_T_per_K": 0.5,
        "experimental_tc_K_reference": 9.25,
        "input_param_provenance": "Allen & Dynes 1975 PRB 12 905 Table I",
        "claim_only": False,
    },
    {
        "family": "LK-99 (hypothetical)",
        "note": (
            "Cu-doped lead-apatite Tc>RT claim (Lee et al. 2307.12008). "
            "Eliashberg coupling params for the alleged flat-band Cu-O "
            "channel are NOT MEASURED — values below are illustrative "
            "ranges used in subsequent first-principles papers (Si & Held "
            "2308.13759 etc.), NOT consensus first-principles values. "
            "Independent replication failed at multiple labs."
        ),
        "theta_d_K": 500.0,        # rough apatite Debye estimate, claim-only
        "omega_log_K": 400.0,      # claim-only
        "lambda_full": 1.50,       # claim-only (would need to be huge for RT)
        "lambda_bcs_weak": 0.40,   # claim-only weak-coupling reduction
        "mu_star": 0.13,
        "dHc2_dT_T_per_K": 1.0,    # claim-only — never measured cleanly
        "experimental_tc_K_reference": None,  # no reproducible measurement
        "input_param_provenance": (
            "arxiv:2307.12008 (Lee et al.) — claim paper. Coupling-strength "
            "values illustrative only; replication failed."
        ),
        "claim_only": True,
    },
]


# ─── record dump ────────────────────────────────────────────────────────


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())

    citations = [
        "BCS — Bardeen, Cooper, Schrieffer 1957, PR 108 1175 "
        "('Theory of Superconductivity').",
        "McMillan 1968, PR 167 331 ('Transition Temperature of "
        "Strong-Coupled Superconductors').",
        "Allen & Dynes 1975, PRB 12 905 ('Transition temperature of "
        "strong-coupled superconductors reanalyzed') — arxiv predates web; "
        "primary citation is PRB.",
        "Werthamer, Helfand, Hohenberg 1966, PR 147 295 ('Temperature and "
        "Purity Dependence of the Superconducting Critical Field, Hc2. III. "
        "Electron Spin and Spin-Orbit Effects').",
        "hexa-rtsc verify pillar — calc_bcs.hexa, calc_mcmillan.hexa, "
        "calc_hc2_48t.hexa, calc_lk99.hexa (n=6 closed-form anchors).",
        "RTSC.md §8.7 Tier 1 — first-principles simulation thin-adapter cohort.",
    ]

    scope_caveats = [
        "(s1) BCS-like effective-coupling assumed throughout — NOT a full "
        "Eliashberg self-consistent Migdal-Eliashberg integral solve. The "
        "α²F(ω) spectral function is collapsed to scalar moments (λ, ω_log, "
        "ω₂) per McMillan / Allen-Dynes; off-Fermi-surface vertex corrections "
        "and frequency-dependent self-energy are absent.",
        "(s2) μ* (Coulomb pseudopotential, Morel-Anderson) is empirical, "
        "NOT first-principles. Standard value 0.10–0.16 is fit to the s/p/d "
        "metal family it came from; using μ*=0.13 for a hypothetical novel "
        "lattice (LK-99) is itself a claim, not a derivation.",
        "(s3) Input params for unproven families (LK-99) are CLAIM-ONLY — "
        "the Θ_D / ω_log / λ values for Cu-doped lead-apatite have no "
        "reproduced first-principles consensus and the experimental Tc has "
        "not been replicated by independent labs. Marked claim_only=true.",
        "(s4) Tier 1 is *prediction*, NEVER *measurement*. absorbed=false "
        "is permanent for this record-kind per RTSC.md §8.7 / §8.8 honest "
        "한계. Promotion to absorbed=true requires Tier 3 measurement + "
        "Tier 4 falsifier dispatch in a separate cohort.",
    ]

    rows: list[dict] = []
    for d in DEFAULTS:
        bcs = bcs_tc(d["theta_d_K"], d["lambda_bcs_weak"])
        mcm = mcmillan_tc(d["omega_log_K"], d["lambda_full"], d["mu_star"])
        ad = allen_dynes_tc(
            d["omega_log_K"], d["lambda_full"], d["mu_star"]
        )
        # Use Allen-Dynes Tc as the WHH input (best closed-form Tc available
        # here). If Allen-Dynes gave 0 (outside regime), Hc2(0) is also 0.
        whh = whh_hc2_zero(ad["tc_K"], d["dHc2_dT_T_per_K"])
        rows.append({
            "family": d["family"],
            "note": d["note"],
            "input_param_provenance": d["input_param_provenance"],
            "claim_only": d["claim_only"],
            "experimental_tc_K_reference": d["experimental_tc_K_reference"],
            "bcs_weak": bcs,
            "mcmillan": mcm,
            "allen_dynes": ad,
            "whh_hc2_zero": whh,
        })

    record = {
        "domain": "material",
        "verb": "verify",
        "kind": "first_principles_tc_prediction",
        "stamp": stamp,
        "producer": "sim_adapter@material-tier1",
        "measurement_gate": "GATE_OPEN",
        "absorbed": False,          # Tier 1 = prediction, never measurement
        "gate_type": "hexa-native-absent",  # Eliashberg solver not landed
        "provisional": True,
        "scope_caveats": scope_caveats,
        "citations": citations,
        "provenance": {
            "source_url": (
                "https://journals.aps.org/pr/abstract/10.1103/PhysRev.108.1175"
            ),
            "arxiv_ids": [
                "cond-mat/2307.12008",  # LK-99 claim paper (Lee et al.)
            ],
            "primary_refs": [
                "PR 108 1175 (BCS 1957)",
                "PR 167 331 (McMillan 1968)",
                "PRB 12 905 (Allen-Dynes 1975)",
                "PR 147 295 (WHH 1966)",
            ],
            "substrate_anchors": [
                "~/core/hexa-rtsc/verify/calc_bcs.hexa",
                "~/core/hexa-rtsc/verify/calc_mcmillan.hexa",
                "~/core/hexa-rtsc/verify/calc_hc2_48t.hexa",
                "~/core/hexa-rtsc/verify/calc_lk99.hexa",
            ],
        },
        "rtsc_anchor": "RTSC.md §8.7 Tier 1 (Computational synthesis)",
        "rows": rows,
    }

    rec_path = out / f"material_verify_{stamp}.json"
    rec_path.write_text(json.dumps(record, indent=2))

    # Headline lines
    print(f"[material+verify] wrote {rec_path}")
    for r in rows:
        flag = " [CLAIM-ONLY]" if r["claim_only"] else ""
        print(
            f"  · {r['family']}{flag}: "
            f"BCS_weak={r['bcs_weak']['tc_K']:.2f} K  "
            f"McMillan={r['mcmillan']['tc_K']:.2f} K  "
            f"AllenDynes={r['allen_dynes']['tc_K']:.2f} K  "
            f"Hc2(0)_WHH={r['whh_hc2_zero']['hc2_0_T']:.2f} T"
        )
    print(
        "[material+verify] absorbed=false (Tier 1 prediction; "
        "RTSC.md §8.7 honest 한계 — NEVER promote to absorbed=true "
        "without Tier 3 measurement + Tier 4 dispatch)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(
        main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/material_verify")
    )
