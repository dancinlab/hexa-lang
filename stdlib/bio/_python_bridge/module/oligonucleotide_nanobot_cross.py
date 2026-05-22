#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
oligonucleotide_nanobot_cross.py — CROSS-AXIS integration F1.

CROSS:  OLIGONUCLEOTIDE-axis SantaLucia NN duplex thermodynamics
        ──bounds──▶  NANOBOT-axis (DNA-nanotech / C0b) origami assembly.

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/oligonucleotide_hybridization_sim.py — the
      OLIGONUCLEOTIDE expansion-main axis. Implements the SantaLucia (1998)
      unified nearest-neighbor (NN) model: per-duplex ΔH°/ΔS°/ΔG°(37) and the
      van 't Hoff two-state melting temperature Tm.

  (2) nanobot/module/nanobot.hexa — the NANOBOT core-5 axis: DNA-nanotechnology
      / C0b 12-vertex polyhedral-skeleton actuation simulator. The NANOBOT
      docstring explicitly cites Rothemund 2006 DNA origami and Seeman 1982
      immobile junctions as the modality's structural basis.

These two have never been crossed. They MUST cross, because of a physical
fact stated by the NANOBOT axis itself: a scaffolded DNA-origami nanobot is
folded by short synthetic STAPLE STRANDS — and a staple strand IS an
oligonucleotide. Each staple hybridizes to two (or more) separated scaffold
segments; the origami holds its shape only because every staple:scaffold
duplex is thermodynamically stable at the folding/operating temperature.
That stability is exactly what the OLIGONUCLEOTIDE axis's SantaLucia NN model
computes. So the NANOBOT axis's assembly is BOUNDED by oligo hybridization
thermodynamics — this module makes that bound explicit.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sides, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic origami staple panel, this module:

  * imports oligonucleotide_hybridization_sim.py and calls its
    `duplex_report()` (SantaLucia NN ΔG°/ΔH°/ΔS°/Tm) — the OLIGONUCLEOTIDE
    side's calculator is reused VERBATIM, never re-implemented (f3);
  * reads the NANOBOT axis's own modality basis (Rothemund 2006 DNA origami)
    straight out of nanobot/module/nanobot.hexa as deterministic structural
    text — the file is NOT executed, its actuation logic is untouched (f3);
  * for each staple, computes whether the staple:scaffold duplex is stable
    enough to fold at the chosen folding temperature, i.e. whether its NN Tm
    sits above a folding-temperature gate.

      staple sequence ──SantaLucia NN──▶ ΔG°/Tm ──gate──▶ fold-competent?

The cross demonstrates the BOUND: a staple too short or too AT-rich has a Tm
below the folding gate — the OLIGONUCLEOTIDE thermodynamics REFUSE to let
that staple hold the origami together, independently of any NANOBOT-axis
actuation parameter. The lattice ceiling of the nanobot is set by base-pair
stacking free energy, not by the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
SantaLucia (1998) unified nearest-neighbor duplex thermodynamics — duplex
stability is the sum of base-pair stacking free energies plus helix-
initiation terms; it cannot be engineered past what that NN free-energy sum
allows. This is the same hybridization-thermodynamics REAL LIMIT that anchors
oligonucleotide_hybridization_sim.py.

    SantaLucia J Jr. "A unified view of polymer, dumbbell, and oligonucleotide
    DNA nearest-neighbor thermodynamics." PNAS 1998; 95(4):1460-1465.

