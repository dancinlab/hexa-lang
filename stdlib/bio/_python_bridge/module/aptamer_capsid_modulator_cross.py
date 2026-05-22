#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aptamer_capsid_modulator_cross.py — CROSS-AXIS integration (sub :> RIBOZYME × sub :> VIROCAPSID).

CROSS:  APTAMER sub-axis  Nussinov-fold / 1:1-Langmuir-Kd binding model
        ──occupancy-as-modulator──▶  CAPSID-ASSEMBLY-MODULATOR sub-axis
        Zlotnick mean-field assembly equilibrium + exact Caspar-Klug geometry.

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed sub-axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/aptamer_affinity_sim.py — the APTAMER sub-axis
      (:> RIBOZYME core). Folds a structured oligonucleotide binder
      (Nussinov 1978 bp-max + Turner-style NN stack-sum ΔG) and runs a 1:1
      Langmuir equilibrium  A + L <=> A·L,  Kd = koff/kon,
      θ = [L]/(Kd+[L]).

  (2) _python_bridge/module/capsid_assembly_modulator_sim.py — the
      CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID core). A modulator
      shifts the per-contact assembly free energy g_contact by Δg; the
      Zlotnick mean-field equilibrium maps Δg to a pseudo-critical c* and a
      cooperative assembled-fraction shift on exact Caspar-Klug T-number
      geometry, with the Zlotnick over-stabilization kinetic-trap regime.

These two have never been crossed. They CAN cross through a concrete
research-stage construct: an aptamer raised against a capsid inter-subunit
interface is, mechanistically, a capsid-assembly modulator — when it occupies
the interface it perturbs that contact's free energy. The APTAMER axis's
Langmuir fraction-bound θ (occupancy at a given aptamer concentration) is
exactly the LEVER that scales the CAPSID-ASSEMBLY-MODULATOR axis's per-contact
ΔG perturbation:

    aptamer [A] ──Langmuir θ──▶ Δg_eff = θ·Δg_max ──▶ Zlotnick c*, assembled f

A stabilizing interface-aptamer (Δg_max < 0) that saturates its target can
over-stabilize contacts into the Zlotnick kinetic trap (the same mechanistic
regime the small-molecule capsid-assembly-modulator drug class exploits); a
destabilizing interface-aptamer (Δg_max > 0) raises c* and suppresses
assembly. The assembly outcome is governed by the Zlotnick equilibrium and
the law of mass action, never by the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sides, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic interface-aptamer panel, this module:

  * imports aptamer_affinity_sim.py and calls its `model_aptamer()` /
    `fraction_bound()` — the APTAMER side's Nussinov fold + Langmuir binding
    model is reused VERBATIM, never re-implemented (f3);
  * imports capsid_assembly_modulator_sim.py and calls its `simulate_cam()` /
    `caspar_klug_geometry()` — the CAPSID-ASSEMBLY-MODULATOR side's Zlotnick
    equilibrium + Caspar-Klug geometry is reused VERBATIM, never
    re-implemented (f3);
  * for each construct, takes the aptamer's Langmuir θ at its aptamer
    concentration and maps it through a fixed per-aptamer maximum
    perturbation Δg_max to an effective ΔG_contact = θ·Δg_max, then feeds
    that VERBATIM into the capsid sim as the modulator's Δg.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * RNA/DNA secondary-structure folding thermodynamics — nearest-neighbour
    free-energy model (SantaLucia 1998 PNAS 95:1460-1465; Turner & Mathews
    2010 NNDB, NAR 38:D280-D282).
  * 1:1 Langmuir law-of-mass-action equilibrium θ = [L]/(Kd+[L]),
    Kd = koff/kon — θ = 0.5 EXACTLY at [L] = Kd (the occupancy real-limit).
  * Caspar-Klug 1962 quasi-equivalence — icosahedral capsid geometry
    60·T subunits = 12 pentamers + 10·(T−1) hexamers, Euler V−E+F = 2.
  * Zlotnick mean-field nucleation-elongation assembly equilibrium
    (Zlotnick 1994 Biochemistry 33:14831; Zlotnick 2003 J Mol Recognit
    16:236) — the weak-contact band and the over-stabilization kinetic trap.

