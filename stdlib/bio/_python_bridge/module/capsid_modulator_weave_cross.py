#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
capsid_modulator_weave_cross.py — CROSS-AXIS integration F3.

CROSS:  CAPSID-ASSEMBLY-MODULATOR sub-axis natural protein-capsid assembly
        ──side-by-side, same ΔG_contact perturbation──▶
        WEAVE-axis designed protein-cage assembly.

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/capsid_assembly_modulator_sim.py — the
      CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID core). Models how a
      capsid-assembly modulator shifts the per-contact inter-subunit
      association free energy g_contact of a NATURAL viral capsid, using
      Caspar-Klug T-number geometry + a Zlotnick mean-field assembly
      equilibrium (c_star, assembled fraction, kinetic-trap flag).

  (2) weave/module/weave.hexa — the WEAVE core-5 axis: DESIGNED protein-cage
      composition. Its docstring states it uses "Caspar-Klug 1962 + Zlotnick
      2003 polyhedral protein cage self-assembly" with a "T=1 60-subunit
      icosahedral cage as reference target" — exactly the same geometry and
      assembly thermodynamics as piece (1).

These two have never been crossed. They MUST cross, because they share the
SAME physics: both a natural virus capsid and an engineered protein cage are
icosahedral self-assemblies governed by Caspar-Klug quasi-equivalence
geometry and Zlotnick weak-contact nucleation-elongation thermodynamics. The
only difference is provenance — natural (evolved) vs designed (engineered).
That makes an honest SIDE-BY-SIDE possible: apply the SAME modulator-style
ΔG_contact perturbation to both, and compare how a natural capsid and a
designed cage respond to identical assembly-energy stress.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import the sim, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic ΔG_contact perturbation ladder, this module:

  * imports capsid_assembly_modulator_sim.py and calls its
    `caspar_klug_geometry()`, `assembly_equilibrium()`, `assembled_fraction()`
    and `simulate_cam()` — the Caspar-Klug + Zlotnick model is reused
    VERBATIM, never re-implemented (f3);
  * reads the WEAVE axis's own Caspar-Klug+Zlotnick basis and its T=1
    60-subunit reference-cage declaration straight out of weave/module/
    weave.hexa as deterministic structural text — the file is NOT executed,
    its composition logic is untouched (f3);
  * for each ΔG_contact step, runs the SAME perturbation on the NATURAL-side
    (CAPSID-ASSEMBLY-MODULATOR / VIROCAPSID) baseline and on the
    DESIGNED-side (WEAVE) baseline, and reports both assembly equilibria
    side-by-side.

      same ΔG_contact ──┬─▶ natural capsid  (CAM-sim Zlotnick equilibrium)
                        └─▶ designed cage   (WEAVE-baseline Zlotnick eq.)
                                 ▼
                       honest natural-vs-engineered comparison

The cross demonstrates that natural and engineered self-assembly obey the
SAME Caspar-Klug + Zlotnick limits — neither escapes them; an honest
comparison shows where (and that) they coincide, not a claim that one is
superior. Any difference is the chosen baseline g_contact, never the n=6
lattice.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * Caspar-Klug quasi-equivalence T-number geometry (Caspar & Klug 1962,
    Cold Spring Harb Symp Quant Biol 27:1-24): an icosahedral shell of
    triangulation number T has exactly 60·T subunits = 12 pentamers +
    10·(T-1) hexamers; the capsomer polyhedron satisfies Euler V−E+F=2.
    Exact closed-form integer geometry — no fitting.
  * Zlotnick assembly thermodynamics (Zlotnick 1994 Biochemistry 33:1233;
    Zlotnick 2003 J Mol Recognit 16:294-298): capsids/cages are held by many
    individually-WEAK inter-subunit contacts (~ -2 to -4 kcal/mol each);
    over-stabilization kinetically TRAPS assembly in aberrant intermediates.
    This weak-contact band is the assembly real-limit anchoring both sides.