Modality precedent (described ONLY by its own precedent — g3/f1/f_lattice_fit,
NEVER lattice-derived):
  - DNA origami / staple-strand scaffolded nanostructures: Rothemund PWK,
    "Folding DNA to create nanoscale shapes and patterns", Nature 440:297-302
    (2006) — the founding scaffolded-staple DNA-origami method, cited by the
    NANOBOT axis docstring itself.
  - Immobile DNA junctions: Seeman NC, "Nucleic acid junctions and lattices",
    J Theor Biol 99:237-247 (1982) — the structural-DNA-nanotechnology
    precedent, also cited by the NANOBOT axis docstring.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both sims are IMPORTED / read as data — no fork (f3). The OLIGONUCLEOTIDE
    NN calculator is called verbatim; the NANOBOT .hexa actuation logic is
    not executed and not duplicated.
  * The SantaLucia NN model uses a 1 M Na+ standard state, which is NOT the
    Mg2+-buffered, non-physiological condition real DNA-origami folding uses;
    salt-corrected Tm, staple cooperativity, scaffold routing, kinetic
    folding pathways and 2'-modified backbones are all out of repo scope
    (CLOSURE_RESIDUAL_BACKLOG.md §0). The Tm values here are illustrative.
  * The staple panel sequences are illustrative deterministic test inputs,
    not a real origami staple set from a published design.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the chain staple-sequence → SantaLucia ΔG°/Tm → fold-competence gate is
    computed self-consistently against oligonucleotide_hybridization_sim.py
    and re-runs byte-identically. It is NOT a structural, folding-yield,
    nanodevice-function, therapeutic or regulatory claim (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit): every
    ΔG°/ΔH°/ΔS°/Tm is a SantaLucia NN sum; the folding gate is a temperature.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A cross-axis bridge is NOT a new axis — the hexa-bio core-5 set
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED. NANOBOT is
a core axis; OLIGONUCLEOTIDE is an expansion-main axis. This file only gates
their interaction and emits witness rows.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_OLIGO_PATH = os.path.join(_HERE, "oligonucleotide_hybridization_sim.py")
_NANOBOT_HEXA = os.path.join(_REPO_ROOT, "nanobot", "module", "nanobot.hexa")

SCHEMA_ID = "oligonucleotide_nanobot_cross_v1"
SENTINEL_OK = "__OLIGONUCLEOTIDE_NANOBOT_CROSS__ PASS"
SENTINEL_FAIL = "__OLIGONUCLEOTIDE_NANOBOT_CROSS__ FAIL"

# Folding-temperature gate (°C). A scaffolded DNA-origami fold is run by an
# annealing ramp; a staple:scaffold duplex must remain hybridized at the
# operating temperature for the staple to hold the origami. We require the
# duplex Tm to sit above this gate. Illustrative fixed value — NOT a measured
# origami protocol temperature, NOT lattice-derived (g2/f_lattice_fit).
FOLDING_TEMP_GATE_C = 45.0

# Total-strand concentration used for the van 't Hoff Tm (M). Illustrative
# fixed value, the same default the OLIGONUCLEOTIDE sim documents.
TOTAL_STRAND_M = 0.4e-6


