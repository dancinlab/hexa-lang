#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
autac_sim.py — AUTAC sub-axis :> BIFUNCTIONAL (expansion-main).

Deterministic, stdlib-only real-limits model of the AUTAC (AUTophagy-TArgeting
Chimera) S-guanylation autophagy-tag recruitment and the autophagic-flux
PARTITION that gates autophagy-mediated degradation. This is the in-silico
simulator-consistency layer for the AUTAC sub-axis registered in
AXIS/HIERARCHY.tape @D sub_under_bifunctional — see the sibling note
`autac_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
An AUTAC is a bifunctional molecule: one end is a target-binding warhead, the
other is an S-guanylation-mimetic **autophagy degradation tag** (a cyclic-GMP
derivative). The tag promotes K63-linked polyubiquitination of the target /
target-containing cargo, which is then recognised by an autophagy receptor
(p62/SQSTM1), recruited to the nascent autophagosome via LC3 (Atg8) on the
isolation membrane, and degraded on fusion with the lysosome.

  Target tagging (law of mass action — dissociation constant):
      target + AUTAC  ⇌  target·AUTAC          K_d(target)

  Autophagy-tag → LC3 recruitment competence:
      lc3_recruitment = θ_target · tag_competence
  where tag_competence in [0,1] is a literature-informed surrogate for how
  effectively the S-guanylation tag drives K63-Ub / p62 / LC3 engagement.

  Autophagic-flux PARTITION — the central real limit of this sub-axis. A tagged
  cargo committed to an autophagosome has two competing fates governed by
  first-order rate constants:
      autophagosome  --k_fusion-->   autolysosome (degraded — productive flux)
      autophagosome  --k_stall -->   stalled / matured-but-unfused (no flux)
  The flux-completion partition is
      flux_partition = k_fusion / (k_fusion + k_stall)
  This is the in-silico analogue of the autophagic-flux measurement (the
  bafilomycin-A1 / chloroquine flux assay): only the fraction whose
  autophagosome completes lysosomal fusion contributes to degradation.

  Steady-state autophagic degradation flux:
      degradation_flux = lc3_recruitment · k_seq · flux_partition
  where k_seq is the rate of cargo sequestration into a forming autophagosome.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Autophagic flux — the first-order kinetic balance of autophagosome formation
versus autophagosome–lysosome fusion — layered on the law of mass action.
Target tagging is a closed-form mass-action equilibrium (θ = [L]/(K_d+[L]),
θ = 1/2 at [L] = K_d). The flux-completion partition and the requirement that
flux be measured as a *rate through* the pathway, not a static autophagosome
count, follow the consensus autophagy-flux methodology:
  - Mizushima, N. & Yoshimori, T., "How to interpret LC3 immunoblotting",
    Autophagy 3:542 (2007) — LC3-I/LC3-II and the flux concept.
  - Klionsky, D.J. et al., "Guidelines for the use and interpretation of assays
    for monitoring autophagy" (consensus guidelines; e.g. Autophagy 17:1, 2021)
    — autophagic flux must be a turnover rate, not a steady-state pool.
  - Loos, B., du Toit, A. & Hofmeyr, J.-H.S., "Defining and measuring
    autophagosome flux — concept and reality", Autophagy 10:2087 (2014).
The flux partition is bounded in [0,1] and the mass-action half-occupancy
identity must hold exactly — the hard real limits that anchor every row.

Modality precedent (described ONLY by its own precedent — g3/f1, never
lattice-derived):
  - Takahashi, Moriya, Hara, Ichimura, Abe, Nishino, Aoki, Mizushima & Arimoto,
    "AUTACs: Cargo-Specific Degraders Using Selective Autophagy", Mol. Cell
    76:797 (2019) — the founding AUTAC work (Arimoto lab, Tohoku Univ.).
    RESEARCH-STAGE: AUTAC is a research-stage modality with no approved drug;
    the 2019 work and follow-ups (mitochondria-targeting mito-AUTACs) are
    discovery-stage. The S-guanylation autophagy tag traces to 8-nitro-cGMP
    biology (Sawa et al., Nat. Chem. Biol. 3:727, 2007).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the mass-action target tagging, the LC3-recruitment competence, the
autophagic-flux partition and the degradation-flux product are computed
self-consistently and reproduce byte-identically. It is NOT a binding-affinity
measurement, NOT a degradation-potency claim, NOT a therapeutic-efficacy claim.
AUTAC is a RESEARCH-STAGE modality — there is no approved AUTAC drug; nothing
here is a clinical or regulatory claim. K_d / rate / competence values are
illustrative literature-informed surrogates, not fits to a specific compound.
Pure stdlib, no network/time/random → byte-identical re-runs.

AUTAC is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it is NOT one
of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape @D sub_under_bifunctional.
"""
from __future__ import annotations
import json
import sys

SCHEMA_ID = "autac_v1"

# ── fixed deterministic operating concentration (nM) of AUTAC ──
# a single physiologically plausible operating point; the half-saturation
# identity (θ = 1/2 at [L] = K_d) is checked independently of this point.
AUTAC_CONC_NM = 100.0

# ── deterministic AUTAC degrader panel ──────────────────────────────────────
# (name, Kd_target_nM, tag_competence, k_seq_per_min, k_fusion_per_min,
#  k_stall_per_min, cargo_type, precedent)
#   Kd_target      : target-warhead binary dissociation constant (nM).
#   tag_competence : S-guanylation-tag -> K63-Ub/p62/LC3 engagement, in [0,1].
#   k_seq          : cargo sequestration into a forming autophagosome (per min).
#   k_fusion       : autophagosome -> autolysosome fusion rate (per min).
#   k_stall        : autophagosome stall / no-fusion rate (per min).
# Values are illustrative literature-informed surrogates, not fits to a
# specific compound (see module honesty note).
AUTAC_PANEL = [
    ("AUTAC_MetAP2_like", 25.0, 0.70, 0.30, 0.45, 0.10, "cytosolic-protein",
     "Arimoto-lab AUTAC4/MetAP2 class (Takahashi et al. 2019, research)"),
    ("AUTAC_FKBP12_like", 18.0, 0.65, 0.28, 0.40, 0.12, "cytosolic-protein",
     "Arimoto-lab FKBP12-targeting AUTAC class (research-stage)"),
    ("mito_AUTAC_like", 30.0, 0.60, 0.35, 0.50, 0.15, "fragmented-mitochondria",
     "mito-AUTAC mitophagy class (Takahashi et al. 2019, research)"),
    ("stall_dominant_AUTAC_like", 22.0, 0.55, 0.30, 0.08, 0.40, "cytosolic-protein",
     "flux-stalled reference — poor autophagosome-lysosome fusion"),
    ("flux_competent_AUTAC_like", 16.0, 0.80, 0.40, 0.60, 0.05, "cytosolic-protein",
     "flux-competent reference — efficient autophagic-flux completion"),
    ("low_tag_AUTAC_like", 55.0, 0.25, 0.12, 0.35, 0.20, "aggregate-prone-protein",
     "low-tag reference — weak S-guanylation-tag LC3 recruitment"),
]


def fraction_bound(conc_nm: float, kd_nm: float) -> float:
    """Mass-action fractional occupancy θ = [L]/(K_d + [L]); θ = 1/2 at [L]=K_d."""
    return conc_nm / (kd_nm + conc_nm)


def autophagy_profile(kd_target_nm: float, tag_competence: float,
                      k_seq: float, k_fusion: float, k_stall: float) -> dict:
    """One AUTAC's tag-recruitment + autophagic-flux-partition profile."""
    # target tagging: mass-action occupancy at the operating point.
    theta_target = fraction_bound(AUTAC_CONC_NM, kd_target_nm)
    # autophagy-tag -> LC3 recruitment competence.
    lc3_recruitment = theta_target * tag_competence
    # autophagic-flux completion partition: fused vs stalled.
    flux_partition = k_fusion / (k_fusion + k_stall)
    stalled_partition = k_stall / (k_fusion + k_stall)
    # steady-state autophagic degradation flux (per min, per unit target pool).
    degradation_flux = lc3_recruitment * k_seq * flux_partition
    return {
        "kd_target_nM": kd_target_nm,
        "tag_competence": tag_competence,
        "k_seq_per_min": k_seq,
        "k_fusion_per_min": k_fusion,
        "k_stall_per_min": k_stall,
        "theta_target": theta_target,
        "lc3_recruitment": lc3_recruitment,
        "flux_partition": flux_partition,
        "stalled_partition": stalled_partition,
        "flux_class": (
            "flux-competent" if flux_partition > 0.5 else
            "balanced" if flux_partition == 0.5 else "flux-stalled"),
        "degradation_flux_per_min": degradation_flux,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per AUTAC in the panel."""
    rows = []
    for (name, kd_t, tag, k_seq, k_fus, k_stall, cargo,
         precedent) in AUTAC_PANEL:
        prof = autophagy_profile(kd_t, tag, k_seq, k_fus, k_stall)
        row = {
            "schema": SCHEMA_ID,
            "autac": name,
            "cargo_type": cargo,
            "drug_precedent": precedent,
            "autac_conc_nM": AUTAC_CONC_NM,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Flux-competent vs flux-stalled autophagic-flux-partition contrast."""
    by_name = {r["autac"]: r for r in rows}
    comp = by_name["flux_competent_AUTAC_like"]
    stall = by_name["stall_dominant_AUTAC_like"]
    return {
        "flux_competent_reference": {
            "autac": comp["autac"],
            "flux_partition": comp["flux_partition"],
            "degradation_flux_per_min": comp["degradation_flux_per_min"],
        },
        "flux_stalled_reference": {
            "autac": stall["autac"],
            "flux_partition": stall["flux_partition"],
            "degradation_flux_per_min": stall["degradation_flux_per_min"],
        },
        "flux_partition_ratio": (
            comp["flux_partition"] / stall["flux_partition"]),
        "note": ("autophagic flux is a turnover RATE, not a static "
                 "autophagosome count: a flux-stalled AUTAC accumulates "
                 "LC3-tagged autophagosomes that never fuse with the lysosome, "
                 "so it degrades little despite high LC3 recruitment."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C6)."""
    comp = [r for r in rows if r["flux_class"] == "flux-competent"]
    stall = [r for r in rows if r["flux_class"] == "flux-stalled"]
    half_ok = True
    for r in rows:
        # mass-action identity: θ = 1/2 exactly at [L] = K_d(target).
        theta_at_kd = fraction_bound(r["kd_target_nM"], r["kd_target_nM"])
        if abs(theta_at_kd - 0.5) > 1e-12:
            half_ok = False
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_partitions_bounded_and_sum_to_one": all(
            0.0 <= r["flux_partition"] <= 1.0
            and 0.0 <= r["stalled_partition"] <= 1.0
            and abs(r["flux_partition"] + r["stalled_partition"] - 1.0) <= 1e-12
            for r in rows),
        "C3_mass_action_half_at_kd": half_ok,
        "C4_recruitment_bounded": all(
            0.0 <= r["theta_target"] <= 1.0
            and 0.0 <= r["lc3_recruitment"] <= 1.0
            for r in rows),
        "C5_both_flux_classes_present": len(comp) >= 1 and len(stall) >= 1,
        "C6_flux_competent_higher_flux": all(
            c["degradation_flux_per_min"] > s["degradation_flux_per_min"]
            for c in [r for r in rows if r["autac"] == "flux_competent_AUTAC_like"]
            for s in [r for r in rows if r["autac"] == "stall_dominant_AUTAC_like"]),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("autac_sim — AUTAC sub-axis :> BIFUNCTIONAL (expansion-main)\n",
          flush=True)
    print("model:  target + AUTAC -> S-guanylation tag -> K63-Ub/p62/LC3 "
          "recruitment -> autophagosome -> autophagic-flux partition\n",
          flush=True)
    print("  real-limit anchor : autophagic flux — autophagosome formation vs")
    print("                      autophagosome-lysosome fusion (Mizushima &")
    print("                      Yoshimori, Autophagy 3:542, 2007; Klionsky et al.)")
    print("  flux partition = k_fusion / (k_fusion + k_stall)\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['autac']:<28}] {r['flux_class']:<15} "
              f"cargo={r['cargo_type']}")
        print(f"      Kd_target={r['kd_target_nM']:.1f}nM  "
              f"tag_competence={r['tag_competence']:.2f}  "
              f"lc3_recruitment={r['lc3_recruitment']:.4f}")
        print(f"      flux_partition={r['flux_partition']:.4f}  "
              f"k_seq={r['k_seq_per_min']:.2f}/min  "
              f"degradation_flux={r['degradation_flux_per_min']:.5f}/min")

    ctr = contrast(rows)
    print("\n## flux-competent vs flux-stalled autophagic-flux contrast")
    cr, sr = ctr["flux_competent_reference"], ctr["flux_stalled_reference"]
    print(f"  FLUX-COMPETENT  {cr['autac']:<28} "
          f"flux_partition={cr['flux_partition']:.4f}  "
          f"flux={cr['degradation_flux_per_min']:.5f}/min")
    print(f"  FLUX-STALLED    {sr['autac']:<28} "
          f"flux_partition={sr['flux_partition']:.4f}  "
          f"flux={sr['degradation_flux_per_min']:.5f}/min")
    print(f"  flux-partition ratio = {ctr['flux_partition_ratio']:.3f}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: {acc['verdict']} ---")

    print("\n## C3 honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — mass-action target tagging, LC3-recruitment")
    print("  competence and the autophagic-flux partition computed self-consistently.")
    print("  NOT a binding-affinity, degradation-potency or therapeutic-efficacy")
    print("  claim. AUTAC is a RESEARCH-STAGE modality — there is no approved AUTAC")
    print("  drug; nothing here is a clinical/regulatory claim. K_d / rate / tag")
    print("  values are literature-informed surrogates. AUTAC is a SUB-AXIS")
    print("  (:> BIFUNCTIONAL expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "AUTAC",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("autophagic flux — autophagosome formation vs "
                              "autophagosome-lysosome fusion + law of mass "
                              "action (Mizushima & Yoshimori, Autophagy "
                              "3:542, 2007)"),
        "modality_stage": "research-stage — no approved AUTAC drug (g8/f2)",
        "autac_conc_nM": AUTAC_CONC_NM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — research-stage modality, not a "
                                   "binding-affinity, degradation-potency or "
                                   "clinical claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__AUTAC__ PASS" if ok else "\n__AUTAC__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
