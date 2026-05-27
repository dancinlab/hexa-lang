#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
capsid_assembly_modulator_sim.py — CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID)

Sub-axis simulator for capsid-assembly modulators (CAMs) — small molecules
that perturb viral capsid self-assembly. Specializes the core VIROCAPSID
axis's Zlotnick nucleation-elongation assembly modeling toward INHIBITION:
a CAM shifts the per-contact inter-subunit association free energy
g_contact, and this module computes how that shift moves the assembly
equilibrium and (per Zlotnick) drives the over-stabilized kinetic-trap /
mis-assembly regime.

This is a SUB-AXIS, NOT a 6th core axis — the hexa-bio core stays 5
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per AXIS.tape). Recorded
under the expansion-layer pattern of AXIS/HIERARCHY.tape; the core-5 SSOT
is UNCHANGED.

Real limits anchored (g1 — real-limits-first):
  - Caspar-Klug quasi-equivalence T-number geometry (Caspar & Klug 1962,
    Cold Spring Harb Symp Quant Biol 27:1-24): an icosahedral capsid of
    triangulation number T has exactly 60*T protein subunits = 12 pentamers
    + 10*(T-1) hexamers; the capsomer polyhedron satisfies Euler V-E+F=2.
    EXACT integer / closed-form geometry — no fitting.
  - Zlotnick assembly thermodynamics (Zlotnick 1994, Biochemistry 33:1233;
    Zlotnick 2003, J Mol Recognit 16:294-298): capsids are held by many
    individually-WEAK inter-subunit contacts (~ -2 to -4 kcal/mol each);
    OVER-stabilization (contacts too strong) kinetically TRAPS assembly in
    incomplete / aberrant intermediates — the system cannot anneal defects.

Modality precedent (g3/f1 — described by its OWN drug precedent, NEVER
lattice-derived): lenacapavir / Sunlenca — HIV-1 capsid inhibitor, a
SMALL-MOLECULE (CDER) drug, FDA-approved 2022; it over-stabilizes the
capsid lattice, disrupting both assembly and uncoating. HBV capsid-assembly
modulators (vebicorvir, JNJ-56136379, GLS4) — clinical-stage.

In-silico scope (g8/f2): every PASS verifies in-silico simulator-consistency
ONLY — that the geometry and equilibrium models are internally consistent
and reproduce the cited closed forms. It is NOT a wet-lab, structural,
binding, therapeutic, clinical, or regulatory claim about any CAM.
Parameters are literature-informed illustrative magnitudes, not fits to a
specific dataset.

No count, energy, or concentration here is derived from the n=6 lattice
(g2/f_lattice_fit). "12 pentamers" is Caspar-Klug capsid geometry — an
observation from structural virology, never a lattice derivation.

Determinism: stdlib only (math, json, sys). No network, no random, no
wall-clock. Re-running on the same input is byte-identical.

CLI:
  python3 capsid_assembly_modulator_sim.py            # selftest + sentinel
  python3 capsid_assembly_modulator_sim.py --json     # emit JSON rows
