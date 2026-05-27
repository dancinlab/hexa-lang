#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
reversible_covalent_mpro_vqe_cross.py — CROSS-AXIS integration A5.

CROSS:  QUANTUM-axis covalent-warhead energetics  ──parameterize──▶
        REVERSIBLE-COVALENT sub-axis Eyring kinetics.

The repo already has two independent pieces:

  (1) tests/mpro_warhead_library_vqe_v7.py — QUANTUM axis. Ranks 5 congeneric
      covalent-SARS-CoV-2-Mpro warhead classes (nitrile / aldehyde /
      alpha-ketoamide / Michael-acceptor / CF3-ketone) by a gas-phase model
      covalent-bond-formation reaction energy
          ΔE_rxn = E(adduct⁻) − E(CH3S⁻) − E(warhead)
      for the half-reaction  CH3-S(−) + warhead → [Cys-S–warhead adduct](−).
      Its own honesty note states ΔE_rxn is a QUALITATIVE warhead-reactivity
      ranking from single-point UNOPTIMISED gas-phase geometries — NOT a
      quantitative ΔG, NOT a binding affinity, NOT a therapeutic claim.

  (2) _python_bridge/module/reversible_covalent_sim.py — REVERSIBLE-COVALENT
      sub-axis. Eyring transition-state-theory covalent EQUILIBRIUM:
          kon  = (kB·T/h)·exp(−ΔG‡_on /RT)
          koff = (kB·T/h)·exp(−ΔG‡_off/RT),   ΔG‡_off = ΔG‡_on + |ΔG_rxn|
          τ_res = 1/koff,   reversible iff koff ≥ 1e-4 /s.

This module is the BRIDGE: it takes the per-warhead covalent reaction energy
ΔE_rxn from piece (1) and feeds it into the Eyring model of piece (2):

      ΔE_rxn  ──barrier-proxy──▶  ΔG‡_off  ──Eyring──▶  koff  ──▶  τ_res
                                                             ──▶  reversible?

The cross demonstrates that QUANTUM-axis-style covalent energetics
PARAMETERIZE the REVERSIBLE-COVALENT kinetics: a more strongly exothermic
covalent-bond-formation ΔE_rxn raises the reverse barrier, lowers koff, and
lengthens the modelled residence time.

────────────────────────────────────────────────────────────────────────────
HOW ΔE_rxn IS OBTAINED  (governance f3 — no fork of sister logic)
────────────────────────────────────────────────────────────────────────────
mpro_warhead_library_vqe_v7.py needs the qiskit/pyscf venv (`~/.hexabio_venv`)
and running it executes a LIVE VQE — neither is available / permitted here.
So this module does NOT re-implement that VQE/CASCI pipeline (that would be a
shadow-implementation, forbidden by f3) and does NOT run a live VQE.

Instead it parses the warhead PANEL — the 5 warhead-class identifiers and the
`warhead_class` reaction-type labels — directly out of the
`mpro_warhead_library_vqe_v7.py` source file (the deterministic, stdlib-
readable structural data), and obtains a per-warhead ΔE_rxn from a transparent,
fully-documented, deterministic stdlib SURROGATE of the *same* gas-phase
covalent-bond-formation half-reaction the QUANTUM module describes. The
surrogate reproduces the QUALITATIVE warhead-class reactivity ordering that
the QUANTUM module's own docstring establishes (nitrile/aldehyde/ketone-class
reversible adducts are near-thermoneutral; the acrylamide thio-Michael adduct
is strongly exothermic). It is NOT the qiskit/pyscf VQE total energy and is
NOT presented as such — see the HONESTY section.

If a future host has the venv, the same ΔE_rxn slot can instead be filled by
importing the QUANTUM module and reading its `results["ranking"]` — the cross
arithmetic downstream is identical.

────────────────────────────────────────────────────────────────────────────
BARRIER-PROXY MAPPING  ΔE_rxn → ΔG‡   (a MODELING CHOICE, not a measurement)
────────────────────────────────────────────────────────────────────────────
The covalent step of reversible_covalent_sim.py is parameterised by
(ΔG‡_on, ΔG_rxn). This cross sets:

    ΔG_rxn(warhead)  :=  ΔE_rxn(warhead)        — the QUANTUM-axis energy IS
                                                  taken as the covalent-step
                                                  reaction energy.
    ΔG‡_on(warhead)  :=  ΔG_ON_INTRINSIC        — a fixed intrinsic forward
                                                  barrier for the thiolate-
                                                  addition class (constant
                                                  across the congeneric set).
    ΔG‡_off          =  ΔG‡_on + |ΔG_rxn|       — microscopic reversibility
                                                  (as in reversible_covalent_sim).

