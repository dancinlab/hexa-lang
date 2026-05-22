#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
protac_capsid_modulator_cross.py — CROSS-AXIS integration G1.

CROSS:  PROTAC sub-axis ternary-complex hook effect (mass-action +
        cooperativity, drives DEGRADATION via E3-mediated ubiquitin transfer)
        ──shared mathematical structure──▶
        CAPSID-ASSEMBLY-MODULATOR sub-axis kinetic-trap regime (mass-action +
        cooperativity, drives ABERRANT ASSEMBLY via per-contact over-
        stabilization).

────────────────────────────────────────────────────────────────────────────
WHAT THIS CROSSES  (two non-monotone, cooperativity-driven regimes)
────────────────────────────────────────────────────────────────────────────
The repo already has two independent sub-axis sims:

  (1) _python_bridge/module/protac_sim.py — PROTAC sub-axis (:> BIFUNCTIONAL
      expansion-main). Mass-action + three-body cooperativity (Douglass et al.
      JACS 135:6092, 2013; Gadd et al. Nat. Chem. Biol. 13:514, 2017). The
      ternary-complex fraction is NON-MONOTONE in [PROTAC] — at high degrader
      concentration the binary POI·PROTAC and E3·PROTAC species out-compete
      the productive ternary complex (the classic HOOK EFFECT). Positive
      cooperativity (alpha > 1) lowers the apparent ternary K_d = K_d(E3)/alpha
      and raises the peak; negative cooperativity (alpha < 1) suppresses it.

  (2) _python_bridge/module/capsid_assembly_modulator_sim.py — CAPSID-
      ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID core). Mass-action assembly
      equilibrium under Caspar-Klug T-number geometry (Caspar & Klug, CSHSQB
      27:1, 1962) + Zlotnick weak-contact thermodynamics (Zlotnick,
      Biochemistry 33:1233, 1994; J. Mol. Recognit. 16:294, 2003). The
      cooperative (Hill-sharp) assembled fraction is monotone increasing in
      c_total but a per-contact OVER-stabilization (g_contact below the weak-
      contact band) traps the system in incomplete / aberrant intermediates
      (the KINETIC TRAP regime) — the cooperative assembly can no longer
      anneal defects.

Both rest on the SAME mathematical scaffold:

      mass-action equilibrium (theta = [L]/(K_d + [L]); f = 0.5 at c = c_star)
    + a cooperativity term (alpha for PROTAC; Hill exponent for CAM
      driving sharp, all-or-nothing assembly transitions)
    + a non-monotone or trap regime when the perturbation grows too large

This module is the BRIDGE: it scans a paired PROTAC-cooperativity ladder
alongside a CAM-perturbation ladder and reports, ROW-BY-ROW, the regime
signature each model produces — the PROTAC HOOK EFFECT signature (interior
peak in the ternary-fraction profile, non-monotone in [degrader]) versus
the CAM KINETIC-TRAP signature (g_contact below KINETIC_TRAP_THRESHOLD).
The cross demonstrates a shared cooperativity-vs-perturbation framework
without claiming the two regimes are mechanistically equivalent.