"""
from __future__ import annotations

import json
import math
import sys

# ── physical constants ────────────────────────────────────────────────
R_KCAL = 1.987204e-3          # gas constant, kcal/(mol*K)
T_KELVIN = 310.0              # body temperature
RT = R_KCAL * T_KELVIN        # ~= 0.6160 kcal/mol

# ── Zlotnick weak-contact regime (cited real limit) ───────────────────
WEAK_CONTACT_LO = -4.5        # kcal/mol — strong end of the "weak contact" band
WEAK_CONTACT_HI = -1.5        # kcal/mol — weak end
KINETIC_TRAP_THRESHOLD = -5.0 # kcal/mol per contact: below this the contacts
                              # are over-stabilized => Zlotnick kinetic trap
SCHEMA_VERSION = "capsid_assembly_modulator_v1"


def caspar_klug_geometry(t_number: int) -> dict:
    """Exact Caspar-Klug T-number capsid geometry.

    Icosahedral capsid: 60*T subunits = 12 pentamers + 10*(T-1) hexamers.
    The capsomer polyhedron (12 pentameric + 10*(T-1) hexameric capsomers)
    satisfies Euler's V - E + F = 2.
    """
    if t_number < 1 or t_number != int(t_number):
        raise ValueError("T-number must be a positive integer")
    n_subunits = 60 * t_number
    n_pentamers = 12
    n_hexamers = 10 * (t_number - 1)
    n_capsomers = n_pentamers + n_hexamers
    # each pentamer contributes 5 edges, each hexamer 6; every edge is shared
    # by 2 capsomers => E = (5*12 + 6*n_hex)/2 ; V from Euler V = 2 - F + E.
    edges = (5 * n_pentamers + 6 * n_hexamers) // 2
    faces = n_capsomers
    vertices = 2 - faces + edges
    return {
        "t_number": t_number,
        "n_subunits": n_subunits,
        "n_pentamers": n_pentamers,
        "n_hexamers": n_hexamers,
        "n_capsomers": n_capsomers,
        "capsomer_polyhedron": {"V": vertices, "E": edges, "F": faces},
        "euler_invariant_ok": (vertices - edges + faces) == 2,
    }


def assembly_equilibrium(g_contact_kcal: float,
                         contacts_per_subunit: float = 3.0,
                         entropy_penalty_kcal: float = 3.0) -> dict:
    """Zlotnick mean-field per-subunit assembly equilibrium.

    Net per-subunit assembly free energy:
        dG_net = (z/2) * g_contact + g_entropy_penalty
    where z = inter-subunit contacts per subunit (each contact shared by 2
    subunits => z/2 contacts "owned" per subunit), g_contact < 0 favourable,
    g_entropy_penalty > 0 is the per-subunit immobilization cost.

    Pseudo-critical (dimensionless, 1 M standard-state) concentration:
        c_star = exp(dG_net / RT)
    Assembly equilibrium constant K = exp(-dG_net / RT) = 1 / c_star.
    """
    dg_net = (contacts_per_subunit / 2.0) * g_contact_kcal + entropy_penalty_kcal
    c_star = math.exp(dg_net / RT)
    k_assembly = math.exp(-dg_net / RT)
    return {"dg_net_kcal": dg_net, "c_star": c_star, "k_assembly": k_assembly}


def assembled_fraction(c_total: float, c_star: float, hill: float = 12.0) -> float:
    """Cooperative (Zlotnick-sharp) assembled fraction at total subunit
    concentration c_total. f = 0.5 exactly at c_total == c_star; monotone
    increasing in c_total; f in [0, 1].
    """
    if c_total <= 0.0:
        return 0.0
    ratio = (c_total / c_star) ** hill
    return ratio / (1.0 + ratio)


def simulate_cam(scenario: str,
                 delta_dg_kcal: float,
                 t_number: int = 1,
                 g_contact_baseline: float = -3.0,
                 c_total: float = 0.05) -> dict:
    """One CAM-scenario row: a modulator shifts g_contact by delta_dg_kcal
    (stabilizer < 0, destabilizer > 0) and we report the equilibrium shift.
    """
    geom = caspar_klug_geometry(t_number)
    base = assembly_equilibrium(g_contact_baseline)
    g_contact_cam = g_contact_baseline + delta_dg_kcal
    cam = assembly_equilibrium(g_contact_cam)
    f_base = assembled_fraction(c_total, base["c_star"])
    f_cam = assembled_fraction(c_total, cam["c_star"])
    kinetic_trap = g_contact_cam <= KINETIC_TRAP_THRESHOLD
    return {
        "schema_version": SCHEMA_VERSION,
        "scenario": scenario,
        "geometry": geom,
        "g_contact_baseline_kcal": g_contact_baseline,
        "delta_dg_modulator_kcal": delta_dg_kcal,
        "g_contact_cam_kcal": g_contact_cam,
        "c_total": c_total,
        "baseline": {"c_star": base["c_star"], "assembled_fraction": f_base},
        "modulated": {"c_star": cam["c_star"], "assembled_fraction": f_cam},
        "assembled_fraction_shift": f_cam - f_base,
        "kinetic_trap_regime": kinetic_trap,
        "honest_scope": ("in-silico simulator-consistency only (g8/f2) — "
                         "Zlotnick mean-field equilibrium + Caspar-Klug "
                         "geometry; NOT a wet-lab/binding/therapeutic claim"),
    }


# panel: baseline (no modulator), mild stabilizer, strong over-stabilizer
# (lenacapavir-style), and a destabilizer — deterministic, fixed inputs.
_PANEL = [
    ("no_modulator", 0.0),
    ("mild_stabilizer", -1.0),
    ("strong_over_stabilizer", -3.0),
    ("destabilizer", +1.5),
]


def run_panel() -> list:
    return [simulate_cam(name, ddg) for name, ddg in _PANEL]


def _selfcheck() -> int:
    rows = run_panel()
    checks = []

    # C1 — Caspar-Klug geometry exact for T in {1,3,4}
    geom_ok = True
    for t in (1, 3, 4):
        g = caspar_klug_geometry(t)
        if g["n_subunits"] != 60 * t or not g["euler_invariant_ok"]:
            geom_ok = False
    checks.append(("C1 Caspar-Klug geometry exact (60*T subunits; Euler V-E+F=2)", geom_ok))

    # C2 — baseline g_contact within the Zlotnick weak-contact band
    base_g = rows[0]["g_contact_baseline_kcal"]
    checks.append(("C2 baseline g_contact in Zlotnick weak-contact band [-4.5,-1.5]",
                   WEAK_CONTACT_LO <= base_g <= WEAK_CONTACT_HI))

    # C3 — dG <-> K round-trip self-consistency (< 1e-9)
    eq = assembly_equilibrium(base_g)
    dg_back = -RT * math.log(eq["k_assembly"])
    checks.append(("C3 dG<->K round-trip self-consistent (<1e-9)",
                   abs(dg_back - eq["dg_net_kcal"]) < 1e-9))

    # C4 — a stabilizer lowers c_star AND raises assembled fraction
    mild = rows[1]
    c4 = (mild["modulated"]["c_star"] < mild["baseline"]["c_star"]
          and mild["assembled_fraction_shift"] > 0.0)
    checks.append(("C4 stabilizer lowers c_star + raises assembled fraction", c4))

    # C5 — strong over-stabilizer triggers the kinetic-trap regime; mild does not
    c5 = (rows[2]["kinetic_trap_regime"] is True
          and rows[1]["kinetic_trap_regime"] is False
          and rows[0]["kinetic_trap_regime"] is False)
    checks.append(("C5 over-stabilizer => Zlotnick kinetic-trap flag; mild stays off", c5))

    # C6 — assembled fraction in [0,1] and monotone increasing in c_total
    cs = assembly_equilibrium(base_g)["c_star"]
    fs = [assembled_fraction(c, cs) for c in (0.2 * cs, cs, 5.0 * cs)]
    c6 = (all(0.0 <= f <= 1.0 for f in fs)
          and fs[0] < fs[1] < fs[2]
          and abs(fs[1] - 0.5) < 1e-9)
    checks.append(("C6 assembled fraction in [0,1], monotone, f=0.5 at c=c_star", c6))

    # C7 — determinism: byte-identical re-run
    c7 = json.dumps(run_panel(), sort_keys=True) == json.dumps(rows, sort_keys=True)
    checks.append(("C7 determinism — byte-identical re-run", c7))

    print("capsid_assembly_modulator_sim — CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID)\n")
    for name, ok in checks:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
    print()
    for r in rows:
        print(f"  {r['scenario']:>22s}  g_contact={r['g_contact_cam_kcal']:+.2f} kcal/mol  "
              f"c*={r['modulated']['c_star']:.4e}  f={r['modulated']['assembled_fraction']:.4f}  "
              f"Δf={r['assembled_fraction_shift']:+.4f}  trap={r['kinetic_trap_regime']}")
    n_pass = sum(1 for _, ok in checks if ok)
    n_total = len(checks)
    print(f"\n  --- summary --- {n_pass}/{n_total} PASS → verdict: "
          f"{'PASS' if n_pass == n_total else 'FAIL'} ---")
    print("  [honesty] in-silico simulator-consistency only — Caspar-Klug geometry +")
    print("  Zlotnick mean-field equilibrium. NOT a wet-lab / structural / binding /")
    print("  therapeutic / clinical / regulatory claim (g8/f2). Sub-axis :> VIROCAPSID;")
    print("  core-5 axis set UNCHANGED. No n=6-lattice derivation (g2/f_lattice_fit).")
    if n_pass == n_total:
        print("\n__CAPSID_ASSEMBLY_MODULATOR__ PASS")
        return 0
    print("\n__CAPSID_ASSEMBLY_MODULATOR__ FAIL")
    return 1


def main(argv: list) -> int:
    if "--json" in argv:
        print(json.dumps(run_panel(), indent=2, ensure_ascii=False))
        return 0
    return _selfcheck()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