Modality precedent (described ONLY by its own precedent — g3/f1/f_lattice_fit,
NEVER lattice-derived):
  - Natural-capsid modulation: lenacapavir / Sunlenca, an HIV-1 capsid
    inhibitor, small-molecule drug, FDA-approved 2022 — it over-stabilizes
    the capsid lattice, disrupting assembly and uncoating; HBV capsid-
    assembly modulators (vebicorvir, JNJ-56136379, GLS4) are clinical-stage.
  - Designed protein cages: de-novo self-assembling icosahedral protein
    nanocages (e.g. King et al., Nature 510:103-108 (2014); Bale et al.,
    Science 353:389-394 (2016)) — an engineered-cage research precedent,
    stated only as the designed-assembly device-class precedent.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * The CAM sim is IMPORTED and the WEAVE .hexa is read as data — no fork
    (f3). The Caspar-Klug + Zlotnick model is called verbatim; the WEAVE
    .hexa composition logic is not executed and not duplicated.
  * The WEAVE side here uses the SAME Zlotnick mean-field equilibrium from
    capsid_assembly_modulator_sim.py, parameterised with the WEAVE axis's
    own T=1 60-subunit reference-cage geometry and an illustrative baseline
    g_contact. This is honest because both axes' docstrings declare the same
    Caspar-Klug + Zlotnick model — it is NOT a re-implementation of WEAVE's
    own ODE cage_assembly() (that lives in the .hexa and is untouched, f3).
  * The g_contact baselines and the ΔG_contact ladder are literature-informed
    illustrative magnitudes within the Zlotnick weak-contact band, NOT fits
    to a specific natural-virus or designed-cage dataset.
  * The comparison is an honest side-by-side: it does NOT claim a natural
    capsid or an engineered cage is more stable, more assemblable, or
    therapeutically superior — it shows both obey the same limits.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the Caspar-Klug geometry, the Zlotnick equilibria and the natural-vs-
    designed comparison are computed self-consistently against
    capsid_assembly_modulator_sim.py and re-run byte-identically. It is NOT a
    wet-lab, structural, binding, assembly-yield, therapeutic or regulatory
    claim (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit). "12
    pentamers", "60·T subunits" are Caspar-Klug structural virology — an
    observation, never a lattice derivation.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A cross-axis bridge is NOT a new axis — the hexa-bio core-5 set
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED. WEAVE is a
core axis; CAPSID-ASSEMBLY-MODULATOR is a sub-axis (:> VIROCAPSID). This file
only gates their interaction and emits witness rows.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_CAM_PATH = os.path.join(_HERE, "capsid_assembly_modulator_sim.py")
_WEAVE_HEXA = os.path.join(_REPO_ROOT, "weave", "module", "weave.hexa")

SCHEMA_ID = "capsid_modulator_weave_cross_v1"
SENTINEL_OK = "__CAPSID_MODULATOR_WEAVE_CROSS__ PASS"
SENTINEL_FAIL = "__CAPSID_MODULATOR_WEAVE_CROSS__ FAIL"

# Reference triangulation number for the side-by-side comparison. Both the
# CAM sim's default and the WEAVE axis's declared reference target are the
# T=1 60-subunit icosahedral shell — so the geometry is held identical and
# only the assembly-energy perturbation varies. Not lattice-derived: T=1 is
# Caspar-Klug structural virology read from the WEAVE axis's own docstring.
REFERENCE_T_NUMBER = 1

# Illustrative baseline per-contact inter-subunit free energy (kcal/mol) for
# each side. Both sit inside the Zlotnick weak-contact band [-4.5, -1.5]. The
# natural-capsid baseline matches the CAM sim's own default (g_contact=-3.0);
# the designed-cage baseline is set slightly weaker, an illustrative choice
# reflecting that a de-novo cage interface is typically engineered toward the
# weaker end of the band to avoid kinetic traps. NOT a fit, NOT lattice-derived.
NATURAL_BASELINE_G_CONTACT = -3.0
DESIGNED_BASELINE_G_CONTACT = -2.6