────────────────────────────────────────────────────────────────────────────
HONESTY  (governance g3 / g8 / forbidden-patterns f1 / f2 / f3 / f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
This comparison reports TWO DISTINCT PHENOMENA THAT SHARE MATHEMATICAL
STRUCTURE (mass-action equilibrium + a cooperativity term + a regime where
the perturbation magnitude is non-monotone-/-trap-inducing). It is NOT a
claim that they are MECHANISTICALLY EQUIVALENT:

  - A PROTAC degrades a target protein (E3-recruited ternary complex →
    polyubiquitination → 26S proteasome). The "non-monotone in perturbation"
    is in DEGRADER DOSE; the trap is a SATURATION OF BINARY SPECIES at high
    [PROTAC].
  - A CAM perturbs viral capsid self-assembly (per-contact ΔG shift →
    Zlotnick equilibrium shift → kinetic trap). The "non-monotone in
    perturbation" is in PER-CONTACT FREE ENERGY; the trap is an INABILITY
    TO ANNEAL incomplete intermediates when contacts are too strong.

Very different biology, very different targets, very different mechanisms.
What is shared is the MATHEMATICAL STRUCTURE — the cooperativity-times-
perturbation framework that organises both regimes. The PASS sentinel
certifies IN-SILICO simulator+metadata internal consistency ONLY (g8/f2):
the two parent sims' regime signatures (PROTAC hook-effect present-flag;
CAM kinetic-trap-regime flag) are computed self-consistently and reproduce
byte-identically. It is NOT a binding-affinity / DC50 / Dmax claim, NOT a
capsid-stability / antiviral-potency claim, NOT a therapeutic-efficacy
claim of any kind.

Modality precedent (g3/f1 — described ONLY by own drug precedent, NEVER
lattice-derived):
  - PROTAC: ARV-471 (vepdegestrant, ER PROTAC) / ARV-110 (bavdegalutamide,
    AR PROTAC) — clinical-stage (Arvinas; chemistry traced to Sakamoto et
    al. PNAS 98:8554, 2001).
  - CAM: lenacapavir / Sunlenca — HIV-1 capsid inhibitor, small-molecule
    (CDER) FDA-approved 2022; over-stabilizes the capsid lattice. HBV CAMs
    (vebicorvir / JNJ-56136379 / GLS4) — clinical-stage.

No count, energy, concentration, or fraction in this module is derived
from the n=6 lattice (g2 / f_lattice_fit). "12 pentamers" comes from
Caspar-Klug structural virology, never from the n=6 invariant lattice.
Three-body ternary equilibrium comes from the Douglass mass-action model,
never from the n=6 lattice.

Both PROTAC and CAPSID-ASSEMBLY-MODULATOR are SUB-AXES; the hexa-bio core-5
axis set (QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID) is UNCHANGED.

Determinism: stdlib only (importlib, json, os, sys, math). No network, no
random, no wall-clock. Re-running on the same input is byte-identical.

CLI:
  python3 protac_capsid_modulator_cross.py            # cross + acceptance + sentinel
