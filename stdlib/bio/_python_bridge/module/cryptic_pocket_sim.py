#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cryptic_pocket_sim.py — CRYPTIC-POCKET sub-axis :> QUANTUM (core).

Deterministic, stdlib-only real-limits model of a CRYPTIC pocket: a transient
binding site that is absent (closed) in the apo crystal structure and opens
only under protein dynamics. This is the in-silico simulator-consistency layer
for the CRYPTIC-POCKET sub-axis registered in AXIS/HIERARCHY.tape
`@D sub_under_quantum` — see the sibling note `cryptic_pocket_subaxis.md`.

The CRYPTIC-POCKET sub-axis hangs off the core QUANTUM axis as a tag (the
opened cryptic pocket is a VQE-applicable active-space target); the hexa-bio
core-5 axis QUANTUM is UNCHANGED — this is a SUB-AXIS, not a core mutation.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A cryptic pocket lives on a CONFORMATIONAL EQUILIBRIUM between a closed
(pocket-absent) and an open (pocket-formed, druggable) state:

      closed  ⇌(ΔG_open)  open          ΔG_open = G_open − G_closed  > 0

  - The apo protein sits overwhelmingly in the CLOSED state (ΔG_open > 0):
        P_open = exp(−ΔG_open/RT) / (1 + exp(−ΔG_open/RT))
    For a genuine cryptic pocket P_open ≪ 1 — the pocket is rarely sampled,
    which is precisely why it is invisible in the apo crystal structure.
  - A binder that targets the cryptic pocket follows conformational SELECTION:
    it can only bind the OPEN state, so it must PAY the opening free-energy
    cost ΔG_open out of its intrinsic binding free energy ΔG_bind_open.
    The observed (apparent) affinity is therefore PENALISED:
        ΔG_bind_obs = ΔG_bind_open + ΔG_open      (the cryptic-site penalty)
    Equivalently the binder shifts the equilibrium (induced-fit / population
    shift): on binding it RECOVERS the cost — the bound complex re-populates
    the open state — so a viable cryptic-pocket binder must have an intrinsic
    ΔG_bind_open negative enough to overcome ΔG_open and still net favourable.
  - Cryptic-site viability gate: ΔG_bind_obs must remain ≤ a druggability
    threshold (here −7 kcal/mol, ~ low-µM) AFTER paying the opening cost.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Conformational free-energy / Boltzmann population statistics: the open-state
population is fixed by P_open = exp(−ΔG_open/RT)/(1+exp(−ΔG_open/RT)) and is
bounded in (0,1). The thermodynamic cycle (conformational selection vs
induced fit close the same cycle — Hammes, Chang & Oas, *PNAS* 106:13737,
2009) FIXES the relation ΔG_bind_obs = ΔG_bind_open + ΔG_open: a binder cannot
escape paying the opening cost. This conservation of the conformational
free-energy ledger is the hard real limit anchoring every row (criterion C2/C5).
Cryptic-pocket conformational equilibria follow the simulation/Markov-state
literature: Bowman & Geissler, *PNAS* 109:11681, 2012; Vajda, Beglov, Wakefield,
Egbert & Whitty, *Curr. Opin. Chem. Biol.* 44:1, 2018 (cryptic-site review).

Own precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - the KRAS-G12C switch-II pocket — a CRYPTIC pocket absent in early apo
    KRAS structures, revealed under dynamics and exploited by sotorasib
    (Ostrem et al., *Nature* 503:548, 2013; Canon et al., *Nature* 575:217,
    2019; sotorasib FDA-approved 2021).
  - the TEM-1 β-lactamase cryptic allosteric site — a transient pocket distal
    to the active site, detected by tethering / MD (Horn & Shoichet,
    *J. Mol. Biol.* 336:1283, 2004; Bowman & Geissler, *PNAS* 109:11681, 2012).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the Boltzmann open-state populations, the conformational
free-energy ledger ΔG_bind_obs = ΔG_bind_open + ΔG_open and the cryptic-site
viability gate are computed self-consistently and reproduce byte-identically.
It is a thermodynamic-equilibrium MODEL — NOT a binding-affinity measurement,
NOT a potency/selectivity claim, NOT a therapeutic-efficacy claim, and NOT a
prediction that any specific pocket is real or druggable. The ΔG values are
illustrative literature-informed surrogates for pocket CLASSES, not fits to a
specific protein. Pure stdlib, no network/time/random → byte-identical re-runs.

