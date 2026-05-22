#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aptamer_nanobot_cross.py — CROSS-AXIS integration F2.

CROSS:  APTAMER sub-axis folding-ΔG / Langmuir-Kd binding model
        ──actuation-trigger──▶  NANOBOT-axis (DNA-nanotech) gated nanodevice.

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two so-far-uncrossed axes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent pieces:

  (1) _python_bridge/module/aptamer_affinity_sim.py — the APTAMER sub-axis
      (:> RIBOZYME core). Folds a structured oligonucleotide binder
      (Nussinov 1978 bp-max + Turner-style NN stack-sum ΔG) and runs a 1:1
      Langmuir equilibrium  A + L <=> A·L,  Kd = koff/kon,
      θ = [L]/(Kd+[L]).

  (2) nanobot/module/nanobot.hexa — the NANOBOT core-5 axis: DNA-nanotechnology
      actuation simulator, whose φ(6)=2 invariant is "bound vs unbound
      (open/closed clamp) binary actuator output".

These two have never been crossed. They MUST cross, because of how a real
aptamer-gated DNA nanodevice works: an aptamer is a functional (binding)
element EMBEDDED in a DNA nanostructure — e.g. an aptamer-gated cargo cage
whose lid is held shut by a duplex that an aptamer strand can re-fold around
its target ligand. When the trigger ligand is present, the aptamer FOLDS into
its ligand-bound pocket, opening the cage; when the ligand is absent the cage
stays shut. So the APTAMER axis's ligand-binding equilibrium is precisely the
NANOBOT axis's ACTUATION TRIGGER: the φ(6)=2 open/closed clamp output of the
DNA nanodevice is governed by the aptamer's fraction-bound θ.

────────────────────────────────────────────────────────────────────────────
THE CROSS  (governance f3 — import both sides, no fork)
────────────────────────────────────────────────────────────────────────────
For a small deterministic aptamer-gated-nanodevice panel, this module:

  * imports aptamer_affinity_sim.py and calls its `model_aptamer()` — the
    APTAMER side's Nussinov fold + Langmuir binding model is reused VERBATIM,
    never re-implemented (f3);
  * reads the NANOBOT axis's own φ(6)=2 binary-actuator-output declaration
    straight out of nanobot/module/nanobot.hexa as deterministic structural
    text — the file is NOT executed, its actuation logic is untouched (f3);
  * for each device, takes the aptamer's Langmuir fraction-bound θ at a given
    trigger-ligand concentration and maps it through a gating threshold to
    the binary NANOBOT actuator state (OPEN / CLOSED).

      trigger ligand [L] ──Langmuir θ──▶ θ vs gate ──▶ actuator OPEN/CLOSED

The cross demonstrates that the APTAMER folding-ΔG / Kd model SUPPLIES the
NANOBOT axis's actuation trigger: a stronger-binding aptamer (smaller Kd)
opens its gate at a lower trigger concentration. The actuation state is
governed by the law of mass action, not by the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
REAL LIMITS ANCHORED  (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
  * RNA/DNA secondary-structure folding thermodynamics — the nearest-neighbour
    free-energy model (SantaLucia 1998 PNAS 95:1460-1465; Turner & Mathews
    2010 NNDB, NAR 38:D280-D282): the aptamer's binding-competent pocket is
    defined by a fold whose free energy is a sum of stacked NN increments.
  * 1:1 Langmuir law-of-mass-action binding equilibrium: θ = [L]/(Kd+[L]),
    Kd = koff/kon — θ = 0.5 EXACTLY at [L] = Kd. The gating response cannot
    be sharper than this saturation isotherm allows (no Hill cooperativity is
    assumed here). This is the equilibrium real-limit anchoring the cross.

Modality precedent (described ONLY by its own precedent — g3/f1/f_lattice_fit,
NEVER lattice-derived):
  - Aptamers as a therapeutic modality: pegaptanib sodium (Macugen),
    anti-VEGF165 RNA aptamer, FDA-approved 2004; avacincaptad pegol
    (Izervay/Zimura), anti-complement-C5 RNA aptamer, FDA-approved 2023.
  - Aptamer-gated DNA nanodevices are an active structural-DNA-nanotechnology
    research area (e.g. aptamer-gated DNA-origami logic-gated nanorobots,
    Douglas, Bachelet & Church, Science 335:831-834 (2012)) — research-stage,
    NOT an approved device; stated only as the device-class precedent.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3)