Setting ΔG_rxn := ΔE_rxn is the barrier-proxy: it asserts the gas-phase
electronic reaction energy stands in for the covalent-step free energy that
drives the reverse barrier. This is a MODELING CHOICE — there is no measured
ΔE_rxn↔ΔG‡ relationship being used; entropy, solvation, the protein
environment and geometry relaxation are all omitted. It is a qualitative
propagation, not a calibrated regression.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
Eyring transition-state theory (Eyring, J. Chem. Phys. 3:107, 1935): the
unimolecular rate prefactor is bounded by the universal frequency factor
kB·T/h ≈ 6.46e12 /s at T = 310 K. No koff produced by this cross can exceed
that physical ceiling — it is the hard real limit anchoring every row, the
same TST limit anchoring reversible_covalent_sim.py and the RIBOZYME-axis
kinetics module.

Modality precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - REVERSIBLE covalent: nirmatrelvir (PF-07321332), the nitrile-warhead
    SARS-CoV-2 Mpro inhibitor of Paxlovid (Owen et al., Science 374:1586,
    2021) — the nitrile→thioimidate adduct with Cys145 is a reversible
    covalent linkage (measurable koff, finite residence time).
  - IRREVERSIBLE covalent: ibrutinib (acrylamide Michael acceptor, covalent
    BTK Cys481; Honigberg et al., PNAS 107:13075, 2010) and sotorasib
    (acrylamide, covalent KRAS-G12C Cys12; Canon et al., Nature 575:217,
    2019) — the acrylamide thio-Michael adduct is non-hydrolysing on the
    biological timescale (koff → 0).

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * NO live VQE was run. The QUANTUM-axis ΔE_rxn fed in here is a deterministic
    stdlib SURROGATE of the documented gas-phase half-reaction model — it is
    NOT the qiskit/pyscf VQE/CASCI total energy of mpro_warhead_library_vqe_v7.
  * The ΔE_rxn INPUT is, by mpro_warhead_library_vqe_v7's own admission, a
    QUALITATIVE warhead-reactivity ranking — NOT a quantitative ΔG, NOT a
    binding affinity, NOT a therapeutic claim. That caveat is carried forward.
  * The barrier-proxy ΔE_rxn → ΔG‡ is a MODELING CHOICE, not a measured
    relationship.
  * Consequently the koff and τ_res this cross prints are ILLUSTRATIVE MODEL
    OUTPUTS propagated from a qualitative input — they are NOT predictions of
    real residence times, real off-rates, real potency, or real efficacy.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that the
    chain ΔE_rxn → ΔG‡_off → koff → τ_res → reversibility is computed self-
    consistently against reversible_covalent_sim.py's Eyring functions and
    re-runs byte-identically. It is NOT an affinity / residence-time /
    selectivity / therapeutic-efficacy claim (g8/f2).
  * Pure stdlib, no network / time / random → byte-identical re-runs.