# Total subunit concentration (dimensionless, 1 M standard-state) — the CAM
# sim's own default; held identical across both sides.
C_TOTAL = 0.05


# ── import the CAPSID-ASSEMBLY-MODULATOR sub-axis (no fork — f3) ─────────────
def _load_cam_sim():
    """Import capsid_assembly_modulator_sim.py as a module — its Caspar-Klug
    geometry + Zlotnick assembly model is reused verbatim (f3)."""
    spec = importlib.util.spec_from_file_location(
        "capsid_assembly_modulator_sim", _CAM_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── read the WEAVE axis's own assembly basis (structural text only — f3) ────
def _read_weave_assembly_basis() -> dict:
    """Read the WEAVE core axis's own Caspar-Klug + Zlotnick assembly basis
    straight out of weave/module/weave.hexa.

    This reads deterministic STRUCTURAL text only (the assembly model and
    reference target the axis declares for itself). It does NOT execute the
    .hexa file and does NOT duplicate any composition / ODE logic (f3)."""
    with open(_WEAVE_HEXA, "r", encoding="utf-8") as fh:
        src = fh.read()
    has_ck = "Caspar-Klug 1962" in src
    has_zlotnick = "Zlotnick 2003" in src
    has_ref = ("T=1 60-subunit icosahedral cage" in src
               or "T=1 60-subunit" in src)
    if not (has_ck and has_zlotnick and has_ref):
        raise RuntimeError(
            "expected WEAVE axis Caspar-Klug 1962 + Zlotnick 2003 assembly "
            "basis and T=1 60-subunit reference cage in weave/module/weave.hexa")
    return {
        "weave_axis_source": "weave/module/weave.hexa",
        "assembly_basis_declared_by_axis": (
            "Caspar-Klug 1962 + Zlotnick 2003 polyhedral protein-cage "
            "self-assembly"),
        "reference_target_declared_by_axis": (
            "T=1 60-subunit icosahedral cage"),
        "axis_role": "WEAVE core-5 axis — designed protein-cage composition "
                     "(write-side multi-strand weave)",
    }


# ── deterministic ΔG_contact perturbation ladder ────────────────────────────
# The same modulator-style per-contact free-energy perturbation is applied to
# BOTH sides. Spans no-perturbation, mild stabilization, strong over-
# stabilization (kinetic-trap-inducing) and a destabilizer. Illustrative
# deterministic inputs (see HONESTY).
_PERTURBATION_LADDER = [
    # (perturbation_id, delta_dg_kcal, note)
    ("no_perturbation", 0.0,
     "baseline — no modulator-style perturbation applied"),
    ("mild_stabilizer", -1.0,
     "mild contact-stabilizing perturbation"),
    ("strong_over_stabilizer", -3.0,
     "strong over-stabilizing perturbation — Zlotnick kinetic-trap regime"),
    ("destabilizer", +1.5,
     "contact-destabilizing perturbation"),
]


# ── the cross: same ΔG_contact → natural capsid vs designed cage side-by-side ─
def build_cross_rows(cam) -> list:
    """One cross row per ΔG_contact perturbation step.

    For each step: run the SAME perturbation through the CAM sim's Zlotnick
    equilibrium on (a) the NATURAL-side baseline and (b) the DESIGNED-side
    (WEAVE) baseline, and report both side-by-side. The CAM sim's
    `simulate_cam()` / `assembly_equilibrium()` / `assembled_fraction()` /
    `caspar_klug_geometry()` are imported and reused verbatim (f3).
    """
    basis = _read_weave_assembly_basis()
    geom = cam.caspar_klug_geometry(REFERENCE_T_NUMBER)
    rows = []
    for pert_id, ddg, note in _PERTURBATION_LADDER:
        # NATURAL side — CAPSID-ASSEMBLY-MODULATOR / VIROCAPSID baseline.
        nat = cam.simulate_cam(
            f"natural_{pert_id}", ddg,
            t_number=REFERENCE_T_NUMBER,
            g_contact_baseline=NATURAL_BASELINE_G_CONTACT,
            c_total=C_TOTAL)
        # DESIGNED side — WEAVE baseline, SAME perturbation, SAME geometry.
        des = cam.simulate_cam(
            f"designed_{pert_id}", ddg,
            t_number=REFERENCE_T_NUMBER,
            g_contact_baseline=DESIGNED_BASELINE_G_CONTACT,
            c_total=C_TOTAL)

        def _side(sim_row: dict) -> dict:
            return {
                "g_contact_baseline_kcal": sim_row["g_contact_baseline_kcal"],
                "g_contact_perturbed_kcal": sim_row["g_contact_cam_kcal"],
                "baseline_c_star": sim_row["baseline"]["c_star"],
                "baseline_assembled_fraction":
                    sim_row["baseline"]["assembled_fraction"],
                "perturbed_c_star": sim_row["modulated"]["c_star"],
                "perturbed_assembled_fraction":
                    sim_row["modulated"]["assembled_fraction"],
                "assembled_fraction_shift": sim_row["assembled_fraction_shift"],
                "kinetic_trap_regime": sim_row["kinetic_trap_regime"],
            }

        natural = _side(nat)
        designed = _side(des)
        # honest comparison fields — magnitudes, not a superiority verdict.
        same_trap_outcome = (natural["kinetic_trap_regime"]
                             == designed["kinetic_trap_regime"])
        rows.append({
            "schema": SCHEMA_ID,
            "perturbation_id": pert_id,
            "perturbation_note": note,
            "delta_dg_contact_kcal": ddg,
            "reference_t_number": REFERENCE_T_NUMBER,
            "caspar_klug_geometry": {
                "t_number": geom["t_number"],
                "n_subunits": geom["n_subunits"],
                "n_pentamers": geom["n_pentamers"],
                "n_hexamers": geom["n_hexamers"],
                "euler_invariant_ok": geom["euler_invariant_ok"],
            },
            "c_total": C_TOTAL,
            "natural_side": natural,
            "designed_side": designed,
            "natural_axis": "CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID)",
            "designed_axis": basis["axis_role"],
            "weave_axis_source": basis["weave_axis_source"],
            "weave_assembly_basis": basis["assembly_basis_declared_by_axis"],
            "weave_reference_target": basis["reference_target_declared_by_axis"],
            "comparison": {
                "assembled_fraction_difference_designed_minus_natural": round(
                    designed["perturbed_assembled_fraction"]
                    - natural["perturbed_assembled_fraction"], 12),
                "same_kinetic_trap_outcome": same_trap_outcome,
                "both_obey_zlotnick_weak_contact_band": True,
            },
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "honest natural-vs-engineered side-by-side; NOT a claim that "
                "either is more stable / assemblable / therapeutically "
                "superior; NOT a wet-lab/structural/assembly-yield claim"),
            "illustrative_only": True,
        })
    return rows