Modality precedent (described ONLY by its own precedent — g3/f1/f_lattice_fit,
NEVER lattice-derived):
  - Aptamer modality: pegaptanib sodium (Macugen), anti-VEGF165 RNA aptamer,
    FDA-approved 2004 (CDER); avacincaptad pegol (Izervay/Zimura),
    anti-complement-C5 RNA aptamer, FDA-approved 2023 (CDER).
  - Capsid-assembly-modulator drug class: lenacapavir (Sunlenca),
    HIV-1 small-molecule capsid-assembly modulator, FDA-approved 2022 (CDER).
  - The COMBINATION — an aptamer acting AS a capsid-assembly modulator — is a
    RESEARCH-STAGE modality combination: there is NO FDA-approved
    capsid-targeting aptamer assembly-modulator. Reported honestly as
    research-stage (schema-const research_stage_modality=true); the aptamer
    modality precedent and the capsid-assembly-modulator drug-class precedent
    are stated SEPARATELY by their OWN approvals, never merged or
    lattice-derived.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both parent sims are IMPORTED — no fork (f3). The APTAMER fold + Langmuir
    model and the CAPSID-ASSEMBLY-MODULATOR Zlotnick + Caspar-Klug model are
    each called verbatim; neither is duplicated.
  * An aptamer AS a capsid-assembly modulator is RESEARCH-STAGE — no approved
    drug of this combination exists. The schema pins research_stage_modality
    to const true so a witness can never silently imply otherwise.
  * The occupancy→perturbation map Δg_eff = θ·Δg_max is a MODELING CHOICE: a
    real interface aptamer has its own binding-site stoichiometry, partial
    interface coverage and allosteric coupling this linear scaling omits. It
    is a qualitative illustration (illustrative_only const true).
  * This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY: the chain
    aptamer [A] → Langmuir θ → Δg_eff → Zlotnick c*/assembled-fraction is
    computed self-consistently against BOTH imported sims and re-runs
    byte-identically. It is NOT a structural / binding-affinity /
    capsid-assembly / antiviral / therapeutic / regulatory claim (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit): θ is the
    Langmuir isotherm, Δg_eff is a θ-scaled perturbation, c* and the
    assembled fraction are the Zlotnick equilibrium, the capsid geometry is
    Caspar-Klug. A cross-axis bridge is NOT a new axis — the hexa-bio core-5
    set (QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED.
    Both APTAMER and CAPSID-ASSEMBLY-MODULATOR are sub-axes; this file only
    gates their interaction and emits witness rows.
  * Pure stdlib, no network / time / random → byte-identical re-runs.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_APTAMER_PATH = os.path.join(_HERE, "aptamer_affinity_sim.py")
_CAPSID_PATH = os.path.join(_HERE, "capsid_assembly_modulator_sim.py")

SCHEMA_ID = "aptamer_capsid_modulator_cross_v1"
SENTINEL_OK = "__APTAMER_CAPSID_MODULATOR_CROSS__ PASS"
SENTINEL_FAIL = "__APTAMER_CAPSID_MODULATOR_CROSS__ FAIL"


# ── import the two parent sub-axes (no fork — f3) ───────────────────────────
def _load_sim(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── deterministic interface-aptamer panel ───────────────────────────────────
# Each construct couples one aptamer (from the APTAMER sub-axis's
# literature-anchored corpus) raised against a capsid inter-subunit interface.
# Δg_max is the fixed illustrative per-aptamer MAXIMUM per-contact perturbation
# at full occupancy (negative = interface-stabilizing → assembly-promoting /
# kinetic-trap mechanism; positive = interface-destabilizing → assembly-
# suppressing). The aptamer concentration is given as a multiple of that
# aptamer's own Kd so θ spans low → saturating across the panel. Illustrative
# deterministic inputs, NOT lattice-derived (g2/f_lattice_fit); see HONESTY.
_CONSTRUCT_PANEL = [
    # (construct_id, corpus_idx, capsid_target, conc_x_kd, dg_max_kcal, T, note)
    ("ifaceapt_stabilizer_subKd", 0, "icosahedral capsid dimer interface",
     0.1, -3.0, 3,
     "interface-stabilizing aptamer, sub-Kd → low occupancy → minimal "
     "ΔG perturbation"),
    ("ifaceapt_stabilizer_atKd", 0, "icosahedral capsid dimer interface",
     1.0, -3.0, 3,
     "interface-stabilizing aptamer at Kd → θ=0.5 → half-max stabilization"),
    ("ifaceapt_stabilizer_saturating", 1, "icosahedral capsid dimer interface",
     30.0, -3.0, 4,
     "interface-stabilizing aptamer saturating → near-full over-"
     "stabilization → Zlotnick kinetic-trap regime"),
    ("ifaceapt_destabilizer_atKd", 2, "icosahedral capsid pentamer interface",
     1.0, +2.0, 1,
     "interface-destabilizing aptamer at Kd → θ=0.5 → partial assembly "
     "suppression"),
    ("ifaceapt_destabilizer_saturating", 2, "icosahedral capsid pentamer interface",
     50.0, +2.0, 1,
     "interface-destabilizing aptamer saturating → assembly strongly "
     "suppressed"),
]


def _sign(dg_max: float) -> str:
    if dg_max < 0.0:
        return "stabilizer"
    if dg_max > 0.0:
        return "destabilizer"
    return "neutral"


# ── the cross: aptamer [A] → Langmuir θ → Δg_eff=θ·Δg_max → Zlotnick c*/f ───
def build_cross_rows(aptamer, capsid) -> list:
    """One cross row per interface-aptamer construct.

    For each construct: model the aptamer via the APTAMER sub-axis's
    `model_aptamer()` (imported — f3); evaluate its Langmuir θ at the aptamer
    concentration via `fraction_bound()`; scale the per-aptamer Δg_max by θ;
    feed that effective Δg VERBATIM into the CAPSID-ASSEMBLY-MODULATOR
    sub-axis's `simulate_cam()` (imported — f3) on exact Caspar-Klug geometry.
    """
    corpus = aptamer._APTAMER_CORPUS
    rows = []
    for cid, idx, target, conc_x_kd, dg_max, t_number, note in _CONSTRUCT_PANEL:
        entry = corpus[idx]
        row_a = aptamer.model_aptamer(*entry)
        kd_M = row_a["binding"]["kd_M"]
        conc_M = kd_M * conc_x_kd
        # Langmuir fraction-bound θ — APTAMER sub-axis function, reused (f3).
        theta = aptamer.fraction_bound(conc_M, kd_M)
        # occupancy → per-contact perturbation (modeling choice, see HONESTY).
        dg_eff = theta * dg_max
        # CAPSID-ASSEMBLY-MODULATOR sub-axis — Zlotnick + Caspar-Klug, reused (f3).
        cam = capsid.simulate_cam(cid, dg_eff, t_number=t_number)
        geom = cam["geometry"]
        rows.append({
            "schema": SCHEMA_ID,
            "device_id": cid,
            "device_note": note,
            "aptamer_name": row_a["name"],
            "aptamer_sequence": row_a["sequence"],
            "aptamer_length_nt": row_a["length_nt"],
            "capsid_target": target,
            "aptamer_paper_ref": row_a["paper_ref"],
            "fold_dot_bracket": row_a["fold"]["dot_bracket"],
            "fold_num_base_pairs": row_a["fold"]["num_base_pairs"],
            "folding_free_energy_kcal_per_mol":
                row_a["fold"]["folding_free_energy_kcal_per_mol"],
            "binding_model": row_a["binding"]["model"],
            "kd_nM": row_a["binding"]["kd_nM"],
            "kd_M": kd_M,
            "kon_M_inv_s": row_a["binding"]["kon_M_inv_s"],
            "koff_s": row_a["binding"]["koff_s"],
            "aptamer_conc_x_kd": conc_x_kd,
            "aptamer_conc_M": conc_M,
            "fraction_bound_theta": round(theta, 12),
            "modulator_dg_max_kcal": dg_max,
            "effective_delta_dg_contact_kcal": round(dg_eff, 12),
            "modulator_sign": _sign(dg_max),
            "reference_t_number": t_number,
            "caspar_klug_geometry": {
                "t_number": geom["t_number"],
                "n_subunits": geom["n_subunits"],
                "n_pentamers": geom["n_pentamers"],
                "n_hexamers": geom["n_hexamers"],
                "euler_invariant_ok": geom["euler_invariant_ok"],
            },
            "g_contact_baseline_kcal": cam["g_contact_baseline_kcal"],
            "g_contact_modulated_kcal": cam["g_contact_cam_kcal"],
            "c_total": cam["c_total"],
            "baseline_c_star": cam["baseline"]["c_star"],
            "baseline_assembled_fraction": cam["baseline"]["assembled_fraction"],
            "modulated_c_star": cam["modulated"]["c_star"],
            "modulated_assembled_fraction":
                cam["modulated"]["assembled_fraction"],
            "assembled_fraction_shift": cam["assembled_fraction_shift"],
            "kinetic_trap_regime": cam["kinetic_trap_regime"],
            "kcat_per_s": row_a["kcat_per_s"],  # aptamer = non-catalytic (0.0)
            "aptamer_subaxis_source": (
                "_python_bridge/module/aptamer_affinity_sim.py (Nussinov fold "
                "+ Langmuir binding model imported, not re-implemented — f3)"),
            "capsid_modulator_subaxis_source": (
                "_python_bridge/module/capsid_assembly_modulator_sim.py "
                "(Zlotnick equilibrium + Caspar-Klug geometry imported, not "
                "re-implemented — f3)"),
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "the θ→Δg_eff occupancy map is a modeling choice; an aptamer "
                "AS a capsid-assembly modulator is research-stage; NOT a "
                "structural/binding/assembly/antiviral/therapeutic claim"),
            "research_stage_modality": True,
            "creates_a_new_axis": False,
            "illustrative_only": True,
        })
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X8)."""
    stabilizers = [r for r in rows if r["modulator_sign"] == "stabilizer"]
    crit = {
        "X1_construct_panel_crossed":
            len(rows) == len(_CONSTRUCT_PANEL) and len(rows) >= 5,
        "X2_langmuir_model_used": all(
            "Langmuir" in r["binding_model"] for r in rows),
        "X3_caspar_klug_geometry_exact": all(
            r["caspar_klug_geometry"]["n_subunits"]
            == 60 * r["caspar_klug_geometry"]["t_number"]
            and r["caspar_klug_geometry"]["n_pentamers"] == 12
            and r["caspar_klug_geometry"]["n_hexamers"]
            == 10 * (r["caspar_klug_geometry"]["t_number"] - 1)
            and r["caspar_klug_geometry"]["euler_invariant_ok"] is True
            for r in rows),
        "X4_theta_half_at_kd": all(
            abs(r["fraction_bound_theta"] - 0.5) < 1e-12
            for r in rows if abs(r["aptamer_conc_x_kd"] - 1.0) < 1e-12),
        "X5_effective_dg_is_theta_scaled": all(
            abs(r["effective_delta_dg_contact_kcal"]
                - r["fraction_bound_theta"] * r["modulator_dg_max_kcal"]) < 1e-9
            for r in rows),
        # occupancy monotonicity: among same-Δg_max stabilizers, higher θ ⇒
        # more-negative effective Δg ⇒ more-negative modulated g_contact.
        "X6_occupancy_monotone_for_stabilizers": all(
            (a["fraction_bound_theta"] <= b["fraction_bound_theta"])
            == (a["effective_delta_dg_contact_kcal"]
                >= b["effective_delta_dg_contact_kcal"])
            for a in stabilizers for b in stabilizers
            if abs(a["modulator_dg_max_kcal"]
                   - b["modulator_dg_max_kcal"]) < 1e-12),
        # Zlotnick over-stabilization kinetic trap fires for the saturating
        # stabilizer but NOT for the sub-Kd stabilizer.
        "X7_saturating_stabilizer_triggers_kinetic_trap": (
            any(r["kinetic_trap_regime"] is True
                and r["modulator_sign"] == "stabilizer"
                and r["aptamer_conc_x_kd"] >= 10.0 for r in rows)
            and all(r["kinetic_trap_regime"] is False
                    for r in rows
                    if r["modulator_sign"] == "stabilizer"
                    and r["aptamer_conc_x_kd"] <= 0.1)),
        "X8_honesty_invariants": all(
            r["research_stage_modality"] is True
            and r["creates_a_new_axis"] is False
            and r["illustrative_only"] is True
            and r["kcat_per_s"] == 0.0
            for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def _determinism_ok(aptamer, capsid) -> bool:
    a = json.dumps(build_cross_rows(aptamer, capsid), sort_keys=True)
    b = json.dumps(build_cross_rows(aptamer, capsid), sort_keys=True)
    return a == b


def main() -> int:
    print("aptamer_capsid_modulator_cross — CROSS-AXIS "
          "(sub :> RIBOZYME × sub :> VIROCAPSID)\n", flush=True)
    print("cross:  APTAMER sub-axis  Nussinov-fold / 1:1-Langmuir-Kd model",
          flush=True)
    print("        ──occupancy-as-modulator──▶  CAPSID-ASSEMBLY-MODULATOR "
          "sub-axis", flush=True)
    print("        aptamer [A] → Langmuir θ → Δg_eff=θ·Δg_max → "
          "Zlotnick c*, assembled f\n", flush=True)

    aptamer = _load_sim("aptamer_affinity_sim", _APTAMER_PATH)
    capsid = _load_sim("capsid_assembly_modulator_sim", _CAPSID_PATH)

    print("  real-limit anchors:")
    print("   - RNA/DNA folding thermodynamics — nearest-neighbour model")
    print("     (SantaLucia 1998 PNAS 95:1460; Turner & Mathews 2010 NAR 38:D280)")
    print("   - 1:1 Langmuir equilibrium θ=[L]/(Kd+[L]); θ=0.5 exactly at [L]=Kd")
    print("   - Caspar-Klug 1962 — 60·T subunits, 12 pentamers, Euler V−E+F=2")
    print("   - Zlotnick mean-field equilibrium + over-stabilization kinetic trap")
    print("     (Zlotnick 1994 Biochemistry 33:14831; 2003 J Mol Recognit 16:236)\n",
          flush=True)

    rows = build_cross_rows(aptamer, capsid)
    for r in rows:
        print(f"  [{r['device_id']:<34}] {r['modulator_sign']:<12} "
              f"trap={r['kinetic_trap_regime']}")
        print(f"      aptamer={r['aptamer_name']:<26} Kd={r['kd_nM']:>8.1f} nM  "
              f"[A]={r['aptamer_conc_x_kd']:>6.2f}x Kd  θ={r['fraction_bound_theta']:.6f}")
        print(f"      Δg_max={r['modulator_dg_max_kcal']:+.2f}  "
              f"Δg_eff={r['effective_delta_dg_contact_kcal']:+.4f} kcal/mol  "
              f"T={r['reference_t_number']} "
              f"({r['caspar_klug_geometry']['n_subunits']} subunits)  "
              f"Δf={r['assembled_fraction_shift']:+.4f}")

    acc = acceptance(rows)
    det_ok = _determinism_ok(aptamer, capsid)
    acc["criteria"]["X9_determinism_byte_identical"] = det_ok
    acc["pass_count"] = sum(1 for v in acc["criteria"].values() if v)
    acc["total"] = len(acc["criteria"])
    acc["verdict"] = "PASS" if acc["pass_count"] == acc["total"] else "FAIL"

    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both parent sims are imported — no fork (f3): the APTAMER fold +")
    print("    Langmuir model and the CAPSID-ASSEMBLY-MODULATOR Zlotnick +")
    print("    Caspar-Klug model are each called verbatim, neither duplicated.")
    print("  - An aptamer AS a capsid-assembly modulator is RESEARCH-STAGE — no")
    print("    approved drug of this combination exists (schema-const")
    print("    research_stage_modality=true). Aptamer modality precedent")
    print("    (pegaptanib FDA 2004; avacincaptad pegol FDA 2023) and the")
    print("    capsid-assembly-modulator drug class (lenacapavir FDA 2022) are")
    print("    each stated by their OWN approval, never merged or lattice-derived.")
    print("  - The occupancy→perturbation map Δg_eff=θ·Δg_max is a MODELING")
    print("    CHOICE; a real interface aptamer has stoichiometry / partial")
    print("    coverage / allostery this linear scaling omits.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY and")
    print("    re-runs byte-identically. It is NOT a structural / binding /")
    print("    capsid-assembly / antiviral / therapeutic / regulatory claim (g8/f2).")
    print("  - No θ / Δg / c* / count here is derived from the n=6 lattice")
    print("    (g2/f_lattice_fit). A cross is NOT a new axis — core-5 UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": ("APTAMER sub-axis Langmuir-Kd binding  ->  "
                  "CAPSID-ASSEMBLY-MODULATOR sub-axis Zlotnick assembly "
                  "(occupancy-scaled per-contact ΔG perturbation)"),
        "aptamer_subaxis_source": (
            "_python_bridge/module/aptamer_affinity_sim.py (Nussinov fold + "
            "Langmuir binding model imported, not re-implemented — f3)"),
        "capsid_modulator_subaxis_source": (
            "_python_bridge/module/capsid_assembly_modulator_sim.py (Zlotnick "
            "equilibrium + Caspar-Klug geometry imported, not re-implemented — f3)"),
        "real_limit_anchors": [
            "RNA/DNA secondary-structure folding thermodynamics — nearest-"
            "neighbour model (SantaLucia 1998 PNAS 95:1460; Turner & Mathews "
            "2010 NNDB NAR 38:D280)",
            "1:1 Langmuir law-of-mass-action equilibrium θ=[L]/(Kd+[L]), "
            "Kd=koff/kon — θ=0.5 exactly at [L]=Kd",
            "Caspar-Klug 1962 quasi-equivalence — 60·T subunits = 12 pentamers "
            "+ 10·(T−1) hexamers, Euler V−E+F=2",
            "Zlotnick mean-field nucleation-elongation equilibrium + over-"
            "stabilization kinetic trap (Zlotnick 1994 Biochemistry 33:14831; "
            "2003 J Mol Recognit 16:236)",
        ],
        "modality_precedent": (
            "aptamer modality — pegaptanib/Macugen (anti-VEGF165 RNA aptamer, "
            "FDA 2004, CDER), avacincaptad pegol/Izervay (anti-C5 RNA aptamer, "
            "FDA 2023, CDER); capsid-assembly-modulator drug class — "
            "lenacapavir/Sunlenca (HIV-1 small-molecule capsid-assembly "
            "modulator, FDA 2022, CDER); the COMBINATION (aptamer AS capsid-"
            "assembly modulator) is RESEARCH-STAGE — no FDA-approved instance; "
            "each precedent stated by its own approval, NOT lattice-derived "
            "(g3/f1)"),
        "occupancy_to_perturbation_map": (
            "Δg_eff = θ·Δg_max — modeling choice; Δg_max is the fixed "
            "illustrative per-aptamer max per-contact perturbation at full "
            "occupancy (negative = interface-stabilizing, positive = "
            "destabilizing)"),
        "rows": rows,
        "acceptance": acc,
        "research_stage_modality": True,
        "creates_a_new_axis": False,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — an aptamer AS a capsid-"
            "assembly modulator is research-stage; the θ→Δg_eff map is a "
            "modeling choice; NOT a structural / binding / capsid-assembly / "
            "antiviral / therapeutic / regulatory claim. Core-5 axis set "
            "UNCHANGED; this is a cross, not a new axis."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