REVERSIBLE-COVALENT is a SUB-AXIS (:> COVALENT expansion-main, AXIS/
HIERARCHY.tape) — NOT one of the hexa-bio core-5 axes.
"""
from __future__ import annotations
import importlib.util
import json
import os
import re
import sys

# ── locate the two sibling sources ─────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_SIM_PATH = os.path.join(_HERE, "reversible_covalent_sim.py")
_MPRO_PATH = os.path.join(_REPO_ROOT, "tests", "mpro_warhead_library_vqe_v7.py")

SCHEMA_ID = "reversible_covalent_mpro_vqe_cross_v1"


# ── import the REVERSIBLE-COVALENT sub-axis (no fork — f3) ──────────────────
def _load_reversible_covalent_sim():
    """Import reversible_covalent_sim.py as a module — its Eyring functions
    are reused verbatim (governance f3: no shadow re-implementation)."""
    spec = importlib.util.spec_from_file_location("reversible_covalent_sim", _SIM_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── obtain the 5 warhead classes from the QUANTUM-axis module ───────────────
def _read_mpro_warhead_panel() -> list:
    """
    Parse the 5 warhead-class identifiers + `warhead_class` reaction-type
    labels straight out of mpro_warhead_library_vqe_v7.py's `WARHEADS` dict.

    This reads the deterministic STRUCTURAL data only (names + class labels);
    it does NOT import or run the module (it needs the qiskit/pyscf venv and
    running it executes a live VQE — neither permitted here). It is therefore
    NOT a fork of the VQE/CASCI logic (f3) — that logic is untouched.
    """
    with open(_MPRO_PATH, "r", encoding="utf-8") as fh:
        src = fh.read()
    # isolate the WARHEADS = { ... } literal
    start = src.index("WARHEADS = {")
    depth = 0
    end = start
    for i in range(src.index("{", start), len(src)):
        c = src[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    block = src[start:end]
    # warhead identifiers: top-level dict keys of the form  "name": (
    names = re.findall(r'^\s{4}"([A-Za-z0-9_]+)":\s*\(', block, re.MULTILINE)
    # the warhead_class label is the last quoted string of each tuple entry,
    # appearing just before the closing  "),
    classes = re.findall(r'"([A-Za-z0-9_]+)",\s*\n\s*\),', block)
    if len(names) != 5 or len(classes) != 5:
        raise RuntimeError(
            "expected 5 warheads + 5 class labels parsed from "
            "mpro_warhead_library_vqe_v7.py, got "
            f"{len(names)} names / {len(classes)} classes")
    return list(zip(names, classes))


# ── deterministic ΔE_rxn surrogate of the documented gas-phase half-reaction ─
# A transparent, fully-documented stdlib surrogate of the SAME half-reaction
# the QUANTUM module models —  CH3-S(−) + warhead → [Cys-S–warhead adduct](−).
# It reproduces the QUALITATIVE warhead-class reactivity ordering that
# mpro_warhead_library_vqe_v7.py's own docstring establishes:
#   - nitrile / aldehyde / alpha-ketoamide / CF3-ketone form REVERSIBLE
#     covalent adducts (thioimidate / thiohemiacetal / thiohemiketal) whose
#     covalent step is only mildly exothermic (near-thermoneutral) — the
#     reverse barrier is climbable;
#   - the Michael acceptor (acrylamide) forms an irreversible thio-Michael
#     adduct whose covalent step is strongly exothermic — koff → 0.
# These per-class ΔE_rxn values are illustrative literature-informed
# surrogates for the warhead CLASS (consistent with the surrogate ΔG_rxn
# panel of reversible_covalent_sim.py), NOT qiskit/pyscf VQE total energies.
# They are keyed by the `warhead_class` label parsed from the QUANTUM module.
_DE_RXN_BY_CLASS = {
    # reversible-covalent classes — near-thermoneutral covalent step (kcal/mol)
    "nitrile_to_thioimidate":          -1.5,
    "cf3ketone_to_thiohemiketal":      -0.8,
    "aldehyde_to_thiohemiacetal":      -2.5,
    "alpha_ketoamide_to_thiohemiketal": -3.0,
    # irreversible-covalent class — strongly exothermic covalent step
    "michael_to_conjugate_enolate":   -14.0,
}

# fixed intrinsic forward barrier for the congeneric thiolate-addition set
# (kcal/mol). Constant across the 5 warheads — the cross varies only ΔG_rxn,
# which is what ΔE_rxn parameterises. Sits well below the Eyring ceiling.
DG_ON_INTRINSIC = 18.0

# illustrative drug precedent per warhead class (g3/f1 — own precedent only)
_PRECEDENT_BY_CLASS = {
    "nitrile_to_thioimidate":
        "nirmatrelvir / Paxlovid — reversible covalent SARS-CoV-2 Mpro (Cys145)",
    "cf3ketone_to_thiohemiketal":
        "trifluoromethyl-ketone class — reversible covalent (hydratable adduct)",
    "aldehyde_to_thiohemiacetal":
        "GC373 / GC376 class — reversible covalent peptidyl-aldehyde",
    "alpha_ketoamide_to_thiohemiketal":
        "alpha-ketoamide 13b class — reversible covalent (Hilgenfeld)",
    "michael_to_conjugate_enolate":
        "ibrutinib / sotorasib — irreversible covalent acrylamide thio-Michael "
        "(BTK Cys481 / KRAS-G12C Cys12)",
}


def _de_rxn_for(warhead_class: str) -> float:
    """Deterministic ΔE_rxn (kcal/mol) surrogate for a parsed warhead class."""
    if warhead_class not in _DE_RXN_BY_CLASS:
        raise RuntimeError(
            f"no ΔE_rxn surrogate registered for warhead_class={warhead_class!r}")
    return _DE_RXN_BY_CLASS[warhead_class]


# ── the cross: ΔE_rxn → barrier-proxy → koff → residence → reversibility ────
def build_cross_rows(sim) -> list:
    """
    One cross row per mpro warhead class.

    For each warhead: take ΔE_rxn from the QUANTUM-axis surrogate, use it as
    the covalent-step reaction free energy (barrier-proxy), and run it through
    reversible_covalent_sim.covalent_equilibrium() — the REVERSIBLE-COVALENT
    sub-axis's Eyring model (imported, not re-implemented — f3).
    """
    panel = _read_mpro_warhead_panel()
    rows = []
    for warhead, wclass in panel:
        de_rxn = _de_rxn_for(wclass)
        # barrier-proxy: ΔG_rxn := ΔE_rxn ; ΔG‡_on := fixed intrinsic barrier.
        eq = sim.covalent_equilibrium(DG_ON_INTRINSIC, de_rxn)
        row = {
            "schema": SCHEMA_ID,
            "warhead": warhead,
            "warhead_class": wclass,
            "drug_precedent": _PRECEDENT_BY_CLASS[wclass],
            "delta_e_rxn_kcal_per_mol": de_rxn,
            "delta_e_rxn_source": (
                "deterministic stdlib surrogate of the documented gas-phase "
                "covalent-bond-formation half-reaction CH3-S(-) + warhead -> "
                "adduct(-) (mpro_warhead_library_vqe_v7.py model); NOT a live "
                "VQE total energy"),
            "barrier_proxy": "dg_rxn := delta_e_rxn (modeling choice, not measured)",
            "temperature_K": sim.TEMP_K,
            "dg_on_kcal_per_mol": eq["dg_on_kcal_per_mol"],
            "dg_off_kcal_per_mol": eq["dg_off_kcal_per_mol"],
            "dg_rxn_kcal_per_mol": eq["dg_rxn_kcal_per_mol"],
            "kon_per_s": eq["kon_per_s"],
            "koff_per_s": eq["koff_per_s"],
            "K_eq": eq["K_eq"],
            "K_eq_from_thermo": eq["K_eq_from_thermo"],
            "K_eq_consistency_rel_err": eq["K_eq_consistency_rel_err"],
            "residence_time_s": eq["residence_time_s"],
            "residence_time_human": eq["residence_time_human"],
            "eyring_prefactor_ceiling_per_s": eq["eyring_prefactor_ceiling_per_s"],
            "kon_below_eyring_ceiling": eq["kon_below_eyring_ceiling"],
            "koff_below_eyring_ceiling": eq["koff_below_eyring_ceiling"],
            "koff_reversible_threshold_per_s": eq["koff_reversible_threshold_per_s"],
            "reversibility": eq["reversibility"],
            "illustrative_only": True,
        }
        rows.append(row)
    return rows


def acceptance(rows: list, sim) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X6)."""
    rev = [r for r in rows if r["reversibility"] == "reversible"]
    irr = [r for r in rows if r["reversibility"] == "irreversible"]
    crit = {
        "X1_five_warheads_crossed": len(rows) == 5,
        "X2_de_rxn_drives_dg_rxn": all(
            abs(r["dg_rxn_kcal_per_mol"] - r["delta_e_rxn_kcal_per_mol"]) < 1e-12
            for r in rows),
        "X3_eyring_ceiling_respected": all(
            r["kon_below_eyring_ceiling"] and r["koff_below_eyring_ceiling"]
            for r in rows),
        "X4_K_eq_thermo_consistent": all(
            r["K_eq_consistency_rel_err"] < 1e-9 for r in rows),
        "X5_both_reversibility_classes_present": len(rev) >= 1 and len(irr) >= 1,
        "X6_more_exothermic_lowers_koff": all(
            # a strictly more exothermic ΔE_rxn must give a strictly smaller
            # koff (monotone parameterisation of the kinetics by the energy)
            (a["delta_e_rxn_kcal_per_mol"] > b["delta_e_rxn_kcal_per_mol"])
            == (a["koff_per_s"] > b["koff_per_s"])
            for a in rows for b in rows
            if a["delta_e_rxn_kcal_per_mol"] != b["delta_e_rxn_kcal_per_mol"]),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("reversible_covalent_mpro_vqe_cross — CROSS-AXIS A5\n", flush=True)
    print("cross:  QUANTUM-axis covalent ΔE_rxn  ──parameterize──▶  "
          "REVERSIBLE-COVALENT Eyring kinetics", flush=True)
    print("        ΔE_rxn → ΔG‡_off (barrier-proxy) → koff → τ_res → "
          "reversible/irreversible\n", flush=True)

    sim = _load_reversible_covalent_sim()
    print(f"  real-limit anchor : Eyring TST prefactor kB·T/h = "
          f"{sim.EYRING_PREFACTOR:.3e} /s @ T={sim.TEMP_K} K  (hard koff ceiling)")
    print(f"  reversibility gate: koff ≥ {sim.KOFF_REVERSIBLE_THRESHOLD:.0e} /s "
          f"→ reversible; below → irreversible")
    print(f"  fixed intrinsic forward barrier ΔG‡_on = {DG_ON_INTRINSIC:.1f} "
          f"kcal/mol (constant across the congeneric set)\n", flush=True)

    rows = build_cross_rows(sim)
    for r in rows:
        print(f"  [{r['warhead']:<26}] {r['reversibility']:<12} "
              f"ΔE_rxn={r['delta_e_rxn_kcal_per_mol']:+6.1f} kcal/mol  "
              f"({r['warhead_class']})")
        print(f"      ΔG‡_off={r['dg_off_kcal_per_mol']:.1f} kcal/mol  "
              f"koff={r['koff_per_s']:.3e}/s  K_eq={r['K_eq']:.3e}  "
              f"τ_res={r['residence_time_human']}")

    acc = acceptance(rows, sim)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - NO live VQE was run; the ΔE_rxn fed in is a deterministic stdlib")
    print("    surrogate of the documented gas-phase half-reaction model, NOT the")
    print("    qiskit/pyscf VQE/CASCI total energy of mpro_warhead_library_vqe_v7.")
    print("  - ΔE_rxn is, per that module's own docstring, a QUALITATIVE warhead-")
    print("    reactivity ranking from unoptimised single-point gas-phase geometries")
    print("    — NOT a quantitative ΔG / binding affinity / therapeutic claim.")
    print("  - The barrier-proxy ΔE_rxn → ΔG‡ is a MODELING CHOICE, not a measured")
    print("    relationship; entropy/solvation/protein-environment are omitted.")
    print("  - Therefore the koff / τ_res above are ILLUSTRATIVE model outputs")
    print("    propagated from a qualitative input — NOT predictions of real")
    print("    residence times, off-rates, potency or efficacy.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY: the")
    print("    chain ΔE_rxn → ΔG‡_off → koff → τ_res → reversibility is computed")
    print("    self-consistently and re-runs byte-identically. REVERSIBLE-COVALENT")
    print("    is a SUB-AXIS (:> COVALENT expansion-main), NOT a core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": "A5  QUANTUM-axis covalent ΔE_rxn  ->  REVERSIBLE-COVALENT Eyring kinetics",
        "quantum_axis_source": "tests/mpro_warhead_library_vqe_v7.py (warhead panel parsed; VQE/CASCI logic untouched — f3)",
        "reversible_covalent_subaxis_source": "_python_bridge/module/reversible_covalent_sim.py (Eyring model imported, not re-implemented — f3)",
        "real_limit_anchor": ("Eyring transition-state theory; universal prefactor "
                              "kB·T/h (Eyring, J. Chem. Phys. 3:107, 1935)"),
        "barrier_proxy_note": ("dg_rxn := delta_e_rxn is a modeling choice, not a "
                               "measured ΔE_rxn↔ΔG‡ relationship"),
        "live_vqe_run": False,
        "temperature_K": sim.TEMP_K,
        "dg_on_intrinsic_kcal_per_mol": DG_ON_INTRINSIC,
        "eyring_prefactor_ceiling_per_s": sim.EYRING_PREFACTOR,
        "koff_reversible_threshold_per_s": sim.KOFF_REVERSIBLE_THRESHOLD,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — koff/residence times are "
            "illustrative model outputs propagated from a qualitative ΔE_rxn "
            "input, NOT affinity / residence-time / therapeutic predictions"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__REVERSIBLE_COVALENT_MPRO_VQE_CROSS__ PASS" if ok
          else "\n__REVERSIBLE_COVALENT_MPRO_VQE_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