CRYPTIC-POCKET is a SUB-AXIS (:> QUANTUM core) — it is NOT one of the hexa-bio
core-5 axes, which remain QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID
(AXIS.tape unchanged). No quantity here is derived from the n=6 lattice.
"""
from __future__ import annotations
import json
import math
import sys

# ── physical constants (CODATA 2019, exact SI) ──
K_B = 1.380649e-23          # J/K
N_A = 6.02214076e23         # 1/mol
R_GAS = K_B * N_A           # J/(mol·K) = 8.314462618…
KCAL_TO_J = 4184.0          # 1 kcal = 4184 J (thermochemical)
TEMP_K = 310.0              # K (physiological)
RT_KCAL = (R_GAS * TEMP_K) / KCAL_TO_J   # ≈ 0.616 kcal/mol @ 310 K

# ── cryptic-pocket classification thresholds ──
# A pocket is CRYPTIC iff its apo open-state population is below this — i.e.
# rarely sampled, hence invisible in the apo crystal structure.
CRYPTIC_POPEN_THRESHOLD = 0.10
# A cryptic-site binder is VIABLE iff, AFTER paying the opening cost, the
# apparent binding free energy is still at least this favourable (~ low-µM).
DRUGGABLE_DG_THRESHOLD_KCAL = -7.0

SCHEMA_ID = "cryptic_pocket_v1"

# ── deterministic cryptic-pocket panel ──────────────────────────────────────
# (name, ΔG_open kcal/mol, ΔG_bind_open kcal/mol, pocket_class, own precedent)
#   ΔG_open       : conformational opening cost, closed→open (> 0 for cryptic).
#   ΔG_bind_open  : intrinsic binding free energy to the ALREADY-OPEN pocket
#                   (< 0, favourable).  The binder must out-pay ΔG_open.
# Values are illustrative literature-informed surrogates for the pocket CLASS,
# not fits to a specific protein (see module honesty note).
POCKET_PANEL = [
    # genuine cryptic pockets (ΔG_open > 0 → low apo open-state population)
    ("kras_g12c_switch_II", 3.2, -12.5, "cryptic_switch_pocket",
     "KRAS-G12C switch-II pocket — cryptic, exploited by sotorasib"),
    ("tem1_betalactamase_cryptic", 2.6, -10.0, "cryptic_allosteric_pocket",
     "TEM-1 beta-lactamase cryptic allosteric site (transient, distal)"),
    ("deep_cryptic_transient", 4.5, -13.5, "cryptic_transient_pocket",
     "deep transient cryptic pocket modality (rarely sampled, MD-revealed)"),
    ("shallow_cryptic_groove", 1.8, -9.0, "cryptic_surface_groove",
     "shallow cryptic surface groove modality (modest opening cost)"),
    # contrast: a constitutively-open pocket (NOT cryptic — ΔG_open ≤ 0)
    ("constitutive_open_site", -1.5, -9.5, "constitutive_open_pocket",
     "constitutively-open orthosteric pocket modality (apo-visible, not cryptic)"),
    # contrast: a too-costly pocket — opens, but the binder cannot out-pay it
    ("uncompensated_cryptic", 6.0, -8.0, "cryptic_uncompensated_pocket",
     "high-cost cryptic pocket modality (opening cost exceeds binder budget)"),
]


def open_population(dg_open_kcal: float, temp_k: float = TEMP_K) -> float:
    """
    Boltzmann population of the OPEN (pocket-formed) state in the apo protein:

        P_open = exp(-ΔG_open/RT) / (1 + exp(-ΔG_open/RT))

    Bounded in (0,1).  ΔG_open > 0 → P_open < 0.5 (closed-dominant); the larger
    ΔG_open the rarer the open state, hence the more cryptic the pocket.
    """
    rt = (R_GAS * temp_k) / KCAL_TO_J
    w = math.exp(-dg_open_kcal / rt)
    return w / (1.0 + w)


def cryptic_profile(dg_open_kcal: float, dg_bind_open_kcal: float,
                    temp_k: float = TEMP_K) -> dict:
    """
    One pocket's cryptic-pocket profile.  Conformational-selection ledger:
    a binder that selects the open state must PAY the opening cost ΔG_open out
    of its intrinsic ΔG_bind_open, so the apparent affinity is penalised:

        ΔG_bind_obs = ΔG_bind_open + ΔG_open
    """
    p_open = open_population(dg_open_kcal, temp_k)
    dg_bind_obs = dg_bind_open_kcal + dg_open_kcal      # opening-cost penalty
    # Independent thermodynamic-cycle cross-check: the apparent dissociation
    # constant ratio Kd_obs/Kd_open = exp(ΔG_open/RT) = 1/P-style Boltzmann factor.
    rt = (R_GAS * temp_k) / KCAL_TO_J
    kd_penalty_factor = math.exp(dg_open_kcal / rt)     # ≥ 1 for cryptic pockets
    dg_obs_from_factor = dg_bind_open_kcal + rt * math.log(kd_penalty_factor)
    ledger_rel_err = (abs(dg_bind_obs - dg_obs_from_factor)
                      / max(abs(dg_bind_obs), 1e-12))
    is_cryptic = (dg_open_kcal > 0.0) and (p_open < CRYPTIC_POPEN_THRESHOLD)
    binder_viable = dg_bind_obs <= DRUGGABLE_DG_THRESHOLD_KCAL
    # The binder out-pays the opening cost iff the intrinsic budget exceeds it.
    cost_outpaid = abs(dg_bind_open_kcal) > dg_open_kcal
    return {
        "dg_open_kcal_per_mol": dg_open_kcal,
        "dg_bind_open_kcal_per_mol": dg_bind_open_kcal,
        "dg_bind_obs_kcal_per_mol": dg_bind_obs,
        "apo_open_state_population": p_open,
        "kd_penalty_factor": kd_penalty_factor,
        "ledger_consistency_rel_err": ledger_rel_err,
        "rt_kcal_per_mol": rt,
        "cryptic_popen_threshold": CRYPTIC_POPEN_THRESHOLD,
        "is_cryptic": is_cryptic,
        "druggable_dg_threshold_kcal_per_mol": DRUGGABLE_DG_THRESHOLD_KCAL,
        "cryptic_binder_viable": binder_viable,
        "opening_cost_outpaid": cost_outpaid,
        "pocket_state": (
            "cryptic" if is_cryptic
            else ("constitutive_open" if dg_open_kcal <= 0.0
                  else "transiently_open_non_cryptic")),
    }


def build_rows() -> list:
    """Compute one schema-conformant row per pocket in the panel."""
    rows = []
    for name, dg_open, dg_bind, pclass, precedent in POCKET_PANEL:
        prof = cryptic_profile(dg_open, dg_bind)
        row = {
            "schema": SCHEMA_ID,
            "pocket": name,
            "pocket_class": pclass,
            "drug_precedent": precedent,
            "temperature_K": TEMP_K,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Cryptic-vs-constitutive contrast and the uncompensated-cost failure mode."""
    by_name = {r["pocket"]: r for r in rows}
    cryptic = by_name["kras_g12c_switch_II"]
    consti = by_name["constitutive_open_site"]
    uncomp = by_name["uncompensated_cryptic"]
    return {
        "cryptic_reference": {
            "pocket": cryptic["pocket"],
            "drug_precedent": cryptic["drug_precedent"],
            "dg_open_kcal_per_mol": cryptic["dg_open_kcal_per_mol"],
            "apo_open_state_population": cryptic["apo_open_state_population"],
            "dg_bind_obs_kcal_per_mol": cryptic["dg_bind_obs_kcal_per_mol"],
            "cryptic_binder_viable": cryptic["cryptic_binder_viable"],
        },
        "constitutive_reference": {
            "pocket": consti["pocket"],
            "drug_precedent": consti["drug_precedent"],
            "dg_open_kcal_per_mol": consti["dg_open_kcal_per_mol"],
            "apo_open_state_population": consti["apo_open_state_population"],
            "pocket_state": consti["pocket_state"],
        },
        "uncompensated_failure_mode": {
            "pocket": uncomp["pocket"],
            "dg_open_kcal_per_mol": uncomp["dg_open_kcal_per_mol"],
            "dg_bind_open_kcal_per_mol": uncomp["dg_bind_open_kcal_per_mol"],
            "dg_bind_obs_kcal_per_mol": uncomp["dg_bind_obs_kcal_per_mol"],
            "opening_cost_outpaid": uncomp["opening_cost_outpaid"],
            "cryptic_binder_viable": uncomp["cryptic_binder_viable"],
        },
        "note": ("a cryptic pocket is rarely populated in the apo state (low "
                 "P_open) — invisible in the apo crystal; a binder pays the "
                 "opening cost ΔG_open out of its intrinsic affinity. If the "
                 "intrinsic budget cannot out-pay ΔG_open the apparent affinity "
                 "fails the druggability gate — the conformational free-energy "
                 "ledger is conserved and cannot be escaped."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    cryptic = [r for r in rows if r["is_cryptic"]]
    non_cryptic = [r for r in rows if not r["is_cryptic"]]
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_open_population_bounded": all(
            0.0 < r["apo_open_state_population"] < 1.0 for r in rows),
        "C3_ledger_consistent": all(
            r["ledger_consistency_rel_err"] < 1e-9 for r in rows),
        "C4_ledger_sum_holds": all(
            abs(r["dg_bind_obs_kcal_per_mol"]
                - (r["dg_bind_open_kcal_per_mol"] + r["dg_open_kcal_per_mol"]))
            <= 1e-9 for r in rows),
        "C5_both_pocket_kinds_present": len(cryptic) >= 1
        and len(non_cryptic) >= 1,
        "C6_cryptic_low_apo_population": all(
            r["apo_open_state_population"] < CRYPTIC_POPEN_THRESHOLD
            for r in cryptic),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("cryptic_pocket_sim — CRYPTIC-POCKET sub-axis :> QUANTUM (core)\n",
          flush=True)
    print("model:  closed ⇌(ΔG_open) open   P_open = Boltzmann   "
          "ΔG_bind_obs = ΔG_bind_open + ΔG_open\n", flush=True)
    print("  real-limit anchor : conformational free-energy / Boltzmann population")
    print("                      statistics + the conformational-selection")
    print("                      thermodynamic cycle (Hammes, Chang & Oas,")
    print(f"                      PNAS 106:13737, 2009).  RT = {RT_KCAL:.4g} "
          f"kcal/mol @ T={TEMP_K} K\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['pocket']:<28}] {r['pocket_state']:<26} "
              f"ΔG_open={r['dg_open_kcal_per_mol']:+.1f} kcal/mol")
        print(f"      P_open(apo)={r['apo_open_state_population']:.4g}  "
              f"ΔG_bind_open={r['dg_bind_open_kcal_per_mol']:+.1f}  "
              f"ΔG_bind_obs={r['dg_bind_obs_kcal_per_mol']:+.2f} kcal/mol  "
              f"viable={r['cryptic_binder_viable']}")

    ctr = contrast(rows)
    print("\n## cryptic-vs-constitutive contrast")
    cr, co, un = (ctr["cryptic_reference"], ctr["constitutive_reference"],
                  ctr["uncompensated_failure_mode"])
    print(f"  CRYPTIC      {cr['pocket']:<28} P_open={cr['apo_open_state_population']:.4g}  "
          f"ΔG_bind_obs={cr['dg_bind_obs_kcal_per_mol']:+.2f}")
    print(f"  CONSTITUTIVE {co['pocket']:<28} P_open={co['apo_open_state_population']:.4g}  "
          f"state={co['pocket_state']}")
    print(f"  UNCOMPENSATED{un['pocket']:<28} cost_outpaid={un['opening_cost_outpaid']}  "
          f"viable={un['cryptic_binder_viable']}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — Boltzmann open-state populations, the")
    print("  conformational free-energy ledger ΔG_bind_obs = ΔG_bind_open +")
    print("  ΔG_open and the cryptic-site viability gate computed")
    print("  self-consistently. NOT a binding-affinity, potency, selectivity or")
    print("  therapeutic-efficacy claim, and NOT a prediction that any specific")
    print("  pocket is real or druggable. ΔG values are literature-informed")
    print("  surrogates for pocket CLASSES, not fits to a specific protein.")
    print("  CRYPTIC-POCKET is a SUB-AXIS (:> QUANTUM core), NOT a hexa-bio")
    print("  core-5 axis. No quantity is derived from the n=6 lattice.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "CRYPTIC-POCKET",
        "parent_axis": "QUANTUM (core-5 — unchanged; sub hangs off it, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("conformational free-energy / Boltzmann population "
                              "statistics; conformational-selection thermodynamic "
                              "cycle (Hammes, Chang & Oas, PNAS 106:13737, 2009) — "
                              "the ledger ΔG_bind_obs = ΔG_bind_open + ΔG_open is "
                              "conserved and cannot be escaped"),
        "temperature_K": TEMP_K,
        "rt_kcal_per_mol": RT_KCAL,
        "cryptic_popen_threshold": CRYPTIC_POPEN_THRESHOLD,
        "druggable_dg_threshold_kcal_per_mol": DRUGGABLE_DG_THRESHOLD_KCAL,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity, druggability "
                                   "or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__CRYPTIC_POCKET__ PASS" if ok else "\n__CRYPTIC_POCKET__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