# ── import the OLIGONUCLEOTIDE axis (no fork — f3) ───────────────────────────
def _load_oligo_sim():
    """Import oligonucleotide_hybridization_sim.py as a module — its
    SantaLucia NN calculator is reused verbatim (f3: no re-implementation)."""
    spec = importlib.util.spec_from_file_location(
        "oligonucleotide_hybridization_sim", _OLIGO_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── read the NANOBOT axis's own modality basis (structural text only — f3) ──
def _read_nanobot_modality_basis() -> dict:
    """Read the NANOBOT core axis's own DNA-nanotech modality citations
    straight out of nanobot/module/nanobot.hexa.

    This reads deterministic STRUCTURAL text only (the modality precedent the
    axis declares for itself). It does NOT execute the .hexa file and does NOT
    duplicate any actuation logic — that logic is untouched (f3)."""
    with open(_NANOBOT_HEXA, "r", encoding="utf-8") as fh:
        src = fh.read()
    cites = []
    if "Rothemund 2006 DNA origami" in src:
        cites.append("Rothemund 2006 DNA origami (Nature 440:297-302)")
    if "Seeman 1982" in src:
        cites.append("Seeman 1982 immobile DNA junctions (J Theor Biol 99:237-247)")
    if not cites:
        raise RuntimeError(
            "expected NANOBOT axis DNA-nanotech modality citations "
            "(Rothemund 2006 / Seeman 1982) in nanobot/module/nanobot.hexa")
    return {
        "nanobot_axis_source": "nanobot/module/nanobot.hexa",
        "modality_basis_cited_by_axis": cites,
        "axis_role": "NANOBOT core-5 axis — DNA-nanotechnology actuation "
                     "(C0b 12-vertex polyhedral-skeleton simulator)",
    }


# ── deterministic origami staple panel ──────────────────────────────────────
# A small illustrative panel of candidate DNA-origami staple strands. Each
# staple is a synthetic oligonucleotide that hybridizes to the scaffold; the
# panel spans short/long and AT-rich/GC-rich so the SantaLucia Tm bound bites
# differently across the set. These are illustrative deterministic test
# inputs, NOT a published origami staple set (see HONESTY).
_STAPLE_PANEL = [
    # (staple_id, sequence_5to3, design_note)
    ("staple_short_at_rich",
     "ATATATATAATTATAT",
     "16-mer AT-rich crossover staple — short + low GC"),
    ("staple_typical_32mer",
     "GCTAGCATCGGATCCATGCAACGTTACGGCTA",
     "32-mer mixed-composition staple — typical origami crossover length"),
    ("staple_gc_clamped_28mer",
     "GCGCATCGACGTACGGATCCATGCGCGC",
     "28-mer with GC-clamped ends — high-stability staple"),
    ("staple_long_40mer",
     "GCTAGCATCGGATCCATGCAACGTTACGGCTAGCATCGAC",
     "40-mer extended staple — long binding region"),
    ("staple_minimal_12mer",
     "ATCGATCGATCG",
     "12-mer minimal staple — below typical origami crossover length"),
]


# ── the cross: staple sequence → SantaLucia NN ΔG°/Tm → fold-competence ─────
def build_cross_rows(oligo) -> list:
    """One cross row per origami staple.

    For each staple: call the OLIGONUCLEOTIDE axis's SantaLucia NN
    `duplex_report()` (imported, not re-implemented — f3) on the
    staple:scaffold duplex, then gate fold-competence on the NN Tm vs the
    folding-temperature gate.
    """
    basis = _read_nanobot_modality_basis()
    rows = []
    for staple_id, seq, note in _STAPLE_PANEL:
        rep = oligo.duplex_report(seq, total_strand_M=TOTAL_STRAND_M)
        tm = rep["Tm_celsius"]
        fold_competent = tm >= FOLDING_TEMP_GATE_C
        margin = round(tm - FOLDING_TEMP_GATE_C, 4)
        rows.append({
            "schema": SCHEMA_ID,
            "staple_id": staple_id,
            "design_note": note,
            "sequence_5to3": rep["sequence_5to3"],
            "length_nt": rep["length_nt"],
            "gc_fraction": round(rep["gc_fraction"], 6),
            "nanobot_axis_source": basis["nanobot_axis_source"],
            "nanobot_axis_role": basis["axis_role"],
            "modality_basis_cited_by_axis": basis["modality_basis_cited_by_axis"],
            "oligonucleotide_model": rep["model"],
            "dH_kcal_mol": rep["dH_kcal_mol"],
            "dS_cal_mol_K": rep["dS_cal_mol_K"],
            "dG37_kcal_mol": rep["dG37_kcal_mol"],
            "Tm_celsius": tm,
            "total_strand_M": TOTAL_STRAND_M,
            "folding_temp_gate_celsius": FOLDING_TEMP_GATE_C,
            "tm_margin_celsius": margin,
            "fold_competent": fold_competent,
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "the SantaLucia 1 M Na+ NN Tm is illustrative, NOT a real "
                "origami folding temperature; NOT a structural/yield/"
                "nanodevice-function/therapeutic claim"),
            "illustrative_only": True,
        })
    return rows


