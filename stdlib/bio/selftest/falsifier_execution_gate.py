#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/falsifier_execution_gate.py — falsifier EXECUTION gate for the
hexa-bio EXPANSION-MAIN axes (METALLODRUG · OLIGONUCLEOTIDE · COVALENT ·
BIFUNCTIONAL).

WHY THIS EXISTS
---------------
The expansion-layer axes preregister falsifiers in their per-axis tapes:
HEXA-METALLODRUG.tape declares F-METALLODRUG-1/2/3, HEXA-OLIGONUCLEOTIDE.tape
declares F-OLIGO-1/2/3, HEXA-COVALENT.tape declares F-COVALENT-1/2/3, and
HEXA-BIFUNCTIONAL.tape declares F-BIFUNCTIONAL-1/2/3. A falsifier is a
preregistered condition that, if it FAILS, falsifies a claim. But declaring a
falsifier is not the same as exercising it — until something actually RUNS
each falsifier's condition, the preregistration is inert.

This gate closes that gap. It:

  1. Scans the root HEXA-METALLODRUG.tape / HEXA-OLIGONUCLEOTIDE.tape /
     HEXA-COVALENT.tape / HEXA-BIFUNCTIONAL.tape for the @D falsifier entries,
     parsing each falsifier id + its `falsifier =` condition text directly
     from the tape.
  2. For each discovered falsifier, EXECUTES the corresponding concrete check
     — it imports and runs the axis sim
     (_python_bridge/module/metallodrug_coordination_sim.py /
      oligonucleotide_hybridization_sim.py /
      covalent_inhibition_sim.py /
      bifunctional_ternary_complex_sim.py) and verifies the falsifier's
     preregistered condition still HOLDS.
  3. Reports per-falsifier HOLD / FALSIFIED and emits the sentinel
     `__FALSIFIER_EXECUTION_GATE__ PASS` iff every DECLARED falsifier HOLDS.

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — every check ties to the axis's real-limit anchor:
     METALLODRUG → the Griffith & Orgel (1957) CFSE closed forms and the
     Takahara (1995) ~2.0 A Pt-N7(guanine) coordinate-bond length;
     OLIGONUCLEOTIDE → the SantaLucia (1998) unified nearest-neighbor
     duplex-thermodynamics model;
     COVALENT → Strelow (2017) kinact/Ki two-step covalent-inhibitor kinetic
     framework + Eyring (1935) transition-state-theory universal frequency
     prefactor kB·T/h (≈6.46e12 /s at T=310 K) as the hard physical ceiling
     on any unimolecular elementary covalent-step rate;
     BIFUNCTIONAL → Douglass (2013) / Han (2020) three-body ternary-complex
     mass-action equilibrium (the non-monotonic bell-shaped hook effect) and
     Gadd (2017) ternary-complex cooperativity factor α monotonicity.
  g7 skip-is-honest — if a tape or a sim module is ABSENT on the host, the
     affected falsifiers are reported SKIP, not FAIL. SKIP does not block the
     sentinel; only a genuine FALSIFIED result does. (A FALSIFIED verdict is
     reserved for "axis reachable, preregistered condition violated".)
  g8 in-silico-only — a HOLD here verifies IN-SILICO simulator-consistency of
     the axis's preregistered condition ONLY. It is NOT a therapeutic,
     cytotoxic, gene-silencing, immunogenic, binding-affinity, potency,
     selectivity, degradation-efficacy, DC50, Dmax, or regulatory claim.

A standing honesty falsifier (e.g. F-METALLODRUG-3) is, by its own tape text,
triggerable ONLY by a published literature result, never by an in-silico run.
This gate executes its in-silico-checkable component (the axis sim performs no
lattice arithmetic / its honesty sentinel is PASS) and HOLDs on that basis,
noting the standing literature condition is out of in-silico scope.

DETERMINISM
-----------
Pure stdlib (no third-party imports). The axis sims are themselves
deterministic (no network / random / wall-clock). Re-running this gate on the
same repo state produces byte-identical output.

Usage:
    python3 selftest/falsifier_execution_gate.py
    # exit 0 = every declared falsifier HOLDS (or honestly SKIPPED)
    # exit 1 = at least one declared falsifier FALSIFIED
