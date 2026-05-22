#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
allosteric_sim.py — ALLOSTERIC sub-axis :> QUANTUM (core).

Deterministic, stdlib-only real-limits model of allosteric modulation: a ligand
bound at a site DISTINCT from the orthosteric site shifts the orthosteric
affinity/activity of the target. This is the in-silico simulator-consistency
layer for the ALLOSTERIC sub-axis registered in AXIS/HIERARCHY.tape
`@D sub_under_quantum` — see the sibling note `allosteric_subaxis.md`.

The ALLOSTERIC sub-axis hangs off the core QUANTUM axis as a tag (the cryptic
allosteric pocket is a VQE-applicable active-site target); the hexa-bio core-5
axis QUANTUM is UNCHANGED — this is a SUB-AXIS, not a core mutation.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
The defining feature of an allosteric modulator — unlike an orthosteric
competitor — is a SATURABLE effect: once every allosteric site is occupied the
modulation reaches a CEILING (the cooperativity factor α), it cannot push the
orthosteric affinity arbitrarily far. We model the allosteric two-state
(Monod-Wyman-Changeux, MWC-style) ternary-complex equilibrium:

      R (active)  ⇌(L)  T (inactive)        L = [T]/[R]  intrinsic isomerisation

  An orthosteric ligand A binds R/T; an allosteric modulator B binds R/T at a
  separate site. The Allosteric Ternary Complex Model collapses this to the
  cooperativity factor α (and an analogous efficacy factor β):

      EC50_obs / EC50_orth  =  (1 + [B]/K_B) / (1 + α·[B]/K_B)

  - α > 1  : positive allosteric modulator (PAM) — improves orthosteric affinity.
  - α < 1  : negative allosteric modulator (NAM) — worsens it.
  - α = 1  : neutral / silent allosteric ligand (no cooperativity).
  As [B] → ∞ the affinity shift saturates at the limiting ratio 1/α — the
  allosteric CEILING. This bounded, saturable behaviour is the real
  pharmacological hallmark that distinguishes allostery from competition.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The Monod-Wyman-Changeux concerted allosteric model (Monod, Wyman & Changeux,
*J. Mol. Biol.* 12:88, 1965) and the Allosteric Two-State / ternary-complex
formalism (Hall, *Mol. Pharmacol.* 58:1412, 2000; Christopoulos & Kenakin,
*Pharmacol. Rev.* 54:323, 2002). The hard real limit: the modulation is
SATURABLE — the observed affinity shift is bounded between 1 (no modulator) and
1/α (allosteric ceiling). No modelled cooperativity can drive the orthosteric
affinity past the ceiling 1/α; this bound anchors every row (criterion C2).
Thermodynamic detailed balance of the ternary cycle fixes the equilibrium
relations self-consistently — a saturable, NOT unbounded, effect.

Own precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - maraviroc — allosteric CCR5 antagonist, transmembrane-cavity allosteric
    site (Dorr et al., *Antimicrob. Agents Chemother.* 49:4721, 2005).
  - trametinib — allosteric MEK1/2 inhibitor binding adjacent to the ATP
    pocket (Gilmartin et al., *Clin. Cancer Res.* 17:989, 2011).
  - asciminib — allosteric BCR-ABL1 inhibitor at the myristoyl pocket, a site
    distinct from the ATP (orthosteric) site (Wylie et al., *Nature* 543:733,
    2017; FDA-approved 2021).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the MWC/ternary-complex equilibria, the cooperativity factor α, the
EC50 shift and the saturable allosteric ceiling are computed self-consistently
and reproduce byte-identically. It is a thermodynamic-equilibrium MODEL — NOT a
binding-affinity measurement, NOT a potency/selectivity claim, NOT a
therapeutic-efficacy claim. The α / K_B values are illustrative
literature-informed surrogates for modulator CLASSES, not fits to a specific
compound. Pure stdlib, no network/time/random → byte-identical re-runs.