────────────────────────────────────────────────────────────────────────────
  * Both sims are IMPORTED / read as data — no fork (f3). The APTAMER fold +
    Langmuir model is called verbatim; the NANOBOT .hexa actuation logic is
    not executed and not duplicated.
  * The aptamer Kd values are literature-informed illustrative magnitudes
    (from aptamer_affinity_sim.py's corpus), NOT fits to a specific dataset.
  * The mapping θ → binary OPEN/CLOSED actuator state via a gating threshold
    is a MODELING CHOICE: a real aptamer-gated nanodevice has its own strand-
    displacement kinetics, cooperativity and incomplete gating that this 1:1
    equilibrium does not capture. It is a qualitative illustration.
  * The PASS sentinel certifies IN-SILICO simulator-CONSISTENCY ONLY: that
    the chain ligand [L] → Langmuir θ → gate → actuator state is computed
    self-consistently against aptamer_affinity_sim.py and re-runs byte-
    identically. It is NOT a structural, binding-affinity, nanodevice-
    function, therapeutic or regulatory claim (g8/f2).
  * Nothing here is derived from the n=6 lattice (g2/f_lattice_fit): the fold
    ΔG is an NN stack sum, θ is the Langmuir isotherm, the gate is a θ
    threshold. φ(6)=2 "open/closed" is read as the NANOBOT axis's own
    structural declaration, never used as a derivation source.
  * Pure stdlib, no network / time / random → byte-identical re-runs.

A cross-axis bridge is NOT a new axis — the hexa-bio core-5 set
(QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED. NANOBOT is
a core axis; APTAMER is a sub-axis (:> RIBOZYME). This file only gates their
interaction and emits witness rows.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys

# ── locate the two sibling sources ──────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
_APTAMER_PATH = os.path.join(_HERE, "aptamer_affinity_sim.py")
_NANOBOT_HEXA = os.path.join(_REPO_ROOT, "nanobot", "module", "nanobot.hexa")

SCHEMA_ID = "aptamer_nanobot_cross_v1"
SENTINEL_OK = "__APTAMER_NANOBOT_CROSS__ PASS"
SENTINEL_FAIL = "__APTAMER_NANOBOT_CROSS__ FAIL"

# Gating threshold on the aptamer's Langmuir fraction-bound θ. The NANOBOT
# axis's φ(6)=2 binary actuator output is OPEN iff the aptamer is bound past
# this fraction, otherwise CLOSED. Illustrative fixed value — NOT measured,
# NOT lattice-derived (g2/f_lattice_fit).
GATING_THETA_THRESHOLD = 0.5


# ── import the APTAMER sub-axis (no fork — f3) ───────────────────────────────
def _load_aptamer_sim():
    """Import aptamer_affinity_sim.py as a module — its Nussinov fold +
    Langmuir binding model is reused verbatim (f3: no re-implementation)."""
    spec = importlib.util.spec_from_file_location(
        "aptamer_affinity_sim", _APTAMER_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── read the NANOBOT axis's own actuator-output declaration (text only — f3) ─
def _read_nanobot_actuator_basis() -> dict:
    """Read the NANOBOT core axis's own φ(6)=2 binary-actuator-output
    declaration straight out of nanobot/module/nanobot.hexa.

    This reads deterministic STRUCTURAL text only. It does NOT execute the
    .hexa file and does NOT duplicate any actuation logic (f3)."""
    with open(_NANOBOT_HEXA, "r", encoding="utf-8") as fh:
        src = fh.read()
    has_phi = ("φ(6) = 2" in src) and ("bound vs unbound" in src
                                       or "open/closed clamp" in src)
    if not has_phi:
        raise RuntimeError(
            "expected NANOBOT axis φ(6)=2 binary actuator-output declaration "
            "(bound vs unbound / open/closed clamp) in nanobot/module/nanobot.hexa")
    return {
        "nanobot_axis_source": "nanobot/module/nanobot.hexa",
        "actuator_output_declared_by_axis": (
            "φ(6)=2 binary actuator output — bound vs unbound "
            "(open/closed clamp)"),
        "axis_role": "NANOBOT core-5 axis — DNA-nanotechnology actuation "
                     "(C0b 12-vertex polyhedral-skeleton simulator)",
    }


# ── deterministic aptamer-gated-nanodevice panel ────────────────────────────
# A small illustrative panel of aptamer-gated DNA nanodevices. Each device
# couples one aptamer (from the APTAMER sub-axis's literature-anchored corpus)
# as the binding/trigger element of a gated DNA nanostructure (e.g. an
# aptamer-gated cargo cage). The trigger-ligand concentration is given as a
# multiple of that aptamer's own Kd so the gating response spans CLOSED and
# OPEN across the panel. Illustrative deterministic inputs (see HONESTY).
_DEVICE_PANEL = [
    # (device_id, aptamer_corpus_index, trigger_ligand_x_kd, device_note)
    ("tba_gated_cargo_cage_low_ligand", 0, 0.1,
     "thrombin-aptamer-gated cargo cage; trigger ligand at 0.1x Kd (sub-Kd)"),
    ("tba_gated_cargo_cage_at_kd", 0, 1.0,
     "thrombin-aptamer-gated cargo cage; trigger ligand exactly at Kd"),
    ("theophylline_gated_clamp_high_ligand", 1, 10.0,
     "theophylline-aptamer-gated clamp; trigger ligand at 10x Kd (saturating)"),
    ("atp_gated_lid_at_kd", 2, 1.0,
     "ATP-aptamer-gated lid; trigger ligand exactly at Kd"),
    ("atp_gated_lid_saturating", 2, 50.0,
     "ATP-aptamer-gated lid; trigger ligand at 50x Kd (fully saturating)"),
]


# ── the cross: ligand [L] → Langmuir θ → gate → NANOBOT actuator state ──────
def build_cross_rows(aptamer) -> list:
    """One cross row per aptamer-gated nanodevice.

    For each device: model the embedded aptamer via the APTAMER sub-axis's
    `model_aptamer()` (imported, not re-implemented — f3), evaluate its
    Langmuir fraction-bound θ at the trigger-ligand concentration, and map θ
    through the gating threshold to the binary NANOBOT actuator state.
    """
    basis = _read_nanobot_actuator_basis()
    corpus = aptamer._APTAMER_CORPUS
    rows = []
    for device_id, idx, ligand_x_kd, note in _DEVICE_PANEL:
        entry = corpus[idx]
        row_a = aptamer.model_aptamer(*entry)
        kd_M = row_a["binding"]["kd_M"]
        ligand_M = kd_M * ligand_x_kd
        # Langmuir fraction-bound θ — APTAMER sub-axis function, reused (f3).
        theta = aptamer.fraction_bound(ligand_M, kd_M)
        actuator_open = theta >= GATING_THETA_THRESHOLD
        actuator_state = "OPEN" if actuator_open else "CLOSED"
        rows.append({
            "schema": SCHEMA_ID,
            "device_id": device_id,
            "device_note": note,
            "aptamer_name": row_a["name"],
            "aptamer_sequence": row_a["sequence"],
            "aptamer_length_nt": row_a["length_nt"],
            "trigger_ligand": row_a["ligand"],
            "aptamer_paper_ref": row_a["paper_ref"],
            "fold_dot_bracket": row_a["fold"]["dot_bracket"],
            "fold_num_base_pairs": row_a["fold"]["num_base_pairs"],
            "folding_free_energy_kcal_per_mol":
                row_a["fold"]["folding_free_energy_kcal_per_mol"],
            "fold_model": row_a["fold"]["model"],
            "binding_model": row_a["binding"]["model"],
            "kd_nM": row_a["binding"]["kd_nM"],
            "kd_M": kd_M,
            "kon_M_inv_s": row_a["binding"]["kon_M_inv_s"],
            "koff_s": row_a["binding"]["koff_s"],
            "trigger_ligand_x_kd": ligand_x_kd,
            "trigger_ligand_M": ligand_M,
            "fraction_bound_theta": round(theta, 12),
            "gating_theta_threshold": GATING_THETA_THRESHOLD,
            "nanobot_axis_source": basis["nanobot_axis_source"],
            "nanobot_axis_role": basis["axis_role"],
            "actuator_output_declared_by_axis":
                basis["actuator_output_declared_by_axis"],
            "actuator_open": actuator_open,
            "actuator_state": actuator_state,
            "kcat_per_s": row_a["kcat_per_s"],  # aptamer = non-catalytic (0.0)
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "the θ→OPEN/CLOSED mapping is a modeling choice; NOT a "
                "structural/binding-affinity/nanodevice-function/therapeutic "
                "claim"),
            "illustrative_only": True,
        })
    return rows


def acceptance(rows: list, aptamer) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1–X6)."""
    opened = [r for r in rows if r["actuator_open"]]
    closed = [r for r in rows if not r["actuator_open"]]
    crit = {
        "X1_device_panel_crossed": len(rows) == len(_DEVICE_PANEL) and len(rows) >= 5,
        "X2_langmuir_model_used": all(
            "Langmuir" in r["binding_model"] for r in rows),
        "X3_nanobot_actuator_basis_read": all(
            "φ(6)=2" in r["actuator_output_declared_by_axis"] for r in rows),
        "X4_theta_half_at_kd": all(
            abs(r["fraction_bound_theta"] - 0.5) < 1e-12
            for r in rows if abs(r["trigger_ligand_x_kd"] - 1.0) < 1e-12),
        "X5_both_actuator_states_present": len(opened) >= 1 and len(closed) >= 1,
        "X6_gate_consistent_with_theta": all(
            r["actuator_open"]
            == (r["fraction_bound_theta"] >= r["gating_theta_threshold"])
            and (r["actuator_state"] == ("OPEN" if r["actuator_open"] else "CLOSED"))
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


def main() -> int:
    print("aptamer_nanobot_cross — CROSS-AXIS F2\n", flush=True)
    print("cross:  APTAMER sub-axis folding-ΔG / Langmuir-Kd binding model",
          flush=True)
    print("        ──actuation-trigger──▶  NANOBOT-axis gated DNA nanodevice",
          flush=True)
    print("        trigger ligand [L] → Langmuir θ → gate → actuator OPEN/CLOSED\n",
          flush=True)

    aptamer = _load_aptamer_sim()
    basis = _read_nanobot_actuator_basis()
    print("  real-limit anchors:")
    print("   - RNA/DNA folding thermodynamics — nearest-neighbour model")
    print("     (SantaLucia 1998 PNAS 95:1460; Turner & Mathews 2010 NAR 38:D280)")
    print("   - 1:1 Langmuir law-of-mass-action equilibrium θ = [L]/(Kd+[L]);")
    print("     θ = 0.5 exactly at [L] = Kd  (Kd = koff/kon)")
    print(f"  NANOBOT axis      : {basis['axis_role']}")
    print(f"    actuator output : {basis['actuator_output_declared_by_axis']}")
    print(f"  gating threshold  : aptamer fraction-bound θ >= "
          f"{GATING_THETA_THRESHOLD} → actuator OPEN\n", flush=True)

    rows = build_cross_rows(aptamer)
    for r in rows:
        print(f"  [{r['device_id']:<36}] actuator {r['actuator_state']:<6}")
        print(f"      aptamer={r['aptamer_name']:<28} Kd={r['kd_nM']:>8.1f} nM  "
              f"ΔG_fold={r['folding_free_energy_kcal_per_mol']:+7.2f} kcal/mol")
        print(f"      trigger [L]={r['trigger_ligand_x_kd']:>6.2f}x Kd  "
              f"θ={r['fraction_bound_theta']:.6f}  "
              f"(gate {r['gating_theta_threshold']})")

    acc = acceptance(rows, aptamer)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3)")
    print("  - Both sims are imported / read as data — no fork (f3): the APTAMER")
    print("    fold + Langmuir model is called verbatim; the NANOBOT .hexa")
    print("    actuation logic is not executed and not duplicated.")
    print("  - The aptamer Kd values are literature-informed illustrative")
    print("    magnitudes, NOT fits to a specific experimental dataset.")
    print("  - The θ → binary OPEN/CLOSED actuator mapping is a MODELING CHOICE:")
    print("    a real aptamer-gated nanodevice has strand-displacement kinetics,")
    print("    cooperativity and incomplete gating this 1:1 equilibrium omits.")
    print("  - This verdict certifies IN-SILICO simulator-CONSISTENCY ONLY: the")
    print("    chain ligand [L] → Langmuir θ → gate → actuator state is computed")
    print("    self-consistently and re-runs byte-identically. It is NOT a")
    print("    structural / binding-affinity / nanodevice-function / therapeutic")
    print("    claim (g8/f2).")
    print("  - No fold ΔG / Kd / θ / count here is derived from the n=6 lattice")
    print("    (g2/f_lattice_fit). φ(6)=2 is read as the NANOBOT axis's own")
    print("    structural declaration, never as a derivation source. A cross-axis")
    print("    bridge is NOT a new axis — the core-5 set is UNCHANGED.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",  # fixed → deterministic byte-identical re-runs
        "cross": ("F2  APTAMER sub-axis Langmuir-Kd binding model  ->  "
                  "NANOBOT-axis gated DNA-nanodevice actuation trigger"),
        "aptamer_subaxis_source": (
            "_python_bridge/module/aptamer_affinity_sim.py (Nussinov fold + "
            "Langmuir binding model imported, not re-implemented — f3)"),
        "nanobot_axis_source": (
            "nanobot/module/nanobot.hexa (φ(6)=2 binary actuator-output "
            "declaration read as structural text; actuation logic untouched — f3)"),
        "real_limit_anchors": [
            "RNA/DNA secondary-structure folding thermodynamics — nearest-"
            "neighbour model (SantaLucia 1998 PNAS 95:1460; Turner & Mathews "
            "2010 NNDB NAR 38:D280)",
            "1:1 Langmuir law-of-mass-action equilibrium θ = [L]/(Kd+[L]), "
            "Kd = koff/kon — θ = 0.5 exactly at [L] = Kd",
        ],
        "modality_precedent": (
            "aptamer modality — pegaptanib/Macugen (anti-VEGF165 RNA aptamer, "
            "FDA 2004), avacincaptad pegol/Izervay (anti-C5 RNA aptamer, FDA "
            "2023); aptamer-gated DNA nanodevice device-class — Douglas, "
            "Bachelet & Church Science 335:831 (2012, research-stage); own "
            "precedent, NOT lattice-derived (g3/f1)"),
        "gating_theta_threshold": GATING_THETA_THRESHOLD,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator-consistency ONLY (g8/f2) — the θ→OPEN/CLOSED mapping is "
            "a modeling choice, NOT a structural / binding-affinity / "
            "nanodevice-function / therapeutic claim. Core-5 axis set "
            "UNCHANGED; this is a cross, not a new axis."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n" + (SENTINEL_OK if ok else SENTINEL_FAIL))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