"""
from __future__ import annotations

import importlib.util
import math
import os
import re
import sys

# ── repo layout ─────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_BRIDGE = os.path.join(REPO_ROOT, "_python_bridge", "module")

METALLODRUG_TAPE = os.path.join(REPO_ROOT, "HEXA-METALLODRUG.tape")
OLIGO_TAPE = os.path.join(REPO_ROOT, "HEXA-OLIGONUCLEOTIDE.tape")
COVALENT_TAPE = os.path.join(REPO_ROOT, "HEXA-COVALENT.tape")
BIFUNCTIONAL_TAPE = os.path.join(REPO_ROOT, "HEXA-BIFUNCTIONAL.tape")
METALLODRUG_SIM = os.path.join(PY_BRIDGE, "metallodrug_coordination_sim.py")
OLIGO_SIM = os.path.join(PY_BRIDGE, "oligonucleotide_hybridization_sim.py")
COVALENT_SIM = os.path.join(PY_BRIDGE, "covalent_inhibition_sim.py")
BIFUNCTIONAL_SIM = os.path.join(PY_BRIDGE, "bifunctional_ternary_complex_sim.py")

# Eyring TST universal frequency prefactor kB·T/h at T=310 K (hard physical
# ceiling on any unimolecular elementary rate). Recomputed locally from the
# CODATA 2019 exact SI constants so this gate does not depend on importing
# the COVALENT sim module just to read the ceiling — the sim is loaded for
# the check itself, but the anchor value is independently computable here.
_K_B = 1.380649e-23          # J/K   (CODATA 2019 exact)
_H_PLANCK = 6.62607015e-34   # J·s   (CODATA 2019 exact)
_TEMP_K = 310.0              # K     (physiological reference)
EYRING_PREFACTOR_310K = _K_B * _TEMP_K / _H_PLANCK   # ≈ 6.46e12 /s

# verdict tokens
HOLD = "HOLD"
FALSIFIED = "FALSIFIED"
SKIP = "SKIP"


# ── tape parsing ─────────────────────────────────────────────────────────
def parse_falsifiers(tape_path, id_prefix):
    """Scan a .tape file for @D falsifier entries whose declared subject
    matches `<id_prefix>-<n>` (e.g. F-METALLODRUG-1). Returns an ordered list
    of {id, subject, condition} dicts — `condition` is the `falsifier =` body
    line text (the preregistered falsifying condition).

    Returns None if the tape file is absent (honest SKIP upstream).
    """
    if not os.path.isfile(tape_path):
        return None
    with open(tape_path, "r", encoding="utf-8") as fh:
        lines = fh.readlines()

    # @D <id> := "<subject>" :: falsifier|prediction [<grades>]
    header_re = re.compile(
        r'^@D\s+(\S+)\s*:=\s*"([^"]*)"\s*::\s*(falsifier|prediction)\b')
    subject_re = re.compile(re.escape(id_prefix) + r"-\d+")

    found = []
    i = 0
    while i < len(lines):
        m = header_re.match(lines[i])
        if not m:
            i += 1
            continue
        entry_id, subject, _kind = m.group(1), m.group(2), m.group(3)
        sm = subject_re.search(subject)
        if not sm:
            i += 1
            continue
        canonical = sm.group(0)  # e.g. "F-OLIGO-1"
        # collect the body (2-space-indented lines) until the next blank /
        # non-indented line, pull the `falsifier =` value out of it.
        condition = ""
        j = i + 1
        while j < len(lines):
            body = lines[j]
            if body.strip() == "" or not body.startswith("  "):
                break
            stripped = body.strip()
            fm = re.match(r'falsifier\s*=\s*"(.*)"\s*$', stripped)
            if fm:
                condition = fm.group(1)
            j += 1
        found.append({
            "id": canonical,
            "entry_id": entry_id,
            "subject": subject,
            "condition": condition,
        })
        i = j
    # stable order by trailing integer
    found.sort(key=lambda d: int(d["id"].rsplit("-", 1)[1]))
    return found


# ── sim loading ──────────────────────────────────────────────────────────
def load_module(path, mod_name):
    """Import an axis-sim file as a module. Returns the module, or None if the
    file is absent (honest SKIP) — import errors propagate (genuine breakage)."""
    if not os.path.isfile(path):
        return None
    spec = importlib.util.spec_from_file_location(mod_name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── METALLODRUG falsifier executors ──────────────────────────────────────
# Each executor runs the metallodrug sim and verifies one preregistered
# condition. Returns (verdict, detail).

def exec_metallodrug(sim, witness):
    """Return {falsifier_id: (verdict, detail)} for F-METALLODRUG-1/2/3."""
    results = {}

    # --- F-METALLODRUG-1: CFSE numerical-recompute fidelity.
    # Condition: every selftest run must pass the CFSE-table check (the
    # recomputed d0..d10 CFSE table matches the Griffith & Orgel closed form
    # within 1e-9). Executed: re-run the sim's CFSE table + verifier.
    cfse = witness["cfse_verification"]
    rows = witness["cfse_table"]
    # independently re-exercise the closed-form anchors named in the tape.
    d5_hs = rows[5]["oct_high_spin"]["cfse_delta_oct"]
    d6_ls = rows[6]["oct_low_spin"]["cfse_delta_oct"]
    d3_hs = rows[3]["oct_high_spin"]["cfse_delta_oct"]
    anchors_ok = (abs(d5_hs - 0.0) <= 1e-9
                  and abs(d6_ls - (-2.4)) <= 1e-9
                  and abs(d3_hs - (-1.2)) <= 1e-9)
    f1_hold = bool(cfse["pass"]) and anchors_ok
    f1_detail = (f"CFSE table vs Griffith&Orgel closed form: "
                 f"max dev HS={cfse['max_deviation_high_spin']:.1e}, "
                 f"LS={cfse['max_deviation_low_spin']:.1e} (tol 1e-9); "
                 f"anchors d5-HS={d5_hs:+.3f}=0, d6-LS={d6_ls:+.3f}=-2.4, "
                 f"d3-HS={d3_hs:+.3f}=-1.2")
    if not f1_hold:
        f1_detail += f"; mismatches={cfse['mismatches']}"
    results["F-METALLODRUG-1"] = (HOLD if f1_hold else FALSIFIED, f1_detail)

    # --- F-METALLODRUG-2: square-planar Pt-N7 bond-length anchor.
    # Condition: a Pt-N7 coordinate-bond length OUTSIDE 1.85-2.15 A falsifies
    # the ~2.0 A anchor. Executed: recompute the square-planar Pt-N radial
    # distance from the sim's geometry model, assert it lands in 1.85-2.15 A.
    gchk = witness["pt_n7_geometry_verification"]
    recomputed = gchk["recomputed_pt_n_angstrom"]
    in_window = 1.85 <= recomputed <= 2.15
    f2_hold = bool(gchk["anchor_match"]) and in_window and bool(
        gchk["square_geometry_self_consistent"])
    f2_detail = (f"recomputed Pt-N radial distance = {recomputed:.4f} A "
                 f"(preregistered window 1.85-2.15 A; anchor "
                 f"{gchk['anchor_value_angstrom']} A, dev "
                 f"{gchk['deviation_angstrom']:.1e} A); square geometry "
                 f"self-consistent={gchk['square_geometry_self_consistent']}")
    results["F-METALLODRUG-2"] = (HOLD if f2_hold else FALSIFIED, f2_detail)

    # --- F-METALLODRUG-3: square-planar is d8, NOT lattice-derived.
    # Standing honesty falsifier — by tape text triggerable ONLY by a
    # published coordination-chemistry result, never by an in-silico run.
    # In-silico-checkable component: (a) every square-planar metallodrug in
    # the sim's metadata is d8; (b) the sim performs NO lattice arithmetic
    # (its lattice_stance declares this explicitly).
    fchk = witness["falsifiers"]
    d8_ok = bool(fchk.get("F-METALLODRUG-3_square_planar_is_d8", False))
    stance = witness.get("lattice_stance", "")
    no_lattice = ("NO n=6 lattice arithmetic" in stance
                  or "No n=6 lattice arithmetic" in stance
                  or "OBSERVATION ONLY" in stance)
    f3_hold = d8_ok and no_lattice
    f3_detail = ("square-planar metallodrugs all d8="
                 f"{d8_ok}; sim declares no lattice arithmetic / "
                 f"observation-only stance={no_lattice}; standing literature "
                 "component is out of in-silico scope (HOLD absent a published "
                 "lattice-predicts-geometry result)")
    results["F-METALLODRUG-3"] = (HOLD if f3_hold else FALSIFIED, f3_detail)

    return results


# ── OLIGONUCLEOTIDE falsifier executors ──────────────────────────────────
def exec_oligonucleotide(sim):
    """Return {falsifier_id: (verdict, detail)} for F-OLIGO-1/2/3 by directly
    exercising the SantaLucia NN-thermodynamics functions of the sim."""
    results = {}

    # --- F-OLIGO-1: ASO:mRNA duplex Tm tracks the SantaLucia NN sum.
    # Condition: a drift of the Dickerson-dodecamer ΔH°/ΔS°/Tm outside the
    # preregistered regimes fails the self-check. Executed: recompute the
    # Dickerson dodecamer from the NN sum, assert ΔH° in -85..-105,
    # ΔS° in -240..-300, Tm in 50..68 C.
    ref = sim.duplex_report("CGCGAATTCGCG", total_strand_M=0.4e-6)
    dh, ds, tm = ref["dH_kcal_mol"], ref["dS_cal_mol_K"], ref["Tm_celsius"]
    f1_hold = (-105.0 <= dh <= -85.0
               and -300.0 <= ds <= -240.0
               and 50.0 <= tm <= 68.0)
    f1_detail = (f"Dickerson dodecamer CGCGAATTCGCG recomputed from the "
                 f"SantaLucia(1998) NN sum: ΔH°={dh:.2f} kcal/mol (regime "
                 f"-85..-105), ΔS°={ds:.2f} cal/mol·K (regime -240..-300), "
                 f"Tm={tm:.2f} C (regime 50..68)")
    results["F-OLIGO-1"] = (HOLD if f1_hold else FALSIFIED, f1_detail)

    # --- F-OLIGO-2: GC>AT Tm ordering and ΔG° length monotonicity.
    # Condition: a GC-rich duplex melting LOWER than an equal-length AT-rich
    # duplex, OR extending a matched duplex RAISING ΔG°, falsifies. Executed:
    # recompute both orderings from the NN model.
    gc_rich = sim.duplex_report("GCGCGCGCGCGC")
    at_rich = sim.duplex_report("ATATATATATAT")
    gc_gt_at = gc_rich["Tm_celsius"] > at_rich["Tm_celsius"]
    short_dg = sim.nn_thermodynamics("GCGCGC")["dG37_kcal_mol"]
    long_dg = sim.nn_thermodynamics("GCGCGCGCGCGC")["dG37_kcal_mol"]
    monotone = long_dg < short_dg
    f2_hold = gc_gt_at and monotone
    f2_detail = (f"GC-rich Tm={gc_rich['Tm_celsius']:.1f} C "
                 f"{'>' if gc_gt_at else '<='} AT-rich Tm="
                 f"{at_rich['Tm_celsius']:.1f} C; length monotonicity: "
                 f"ΔG°(12-mer)={long_dg:.2f} {'<' if monotone else '>='} "
                 f"ΔG°(6-mer)={short_dg:.2f} kcal/mol")
    results["F-OLIGO-2"] = (HOLD if f2_hold else FALSIFIED, f2_detail)

    # --- F-OLIGO-3: off-target hybridization is ΔG-detectable.
    # Condition: an off-target screen returning ZERO flagged windows for an
    # oligo that is, by construction, the reverse complement of a decoy-pool
    # window falsifies. Executed: build the deliberate CTG-repeat off-targeter
    # and assert the screen flags >= 1 window.
    demo_aso = sim.reverse_complement("CTG" * 7)  # 21-mer, complementary to (CTG)n
    scr = sim.screen_off_targets(demo_aso)
    n_flagged = scr["n_flagged_off_targets"]
    f3_hold = n_flagged >= 1
    f3_detail = (f"deliberate low-complexity off-targeter (rc of (CTG)7, "
                 f"{scr['aso_length_nt']} nt) screened vs {scr['pool_size']}"
                 f"-decoy pool: {scr['windows_scanned']} windows scanned, "
                 f"{n_flagged} flagged (ΔG gate "
                 f"{scr['off_target_dG_gate_kcal_mol']} kcal/mol, "
                 f"min ΔG°={scr['min_duplex_dG37_kcal_mol']:.2f})")
    results["F-OLIGO-3"] = (HOLD if f3_hold else FALSIFIED, f3_detail)

    return results


# ── COVALENT falsifier executors ─────────────────────────────────────────
# Each executor runs the covalent-inhibition sim's witness and verifies one
# preregistered F-COVALENT-* condition. Returns (verdict, detail).

def exec_covalent(sim, witness):
    """Return {falsifier_id: (verdict, detail)} for F-COVALENT-1/2/3.

    Real-limit anchors (g1):
      F-COVALENT-1 → Strelow (2017) kinact/Ki kinetic framework: the second-
                     order efficiency constant recomputed two ways (kinact÷Ki
                     directly, and back-computed from the limiting kobs slope)
                     must agree; the Eyring rate-↔-barrier roundtrip must be
                     self-consistent; t_1/2 = ln2/kobs must follow from kobs.
      F-COVALENT-2 → Eyring (1935) TST universal frequency prefactor kB·T/h
                     (≈6.46e12 /s at T=310 K) is the hard physical ceiling
                     on every unimolecular elementary covalent-step rate.
      F-COVALENT-3 → standing honesty falsifier — by tape text triggerable
                     ONLY by a published enzyme-kinetics result, never by an
                     in-silico run. In-silico-checkable component: the sim's
                     lattice_stance declares NO n=6 lattice arithmetic.
    """
    results = {}
    rows = witness["rows"]
    acc = witness["acceptance"]["criteria"]

    # --- F-COVALENT-1: kinact/Ki numerical-recompute fidelity.
    # Condition (tape): if the two kinact/Ki recomputation paths disagree by
    # more than 1e-9 (relative), OR the Eyring rate↔barrier roundtrip diverges
    # by more than 1e-6 (relative), OR t_1/2 does not follow from kobs, this
    # falsifier is FALSIFIED. Executed: independently recompute kinact/Ki two
    # ways per row + assert the sim's per-row consistency residuals are within
    # tolerance + check the half-life identity.
    max_metric_err = max(r["metric_consistency_rel_err"] for r in rows)
    max_direct_err = 0.0
    max_halflife_err = 0.0
    for r in rows:
        direct = r["kinact_per_s"] / r["Ki_molar"]
        rel = abs(r["kinact_over_Ki_M_per_s"] - direct) / max(
            abs(r["kinact_over_Ki_M_per_s"]), 1e-300)
        if rel > max_direct_err:
            max_direct_err = rel
        if r["kobs_per_s"] > 0.0:
            t12_expected = math.log(2.0) / r["kobs_per_s"]
            rel_t = (abs(r["free_enzyme_half_life_s"] - t12_expected)
                     / max(abs(t12_expected), 1e-300))
            if rel_t > max_halflife_err:
                max_halflife_err = rel_t
    f1_hold = (bool(acc["C3_kinact_over_Ki_self_consistent"])
               and bool(acc["C4_kinact_over_Ki_equals_kinact_div_Ki"])
               and bool(acc["C5_eyring_roundtrip_consistent"])
               and bool(acc["C7_half_life_follows_kobs"])
               and max_metric_err < 1e-9
               and max_direct_err < 1e-6
               and max_halflife_err < 1e-6)
    f1_detail = (f"kinact/Ki two-way recompute (Strelow 2017): "
                 f"max metric-consistency rel-err = {max_metric_err:.1e} "
                 f"(tol 1e-9); independent kinact÷Ki rel-err = "
                 f"{max_direct_err:.1e} (tol 1e-6); Eyring roundtrip "
                 f"consistent={acc['C5_eyring_roundtrip_consistent']}; "
                 f"t_1/2=ln2/kobs rel-err = {max_halflife_err:.1e} (tol 1e-6)")
    results["F-COVALENT-1"] = (HOLD if f1_hold else FALSIFIED, f1_detail)

    # --- F-COVALENT-2: Eyring kB·T/h ceiling respected.
    # Condition (tape): if any covalent-step rate is at or above kB·T/h, TST
    # has been violated. Executed: independently recompute the prefactor from
    # CODATA constants + assert every row's kinact AND its Eyring-TST kinact
    # are strictly below it.
    ceiling = EYRING_PREFACTOR_310K
    sim_ceiling = rows[0]["eyring_prefactor_ceiling_per_s"]
    ceiling_match = abs(ceiling - sim_ceiling) <= 1e-3 * ceiling
    max_kinact = max(r["kinact_per_s"] for r in rows)
    max_kinact_tst = max(r["kinact_eyring_tst_per_s"] for r in rows)
    all_below_kinact = all(r["kinact_per_s"] < ceiling for r in rows)
    all_below_tst = all(r["kinact_eyring_tst_per_s"] < ceiling for r in rows)
    f2_hold = (bool(acc["C2_eyring_ceiling_respected"])
               and ceiling_match and all_below_kinact and all_below_tst)
    f2_detail = (f"Eyring TST ceiling kB·T/h @ 310K = {ceiling:.3e} /s "
                 f"(Eyring 1935; sim-reported {sim_ceiling:.3e}, match="
                 f"{ceiling_match}); max observed kinact = {max_kinact:.3e} /s, "
                 f"max Eyring-TST kinact = {max_kinact_tst:.3e} /s — both "
                 f"strictly below ceiling = {all_below_kinact and all_below_tst}")
    results["F-COVALENT-2"] = (HOLD if f2_hold else FALSIFIED, f2_detail)

    # --- F-COVALENT-3: two-step kinetics is mechanism, not lattice-derived.
    # Standing honesty falsifier — by tape text triggerable ONLY by a
    # published enzyme-kinetics result that derives the mechanism / kinact/Ki
    # ranking from a 6-fold lattice scalar, never by an in-silico run.
    # In-silico-checkable component: the sim performs NO lattice arithmetic
    # (its lattice_stance declares this explicitly).
    stance = witness.get("lattice_stance", "")
    no_lattice = ("No n=6 lattice arithmetic" in stance
                  or "NO n=6 lattice arithmetic" in stance
                  or "OBSERVATION ONLY" in stance.upper())
    f3_hold = no_lattice
    f3_detail = ("sim declares no lattice arithmetic / observation-only "
                 f"stance={no_lattice}; standing literature component is out "
                 "of in-silico scope (HOLD absent a published enzyme-kinetics "
                 "result showing a 6-fold lattice scalar predicts mechanism / "
                 "kinact/Ki ranking better than enzyme-kinetics theory)")
    results["F-COVALENT-3"] = (HOLD if f3_hold else FALSIFIED, f3_detail)

    return results


# ── BIFUNCTIONAL falsifier executors ─────────────────────────────────────
# Each executor runs the bifunctional ternary-complex sim's witness and
# verifies one preregistered F-BIFUNCTIONAL-* condition.

def exec_bifunctional(sim, witness):
    """Return {falsifier_id: (verdict, detail)} for F-BIFUNCTIONAL-1/2/3.

    Real-limit anchors (g1):
      F-BIFUNCTIONAL-1 → Gadd (2017) ternary-complex cooperativity factor α
                          — at fixed dose, the peak ternary-complex
                          concentration must be monotone non-decreasing in α
                          across the α scan ({0.5, 1, 2, 5, 20}).
      F-BIFUNCTIONAL-2 → Douglass (2013) / Han (2020) three-body ternary
                          mass-action equilibrium — the dose-scanned ternary
                          curve must be bell-shaped (rise then fall) with a
                          single interior maximum (the hook effect), with
                          mass-action occupancies all in [0,1] times the
                          relevant total pool.
      F-BIFUNCTIONAL-3 → standing honesty falsifier — by tape text triggerable
                          ONLY by a published chemical-equilibrium result,
                          never by an in-silico run. In-silico-checkable
                          component: the sim's lattice_stance declares NO
                          n=6 lattice arithmetic.
    """
    results = {}
    coop_rows = witness["cooperativity_scan"]
    coop_chk = witness["cooperativity_verification"]
    dose_rows = witness["dose_scan_hook"]
    hook = witness["hook_verification"]
    params = witness["model_parameters"]
    t_total = params["target_total_um"]
    e3_total = params["e3_total_um"]

    # --- F-BIFUNCTIONAL-1: cooperativity α-monotonicity.
    # Condition (tape): peak ternary-complex concentration must be monotone
    # non-decreasing in α across {0.5, 1, 2, 5, 20}. Executed: independently
    # walk the cooperativity scan and verify monotone non-decreasing ternary;
    # also confirm α=1 (non-cooperative reference) is in the scan and that
    # occupancies are within mass-action bounds [0, total_pool].
    alphas_seen = [r["alpha"] for r in coop_rows]
    ternary_seq = [r["ternary_TDE_um"] for r in coop_rows]
    monotone = all(ternary_seq[i] >= ternary_seq[i - 1] - 1e-6
                   for i in range(1, len(ternary_seq)))
    has_alpha_1 = any(abs(a - 1.0) < 1e-12 for a in alphas_seen)
    # mass-action sanity: every occupancy in [0, total pool] (per-row)
    occ_ok = all(
        0.0 <= r["ternary_TDE_um"] <= t_total + 1e-9
        and 0.0 <= r["binary_TD_um"] <= t_total + 1e-9
        and 0.0 <= r["binary_DE_um"] <= e3_total + 1e-9
        for r in coop_rows)
    f1_hold = (bool(coop_chk["pass"]) and monotone and has_alpha_1 and occ_ok)
    f1_detail = (
        f"α-monotonicity (Gadd 2017 VHL-MZ1-BRD4 cooperativity): "
        f"scan α={alphas_seen}, peak ternary [T·D·E] = "
        + " → ".join(f"{v:.4f}" for v in ternary_seq)
        + f" uM; monotone non-decreasing = {monotone}; α=1 reference present"
        f" = {has_alpha_1}; per-row mass-action occupancies in [0, total]"
        f" = {occ_ok}")
    results["F-BIFUNCTIONAL-1"] = (HOLD if f1_hold else FALSIFIED, f1_detail)

    # --- F-BIFUNCTIONAL-2: the hook effect (non-monotonic dose response).
    # Condition (tape): the dose-scanned ternary curve must be bell-shaped
    # (rises from low-dose, single interior maximum, decays toward zero at
    # very high dose). Executed: independently locate the peak in the dose
    # scan + assert interior + rising + falling arms + the high-dose binary
    # saturation that mechanistically causes the hook + verify per-dose
    # occupancies remain within mass-action bounds.
    n = len(dose_rows)
    concs = [r["ternary_TDE_um"] for r in dose_rows]
    peak_i = max(range(n), key=lambda i: concs[i])
    interior = 0 < peak_i < n - 1
    rises = concs[peak_i] > concs[0] * 1.05
    falls = concs[-1] < concs[peak_i] * 0.95
    dose_occ_ok = all(
        0.0 <= r["ternary_TDE_um"] <= t_total + 1e-9
        and 0.0 <= r["binary_TD_um"] <= t_total + 1e-9
        and 0.0 <= r["binary_DE_um"] <= e3_total + 1e-9
        for r in dose_rows)
    f2_hold = (bool(hook["pass"])
               and bool(hook["non_monotonic_bell_shaped"])
               and bool(hook["high_dose_binary_saturation"])
               and interior and rises and falls and dose_occ_ok)
    f2_detail = (
        f"hook effect (Douglass 2013 / Han 2020 three-body mass action): "
        f"dose-scan of {n} log-spaced points; low-dose [T·D·E]={concs[0]:.4f} "
        f"uM → peak {concs[peak_i]:.4f} uM at dose "
        f"{dose_rows[peak_i]['degrader_dose_um']:.4f} uM → high-dose "
        f"{concs[-1]:.4f} uM; interior-max={interior}, rising-arm={rises}, "
        f"falling-arm={falls}, high-dose binary saturation = "
        f"{hook['high_dose_binary_saturation']}; per-dose mass-action "
        f"occupancies in [0, total] = {dose_occ_ok}")
    results["F-BIFUNCTIONAL-2"] = (HOLD if f2_hold else FALSIFIED, f2_detail)

    # --- F-BIFUNCTIONAL-3: ternary equilibrium is mass-action, not lattice.
    # Standing honesty falsifier — by tape text triggerable ONLY by a published
    # chemical-equilibrium result that derives ternary behaviour / α / hook
    # dose maximum from a 6-fold lattice scalar, never by an in-silico run.
    # In-silico-checkable component: the sim performs NO lattice arithmetic.
    stance = witness.get("lattice_stance", "")
    no_lattice = ("No n=6 lattice arithmetic" in stance
                  or "NO n=6 lattice arithmetic" in stance
                  or "OBSERVATION ONLY" in stance.upper())
    f3_hold = no_lattice
    f3_detail = ("sim declares no lattice arithmetic / observation-only "
                 f"stance={no_lattice}; standing literature component is out "
                 "of in-silico scope (HOLD absent a published chemical-"
                 "equilibrium result showing a 6-fold lattice scalar predicts "
                 "ternary behaviour / α / hook dose maximum better than three-"
                 "body mass-action thermodynamics)")
    results["F-BIFUNCTIONAL-3"] = (HOLD if f3_hold else FALSIFIED, f3_detail)

    return results


# ── per-axis driver ──────────────────────────────────────────────────────
def run_axis(axis_name, tape_path, id_prefix, sim_path, executor, sim_kind):
    """Discover falsifiers in `tape_path`, execute them via `executor`.

    Returns a list of {id, verdict, detail} rows. Honest SKIP (g7) when the
    tape or sim is absent on the host.
    """
    print(f"── {axis_name} axis " + "─" * (60 - len(axis_name)))

    declared = parse_falsifiers(tape_path, id_prefix)
    if declared is None:
        print(f"  [SKIP] {os.path.basename(tape_path)} absent on host "
              f"— g7 skip-is-honest (absent tape != FAIL)\n")
        return [{"id": f"{id_prefix}-*", "verdict": SKIP,
                 "detail": "axis tape absent"}]
    if not declared:
        print(f"  [SKIP] no {id_prefix}-* falsifier entries found in "
              f"{os.path.basename(tape_path)}\n")
        return [{"id": f"{id_prefix}-*", "verdict": SKIP,
                 "detail": "no falsifier entries declared"}]

    print(f"  discovered {len(declared)} falsifier(s) in "
          f"{os.path.basename(tape_path)}: "
          + ", ".join(d["id"] for d in declared))

    if not os.path.isfile(sim_path):
        print(f"  [SKIP] {os.path.basename(sim_path)} absent on host "
              f"— g7 skip-is-honest; falsifiers declared but not executable\n")
        return [{"id": d["id"], "verdict": SKIP, "detail": "axis sim absent"}
                for d in declared]

    sim = load_module(sim_path, f"_axis_sim_{id_prefix}")

    # METALLODRUG / COVALENT / BIFUNCTIONAL executors need the sim's full
    # witness dict (built by sim.run()); OLIGONUCLEOTIDE exercises the sim's
    # functions directly without a top-level run().
    if sim_kind in ("metallodrug", "covalent", "bifunctional"):
        witness = sim.run()
        exec_results = executor(sim, witness)
    else:
        exec_results = executor(sim)

    rows = []
    for d in declared:
        fid = d["id"]
        verdict, detail = exec_results.get(
            fid, (SKIP, "no executor mapped for this falsifier id"))
        cond = d["condition"]
        cond_short = (cond[:96] + "…") if len(cond) > 97 else cond
        tag = {HOLD: "HOLD", FALSIFIED: "FALSIFIED", SKIP: "SKIP"}[verdict]
        print(f"  [{tag}] {fid}")
        if cond_short:
            print(f"         preregistered: {cond_short}")
        print(f"         executed     : {detail}")
        rows.append({"id": fid, "verdict": verdict, "detail": detail})
    print()
    return rows


# ── main ─────────────────────────────────────────────────────────────────
def main():
    print("falsifier_execution_gate — hexa-bio expansion-main axes "
          "(METALLODRUG · OLIGONUCLEOTIDE · COVALENT · BIFUNCTIONAL)")
    print("  scans the per-axis tapes for preregistered @D falsifiers, then")
    print("  EXECUTES each one against its axis sim and checks it HOLDS.")
    print("  governance: g1 real-limits-first · g7 skip-is-honest · "
          "g8 in-silico-only\n")

    all_rows = []
    all_rows += run_axis(
        "METALLODRUG", METALLODRUG_TAPE, "F-METALLODRUG",
        METALLODRUG_SIM, exec_metallodrug, "metallodrug")
    all_rows += run_axis(
        "OLIGONUCLEOTIDE", OLIGO_TAPE, "F-OLIGO",
        OLIGO_SIM, exec_oligonucleotide, "oligonucleotide")
    all_rows += run_axis(
        "COVALENT", COVALENT_TAPE, "F-COVALENT",
        COVALENT_SIM, exec_covalent, "covalent")
    all_rows += run_axis(
        "BIFUNCTIONAL", BIFUNCTIONAL_TAPE, "F-BIFUNCTIONAL",
        BIFUNCTIONAL_SIM, exec_bifunctional, "bifunctional")

    n_hold = sum(1 for r in all_rows if r["verdict"] == HOLD)
    n_falsified = sum(1 for r in all_rows if r["verdict"] == FALSIFIED)
    n_skip = sum(1 for r in all_rows if r["verdict"] == SKIP)
    n_total = len(all_rows)

    print("── summary " + "─" * 60)
    for r in all_rows:
        print(f"  {r['verdict']:<10} {r['id']}")
    print(f"\n  {n_hold} HOLD · {n_falsified} FALSIFIED · {n_skip} SKIP "
          f"(of {n_total} falsifier rows)")
    print("  HONESTY (g7): a SKIP is an absent tape/sim on this host — it does")
    print("  NOT block the sentinel. Only a genuine FALSIFIED (axis reachable,")
    print("  preregistered condition violated) blocks it.")
    print("  HONESTY (g8): a HOLD verifies IN-SILICO simulator-consistency of")
    print("  the preregistered condition ONLY — not a therapeutic / cytotoxic /")
    print("  gene-silencing / immunogenic / efficacy / regulatory claim.\n")

    # sentinel: PASS iff no falsifier is FALSIFIED. SKIP is honest (g7).
    ok = n_falsified == 0
    if ok:
        print("__FALSIFIER_EXECUTION_GATE__ PASS")
        return 0
    print("__FALSIFIER_EXECUTION_GATE__ FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