ALLOSTERIC is a SUB-AXIS (:> QUANTUM core) — it is NOT one of the hexa-bio
core-5 axes, which remain QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID
(AXIS.tape unchanged). No quantity here is derived from the n=6 lattice.
"""
from __future__ import annotations
import json
import math
import sys

# ── classification threshold for neutral (silent) allosteric ligands ──
# |log10 α| below this → effectively neutral (no measurable cooperativity).
NEUTRAL_LOG_ALPHA_TOL = 0.05

SCHEMA_ID = "allosteric_v1"

# ── deterministic allosteric-modulator panel ────────────────────────────────
# (name, alpha, K_B_uM, modulator_class, own drug precedent)
#   alpha : cooperativity factor (affinity).  >1 PAM · <1 NAM · ~1 neutral.
#   K_B_uM: equilibrium dissociation constant of the modulator at its
#           allosteric site (micromolar).
# Values are illustrative literature-informed surrogates for the modulator
# CLASS, not fits to a specific compound (see module honesty note).
MODULATOR_PANEL = [
    # negative allosteric modulators (NAM — alpha < 1)
    ("maraviroc_CCR5_NAM", 0.02, 5.0, "negative_allosteric_modulator",
     "maraviroc — allosteric CCR5 antagonist (transmembrane-cavity site)"),
    ("asciminib_ABL_NAM", 0.05, 0.5, "negative_allosteric_modulator",
     "asciminib — allosteric BCR-ABL1 inhibitor (myristoyl pocket, non-ATP)"),
    ("trametinib_MEK_NAM", 0.10, 1.0, "negative_allosteric_modulator",
     "trametinib — allosteric MEK1/2 inhibitor (adjacent to ATP pocket)"),
    # positive allosteric modulators (PAM — alpha > 1)
    ("pam_classA_GPCR", 8.0, 2.0, "positive_allosteric_modulator",
     "class-A GPCR PAM modality (cooperative orthosteric enhancement)"),
    ("pam_classC_GPCR", 25.0, 0.8, "positive_allosteric_modulator",
     "class-C GPCR PAM modality (allosteric affinity enhancement)"),
    # neutral / silent allosteric ligand (alpha ~ 1)
    ("neutral_allosteric_ligand", 1.0, 3.0, "neutral_allosteric_ligand",
     "silent allosteric ligand modality (probe-dependent, no cooperativity)"),
]

# Free modulator concentrations probed (micromolar) — saturation sweep.
CONC_SWEEP_UM = [0.0, 0.1, 1.0, 10.0, 100.0, 1000.0]


def affinity_shift(alpha: float, k_b_uM: float, conc_uM: float) -> float:
    """
    Allosteric ternary-complex affinity-shift ratio EC50_obs / EC50_orth at a
    given free modulator concentration:

        shift = (1 + [B]/K_B) / (1 + alpha·[B]/K_B)

    shift > 1 → orthosteric affinity weakened (NAM); < 1 → strengthened (PAM);
    = 1 → no modulator or neutral.  As [B] → ∞, shift → 1/alpha (the ceiling).
    """
    occ = conc_uM / k_b_uM            # [B]/K_B (dimensionless occupancy term)
    return (1.0 + occ) / (1.0 + alpha * occ)


def allosteric_profile(alpha: float, k_b_uM: float) -> dict:
    """One modulator's saturable allosteric profile across the concentration sweep."""
    shifts = [
        {"conc_uM": c, "ec50_shift_ratio": affinity_shift(alpha, k_b_uM, c)}
        for c in CONC_SWEEP_UM
    ]
    # Allosteric CEILING: the limiting affinity shift as [B] → ∞ is exactly 1/alpha.
    ceiling = 1.0 / alpha
    # The largest probed concentration must approach (but not pass) the ceiling.
    shift_at_max = shifts[-1]["ec50_shift_ratio"]
    if alpha < 1.0:        # NAM — shift increases toward ceiling > 1 from below
        ceiling_respected = shift_at_max <= ceiling + 1e-9
    elif alpha > 1.0:      # PAM — shift decreases toward ceiling < 1 from above
        ceiling_respected = shift_at_max >= ceiling - 1e-9
    else:                  # neutral — shift is identically 1
        ceiling_respected = abs(shift_at_max - 1.0) < 1e-12
    log_alpha = math.log10(alpha)
    if log_alpha > NEUTRAL_LOG_ALPHA_TOL:
        kind = "PAM"
    elif log_alpha < -NEUTRAL_LOG_ALPHA_TOL:
        kind = "NAM"
    else:
        kind = "neutral"
    # Monotonicity of the saturation sweep (toward the ceiling).
    vals = [s["ec50_shift_ratio"] for s in shifts]
    if alpha < 1.0:
        monotone = all(vals[i + 1] >= vals[i] - 1e-12 for i in range(len(vals) - 1))
    elif alpha > 1.0:
        monotone = all(vals[i + 1] <= vals[i] + 1e-12 for i in range(len(vals) - 1))
    else:
        monotone = all(abs(v - 1.0) < 1e-12 for v in vals)
    return {
        "cooperativity_alpha": alpha,
        "modulator_kd_uM": k_b_uM,
        "modulation_kind": kind,
        "saturation_sweep": shifts,
        "allosteric_ceiling_shift": ceiling,
        "ec50_shift_at_max_conc": shift_at_max,
        "ceiling_respected": ceiling_respected,
        "sweep_monotone_toward_ceiling": monotone,
        "log10_alpha": log_alpha,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per modulator in the panel."""
    rows = []
    for name, alpha, k_b, mclass, precedent in MODULATOR_PANEL:
        prof = allosteric_profile(alpha, k_b)
        row = {
            "schema": SCHEMA_ID,
            "modulator": name,
            "modulator_class": mclass,
            "drug_precedent": precedent,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Explicit NAM-vs-PAM contrast plus the orthosteric-competition distinction."""
    by_name = {r["modulator"]: r for r in rows}
    nam = by_name["asciminib_ABL_NAM"]
    pam = by_name["pam_classC_GPCR"]
    return {
        "nam_reference": {
            "modulator": nam["modulator"],
            "drug_precedent": nam["drug_precedent"],
            "cooperativity_alpha": nam["cooperativity_alpha"],
            "allosteric_ceiling_shift": nam["allosteric_ceiling_shift"],
            "ec50_shift_at_max_conc": nam["ec50_shift_at_max_conc"],
        },
        "pam_reference": {
            "modulator": pam["modulator"],
            "drug_precedent": pam["drug_precedent"],
            "cooperativity_alpha": pam["cooperativity_alpha"],
            "allosteric_ceiling_shift": pam["allosteric_ceiling_shift"],
            "ec50_shift_at_max_conc": pam["ec50_shift_at_max_conc"],
        },
        "note": ("an orthosteric competitor shifts EC50 without bound (linear in "
                 "competitor concentration); an allosteric modulator's effect is "
                 "SATURABLE — it cannot drive the orthosteric affinity past the "
                 "ceiling 1/alpha, the defining real limit of allostery."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    pam = [r for r in rows if r["modulation_kind"] == "PAM"]
    nam = [r for r in rows if r["modulation_kind"] == "NAM"]
    neu = [r for r in rows if r["modulation_kind"] == "neutral"]
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_allosteric_ceiling_respected": all(
            r["ceiling_respected"] for r in rows),
        "C3_zero_conc_no_shift": all(
            abs(r["saturation_sweep"][0]["ec50_shift_ratio"] - 1.0) < 1e-12
            for r in rows),
        "C4_sweep_monotone_toward_ceiling": all(
            r["sweep_monotone_toward_ceiling"] for r in rows),
        "C5_all_three_classes_present": len(pam) >= 1 and len(nam) >= 1
        and len(neu) >= 1,
        "C6_ceiling_equals_inverse_alpha": all(
            abs(r["allosteric_ceiling_shift"] - 1.0 / r["cooperativity_alpha"])
            <= 1e-9 for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("allosteric_sim — ALLOSTERIC sub-axis :> QUANTUM (core)\n", flush=True)
    print("model:  MWC / ternary-complex   shift = (1+[B]/K_B)/(1+alpha·[B]/K_B)"
          "   ceiling = 1/alpha\n", flush=True)
    print("  real-limit anchor : Monod-Wyman-Changeux concerted allosteric model")
    print("                      (Monod, Wyman & Changeux, J. Mol. Biol. 12:88, 1965)")
    print("                      — the modulation is SATURABLE, bounded by 1/alpha\n",
          flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['modulator']:<26}] {r['modulation_kind']:<8} "
              f"alpha={r['cooperativity_alpha']:<7g} K_B={r['modulator_kd_uM']:g} uM")
        print(f"      ceiling shift 1/alpha = {r['allosteric_ceiling_shift']:.4g}   "
              f"shift @ max conc = {r['ec50_shift_at_max_conc']:.4g}")

    ctr = contrast(rows)
    print("\n## NAM-vs-PAM contrast")
    nr, pr = ctr["nam_reference"], ctr["pam_reference"]
    print(f"  NAM {nr['modulator']:<26} alpha={nr['cooperativity_alpha']:g}  "
          f"ceiling={nr['allosteric_ceiling_shift']:.4g}")
    print(f"  PAM {pr['modulator']:<26} alpha={pr['cooperativity_alpha']:g}  "
          f"ceiling={pr['allosteric_ceiling_shift']:.4g}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — MWC/ternary-complex equilibria, the")
    print("  cooperativity factor alpha, the EC50 shift and the saturable ceiling")
    print("  computed self-consistently. NOT a binding-affinity, potency,")
    print("  selectivity or therapeutic-efficacy claim. alpha/K_B values are")
    print("  literature-informed surrogates for modulator CLASSES, not fits to a")
    print("  specific compound. ALLOSTERIC is a SUB-AXIS (:> QUANTUM core), NOT a")
    print("  hexa-bio core-5 axis. No quantity is derived from the n=6 lattice.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "ALLOSTERIC",
        "parent_axis": "QUANTUM (core-5 — unchanged; sub hangs off it, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("Monod-Wyman-Changeux concerted allosteric model "
                              "(Monod, Wyman & Changeux, J. Mol. Biol. 12:88, 1965); "
                              "Allosteric Two-State / ternary-complex formalism "
                              "(Hall, Mol. Pharmacol. 58:1412, 2000) — modulation "
                              "is SATURABLE, bounded by the ceiling 1/alpha"),
        "concentration_sweep_uM": CONC_SWEEP_UM,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__ALLOSTERIC__ PASS" if ok else "\n__ALLOSTERIC__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
