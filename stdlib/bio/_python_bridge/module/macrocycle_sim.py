#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
macrocycle_sim.py — MACROCYCLE sub-axis :> WEAVE (core).

Deterministic, stdlib-only real-limits model of the macrocyclization entropic
effect: how closing a flexible acyclic chain into a ring PRE-ORGANIZES the
bound conformer, reducing the entropic penalty paid on binding — and the
"beyond rule of 5" property space that macrocyclic drugs occupy. This is the
in-silico simulator-consistency layer for the MACROCYCLE sub-axis registered in
AXIS/HIERARCHY.tape `@D sub_under_weave` — see the sibling note
`macrocycle_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A ligand binding its target must adopt one specific bound conformer. A
FLEXIBLE acyclic ligand samples many conformers free in solution; on binding
it is frozen into one, paying a CONFORMATIONAL ENTROPY penalty −T·ΔS_conf. A
MACROCYCLE — the same pharmacophore with a ring-closing bridge — has far fewer
accessible conformers because the ring covalently constrains the rotatable
bonds; it is *pre-organized* toward the bound state, so it pays a much smaller
entropy penalty. This is the macrocyclization pre-organization effect.

The model treats each rotatable bond as a discrete rotamer multiplicity:

      W_conf = Π over rotatable bonds of  g_b     (conformational microstates)
      S_conf = R · ln(W_conf)                    (Boltzmann conformational S)

  - g_b   : the rotamer multiplicity of bond b (e.g. 3 for an sp3-sp3 bond).
  - acyclic ligand : every rotatable bond is free            → large W_conf.
  - macrocycle     : the ring CONSTRAINS the bonds inside it — their effective
                     multiplicity collapses toward 1 (the ring permits only a
                     narrow band of correlated torsions). A constraint factor
                     f_ring ∈ (0,1] multiplies the in-ring bond multiplicities.
  - the binding conformational-entropy penalty for a ligand is
      −T·ΔS_bind = +T·S_conf(free)            (all conformational S lost on
                                               freezing into the bound state).
  - pre-organization gain ΔΔG_preorg = −T·[S_conf(acyclic) − S_conf(macrocycle)]
      — a NEGATIVE (favourable) free-energy difference: the macrocycle gives
      back the entropy the acyclic analog would have had to pay.

The "beyond rule of 5" (bRo5) space: Lipinski's rule of 5 (MW ≤ 500,
HBD ≤ 5, HBA ≤ 10, cLogP ≤ 5) bounds typical oral small molecules.
Macrocyclic drugs systematically EXCEED these bounds (cyclosporine MW ≈ 1203)
yet remain orally relevant because the ring's pre-organization and the
shielding of polar groups (chameleonic conformations) recover permeability.
The model carries a simple bRo5 classifier — an honest metadata flag, not a
permeability prediction.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The macrocyclization PRE-ORGANIZATION ENTROPY effect — the conformational
free-energy penalty of freezing a flexible ligand on binding, and its
reduction by ring constraint. Real-limit references:
  - Boltzmann's relation S = R·ln W (conformational entropy as the log of the
    accessible microstate count) — the statistical-mechanics foundation that
    bounds every entropy here: S_conf ≥ 0, and S_conf = 0 iff W_conf = 1
    (a fully rigid, single-conformer ligand pays no conformational penalty).
  - the conformational-restriction / pre-organization principle in
    medicinal chemistry: macrocyclization reduces the entropic cost of binding
    by limiting accessible conformers — Mallinson & Collins, *Future Med.
    Chem.* 4:1409 (2012); Driggers, Hale, Lee & Terrett, *Nat. Rev. Drug
    Discov.* 7:608 (2008); Villar et al., *Nat. Chem. Biol.* 10:723 (2014).
  - the "beyond rule of 5" property space for macrocycles — Doak, Over,
    Giordanetto & Kihlberg, *Chem. Biol.* 21:1115 (2014); the parent
    rule of 5 — Lipinski et al., *Adv. Drug Deliv. Rev.* 23:3 (1997).
A hard ceiling: the macrocycle's W_conf can never EXCEED its acyclic analog's
(a ring constraint can only REMOVE conformers) — so ΔΔG_preorg ≤ 0 always.
The simulator gates on this (acceptance C3).

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - cyclosporine — a cyclic undecapeptide immunosuppressant (MW ≈ 1203,
    bRo5); the canonical macrocyclic drug. The macrolide class (erythromycin,
    azithromycin, rapamycin/sirolimus, tacrolimus) is the broader natural-
    product macrocycle precedent.
  - lorlatinib — a synthetic MACROCYCLIC ALK/ROS1 tyrosine-kinase inhibitor
    (FDA 2018); the ring was designed to pre-organize the pharmacophore and
    improve CNS penetration. The canonical *synthetic* macrocyclic-drug
    precedent.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the conformational microstate counts W_conf, the Boltzmann
entropies S_conf = R·ln W, the pre-organization free-energy gain ΔΔG_preorg,
and the bRo5 classification are computed self-consistently and reproduce
byte-identically. It is a statistical-mechanics MODEL — NOT a binding-affinity
measurement, NOT a potency, permeability, or therapeutic-efficacy claim. The
rotamer multiplicities and ring-constraint factors are illustrative
literature-informed surrogates for ligand CLASSES, not fits to a specific
compound. Pure stdlib, no network/time/random → byte-identical re-runs.

MACROCYCLE is a SUB-AXIS (:> WEAVE core) — it is NOT one of the hexa-bio
core-5 axes. See AXIS/AXIS.tape (core-5 unchanged) and AXIS/HIERARCHY.tape.
"""
from __future__ import annotations
import json
import math
import sys

# ── physical constants (CODATA 2019) ──
K_B = 1.380649e-23          # J/K
N_A = 6.02214076e23         # 1/mol
R_GAS = K_B * N_A           # J/(mol·K) = 8.314462618…
KCAL_TO_J = 4184.0          # 1 kcal = 4184 J (thermochemical)
TEMP_K = 310.0              # K (physiological)

SCHEMA_ID = "macrocycle_v1"

# ── per-bond rotamer multiplicity for a free (unconstrained) rotatable bond ──
# An sp3-sp3 single bond has ~3 staggered rotamers; this is the textbook
# discrete-rotamer count. Illustrative magnitude, not a fit.
ROTAMER_MULTIPLICITY_FREE = 3.0

# ── ring-constraint factor f_ring ∈ (0,1] ──────────────────────────────────
# Closing a macrocyclic ring correlates the torsions of the in-ring bonds: the
# ring permits only a narrow band of mutually compatible conformers, so each
# in-ring bond's EFFECTIVE multiplicity is f_ring * its free multiplicity.
# f_ring < 1 ⇒ the ring removes conformers (pre-organization). 0.40 is an
# illustrative magnitude for a moderately rigid macrocyclic ring.
RING_CONSTRAINT_FACTOR = 0.40

# ── Lipinski rule-of-5 bounds (Lipinski et al. 1997) — metadata classifier ──
RO5_MW_MAX = 500.0
RO5_HBD_MAX = 5
RO5_HBA_MAX = 10
RO5_CLOGP_MAX = 5.0

# ── deterministic ligand-pair panel ─────────────────────────────────────────
# Each entry pairs an ACYCLIC analog with its MACROCYCLE counterpart.
# (name, n_rotatable_total, n_bonds_in_ring, MW, HBD, HBA, cLogP,
#  modality_note, own drug precedent)
#   For the macrocycle, n_bonds_in_ring of the rotatable bonds are ring-
#   constrained; for the acyclic analog n_bonds_in_ring = 0 (all bonds free).
# Properties (MW/HBD/HBA/cLogP) are illustrative literature-informed
# magnitudes for the ligand CLASS, not fits to a specific compound.
LIGAND_PANEL = [
    ("cyclosporine_macrocycle", 33, 30, 1202.6, 5, 12, 3.0, True,
     "cyclic-undecapeptide immunosuppressant (macrocycle, bRo5)",
     "cyclosporine — cyclic undecapeptide; canonical macrocyclic drug"),
    ("cyclosporine_acyclic_analog", 33, 0, 1202.6, 5, 12, 3.0, False,
     "hypothetical ring-opened acyclic analog (all bonds free)",
     "cyclosporine — acyclic-analog contrast for pre-organization"),
    ("lorlatinib_macrocycle", 8, 5, 406.4, 1, 5, 2.3, True,
     "synthetic macrocyclic ALK/ROS1 kinase inhibitor",
     "lorlatinib — synthetic macrocyclic ALK inhibitor (FDA 2018)"),
    ("lorlatinib_acyclic_analog", 8, 0, 406.4, 1, 5, 2.3, False,
     "ring-opened acyclic analog of the lorlatinib pharmacophore",
     "lorlatinib — acyclic-analog contrast for pre-organization"),
    ("rapamycin_macrocycle", 26, 22, 914.2, 3, 13, 6.0, True,
     "macrolide natural-product macrocycle (mTOR)",
     "rapamycin / sirolimus — macrolide-class macrocyclic drug"),
    ("rapamycin_acyclic_analog", 26, 0, 914.2, 3, 13, 6.0, False,
     "ring-opened acyclic analog of the rapamycin macrolide",
     "rapamycin / sirolimus — acyclic-analog contrast"),
]


def conformational_entropy(n_rotatable: int, n_in_ring: int,
                           f_ring: float = RING_CONSTRAINT_FACTOR) -> dict:
    """
    Conformational microstate count and Boltzmann entropy of one ligand.

    W_conf = Π over rotatable bonds of g_b, where a free bond has g = 3 and an
    in-ring (ring-constrained) bond has effective g = f_ring * 3. The binding
    conformational-entropy penalty is the full S_conf lost on freezing into
    the bound conformer.
    """
    n_free = n_rotatable - n_in_ring
    g_free = ROTAMER_MULTIPLICITY_FREE
    g_ring = f_ring * ROTAMER_MULTIPLICITY_FREE
    # W_conf as a product of per-bond multiplicities (log-space for stability)
    ln_w = n_free * math.log(g_free) + n_in_ring * math.log(g_ring)
    w_conf = math.exp(ln_w)
    s_conf_j = R_GAS * ln_w                       # J/(mol·K)
    # binding conformational-entropy penalty −T·ΔS at body temperature
    minus_t_delta_s_j = TEMP_K * s_conf_j         # J/mol  (penalty, > 0)
    return {
        "n_rotatable_bonds": n_rotatable,
        "n_bonds_in_ring": n_in_ring,
        "n_bonds_free": n_free,
        "rotamer_multiplicity_free": g_free,
        "rotamer_multiplicity_in_ring": g_ring,
        "conformational_microstates_W": w_conf,
        "ln_W_conf": ln_w,
        "S_conf_cal_per_mol_K": s_conf_j / (KCAL_TO_J / 1000.0),
        "S_conf_J_per_mol_K": s_conf_j,
        "binding_entropy_penalty_kcal_per_mol": minus_t_delta_s_j / KCAL_TO_J,
    }


def rule_of_5(mw: float, hbd: int, hba: int, clogp: float) -> dict:
    """Lipinski rule-of-5 metadata classifier — honest flag, not a prediction."""
    violations = []
    if mw > RO5_MW_MAX:
        violations.append("MW>500")
    if hbd > RO5_HBD_MAX:
        violations.append("HBD>5")
    if hba > RO5_HBA_MAX:
        violations.append("HBA>10")
    if clogp > RO5_CLOGP_MAX:
        violations.append("cLogP>5")
    return {
        "ro5_violations": violations,
        "ro5_violation_count": len(violations),
        "beyond_rule_of_5": len(violations) >= 2,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per ligand in the panel."""
    rows = []
    for (name, n_rot, n_ring, mw, hbd, hba, clogp, is_macro,
         note, precedent) in LIGAND_PANEL:
        ent = conformational_entropy(n_rot, n_ring)
        ro5 = rule_of_5(mw, hbd, hba, clogp)
        row = {
            "schema": SCHEMA_ID,
            "ligand": name,
            "is_macrocycle": is_macro,
            "modality_note": note,
            "drug_precedent": precedent,
            "temperature_K": TEMP_K,
            "ring_constraint_factor": RING_CONSTRAINT_FACTOR,
            "molecular_weight": mw,
            "h_bond_donors": hbd,
            "h_bond_acceptors": hba,
            "clogp": clogp,
        }
        row.update(ent)
        row.update(ro5)
        rows.append(row)
    return rows


def preorganization(rows: list) -> list:
    """
    For each macrocycle/acyclic-analog pair, the pre-organization free-energy
    gain ΔΔG_preorg = −T·[S_conf(acyclic) − S_conf(macrocycle)] — a NEGATIVE
    (favourable) quantity: the entropy the macrocycle does NOT have to pay.
    """
    by_name = {r["ligand"]: r for r in rows}
    pairs = [
        ("cyclosporine_macrocycle", "cyclosporine_acyclic_analog"),
        ("lorlatinib_macrocycle", "lorlatinib_acyclic_analog"),
        ("rapamycin_macrocycle", "rapamycin_acyclic_analog"),
    ]
    out = []
    for macro_name, acyclic_name in pairs:
        m, a = by_name[macro_name], by_name[acyclic_name]
        # entropy penalty difference (macrocycle pays less)
        ddg_preorg = (m["binding_entropy_penalty_kcal_per_mol"]
                      - a["binding_entropy_penalty_kcal_per_mol"])
        out.append({
            "macrocycle": macro_name,
            "acyclic_analog": acyclic_name,
            "drug_precedent": m["drug_precedent"],
            "S_conf_macrocycle_cal_per_mol_K": m["S_conf_cal_per_mol_K"],
            "S_conf_acyclic_cal_per_mol_K": a["S_conf_cal_per_mol_K"],
            "binding_penalty_macrocycle_kcal_per_mol":
                m["binding_entropy_penalty_kcal_per_mol"],
            "binding_penalty_acyclic_kcal_per_mol":
                a["binding_entropy_penalty_kcal_per_mol"],
            "ddg_preorg_kcal_per_mol": ddg_preorg,
            "preorg_is_favourable": ddg_preorg <= 0.0,
            "note": ("ring closure removes accessible conformers, so the "
                     "macrocycle freezes a smaller conformational entropy on "
                     "binding than its acyclic analog — ΔΔG_preorg ≤ 0, a "
                     "favourable pre-organization free-energy difference."),
        })
    return out


def acceptance(rows: list, preorg: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1-C7)."""
    macros = [r for r in rows if r["is_macrocycle"]]
    acyclics = [r for r in rows if not r["is_macrocycle"]]
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_entropy_non_negative": all(
            r["S_conf_J_per_mol_K"] >= 0.0 for r in rows),
        "C3_preorg_favourable": all(
            p["preorg_is_favourable"] for p in preorg),
        "C4_macrocycle_fewer_microstates": all(
            p["S_conf_macrocycle_cal_per_mol_K"]
            < p["S_conf_acyclic_cal_per_mol_K"] for p in preorg),
        "C5_both_classes_present": len(macros) >= 1 and len(acyclics) >= 1,
        "C6_entropy_equals_R_ln_W": all(
            abs(r["S_conf_J_per_mol_K"] - R_GAS * r["ln_W_conf"])
            <= 1e-6 * max(1.0, abs(r["S_conf_J_per_mol_K"])) for r in rows),
        "C7_bro5_macrocycle_present": any(
            r["beyond_rule_of_5"] for r in macros),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("macrocycle_sim — MACROCYCLE sub-axis :> WEAVE (core)\n", flush=True)
    print("model:  W_conf = Π g_b   S_conf = R·ln W_conf   "
          "ΔΔG_preorg = −T·[S(acyclic) − S(macrocycle)]\n", flush=True)
    print(f"  real-limit anchor : macrocyclization pre-organization entropy; "
          f"Boltzmann S = R·ln W")
    print(f"                      (Mallinson & Collins 2012; Villar et al. 2014; "
          f"Driggers et al. 2008)")
    print(f"  hard ceiling      : a ring can only REMOVE conformers ⇒ "
          f"W_macro ≤ W_acyclic ⇒ ΔΔG_preorg ≤ 0")
    print(f"  ring constraint   : f_ring = {RING_CONSTRAINT_FACTOR}  "
          f"(in-ring effective rotamer multiplicity = f_ring·3)\n", flush=True)

    rows = build_rows()
    for r in rows:
        kind = "macrocycle" if r["is_macrocycle"] else "acyclic   "
        print(f"  [{r['ligand']:<28}] {kind}  W_conf={r['conformational_microstates_W']:.3e}")
        print(f"      S_conf={r['S_conf_cal_per_mol_K']:.2f} cal/mol·K  "
              f"binding-entropy-penalty={r['binding_entropy_penalty_kcal_per_mol']:.2f} kcal/mol  "
              f"bRo5={r['beyond_rule_of_5']}")

    preorg = preorganization(rows)
    print("\n## macrocyclization pre-organization (macrocycle vs acyclic analog)")
    for p in preorg:
        print(f"  {p['macrocycle']:<28} ΔΔG_preorg = {p['ddg_preorg_kcal_per_mol']:+.2f} kcal/mol "
              f"(favourable={p['preorg_is_favourable']})")
        print(f"      S_conf: macrocycle={p['S_conf_macrocycle_cal_per_mol_K']:.2f} < "
              f"acyclic={p['S_conf_acyclic_cal_per_mol_K']:.2f} cal/mol·K")

    acc = acceptance(rows, preorg)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## WEAVE-overlap honesty (HIERARCHY.tape criterion #2)")
    print("  MACROCYCLE is a SUB-axis :> WEAVE core (strong own precedent,")
    print("  WEAVE-adjacent). WEAVE = structural quasi-equivalence (closed")
    print("  capsomer lattice); MACROCYCLE specializes toward single-molecule")
    print("  ring-closure conformational thermodynamics. Sub-axis, NOT a 6th")
    print("  core axis — core-5 (AXIS/AXIS.tape) UNCHANGED.")

    print("\n## C-honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — conformational microstate counts,")
    print("  S_conf = R·ln W, ΔΔG_preorg and the bRo5 flag computed")
    print("  self-consistently. NOT a binding-affinity, potency, permeability or")
    print("  therapeutic-efficacy claim. Rotamer multiplicities, ring-constraint")
    print("  factor and properties are literature-informed surrogates for ligand")
    print("  CLASSES, not fits to a specific compound.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "MACROCYCLE",
        "parent_axis": "WEAVE (core-5, AXIS/AXIS.tape — UNCHANGED)",
        "registration": "AXIS/HIERARCHY.tape @D sub_under_weave",
        "real_limit_anchor": ("macrocyclization pre-organization entropy "
                              "(Mallinson & Collins, Future Med. Chem. 4:1409, "
                              "2012; Villar et al., Nat. Chem. Biol. 10:723, "
                              "2014; Driggers et al., Nat. Rev. Drug Discov. "
                              "7:608, 2008); Boltzmann S = R·ln W"),
        "bro5_source": ("Doak, Over, Giordanetto & Kihlberg, Chem. Biol. "
                        "21:1115 (2014); rule of 5 — Lipinski et al., "
                        "Adv. Drug Deliv. Rev. 23:3 (1997)"),
        "weave_overlap_note": ("MACROCYCLE :> WEAVE core — WEAVE-adjacent with "
                               "strong own precedent; specializes toward "
                               "single-molecule ring-closure conformational "
                               "thermodynamics (HIERARCHY.tape criterion #2)"),
        "temperature_K": TEMP_K,
        "ring_constraint_factor": RING_CONSTRAINT_FACTOR,
        "rows": rows,
        "preorganization": preorg,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity, "
                                   "permeability or therapeutic claim"),
        "lattice_derivation": ("none — no count, entropy, or parameter derived "
                               "from the n=6 lattice (g2/f1/f_lattice_fit)"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__MACROCYCLE__ PASS" if ok else "\n__MACROCYCLE__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