"""
from __future__ import annotations

import importlib.util
import json
import math
import os
import sys

# ── locate the two sibling sources ─────────────────────────────────────────
_HERE = os.path.dirname(os.path.abspath(__file__))
_PROTAC_PATH = os.path.join(_HERE, "protac_sim.py")
_CAM_PATH = os.path.join(_HERE, "capsid_assembly_modulator_sim.py")
_SCHEMA_PATH = os.path.abspath(
    os.path.join(_HERE, "..", "spec",
                 "protac_capsid_modulator_cross_v1.schema.json"))

SCHEMA_ID = "protac_capsid_modulator_cross_v1"


# ── import BOTH sub-axis sims (no fork — governance f3) ────────────────────
def _load_module(name: str, path: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_protac_sim():
    """Import protac_sim.py verbatim — its mass-action + cooperativity
    ternary-complex and hook-effect machinery is reused, never re-implemented
    (governance f3)."""
    return _load_module("protac_sim", _PROTAC_PATH)


def _load_cam_sim():
    """Import capsid_assembly_modulator_sim.py verbatim — its Caspar-Klug
    + Zlotnick assembly-equilibrium and kinetic-trap machinery is reused,
    never re-implemented (governance f3)."""
    return _load_module("capsid_assembly_modulator_sim", _CAM_PATH)


# ── deterministic paired ladder ────────────────────────────────────────────
# Each row pairs one PROTAC-cooperativity scenario (alpha, named in
# protac_sim's PROTAC_PANEL) with one CAM-perturbation scenario (delta_dg,
# matched roughly to the magnitude of the PROTAC perturbation: strong
# positive cooperativity <-> strong over-stabilization; mild positive
# cooperativity <-> mild stabilization; no cooperativity <-> no
# perturbation; negative cooperativity <-> destabilization). The pairing
# is a deterministic ORGANISATIONAL choice for honest side-by-side
# reporting under the shared cooperativity-vs-perturbation framework — it
# is NOT a claim that cooperativity factor alpha and per-contact ΔΔG are
# physically equivalent perturbations.
_PAIRED_LADDER = [
    # (pair_id, protac_panel_name, cam_scenario_name, cam_delta_dg_kcal, note)
    ("none_vs_none",
     "noncoop_PROTAC_like", "no_modulator", 0.0,
     "no cooperativity / no perturbation — baseline reference for both axes"),
    ("mild_pos_vs_mild_stab",
     "AR_PROTAC_ARV110_like", "mild_stabilizer", -1.0,
     "mild positive PROTAC cooperativity paired with a mild CAM stabilizer"),
    ("strong_pos_vs_over_stab",
     "strongcoop_PROTAC_like", "strong_over_stabilizer", -3.0,
     "strong positive PROTAC cooperativity paired with a CAM over-stabilizer"),
    ("vhl_brd4_vs_over_stab",
     "BRD4_VHL_PROTAC_like", "strong_over_stabilizer", -3.0,
     "VHL/BRD4-class PROTAC (Gadd 2017) paired with a CAM over-stabilizer"),
    ("er_arv471_vs_mild_stab",
     "ER_PROTAC_ARV471_like", "mild_stabilizer", -1.0,
     "ARV-471-like ER PROTAC paired with a mild CAM stabilizer"),
    ("neg_vs_destab",
     "negcoop_PROTAC_like", "destabilizer", +1.5,
     "negative PROTAC cooperativity paired with a CAM destabilizer"),
]

# CAM reference geometry / total-subunit concentration — the same defaults
# used by capsid_assembly_modulator_sim.simulate_cam (g_contact_baseline=-3.0,
# c_total=0.05, T=1). We feed these explicitly so the cross is hermetic.
_CAM_T_NUMBER = 1
_CAM_BASELINE_G_CONTACT_KCAL = -3.0
_CAM_C_TOTAL = 0.05


def _protac_row_from_panel(protac_sim, panel_name: str) -> dict:
    """Look up one named entry in protac_sim.PROTAC_PANEL and run the
    sub-axis's own degrader_profile() on it (f3 — sub-axis machinery
    reused verbatim)."""
    for name, kd_t, kd_e3, alpha, te, e3, precedent in protac_sim.PROTAC_PANEL:
        if name == panel_name:
            prof = protac_sim.degrader_profile(kd_t, kd_e3, alpha, te)
            return {
                "protac": name,
                "e3_ligase": e3,
                "drug_precedent": precedent,
                "kd_target_nM": kd_t,
                "kd_e3_nM": kd_e3,
                "alpha_cooperativity": alpha,
                "cooperativity_class": prof["cooperativity_class"],
                "kd_ternary_apparent_nM": prof["kd_ternary_apparent_nM"],
                "transfer_efficiency": te,
                "ternary_fraction_peak": prof["ternary_fraction_peak"],
                "protac_at_peak_nM": prof["protac_at_peak_nM"],
                "hook_effect_present": prof["hook_effect_present"],
                "degradation_drive": prof["degradation_drive"],
            }
    raise RuntimeError(
        f"PROTAC panel entry {panel_name!r} not found in protac_sim.PROTAC_PANEL")


def _cam_row(cam_sim, scenario: str, delta_dg_kcal: float) -> dict:
    """Run capsid_assembly_modulator_sim.simulate_cam() with the cross's
    deterministic reference geometry + c_total (f3 — sub-axis machinery
    reused verbatim)."""
    sim_row = cam_sim.simulate_cam(
        scenario, delta_dg_kcal,
        t_number=_CAM_T_NUMBER,
        g_contact_baseline=_CAM_BASELINE_G_CONTACT_KCAL,
        c_total=_CAM_C_TOTAL,
    )
    geom = sim_row["geometry"]
    return {
        "scenario": scenario,
        "drug_precedent": (
            "lenacapavir (Sunlenca) — HIV-1 capsid inhibitor, FDA 2022; "
            "HBV CAMs (vebicorvir / JNJ-56136379 / GLS4) — clinical"),
        "t_number": geom["t_number"],
        "n_subunits": geom["n_subunits"],
        "n_pentamers": geom["n_pentamers"],
        "n_hexamers": geom["n_hexamers"],
        "euler_invariant_ok": geom["euler_invariant_ok"],
        "g_contact_baseline_kcal": sim_row["g_contact_baseline_kcal"],
        "delta_dg_modulator_kcal": sim_row["delta_dg_modulator_kcal"],
        "g_contact_cam_kcal": sim_row["g_contact_cam_kcal"],
        "c_total": sim_row["c_total"],
        "baseline_c_star": sim_row["baseline"]["c_star"],
        "baseline_assembled_fraction": sim_row["baseline"]["assembled_fraction"],
        "perturbed_c_star": sim_row["modulated"]["c_star"],
        "perturbed_assembled_fraction": sim_row["modulated"]["assembled_fraction"],
        "assembled_fraction_shift": sim_row["assembled_fraction_shift"],
        "kinetic_trap_regime": sim_row["kinetic_trap_regime"],
    }


def _shared_magnitudes(protac_side: dict, cam_side: dict) -> dict:
    """Two unit-distinct, model-distinct magnitudes summarising each side's
    perturbation strength under the shared cooperativity-vs-perturbation
    framework. Reported side-by-side; NEVER summed or normalised to one
    another — they are not physically commensurate quantities.
    """
    # PROTAC: |log10(alpha)|  — magnitude (in decades) by which positive (or
    # negative) cooperativity shifts the apparent ternary K_d = K_d(E3)/alpha
    # away from the no-cooperativity baseline (alpha = 1).
    alpha = protac_side["alpha_cooperativity"]
    protac_mag_log10 = abs(math.log10(alpha)) if alpha > 0.0 else 0.0
    # CAM: |delta_dg| — magnitude (kcal/mol) of the per-contact modulator
    # perturbation off the Zlotnick weak-contact baseline g_contact.
    cam_mag_kcal = abs(cam_side["delta_dg_modulator_kcal"])
    return {
        "protac_cooperativity_log10_alpha_magnitude": protac_mag_log10,
        "cam_delta_dg_abs_kcal_magnitude": cam_mag_kcal,
        "note": (
            "Two perturbation magnitudes on DIFFERENT axes with DIFFERENT "
            "units — reported side-by-side under the shared cooperativity-"
            "vs-perturbation framework. NOT physically commensurate; never "
            "summed or normalised to each other."),
    }


def _regime_signature(protac_side: dict, cam_side: dict) -> dict:
    """Two regime flags reported side-by-side.

    PROTAC hook-effect regime: ternary-fraction profile peak is INTERIOR
    to the [PROTAC] grid (non-monotone) — driven by binary E3·PROTAC and
    POI·PROTAC species out-competing the productive ternary complex at
    high [PROTAC]. CAM kinetic-trap regime: per-contact free energy
    g_contact has dropped below KINETIC_TRAP_THRESHOLD (over-stabilized)
    — the cooperative assembly can no longer anneal defects.
    """
    return {
        "protac_regime": (
            "hook-effect (non-monotone in [degrader], interior peak)"
            if protac_side["hook_effect_present"]
            else "no-hook (monotone in [degrader])"),
        "protac_signature_flag": protac_side["hook_effect_present"],
        "cam_regime": (
            "kinetic-trap (g_contact below Zlotnick weak-contact band)"
            if cam_side["kinetic_trap_regime"]
            else "weak-contact (normal Zlotnick assembly)"),
        "cam_signature_flag": cam_side["kinetic_trap_regime"],
    }


# ── the cross: paired regime signatures under one framework ────────────────
def build_cross_rows(protac_sim, cam_sim) -> list:
    """One cross row per paired (PROTAC-cooperativity, CAM-perturbation)
    entry from _PAIRED_LADDER. Each row reports BOTH regimes' signatures
    plus the side-by-side cooperativity-vs-perturbation magnitudes.
    """
    rows = []
    for pair_id, protac_name, cam_name, ddg, note in _PAIRED_LADDER:
        protac_side = _protac_row_from_panel(protac_sim, protac_name)
        cam_side = _cam_row(cam_sim, cam_name, ddg)
        sig = _regime_signature(protac_side, cam_side)
        mag = _shared_magnitudes(protac_side, cam_side)
        rows.append({
            "schema": SCHEMA_ID,
            "pair_id": pair_id,
            "pair_note": note,
            "protac_axis": "PROTAC sub-axis (:> BIFUNCTIONAL expansion-main)",
            "cam_axis": "CAPSID-ASSEMBLY-MODULATOR sub-axis (:> VIROCAPSID core)",
            "protac_side": protac_side,
            "cam_side": cam_side,
            "regime_signature": sig,
            "shared_magnitudes": mag,
            "framework": (
                "mass-action equilibrium + a cooperativity term + a regime "
                "where the perturbation magnitude drives non-monotone "
                "(PROTAC hook) or trap (CAM over-stabilization) behaviour"),
            "in_silico_caveat": (
                "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
                "two distinct phenomena that SHARE MATHEMATICAL STRUCTURE; "
                "NOT a claim of mechanistic equivalence. PROTAC degrades a "
                "protein; CAM perturbs capsid self-assembly. Very different "
                "biology. NOT a binding-affinity / DC50 / Dmax / antiviral / "
                "therapeutic claim."),
            "illustrative_only": True,
        })
    return rows


# ── inline schema validation (stdlib only — no external jsonschema dep) ────
def _load_schema() -> dict:
    with open(_SCHEMA_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _validate_row_against_schema(row: dict, schema: dict) -> list:
    """Minimal stdlib draft-07 validator covering the constructs used in
    the cross schema: top-level required + properties + nested object
    properties (required + scalar types) + enum/const checks. Returns the
    list of error strings (empty = row valid)."""
    errs = []

    def _type_ok(value, jtype):
        if jtype == "string":
            return isinstance(value, str)
        if jtype == "integer":
            return isinstance(value, int) and not isinstance(value, bool)
        if jtype == "number":
            return isinstance(value, (int, float)) and not isinstance(value, bool)
        if jtype == "boolean":
            return isinstance(value, bool)
        if jtype == "object":
            return isinstance(value, dict)
        if jtype == "array":
            return isinstance(value, list)
        return True

    def _check_object(obj, sub_schema, path):
        if not isinstance(obj, dict):
            errs.append(f"{path}: expected object")
            return
        for req in sub_schema.get("required", []):
            if req not in obj:
                errs.append(f"{path}: missing required field '{req}'")
        for prop, prop_schema in sub_schema.get("properties", {}).items():
            if prop not in obj:
                continue
            v = obj[prop]
            sub_path = f"{path}.{prop}"
            t = prop_schema.get("type")
            if isinstance(t, str) and not _type_ok(v, t):
                errs.append(f"{sub_path}: expected type '{t}', got {type(v).__name__}")
            if "const" in prop_schema and v != prop_schema["const"]:
                errs.append(f"{sub_path}: const mismatch (expected {prop_schema['const']!r})")
            if "enum" in prop_schema and v not in prop_schema["enum"]:
                errs.append(f"{sub_path}: not in enum {prop_schema['enum']!r}")
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                if "minimum" in prop_schema and v < prop_schema["minimum"]:
                    errs.append(f"{sub_path}: {v} < minimum {prop_schema['minimum']}")
                if "maximum" in prop_schema and v > prop_schema["maximum"]:
                    errs.append(f"{sub_path}: {v} > maximum {prop_schema['maximum']}")
                if "exclusiveMinimum" in prop_schema and v <= prop_schema["exclusiveMinimum"]:
                    errs.append(f"{sub_path}: {v} <= exclusiveMinimum {prop_schema['exclusiveMinimum']}")
            if t == "object" and isinstance(v, dict):
                _check_object(v, prop_schema, sub_path)

    _check_object(row, schema, "row")
    return errs


# ── acceptance criteria ────────────────────────────────────────────────────
def acceptance(rows: list, protac_sim, cam_sim) -> dict:
    """In-silico simulator-CONSISTENCY acceptance criteria (X1-X8)."""
    schema = _load_schema()
    schema_errors_total = 0
    for r in rows:
        schema_errors_total += len(_validate_row_against_schema(r, schema))

    # X1 — paired ladder fully crossed.
    x1 = len(rows) == len(_PAIRED_LADDER) and len(rows) >= 6

    # X2 — every row validates against the v1 schema.
    x2 = schema_errors_total == 0

    # X3 — at least one PROTAC-side row exhibits the HOOK EFFECT (interior peak,
    # non-monotone ternary fraction in [PROTAC]).
    x3 = any(r["protac_side"]["hook_effect_present"] for r in rows)

    # X4 — at least one CAM-side row exhibits the KINETIC-TRAP regime
    # (g_contact below KINETIC_TRAP_THRESHOLD).
    x4 = any(r["cam_side"]["kinetic_trap_regime"] for r in rows)

    # X5 — mass-action identity passes through the cross unchanged: PROTAC
    # apparent ternary K_d = K_d(E3) / alpha (Douglass three-body equilibrium).
    x5 = all(
        abs(r["protac_side"]["kd_ternary_apparent_nM"]
            - r["protac_side"]["kd_e3_nM"] / r["protac_side"]["alpha_cooperativity"])
        <= 1e-9
        for r in rows)

    # X6 — Caspar-Klug geometry passes through the cross unchanged: every CAM
    # side has 60*T subunits exactly and Euler V-E+F=2 holds on the capsomer
    # polyhedron.
    x6 = all(
        r["cam_side"]["n_subunits"] == 60 * r["cam_side"]["t_number"]
        and r["cam_side"]["euler_invariant_ok"]
        for r in rows)

    # X7 — every CAM g_contact_cam = baseline + delta_dg (mass-action shift
    # passes through verbatim).
    x7 = all(
        abs((r["cam_side"]["g_contact_cam_kcal"]
             - r["cam_side"]["g_contact_baseline_kcal"])
            - r["cam_side"]["delta_dg_modulator_kcal"]) < 1e-9
        for r in rows)

    # X8 — shared-framework magnitudes are properly side-by-side: PROTAC
    # magnitude is in log10(alpha), CAM magnitude is in kcal/mol — checked
    # only that both are non-negative real numbers (they are NOT summed).
    x8 = all(
        isinstance(r["shared_magnitudes"]["protac_cooperativity_log10_alpha_magnitude"],
                   (int, float))
        and r["shared_magnitudes"]["protac_cooperativity_log10_alpha_magnitude"] >= 0.0
        and isinstance(r["shared_magnitudes"]["cam_delta_dg_abs_kcal_magnitude"],
                       (int, float))
        and r["shared_magnitudes"]["cam_delta_dg_abs_kcal_magnitude"] >= 0.0
        for r in rows)

    crit = {
        "X1_paired_ladder_crossed": x1,
        "X2_rows_validate_against_v1_schema": x2,
        "X3_protac_hook_effect_present_at_least_once": x3,
        "X4_cam_kinetic_trap_regime_present_at_least_once": x4,
        "X5_protac_mass_action_kd_ternary_identity_preserved": x5,
        "X6_cam_caspar_klug_geometry_exact_and_euler_ok": x6,
        "X7_cam_g_contact_shift_consistent_with_delta_dg": x7,
        "X8_shared_magnitudes_well_formed_and_non_negative": x8,
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "schema_errors_total": schema_errors_total,
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("protac_capsid_modulator_cross — CROSS-AXIS G1\n", flush=True)
    print("cross:  PROTAC ternary-complex HOOK EFFECT (mass-action + cooperativity)",
          flush=True)
    print("        ──shared mathematical structure──▶",
          flush=True)
    print("        CAPSID-ASSEMBLY-MODULATOR KINETIC-TRAP regime "
          "(mass-action + cooperativity)\n",
          flush=True)

    protac_sim = _load_protac_sim()
    cam_sim = _load_cam_sim()

    print("  real-limit anchors:")
    print("   - PROTAC: law of mass action / three-body binding equilibria")
    print("     (Douglass et al., JACS 135:6092, 2013; Gadd et al., Nat. Chem.")
    print("     Biol. 13:514, 2017)")
    print("   - CAM   : Caspar-Klug quasi-equivalence T-number geometry")
    print("     (Caspar & Klug, CSHSQB 27:1, 1962) + Zlotnick weak-contact")
    print("     thermodynamics (Zlotnick, Biochemistry 33:1233, 1994;")
    print(f"     JMR 16:294, 2003) — band "
          f"[{cam_sim.WEAK_CONTACT_LO}, {cam_sim.WEAK_CONTACT_HI}] kcal/mol,")
    print(f"     kinetic-trap threshold = {cam_sim.KINETIC_TRAP_THRESHOLD} kcal/mol")
    print(f"  CAM reference   : T={_CAM_T_NUMBER}  baseline g_contact="
          f"{_CAM_BASELINE_G_CONTACT_KCAL:+.1f} kcal/mol  c_total={_CAM_C_TOTAL}")
    print(f"  PROTAC grid     : {protac_sim.PROTAC_CONC_GRID_NM} nM\n", flush=True)

    rows = build_cross_rows(protac_sim, cam_sim)
    for r in rows:
        p = r["protac_side"]
        c = r["cam_side"]
        s = r["regime_signature"]
        m = r["shared_magnitudes"]
        print(f"  [{r['pair_id']:<26}]")
        print(f"      PROTAC   : {p['protac']:<26} coop={p['cooperativity_class']:<9} "
              f"alpha={p['alpha_cooperativity']:>5.1f}  E3={p['e3_ligase']}")
        print(f"                 ternary_peak={p['ternary_fraction_peak']:.4f} @ "
              f"[PROTAC]={p['protac_at_peak_nM']:.1f}nM  "
              f"hook={p['hook_effect_present']}")
        print(f"      CAM      : {c['scenario']:<26} "
              f"Δg_contact={c['delta_dg_modulator_kcal']:+.2f}  "
              f"g_contact={c['g_contact_cam_kcal']:+.2f} kcal/mol")
        print(f"                 assembled_fraction "
              f"{c['baseline_assembled_fraction']:.4f}->{c['perturbed_assembled_fraction']:.4f}  "
              f"trap={c['kinetic_trap_regime']}")
        print(f"      regime   : PROTAC={s['protac_regime']}")
        print(f"                 CAM   ={s['cam_regime']}")
        print(f"      magnitudes: |log10(alpha)|="
              f"{m['protac_cooperativity_log10_alpha_magnitude']:.3f}  "
              f"|Δg_contact|={m['cam_delta_dg_abs_kcal_magnitude']:.2f} kcal/mol")

    acc = acceptance(rows, protac_sim, cam_sim)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"  schema_errors_total = {acc['schema_errors_total']}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  ->  verdict: {acc['verdict']} ---")

    print("\n## honesty (g3 / g8 / f1 / f2 / f3 / f_lattice_fit)")
    print("  - This comparison reports TWO DISTINCT PHENOMENA THAT SHARE")
    print("    MATHEMATICAL STRUCTURE (mass-action + cooperativity + a regime")
    print("    where the perturbation magnitude is non-monotone or trap-")
    print("    inducing). It is NOT a claim of mechanistic equivalence.")
    print("  - A PROTAC degrades a protein via E3-recruited ternary complex →")
    print("    polyubiquitination → 26S proteasome.  A CAM perturbs viral")
    print("    capsid self-assembly via per-contact ΔG shift → Zlotnick")
    print("    equilibrium → kinetic trap.  Very different biology, very")
    print("    different targets, very different mechanisms.")
    print("  - The PASS sentinel certifies IN-SILICO simulator+metadata")
    print("    internal consistency ONLY (g8/f2) — the two parent sims' regime")
    print("    signatures are computed self-consistently and reproduce byte-")
    print("    identically. NOT a binding-affinity, DC50/Dmax, antiviral, or")
    print("    therapeutic-efficacy claim of any kind.")
    print("  - Modalities described by their OWN drug precedent (g3/f1):")
    print("    PROTAC = ARV-471 / ARV-110; CAM = lenacapavir (HIV-1, FDA 2022).")
    print("  - No quantity in this module is derived from the n=6 lattice")
    print("    (g2 / f_lattice_fit). Both parents are SUB-AXES; the hexa-bio")
    print("    core-5 axis set is UNCHANGED.  Sister sims imported, not")
    print("    re-implemented (f3).")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed -> deterministic byte-identical re-runs
        "cross": ("G1  PROTAC ternary-complex hook effect  <->  "
                  "CAPSID-ASSEMBLY-MODULATOR kinetic-trap regime "
                  "(shared mass-action + cooperativity framework)"),
        "protac_subaxis_source":
            "_python_bridge/module/protac_sim.py (imported, not re-implemented - f3)",
        "cam_subaxis_source":
            "_python_bridge/module/capsid_assembly_modulator_sim.py "
            "(imported, not re-implemented - f3)",
        "real_limit_anchors": [
            "law of mass action / three-body binding equilibria "
            "(Douglass et al., JACS 135:6092, 2013; Gadd et al., "
            "Nat. Chem. Biol. 13:514, 2017)",
            "Caspar-Klug quasi-equivalence T-number geometry "
            "(Caspar & Klug, CSHSQB 27:1, 1962) + Zlotnick weak-contact "
            "thermodynamics (Zlotnick, Biochemistry 33:1233, 1994; "
            "J. Mol. Recognit. 16:294, 2003)",
        ],
        "shared_framework": (
            "mass-action equilibrium + a cooperativity term + a regime "
            "where the perturbation magnitude drives non-monotone (PROTAC "
            "hook) or trap (CAM over-stabilization) behaviour"),
        "cam_reference_t_number": _CAM_T_NUMBER,
        "cam_baseline_g_contact_kcal": _CAM_BASELINE_G_CONTACT_KCAL,
        "cam_c_total": _CAM_C_TOTAL,
        "protac_conc_grid_nM": protac_sim.PROTAC_CONC_GRID_NM,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": (
            "simulator+metadata internal consistency ONLY (g8/f2) — two "
            "distinct phenomena that SHARE MATHEMATICAL STRUCTURE; NOT a "
            "claim of mechanistic equivalence. NOT a binding-affinity / "
            "DC50 / Dmax / antiviral / therapeutic claim."),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PROTAC_CAPSID_MODULATOR_CROSS__ PASS" if ok
          else "\n__PROTAC_CAPSID_MODULATOR_CROSS__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