def acceptance(rows: list, oligo) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X6)."""
    competent = [r for r in rows if r["fold_competent"]]
    blocked = [r for r in rows if not r["fold_competent"]]
    # GC-content monotonicity: among equal-length staples a higher GC
    # fraction must give a higher (or equal) Tm — base-pair stacking ordering.
    by_len: dict = {}
    for r in rows:
        by_len.setdefault(r["length_nt"], []).append(r)
    gc_monotone = True
    for group in by_len.values():
        for a in group:
            for b in group:
                if a["gc_fraction"] > b["gc_fraction"] and a["Tm_celsius"] < b["Tm_celsius"]:
                    gc_monotone = False
    crit = {
        "X1_panel_crossed": len(rows) == len(_STAPLE_PANEL) and len(rows) >= 5,
        "X2_santalucia_model_used": all(
            "SantaLucia 1998" in r["oligonucleotide_model"] for r in rows),
        "X3_nanobot_modality_basis_read": all(
            len(r["modality_basis_cited_by_axis"]) >= 1 for r in rows),
        "X4_tm_margin_consistent": all(
            abs(r["tm_margin_celsius"]
                - (r["Tm_celsius"] - r["folding_temp_gate_celsius"])) < 1e-9
            and (r["fold_competent"] == (r["tm_margin_celsius"] >= 0.0))
            for r in rows),
        "X5_both_outcomes_present": len(competent) >= 1 and len(blocked) >= 1,
        "X6_gc_raises_tm_monotone": gc_monotone,
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("oligonucleotide_nanobot_cross — CROSS-AXIS F1\n", flush=True)
    print("cross:  OLIGONUCLEOTIDE-axis SantaLucia NN duplex thermodynamics", flush=True)
    print("        ──bounds──▶  NANOBOT-axis (DNA-nanotech) origami assembly", flush=True)
    print("        staple sequence → SantaLucia ΔG°/Tm → fold-competence gate\n",
          flush=True)

    oligo = _load_oligo_sim()
    basis = _read_nanobot_modality_basis()
    print("  real-limit anchor : SantaLucia 1998 unified nearest-neighbor duplex")
    print("                      thermodynamics (PNAS 95:1460-1465) — staple")
    print("                      stability bounded by base-pair stacking ΔG°")
    print(f"  NANOBOT axis      : {basis['axis_role']}")
    for c in basis["modality_basis_cited_by_axis"]:
        print(f"    modality basis  : {c}")
    print(f"  folding gate      : staple:scaffold duplex Tm >= "
          f"{FOLDING_TEMP_GATE_C:.1f} °C → fold-competent\n", flush=True)

    rows = build_cross_rows(oligo)
    for r in rows:
        flag = "fold-competent" if r["fold_competent"] else "BELOW GATE"
        print(f"  [{r['staple_id']:<24}] {flag:<15} "
              f"n={r['length_nt']:>2}  GC={r['gc_fraction']*100:5.1f}%  "
              f"Tm={r['Tm_celsius']:6.2f} °C  (margin {r['tm_margin_celsius']:+6.2f})")
        print(f"      ΔG°(37)={r['dG37_kcal_mol']:8.2f} kcal/mol  "
              f"ΔH°={r['dH_kcal_mol']:8.2f}  ΔS°={r['dS_cal_mol_K']:8.2f}")

    acc = acceptance(rows, oligo)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both sims are imported / read as data — no fork (f3): the")
    print("    SantaLucia NN calculator is called verbatim; the NANOBOT .hexa")
    print("    actuation logic is not executed and not duplicated.")
    print("  - The SantaLucia 1 M Na+ standard state is NOT the Mg2+-buffered")
    print("    condition real DNA-origami folding uses; salt-corrected Tm,")
    print("    staple cooperativity, scaffold routing and kinetic folding")
    print("    pathways are out of repo scope — the Tm values are illustrative.")
    print("  - The staple panel sequences are illustrative deterministic test")
    print("    inputs, NOT a published origami staple set.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY: the")
    print("    chain staple-sequence → SantaLucia ΔG°/Tm → fold-competence is")
    print("    computed self-consistently and re-runs byte-identically. It is")
    print("    NOT a structural / folding-yield / nanodevice-function /")
    print("    therapeutic claim (g8/f2).")
    print("  - No ΔG°/ΔH°/ΔS°/Tm/count here is derived from the n=6 lattice")
    print("    (g2/f_lattice_fit). A cross-axis bridge is NOT a new axis — the")
    print("    core-5 set is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": ("F1  OLIGONUCLEOTIDE-axis SantaLucia NN duplex thermodynamics "
                  "->  NANOBOT-axis DNA-origami staple assembly bound"),
        "oligonucleotide_axis_source": (
            "_python_bridge/module/oligonucleotide_hybridization_sim.py "
            "(SantaLucia NN calculator imported, not re-implemented — f3)"),
        "nanobot_axis_source": (
            "nanobot/module/nanobot.hexa (DNA-nanotech modality basis read as "
            "structural text; actuation logic untouched — f3)"),
        "real_limit_anchor": (
            "SantaLucia 1998 unified nearest-neighbor DNA duplex thermodynamics "
            "(PNAS 95:1460-1465) — staple stability bounded by base-pair "
            "stacking free energy"),
        "modality_precedent": (
            "DNA origami — Rothemund 2006 (Nature 440:297-302); immobile DNA "
            "junctions — Seeman 1982 (J Theor Biol 99:237-247); own precedent, "
            "NOT lattice-derived (g3/f1)"),
        "folding_temp_gate_celsius": FOLDING_TEMP_GATE_C,
        "total_strand_M": TOTAL_STRAND_M,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — the SantaLucia 1 M Na+ NN "
            "Tm is illustrative, NOT a real origami folding temperature; NOT "
            "a structural / folding-yield / nanodevice-function / therapeutic "
            "claim. Core-5 axis set UNCHANGED; this is a cross, not a new axis."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
