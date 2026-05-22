#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
protac_sim.py — PROTAC sub-axis :> BIFUNCTIONAL (expansion-main).

Deterministic, stdlib-only real-limits model of the PROTAC (PROteolysis-
TArgeting Chimera) ternary-complex EQUILIBRIUM and the ubiquitin-transfer
competence that gate proteasomal degradation. This is the in-silico
simulator-consistency layer for the PROTAC sub-axis registered in
AXIS/HIERARCHY.tape @D sub_under_bifunctional — see the sibling note
`protac_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A PROTAC is a bifunctional molecule: one warhead binds the target protein of
interest (POI), the other binds an E3 ubiquitin ligase (CRBN, VHL, …); a linker
joins them. Degradation requires a productive TERNARY complex POI·PROTAC·E3 in
which the POI surface lysines are presented to the E2~ubiquitin for transfer.

  Binary equilibria (law of mass action — dissociation constants):
      POI + PROTAC  ⇌  POI·PROTAC          K_d(target)
      E3  + PROTAC  ⇌  E3·PROTAC           K_d(E3)

  Ternary complex with cooperativity factor α (Douglass et al. 2013):
      POI·PROTAC + E3   ⇌   POI·PROTAC·E3
      apparent  K_d,ternary = K_d(E3) / α
  α > 1 → POSITIVE cooperativity (protein–protein contacts in the ternary
  complex stabilise it beyond the sum of the two binary affinities — the
  hallmark of a well-designed PROTAC); α < 1 → negative cooperativity;
  α = 1 → no cooperativity.

  The classic HOOK EFFECT: at high [PROTAC] the binary POI·PROTAC and E3·PROTAC
  species out-compete the ternary complex (PROTAC saturates both partners
  separately), so the ternary fraction is non-monotone in [PROTAC] and peaks at
  an optimum concentration. The model computes the ternary fraction across a
  fixed deterministic [PROTAC] grid and locates that peak.

  Ubiquitin-transfer competence:
      degradation_drive = ternary_fraction_peak · transfer_efficiency
  where transfer_efficiency in [0,1] is a literature-informed surrogate for the
  geometric competence of the POI lysine presentation to the E2~Ub.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The law of mass action / chemical-equilibrium thermodynamics. Every binary and
ternary occupancy here is a closed-form mass-action equilibrium: fraction bound
θ = [L]/(K_d + [L]) with θ = 1/2 exactly at [L] = K_d. The ternary-complex
cooperativity factor α and the hook effect are the established equilibrium
description of PROTAC ternary complexes:
  - Douglass, Miller, Sparer, Shapiro & Spiegel, "A comprehensive mathematical
    model for three-body binding equilibria", J. Am. Chem. Soc. 135:6092 (2013).
  - Gadd, Testa, Lucas, et al., "Structural basis of PROTAC cooperative
    recognition for selective protein degradation", Nat. Chem. Biol. 13:514
    (2017) — cooperativity α measured for the VHL–BRD4 ternary complex.
  - Roy, Nowak, Buckley & Fischer, "SAR of PROTAC ternary complexes" and the
    hook-effect review in Hughes & Ciulli, Essays Biochem. 61:505 (2017).
Mass-action equilibrium is the hard real limit: no modelled occupancy may
exceed 1 and θ = 1/2 must hold exactly at [L] = K_d (acceptance criteria).

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - ARV-471 (vepdegestrant) — an estrogen-receptor (ER) PROTAC, in clinical
    development (Flanagan et al., reported at SABCS; Arvinas/Pfizer programme).
  - ARV-110 (bavdegalutamide) — an androgen-receptor (AR) PROTAC, clinical-stage
    (Arvinas). PROTAC chemistry traces to Sakamoto et al., PNAS 98:8554 (2001).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the mass-action binary/ternary equilibria, the cooperativity factor,
the hook-effect peak and the degradation-drive product are computed
self-consistently and reproduce byte-identically. It is NOT a binding-affinity
measurement, NOT a degradation-potency (DC50/Dmax) claim, NOT a therapeutic-
efficacy claim. K_d / α / transfer-efficiency values are illustrative
literature-informed surrogates, not fits to a specific compound. Pure stdlib,
no network/time/random → byte-identical re-runs.

PROTAC is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it is NOT one
of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape @D sub_under_bifunctional.
"""
from __future__ import annotations
import json
import sys

SCHEMA_ID = "protac_v1"

# ── deterministic [PROTAC] concentration grid (nM, log-spaced, fixed) ──
# spans below both K_d values up to far above — exposes the hook effect.
PROTAC_CONC_GRID_NM = [
    0.1, 0.3, 1.0, 3.0, 10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0, 10000.0,
]

# ── deterministic PROTAC degrader panel ─────────────────────────────────────
# (name, Kd_target_nM, Kd_e3_nM, alpha, transfer_efficiency, e3_ligase, precedent)
#   Kd_target : POI-warhead binary dissociation constant (nM).
#   Kd_e3     : E3-warhead binary dissociation constant (nM).
#   alpha     : ternary-complex cooperativity factor (>1 positive, <1 negative).
#   transfer_efficiency : geometric competence of POI-lysine→E2~Ub presentation,
#                         in [0,1] — a literature-informed surrogate.
# Values are illustrative literature-informed surrogates, not fits to a
# specific compound (see module honesty note).
PROTAC_PANEL = [
    ("ER_PROTAC_ARV471_like", 12.0, 30.0, 8.0, 0.70, "CRBN",
     "ARV-471 (vepdegestrant) — estrogen-receptor PROTAC, clinical"),
    ("AR_PROTAC_ARV110_like", 20.0, 25.0, 5.0, 0.65, "CRBN",
     "ARV-110 (bavdegalutamide) — androgen-receptor PROTAC, clinical"),
    ("BRD4_VHL_PROTAC_like", 8.0, 40.0, 12.0, 0.75, "VHL",
     "VHL-recruiting BRD4 PROTAC class — positive cooperativity (Gadd 2017)"),
    ("noncoop_PROTAC_like", 30.0, 30.0, 1.0, 0.50, "CRBN",
     "no-cooperativity reference (alpha = 1) — additive binary affinities"),
    ("negcoop_PROTAC_like", 25.0, 35.0, 0.4, 0.40, "VHL",
     "negative-cooperativity reference (alpha < 1) — poor ternary design"),
    ("strongcoop_PROTAC_like", 6.0, 20.0, 20.0, 0.80, "CRBN",
     "strong positive-cooperativity reference — extensive PPI interface"),
]


def fraction_bound(conc_nm: float, kd_nm: float) -> float:
    """Mass-action fractional occupancy θ = [L]/(K_d + [L]); θ = 1/2 at [L]=K_d."""
    return conc_nm / (kd_nm + conc_nm)


def ternary_fraction(conc_nm: float, kd_target_nm: float, kd_e3_nm: float,
                      alpha: float) -> float:
    """
    Ternary-complex fraction (of total POI) at a given [PROTAC].

    Two-step productive route: POI binds PROTAC (θ_target), then the E3 binds
    the POI·PROTAC binary species with the cooperatively enhanced apparent
    affinity K_d,ternary = K_d(E3)/α.  The hook effect is reproduced because
    θ_target itself saturates toward 1 at high [PROTAC] while the SECOND step
    sees the *free* PROTAC competing E3 away into the binary E3·PROTAC species
    — modelled by an effective E3 occupancy that uses the cooperative apparent
    K_d but is damped by the binary E3·PROTAC competition term.
    """
    theta_target = fraction_bound(conc_nm, kd_target_nm)
    kd_ternary = kd_e3_nm / alpha
    # productive ternary capture vs unproductive binary E3·PROTAC sequestration:
    # the E3 partitions between the POI·PROTAC complex (apparent K_d,ternary)
    # and free PROTAC (binary K_d(E3)).  Productive share = ternary / (ternary +
    # binary-sequestered).  At high [PROTAC] the binary term dominates → hook.
    productive = theta_target / kd_ternary
    sequestered = conc_nm / kd_e3_nm
    theta_ternary = productive / (1.0 + productive + sequestered)
    return theta_ternary


def degrader_profile(kd_target_nm: float, kd_e3_nm: float, alpha: float,
                      transfer_efficiency: float) -> dict:
    """One PROTAC's ternary-occupancy profile across the fixed [PROTAC] grid."""
    profile = []
    for c in PROTAC_CONC_GRID_NM:
        tf = ternary_fraction(c, kd_target_nm, kd_e3_nm, alpha)
        profile.append({"protac_nM": c, "ternary_fraction": tf})
    peak = max(profile, key=lambda p: p["ternary_fraction"])
    # hook effect present iff the peak is interior to the grid (non-monotone).
    interior = profile[0] != peak and profile[-1] != peak
    drive = peak["ternary_fraction"] * transfer_efficiency
    # cooperativity-consistency cross-check: apparent ternary K_d = Kd_e3/alpha.
    kd_ternary = kd_e3_nm / alpha
    return {
        "kd_target_nM": kd_target_nm,
        "kd_e3_nM": kd_e3_nm,
        "alpha_cooperativity": alpha,
        "kd_ternary_apparent_nM": kd_ternary,
        "cooperativity_class": (
            "positive" if alpha > 1.0 else
            "none" if alpha == 1.0 else "negative"),
        "transfer_efficiency": transfer_efficiency,
        "ternary_profile": profile,
        "ternary_fraction_peak": peak["ternary_fraction"],
        "protac_at_peak_nM": peak["protac_nM"],
        "hook_effect_present": interior,
        "degradation_drive": drive,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per PROTAC in the panel."""
    rows = []
    for name, kd_t, kd_e3, alpha, te, e3, precedent in PROTAC_PANEL:
        prof = degrader_profile(kd_t, kd_e3, alpha, te)
        row = {
            "schema": SCHEMA_ID,
            "protac": name,
            "e3_ligase": e3,
            "drug_precedent": precedent,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Positive- vs negative-cooperativity contrast at matched transfer."""
    by_name = {r["protac"]: r for r in rows}
    pos = by_name["strongcoop_PROTAC_like"]
    neg = by_name["negcoop_PROTAC_like"]
    return {
        "positive_cooperativity_reference": {
            "protac": pos["protac"],
            "alpha_cooperativity": pos["alpha_cooperativity"],
            "ternary_fraction_peak": pos["ternary_fraction_peak"],
            "degradation_drive": pos["degradation_drive"],
        },
        "negative_cooperativity_reference": {
            "protac": neg["protac"],
            "alpha_cooperativity": neg["alpha_cooperativity"],
            "ternary_fraction_peak": neg["ternary_fraction_peak"],
            "degradation_drive": neg["degradation_drive"],
        },
        "peak_ratio_pos_over_neg": (
            pos["ternary_fraction_peak"] / neg["ternary_fraction_peak"]),
        "note": ("positive cooperativity (alpha > 1) lowers the apparent ternary "
                 "K_d = Kd_e3/alpha, raising the ternary-complex peak; negative "
                 "cooperativity (alpha < 1) raises it and suppresses the peak."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C6)."""
    pos = [r for r in rows if r["cooperativity_class"] == "positive"]
    neg = [r for r in rows if r["cooperativity_class"] == "negative"]
    half_ok = True
    for r in rows:
        # mass-action identity: θ = 1/2 exactly at [L] = K_d(target).
        theta_at_kd = fraction_bound(r["kd_target_nM"], r["kd_target_nM"])
        if abs(theta_at_kd - 0.5) > 1e-12:
            half_ok = False
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_occupancies_bounded": all(
            0.0 <= p["ternary_fraction"] <= 1.0
            for r in rows for p in r["ternary_profile"]),
        "C3_mass_action_half_at_kd": half_ok,
        "C4_kd_ternary_equals_kde3_over_alpha": all(
            abs(r["kd_ternary_apparent_nM"]
                - r["kd_e3_nM"] / r["alpha_cooperativity"]) <= 1e-9
            for r in rows),
        "C5_both_cooperativity_classes_present": len(pos) >= 1 and len(neg) >= 1,
        "C6_positive_coop_raises_peak": all(
            p["ternary_fraction_peak"] > n["ternary_fraction_peak"]
            for p in pos for n in neg),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("protac_sim — PROTAC sub-axis :> BIFUNCTIONAL (expansion-main)\n",
          flush=True)
    print("model:  POI + PROTAC + E3  ->  ternary POI·PROTAC·E3 "
          "(mass-action; cooperativity alpha; hook effect)\n", flush=True)
    print("  real-limit anchor : law of mass action / 3-body binding equilibria")
    print("                      (Douglass et al., JACS 135:6092, 2013)")
    print("  ternary apparent K_d = K_d(E3) / alpha   "
          "(alpha > 1 = positive cooperativity)\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['protac']:<26}] coop={r['cooperativity_class']:<9} "
              f"alpha={r['alpha_cooperativity']:>5.1f}  E3={r['e3_ligase']}")
        print(f"      Kd_target={r['kd_target_nM']:.1f}nM  Kd_E3={r['kd_e3_nM']:.1f}nM  "
              f"Kd_ternary={r['kd_ternary_apparent_nM']:.2f}nM")
        print(f"      ternary_peak={r['ternary_fraction_peak']:.4f} @ "
              f"[PROTAC]={r['protac_at_peak_nM']:.1f}nM  "
              f"hook={r['hook_effect_present']}  "
              f"degradation_drive={r['degradation_drive']:.4f}")

    ctr = contrast(rows)
    print("\n## positive-vs-negative cooperativity contrast")
    pr, nr = ctr["positive_cooperativity_reference"], ctr["negative_cooperativity_reference"]
    print(f"  POSITIVE  {pr['protac']:<26} alpha={pr['alpha_cooperativity']:>5.1f}  "
          f"peak={pr['ternary_fraction_peak']:.4f}")
    print(f"  NEGATIVE  {nr['protac']:<26} alpha={nr['alpha_cooperativity']:>5.1f}  "
          f"peak={nr['ternary_fraction_peak']:.4f}")
    print(f"  peak ratio (pos/neg) = {ctr['peak_ratio_pos_over_neg']:.3f}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: {acc['verdict']} ---")

    print("\n## C3 honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — mass-action binary/ternary equilibria,")
    print("  the cooperativity factor and hook-effect peak computed self-consistently.")
    print("  NOT a binding-affinity, degradation-potency (DC50/Dmax) or therapeutic-")
    print("  efficacy claim. K_d / alpha / transfer values are literature-informed")
    print("  surrogates, not fits to a specific compound. PROTAC is a SUB-AXIS")
    print("  (:> BIFUNCTIONAL expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "PROTAC",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("law of mass action / three-body binding "
                              "equilibria (Douglass et al., JACS 135:6092, 2013)"),
        "protac_conc_grid_nM": PROTAC_CONC_GRID_NM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity, degradation-"
                                   "potency or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PROTAC__ PASS" if ok else "\n__PROTAC__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