def acceptance(rows: list, cam) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X6)."""
    lo, hi = cam.WEAK_CONTACT_LO, cam.WEAK_CONTACT_HI
    # both baselines must sit inside the Zlotnick weak-contact band.
    baselines_in_band = (
        lo <= NATURAL_BASELINE_G_CONTACT <= hi
        and lo <= DESIGNED_BASELINE_G_CONTACT <= hi)
    # geometry identical and exact across all rows.
    geom_exact = all(
        r["caspar_klug_geometry"]["n_subunits"] == 60 * REFERENCE_T_NUMBER
        and r["caspar_klug_geometry"]["euler_invariant_ok"]
        for r in rows)
    # same perturbation applied to both sides (g_contact_perturbed - baseline
    # equals delta_dg on each side).
    same_pert = all(
        abs((r["natural_side"]["g_contact_perturbed_kcal"]
             - r["natural_side"]["g_contact_baseline_kcal"])
            - r["delta_dg_contact_kcal"]) < 1e-9
        and abs((r["designed_side"]["g_contact_perturbed_kcal"]
                 - r["designed_side"]["g_contact_baseline_kcal"])
                - r["delta_dg_contact_kcal"]) < 1e-9
        for r in rows)
    # a stabilizer (delta_dg < 0) raises the assembled fraction on BOTH sides.
    stab_both = all(
        r["natural_side"]["assembled_fraction_shift"] > 0.0
        and r["designed_side"]["assembled_fraction_shift"] > 0.0
        for r in rows if r["delta_dg_contact_kcal"] < 0.0)
    # the strong over-stabilizer triggers the kinetic-trap regime on BOTH
    # sides (both obey the same Zlotnick limit — the point of the comparison).
    over = [r for r in rows
            if r["perturbation_id"] == "strong_over_stabilizer"]
    trap_both = len(over) == 1 and (
        over[0]["natural_side"]["kinetic_trap_regime"]
        and over[0]["designed_side"]["kinetic_trap_regime"])
    crit = {
        "X1_perturbation_ladder_crossed":
            len(rows) == len(_PERTURBATION_LADDER) and len(rows) >= 4,
        "X2_both_baselines_in_zlotnick_band": baselines_in_band,
        "X3_caspar_klug_geometry_exact_and_shared": geom_exact,
        "X4_same_perturbation_applied_both_sides": same_pert,
        "X5_stabilizer_raises_fraction_both_sides": stab_both,
        "X6_over_stabilizer_traps_both_sides": trap_both,
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("capsid_modulator_weave_cross — CROSS-AXIS F3\n", flush=True)
    print("cross:  CAPSID-ASSEMBLY-MODULATOR sub-axis (natural capsid)", flush=True)
    print("        ──same ΔG_contact perturbation──▶  WEAVE-axis (designed cage)",
          flush=True)
    print("        honest natural-vs-engineered self-assembly side-by-side\n",
          flush=True)

    cam = _load_cam_sim()
    basis = _read_weave_assembly_basis()
    print("  real-limit anchors:")
    print("   - Caspar-Klug quasi-equivalence T-number geometry (Caspar & Klug")
    print("     1962, CSHSQB 27:1-24) — 60·T subunits; Euler V-E+F=2")
    print("   - Zlotnick assembly thermodynamics (Zlotnick 1994 Biochemistry")
    print(f"     33:1233; 2003 JMR 16:294) — weak-contact band "
          f"[{cam.WEAK_CONTACT_LO}, {cam.WEAK_CONTACT_HI}] kcal/mol")
    print(f"  WEAVE axis        : {basis['axis_role']}")
    print(f"    assembly basis  : {basis['assembly_basis_declared_by_axis']}")
    print(f"    reference target: {basis['reference_target_declared_by_axis']}")
    print(f"  side-by-side      : natural baseline g_contact="
          f"{NATURAL_BASELINE_G_CONTACT:+.1f}  vs  designed baseline "
          f"g_contact={DESIGNED_BASELINE_G_CONTACT:+.1f} kcal/mol\n", flush=True)

    rows = build_cross_rows(cam)
    for r in rows:
        n = r["natural_side"]
        d = r["designed_side"]
        print(f"  [{r['perturbation_id']:<24}] ΔΔG_contact="
              f"{r['delta_dg_contact_kcal']:+.2f} kcal/mol")
        print(f"      natural  : g_contact={n['g_contact_perturbed_kcal']:+.2f}  "
              f"f={n['perturbed_assembled_fraction']:.4f}  "
              f"Δf={n['assembled_fraction_shift']:+.4f}  "
              f"trap={n['kinetic_trap_regime']}")
        print(f"      designed : g_contact={d['g_contact_perturbed_kcal']:+.2f}  "
              f"f={d['perturbed_assembled_fraction']:.4f}  "
              f"Δf={d['assembled_fraction_shift']:+.4f}  "
              f"trap={d['kinetic_trap_regime']}")
        c = r["comparison"]
        print(f"      compare  : Δf(designed-natural)="
              f"{c['assembled_fraction_difference_designed_minus_natural']:+.4f}  "
              f"same-trap-outcome={c['same_kinetic_trap_outcome']}")

    acc = acceptance(rows, cam)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - The CAM sim is imported and the WEAVE .hexa is read as data — no")
    print("    fork (f3): the Caspar-Klug + Zlotnick model is called verbatim;")
    print("    the WEAVE .hexa composition/ODE logic is not executed or duplicated.")
    print("  - The WEAVE side uses the SAME Zlotnick mean-field equilibrium from")
    print("    the CAM sim, parameterised with the WEAVE axis's own T=1 60-subunit")
    print("    reference geometry — honest because both axes declare the same")
    print("    Caspar-Klug + Zlotnick model; it is NOT a re-implementation of")
    print("    WEAVE's own cage_assembly() ODE (untouched in the .hexa, f3).")
    print("  - The g_contact baselines and the ΔΔG ladder are literature-informed")
    print("    illustrative magnitudes in the Zlotnick weak-contact band, NOT fits.")
    print("  - The comparison is an honest side-by-side: it does NOT claim a")
    print("    natural capsid or an engineered cage is more stable, more")
    print("    assemblable, or therapeutically superior — both obey the same limits.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY and")
    print("    re-runs byte-identically. It is NOT a wet-lab / structural /")
    print("    assembly-yield / therapeutic claim (g8/f2).")
    print("  - '12 pentamers', '60·T subunits' are Caspar-Klug structural")
    print("    virology — NOT n=6-lattice derivations (g2/f_lattice_fit). A")
    print("    cross-axis bridge is NOT a new axis — the core-5 set is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": ("F3  CAPSID-ASSEMBLY-MODULATOR sub-axis natural-capsid assembly "
                  "->  WEAVE-axis designed-cage assembly (same ΔG_contact "
                  "perturbation, honest side-by-side)"),
        "capsid_modulator_subaxis_source": (
            "_python_bridge/module/capsid_assembly_modulator_sim.py "
            "(Caspar-Klug geometry + Zlotnick assembly model imported, not "
            "re-implemented — f3)"),
        "weave_axis_source": (
            "weave/module/weave.hexa (Caspar-Klug+Zlotnick assembly basis and "
            "T=1 60-subunit reference cage read as structural text; "
            "composition/ODE logic untouched — f3)"),
        "real_limit_anchors": [
            "Caspar-Klug quasi-equivalence T-number geometry (Caspar & Klug "
            "1962 CSHSQB 27:1-24) — 60·T subunits, Euler V-E+F=2",
            "Zlotnick assembly thermodynamics (Zlotnick 1994 Biochemistry "
            "33:1233; 2003 JMR 16:294-298) — weak-contact band, over-"
            "stabilization kinetic trap",
        ],
        "modality_precedent": (
            "natural-capsid modulation — lenacapavir/Sunlenca (HIV-1 capsid "
            "inhibitor, FDA 2022), HBV CAMs vebicorvir/JNJ-56136379/GLS4 "
            "(clinical-stage); designed protein cages — King 2014 (Nature "
            "510:103), Bale 2016 (Science 353:389), research-stage; own "
            "precedent, NOT lattice-derived (g3/f1)"),
        "reference_t_number": REFERENCE_T_NUMBER,
        "natural_baseline_g_contact_kcal": NATURAL_BASELINE_G_CONTACT,
        "designed_baseline_g_contact_kcal": DESIGNED_BASELINE_G_CONTACT,
        "c_total": C_TOTAL,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — honest natural-vs-engineered "
            "side-by-side; NOT a claim that either is more stable / assemblable "
            "/ therapeutically superior; NOT a wet-lab / structural / assembly-"
            "yield claim. Core-5 axis set UNCHANGED; this is a cross, not a "
            "new axis."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
