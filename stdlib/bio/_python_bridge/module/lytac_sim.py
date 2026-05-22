#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
lytac_sim.py — LYTAC sub-axis :> BIFUNCTIONAL (expansion-main).

Deterministic, stdlib-only real-limits model of the LYTAC (LYsosome-TArgeting
Chimera) receptor-mediated uptake and intracellular trafficking PARTITION that
gates lysosomal degradation of extracellular and membrane targets. This is the
in-silico simulator-consistency layer for the LYTAC sub-axis registered in
AXIS/HIERARCHY.tape @D sub_under_bifunctional — see the sibling note
`lytac_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A LYTAC is a bifunctional conjugate: one end binds an extracellular or
membrane-bound target protein, the other end is a glycan ligand for a
lysosome-shuttling cell-surface receptor — the cation-independent
mannose-6-phosphate receptor (CI-M6PR, ubiquitous) or the asialoglycoprotein
receptor (ASGPR, hepatocyte-restricted). The receptor binds the LYTAC·target
ternary species, internalises it by endocytosis, and delivers the target to the
lysosome for degradation while the receptor recycles.

  Surface ternary capture (law of mass action — dissociation constants):
      target  + LYTAC   ⇌  target·LYTAC          K_d(target)
      receptor + target·LYTAC ⇌ receptor·target·LYTAC   K_d(receptor)

  Receptor-mediated endocytosis (first-order trafficking kinetics):
      bound complex  --k_int-->  endosome  --k_sort-->  lysosome (degraded)
                                            \--k_recycle--> surface (escapes)
  The endosomal SORTING PARTITION decides the fate of an internalised complex:
      lysosomal_partition = k_sort / (k_sort + k_recycle)
  Only the lysosomally sorted fraction is degraded; the recycled fraction
  returns the still-intact target to the cell surface.

  Steady-state degradation flux (uptake gated by surface ternary occupancy,
  then by the trafficking partition):
      degradation_flux = receptor_ternary_occupancy
                         · k_int
                         · lysosomal_partition
  Receptor recycling means k_int is a per-receptor turnover rate; the surface
  receptor pool is treated as not rate-limiting (fast recycling), so flux is
  governed by surface ternary occupancy × internalisation × sorting partition.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Receptor-mediated endocytosis trafficking kinetics, layered on the law of mass
action. Surface ternary capture is a closed-form mass-action equilibrium
(θ = [L]/(K_d+[L]), θ = 1/2 at [L] = K_d); the endosomal sort-vs-recycle
partition and the internalisation rate are the established first-order
compartmental description of receptor trafficking:
  - Banghart, M. & Lakadamyali, M. (review of receptor-mediated endocytosis
    sorting kinetics); the canonical compartmental treatment is Wiley & Cunningham,
    "A steady state model for analyzing the cellular binding, internalization
    and degradation of polypeptide ligands", Cell 25:433 (1981).
  - Lauffenburger & Linderman, "Receptors: Models for Binding, Trafficking, and
    Signaling", Oxford Univ. Press (1993) — the sort/recycle/degrade partition.
  - Ghosh, Dahms & Kornfeld, "Mannose 6-phosphate receptors: new twists in the
    tale", Nat. Rev. Mol. Cell Biol. 4:202 (2003) — CI-M6PR lysosomal targeting.
The trafficking partition is bounded in [0,1] and the mass-action half-occupancy
identity must hold exactly — the hard real limits that anchor every row.

Modality precedent (described ONLY by its own precedent — g3/f1, never
lattice-derived):
  - Banik, Pedram, Wisnovsky, Ahn, Riley & Bertozzi, "Lysosome-targeting
    chimaeras for degradation of extracellular proteins", Nature 584:291 (2020)
    — the founding LYTAC work (Bertozzi lab, Stanford). RESEARCH-STAGE: LYTAC is
    a research-stage modality with no approved drug; the 2020 work and follow-ups
    (e.g. ASGPR-directed GalNAc-LYTACs, Ahn et al., Nat. Chem. Biol. 17:937,
    2021) are pre-clinical / discovery-stage.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the mass-action surface capture, the trafficking sort/recycle
partition and the degradation-flux product are computed self-consistently and
reproduce byte-identically. It is NOT a binding-affinity measurement, NOT a
degradation-potency claim, NOT a therapeutic-efficacy claim. LYTAC is a
RESEARCH-STAGE modality — there is no approved LYTAC drug; nothing here is a
clinical or regulatory claim. K_d / rate-constant values are illustrative
literature-informed surrogates, not fits to a specific compound. Pure stdlib,
no network/time/random → byte-identical re-runs.

LYTAC is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it is NOT one
of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape @D sub_under_bifunctional.
"""
from __future__ import annotations
import json
import sys

SCHEMA_ID = "lytac_v1"

# ── fixed deterministic operating concentration (nM) of target + LYTAC ──
# a single physiologically plausible operating point; occupancy identities
# (half-saturation at K_d) are checked independently of this point.
TARGET_CONC_NM = 50.0
LYTAC_CONC_NM = 100.0

# ── deterministic LYTAC degrader panel ──────────────────────────────────────
# (name, Kd_target_nM, Kd_receptor_nM, k_int_per_min, k_sort_per_min,
#  k_recycle_per_min, receptor, precedent)
#   Kd_target    : target-protein binary dissociation constant (nM).
#   Kd_receptor  : LYTAC glycan ↔ shuttling-receptor dissociation constant (nM).
#   k_int        : receptor-mediated internalisation rate (per min).
#   k_sort       : endosome -> lysosome sorting rate (per min).
#   k_recycle    : endosome -> surface recycling rate (per min).
# Values are illustrative literature-informed surrogates, not fits to a
# specific compound (see module honesty note).
LYTAC_PANEL = [
    ("CI_M6PR_LYTAC_apoE_like", 20.0, 30.0, 0.30, 0.40, 0.10, "CI-M6PR",
     "Bertozzi-lab M6Pn-glycopeptide LYTAC class (Banik et al. 2020, research)"),
    ("CI_M6PR_LYTAC_EGFR_like", 15.0, 25.0, 0.25, 0.35, 0.15, "CI-M6PR",
     "CI-M6PR-directed membrane-target LYTAC class (research-stage)"),
    ("ASGPR_GalNAc_LYTAC_like", 18.0, 12.0, 0.45, 0.50, 0.12, "ASGPR",
     "ASGPR/GalNAc hepatocyte LYTAC class (Ahn et al. 2021, research)"),
    ("recycle_dominant_LYTAC_like", 22.0, 28.0, 0.30, 0.08, 0.40, "CI-M6PR",
     "recycle-dominant reference — poor lysosomal sorting partition"),
    ("sort_dominant_LYTAC_like", 16.0, 20.0, 0.40, 0.60, 0.05, "CI-M6PR",
     "sort-dominant reference — efficient lysosomal delivery"),
    ("low_uptake_LYTAC_like", 60.0, 90.0, 0.10, 0.30, 0.20, "ASGPR",
     "low-uptake reference — weak receptor affinity, low internalisation"),
]


def fraction_bound(conc_nm: float, kd_nm: float) -> float:
    """Mass-action fractional occupancy θ = [L]/(K_d + [L]); θ = 1/2 at [L]=K_d."""
    return conc_nm / (kd_nm + conc_nm)


def trafficking_profile(kd_target_nm: float, kd_receptor_nm: float,
                        k_int: float, k_sort: float, k_recycle: float) -> dict:
    """One LYTAC's receptor-mediated uptake + trafficking-partition profile."""
    # surface ternary capture: target bound by LYTAC, then receptor binds the
    # target·LYTAC species — both mass-action equilibria at the operating point.
    theta_target = fraction_bound(LYTAC_CONC_NM, kd_target_nm)
    theta_receptor = fraction_bound(TARGET_CONC_NM, kd_receptor_nm)
    receptor_ternary_occupancy = theta_target * theta_receptor
    # endosomal sort-vs-recycle partition: lysosomal fraction of internalised.
    lysosomal_partition = k_sort / (k_sort + k_recycle)
    recycled_partition = k_recycle / (k_sort + k_recycle)
    # steady-state degradation flux (per min, per unit target pool).
    degradation_flux = receptor_ternary_occupancy * k_int * lysosomal_partition
    return {
        "kd_target_nM": kd_target_nm,
        "kd_receptor_nM": kd_receptor_nm,
        "k_int_per_min": k_int,
        "k_sort_per_min": k_sort,
        "k_recycle_per_min": k_recycle,
        "theta_target": theta_target,
        "theta_receptor": theta_receptor,
        "receptor_ternary_occupancy": receptor_ternary_occupancy,
        "lysosomal_partition": lysosomal_partition,
        "recycled_partition": recycled_partition,
        "trafficking_class": (
            "lysosome-dominant" if lysosomal_partition > 0.5 else
            "balanced" if lysosomal_partition == 0.5 else "recycle-dominant"),
        "degradation_flux_per_min": degradation_flux,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per LYTAC in the panel."""
    rows = []
    for (name, kd_t, kd_r, k_int, k_sort, k_rec, receptor,
         precedent) in LYTAC_PANEL:
        prof = trafficking_profile(kd_t, kd_r, k_int, k_sort, k_rec)
        row = {
            "schema": SCHEMA_ID,
            "lytac": name,
            "shuttling_receptor": receptor,
            "drug_precedent": precedent,
            "target_conc_nM": TARGET_CONC_NM,
            "lytac_conc_nM": LYTAC_CONC_NM,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Sort-dominant vs recycle-dominant trafficking-partition contrast."""
    by_name = {r["lytac"]: r for r in rows}
    sort = by_name["sort_dominant_LYTAC_like"]
    rec = by_name["recycle_dominant_LYTAC_like"]
    return {
        "sort_dominant_reference": {
            "lytac": sort["lytac"],
            "lysosomal_partition": sort["lysosomal_partition"],
            "degradation_flux_per_min": sort["degradation_flux_per_min"],
        },
        "recycle_dominant_reference": {
            "lytac": rec["lytac"],
            "lysosomal_partition": rec["lysosomal_partition"],
            "degradation_flux_per_min": rec["degradation_flux_per_min"],
        },
        "lysosomal_partition_ratio": (
            sort["lysosomal_partition"] / rec["lysosomal_partition"]),
        "note": ("the endosomal sort/recycle partition gates LYTAC efficacy: a "
                 "sort-dominant LYTAC delivers most internalised target to the "
                 "lysosome, a recycle-dominant LYTAC returns intact target to "
                 "the cell surface and degrades little."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C6)."""
    lyso = [r for r in rows if r["trafficking_class"] == "lysosome-dominant"]
    recyc = [r for r in rows if r["trafficking_class"] == "recycle-dominant"]
    half_ok = True
    for r in rows:
        # mass-action identity: θ = 1/2 exactly at [L] = K_d(receptor).
        theta_at_kd = fraction_bound(r["kd_receptor_nM"], r["kd_receptor_nM"])
        if abs(theta_at_kd - 0.5) > 1e-12:
            half_ok = False
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_partitions_bounded_and_sum_to_one": all(
            0.0 <= r["lysosomal_partition"] <= 1.0
            and 0.0 <= r["recycled_partition"] <= 1.0
            and abs(r["lysosomal_partition"] + r["recycled_partition"] - 1.0) <= 1e-12
            for r in rows),
        "C3_mass_action_half_at_kd": half_ok,
        "C4_occupancies_bounded": all(
            0.0 <= r["theta_target"] <= 1.0
            and 0.0 <= r["theta_receptor"] <= 1.0
            and 0.0 <= r["receptor_ternary_occupancy"] <= 1.0
            for r in rows),
        "C5_both_trafficking_classes_present": len(lyso) >= 1 and len(recyc) >= 1,
        "C6_sort_dominant_higher_flux": all(
            l["degradation_flux_per_min"] > rc["degradation_flux_per_min"]
            for l in [r for r in rows if r["lytac"] == "sort_dominant_LYTAC_like"]
            for rc in [r for r in rows if r["lytac"] == "recycle_dominant_LYTAC_like"]),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("lytac_sim — LYTAC sub-axis :> BIFUNCTIONAL (expansion-main)\n",
          flush=True)
    print("model:  target + LYTAC + shuttling-receptor -> endocytosis -> "
          "endosomal sort/recycle partition -> lysosome\n", flush=True)
    print("  real-limit anchor : receptor-mediated endocytosis trafficking")
    print("                      kinetics (Wiley & Cunningham, Cell 25:433, 1981)")
    print("  lysosomal partition = k_sort / (k_sort + k_recycle)\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['lytac']:<30}] {r['trafficking_class']:<17} "
              f"receptor={r['shuttling_receptor']}")
        print(f"      Kd_target={r['kd_target_nM']:.1f}nM  "
              f"Kd_receptor={r['kd_receptor_nM']:.1f}nM  "
              f"ternary_occ={r['receptor_ternary_occupancy']:.4f}")
        print(f"      lysosomal_partition={r['lysosomal_partition']:.4f}  "
              f"k_int={r['k_int_per_min']:.2f}/min  "
              f"degradation_flux={r['degradation_flux_per_min']:.5f}/min")

    ctr = contrast(rows)
    print("\n## sort-dominant vs recycle-dominant trafficking contrast")
    sr, rr = ctr["sort_dominant_reference"], ctr["recycle_dominant_reference"]
    print(f"  SORT-DOMINANT    {sr['lytac']:<30} "
          f"lyso_partition={sr['lysosomal_partition']:.4f}  "
          f"flux={sr['degradation_flux_per_min']:.5f}/min")
    print(f"  RECYCLE-DOMINANT {rr['lytac']:<30} "
          f"lyso_partition={rr['lysosomal_partition']:.4f}  "
          f"flux={rr['degradation_flux_per_min']:.5f}/min")
    print(f"  lysosomal-partition ratio = {ctr['lysosomal_partition_ratio']:.3f}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: {acc['verdict']} ---")

    print("\n## C3 honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — mass-action surface capture and the")
    print("  endosomal sort/recycle trafficking partition computed self-consistently.")
    print("  NOT a binding-affinity, degradation-potency or therapeutic-efficacy")
    print("  claim. LYTAC is a RESEARCH-STAGE modality — there is no approved LYTAC")
    print("  drug; nothing here is a clinical/regulatory claim. K_d / rate values")
    print("  are literature-informed surrogates. LYTAC is a SUB-AXIS")
    print("  (:> BIFUNCTIONAL expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "LYTAC",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("receptor-mediated endocytosis trafficking "
                              "kinetics + law of mass action (Wiley & "
                              "Cunningham, Cell 25:433, 1981)"),
        "modality_stage": "research-stage — no approved LYTAC drug (g8/f2)",
        "target_conc_nM": TARGET_CONC_NM,
        "lytac_conc_nM": LYTAC_CONC_NM,
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
    print("\n__LYTAC__ PASS" if ok else "\n__LYTAC__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
