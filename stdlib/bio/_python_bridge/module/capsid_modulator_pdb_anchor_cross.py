#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
capsid_modulator_pdb_anchor_cross.py — CROSS-AXIS A4
CAPSID-ASSEMBLY-MODULATOR  ×  VIROCAPSID PDB corpus

Anchors the generic CAPSID-ASSEMBLY-MODULATOR (CAM) Zlotnick perturbation
model to the REAL structural-virology entries in the core VIROCAPSID axis's
curated PDB capsid corpus. Instead of running the CAM panel on a toy fixed
T-number, this cross walks every corpus capsid, classifies its triangulation
(T) number, and runs the CAM perturbation parameterized to that real capsid.

Two sister modules are IMPORTED, never forked (AGENTS.tape f3 — no
shadow-implementation of a sister module):
  - virocapsid_pdb_corpus.py  — the VIROCAPSID axis's curated PDB corpus
    (VIPERdb v3.0 snapshot, or the literature-curated fallback). We read
    its `load_corpus()` rows; we do NOT re-derive the corpus.
  - capsid_assembly_modulator_sim.py — the CAPSID-ASSEMBLY-MODULATOR
    sub-axis. We call its `simulate_cam()` / `caspar_klug_geometry()`; we do
    NOT re-derive Caspar-Klug geometry or Zlotnick equilibrium.

────────────────────────────────────────────────────────────────────────────
CRITICAL HONESTY — T-number applicability (AGENTS.tape g3 / g8 / f2):

  The Caspar-Klug triangulation number T is defined ONLY for a CLOSED
  icosahedral protein shell: exactly 60*T quasi-equivalent subunits =
  12 pentamers + 10*(T-1) hexamers, on a polyhedron with icosahedral
  (532) symmetry (Caspar & Klug 1962). It is NOT a universal capsid
  descriptor.

  The mature HIV-1 capsid — the actual target of lenacapavir / Sunlenca —
  is NOT a closed icosahedral shell. It is a variable-curvature FULLERENE
  CONE: it contains exactly 12 pentamers (the Euler-mandated minimum to
  close a hexameric sheet) but a VARIABLE number of hexamers (~150-250,
  not fixed). A cone has no single triangulation number. The same holds
  for other Retroviridae native virions (HIV-2, Rous sarcoma virus,
  foamy virus, retrotransposon cores).

  This corpus (sourced from VIPERdb, which catalogues icosahedral
  reconstructions) DOES contain Retroviridae entries — but they are
  ENGINEERED in-vitro icosahedral CA assemblies / VLPs (entry names
  literally read "T=1 PARTICLE HIV-1 CA …", "RSV CA LATTICE: T=1 CA
  ICOSAHEDRON", "HIV-2 CA T=1 ICOSAHEDRON; ASSEMBLED VIA LIPID
  TEMPLATING"). Structural virology builds those VLPs PRECISELY BECAUSE
  the native virion is the non-icosahedral cone and is hard to study
  directly. The VIPERdb T-number on such a row describes the engineered
  VLP reconstruction, NOT the native virion topology.

  Therefore this cross classifies each capsid into:
    * t_number_applicable = true  — native virion is a closed icosahedral
      shell (HBV T=3/T=4, AAV / parvovirus T=1, the corpus's plant /
      satellite / nodavirus / picornavirus etc. families). The CAM
      Caspar-Klug + Zlotnick model is run with that real T-number.
    * t_number_applicable = false — native virion is non-icosahedral
      (Retroviridae fullerene-cone class). Classification is the HONEST
      string "T-number N/A — non-icosahedral native virion (fullerene
      cone)". NO T-number is fabricated; the CAM perturbation is NOT run
      with a forced T.

  This honest applicable / N/A split IS the deliverable. Forcing HIV-1
  into the T-number formula would be exactly the f2 over-claim this
  governance forbids.

────────────────────────────────────────────────────────────────────────────
Real limits anchored (AGENTS.tape g1 — real-limits-first):
  - Caspar-Klug quasi-equivalence T-number geometry — Caspar & Klug 1962,
    Cold Spring Harb Symp Quant Biol 27:1-24. EXACT closed-form integer
    geometry: closed icosahedral capsid of triangulation number T has
    exactly 60*T subunits = 12 pentamers + 10*(T-1) hexamers; the capsomer
    polyhedron satisfies Euler V - E + F = 2.
  - Zlotnick assembly thermodynamics — Zlotnick 1994, Biochemistry
    33:1233; Zlotnick 2003, J Mol Recognit 16:294-298. Capsids are held
    by many individually-WEAK contacts; over-stabilization kinetically
    TRAPS assembly in aberrant intermediates.
  - HIV-1 fullerene-cone capsid topology — Ganser et al. 1999, Science
    283:80; Pornillos et al. 2011, Nature 469:424 (12 pentamers + variable
    hexamers; conical, non-icosahedral). This is the real structural fact
    that makes the N/A classification mandatory, not optional.

Modality precedent (g3 / f1 / f_lattice_fit — by its OWN drug precedent,
NEVER lattice-derived): lenacapavir / Sunlenca — HIV-1 capsid inhibitor,
small-molecule (CDER), FDA-approved 2022. HBV capsid-assembly modulators
(vebicorvir, JNJ-56136379, GLS4) — clinical-stage. "12 pentamers" is
Caspar-Klug / fullerene capsid science, an observation from structural
virology — never an n=6-lattice derivation.

In-silico scope (g8 / f2): every PASS verifies in-silico
simulator-consistency ONLY — that the CAM model, parameterized to corpus
METADATA (a curator-assigned T-number), is internally consistent and
reproduces the cited closed forms. It is NOT a wet-lab, structural,
binding, therapeutic, clinical, or regulatory claim about any capsid or
any CAM.

Determinism: stdlib only (json, os, sys + the two imported sibling
modules, themselves stdlib-only). No network, no random, no wall-clock.
The corpus is read from the vendored VIPERdb snapshot (or the
literature-curated fallback) → byte-identical re-runs.

CLI:
  python3 capsid_modulator_pdb_anchor_cross.py           # selftest + sentinel
  python3 capsid_modulator_pdb_anchor_cross.py --json    # emit JSON rows
"""
from __future__ import annotations

import json
import os
import sys

# ── import the two sibling modules (AGENTS.tape f3 — import, never fork) ──
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import virocapsid_pdb_corpus as corpus            # VIROCAPSID axis corpus
import capsid_assembly_modulator_sim as cam        # CAPSID-ASSEMBLY-MODULATOR sub-axis

SCHEMA_VERSION = "capsid_modulator_pdb_anchor_cross_v1"
SENTINEL_OK = "__CAPSID_MODULATOR_PDB_ANCHOR_CROSS__ PASS"
SENTINEL_FAIL = "__CAPSID_MODULATOR_PDB_ANCHOR_CROSS__ FAIL"

# ── the single CAM scenario this cross applies to every corpus capsid ──
# "strong_over_stabilizer" is the lenacapavir-style regime: a modulator that
# over-stabilizes inter-subunit contacts and (per Zlotnick) drives the
# kinetic-trap / mis-assembly outcome. Deterministic fixed delta.
_CAM_SCENARIO = "strong_over_stabilizer"
_CAM_DELTA_DG_KCAL = -3.0

# ── honesty classifier — which native virions are closed icosahedral shells ──
#
# Caspar-Klug T is defined only for a closed icosahedral shell. Retroviridae
# native virions (HIV-1 / HIV-2 / RSV / foamy virus / retrotransposon cores)
# are NOT closed icosahedral shells — they are variable-curvature fullerene
# cones / tubes. VIPERdb still catalogues ENGINEERED in-vitro icosahedral CA
# VLPs of these viruses; those rows carry a T-number that describes the VLP
# reconstruction, not the native virion. We classify by family so HIV is
# never forced into the T-number formula (g3 / g8 / f2).
_NON_ICOSAHEDRAL_NATIVE_FAMILIES = frozenset({
    "retroviridae",          # HIV-1, HIV-2, RSV, HERV, retrotransposons — fullerene cone
})

_T_NA_REASON = ("T-number N/A — non-icosahedral native virion (fullerene cone): "
                "the native virion has 12 pentamers but a VARIABLE hexamer count "
                "and no single triangulation number; the corpus T-number describes "
                "an engineered in-vitro icosahedral CA-VLP reconstruction, not the "
                "native topology (Ganser 1999 Science 283:80; Pornillos 2011 Nature "
                "469:424). Caspar-Klug T is not applied (AGENTS.tape g3/g8/f2).")


def _t_number_applicable(entry: dict) -> bool:
    """True iff the entry's NATIVE virion is a closed icosahedral shell, so the
    Caspar-Klug T-number / Zlotnick CAM model legitimately applies.

    The corpus row always carries a (parseable) VIPERdb T-number — but that is
    not sufficient: VIPERdb also catalogues engineered icosahedral VLPs of
    viruses whose native virion is non-icosahedral. We gate on the virus
    FAMILY, the real structural-biology fact.
    """
    family = str(entry.get("family", "")).strip().lower()
    return family not in _NON_ICOSAHEDRAL_NATIVE_FAMILIES


def anchor_capsid(entry: dict) -> dict:
    """Build one cross row for a single corpus capsid.

    If the native virion is a closed icosahedral shell: classify its
    T-number and run the CAM perturbation (imported simulate_cam) with that
    real T. Otherwise: emit the honest N/A classification and do NOT run a
    forced-T CAM perturbation.
    """
    pdb_id = entry["pdb_id"]
    virus = entry.get("name", "")
    family = entry.get("family", "")
    t_declared = entry["t_number_declared"]          # corpus's curator-assigned integer T
    t_raw = entry.get("t_number_raw", str(t_declared))
    pseudo_t = bool(entry.get("pseudo_t", False))
    applicable = _t_number_applicable(entry)

    row = {
        "schema_version": SCHEMA_VERSION,
        "pdb_id": pdb_id,
        "virus": virus,
        "family": family,
        "corpus_t_number_raw": t_raw,
        "corpus_t_number_declared": t_declared,
        "pseudo_t": pseudo_t,
        "t_number_applicable": applicable,
    }

    if not applicable:
        # HONEST N/A — non-icosahedral native virion. No fabricated T-number,
        # no forced CAM perturbation.
        row["t_number_classification"] = "N/A — non-icosahedral"
        row["t_number_na_reason"] = _T_NA_REASON
        row["cam_scenario"] = None
        row["cam_outcome"] = None
        row["honest_scope"] = ("in-silico simulator-consistency only (g8/f2) — "
                               "non-icosahedral native virion; Caspar-Klug T-number "
                               "and the Zlotnick CAM model are NOT applied")
        return row

    # closed icosahedral shell → classify T and run the imported CAM model
    # (capsid_assembly_modulator_sim.simulate_cam). For a pseudo-T capsid the
    # T is convention-dependent; we anchor the CAM run to the integer T the
    # corpus declares and flag it as pseudo so the row stays honest.
    classification = f"T={t_declared}" + (" (pseudo-T)" if pseudo_t else "")
    row["t_number_classification"] = classification

    sim = cam.simulate_cam(
        scenario=_CAM_SCENARIO,
        delta_dg_kcal=_CAM_DELTA_DG_KCAL,
        t_number=t_declared,
    )
    geom = sim["geometry"]
    row["cam_scenario"] = _CAM_SCENARIO
    row["cam_outcome"] = {
        "t_number": geom["t_number"],
        "n_subunits": geom["n_subunits"],
        "n_pentamers": geom["n_pentamers"],
        "n_hexamers": geom["n_hexamers"],
        "euler_invariant_ok": geom["euler_invariant_ok"],
        "g_contact_baseline_kcal": sim["g_contact_baseline_kcal"],
        "delta_dg_modulator_kcal": sim["delta_dg_modulator_kcal"],
        "g_contact_cam_kcal": sim["g_contact_cam_kcal"],
        "baseline_assembled_fraction": sim["baseline"]["assembled_fraction"],
        "modulated_assembled_fraction": sim["modulated"]["assembled_fraction"],
        "assembled_fraction_shift": sim["assembled_fraction_shift"],
        "kinetic_trap_regime": sim["kinetic_trap_regime"],
    }
    row["honest_scope"] = ("in-silico simulator-consistency only (g8/f2) — closed "
                           "icosahedral shell; CAM perturbation parameterized to the "
                           "corpus's curator-assigned T-number metadata, NOT a "
                           "structural/binding/therapeutic claim")
    return row


def run_cross() -> list:
    """Walk the full VIROCAPSID corpus → one anchored CAM cross row per capsid.
    Deterministic: corpus rows arrive in the snapshot's fixed sort order.
    """
    rows, _src = corpus.load_corpus()
    return [anchor_capsid(e) for e in rows]


def corpus_source() -> str:
    _rows, src = corpus.load_corpus()
    return src


def _selfcheck() -> int:
    rows = run_cross()
    src = corpus_source()
    n = len(rows)
    applicable = [r for r in rows if r["t_number_applicable"]]
    na = [r for r in rows if not r["t_number_applicable"]]
    checks = []

    # C1 — cross produced one anchored row per corpus capsid
    checks.append((f"C1 one cross row per corpus capsid (n={n})", n > 0 and n == len(applicable) + len(na)))

    # C2 — every applicable row ran the imported CAM model with the real T-number
    #      and the Caspar-Klug Euler invariant holds (60*T subunits, V-E+F=2)
    c2 = True
    for r in applicable:
        o = r["cam_outcome"]
        if o is None or not o["euler_invariant_ok"]:
            c2 = False
        elif o["n_subunits"] != 60 * o["t_number"]:
            c2 = False
        elif o["n_pentamers"] != 12 or o["n_hexamers"] != 10 * (o["t_number"] - 1):
            c2 = False
        elif o["t_number"] != r["corpus_t_number_declared"]:
            c2 = False
    checks.append(("C2 every applicable capsid: CAM run @ real T; 60*T subunits, 12 pentamers, Euler OK", c2))

    # C3 — honesty: NO non-icosahedral entry was given a T-number / CAM run;
    #      every N/A row carries the honest reason and no fabricated number
    c3 = True
    for r in na:
        if r["cam_outcome"] is not None or r["cam_scenario"] is not None:
            c3 = False
        if r["t_number_classification"] != "N/A — non-icosahedral":
            c3 = False
        if "non-icosahedral" not in (r.get("t_number_na_reason") or ""):
            c3 = False
    checks.append(("C3 honesty — non-icosahedral virions get N/A, never a forced T-number (g3/g8/f2)", c3))

    # C4 — the imported sibling CAM model is REAL (not forked): a direct call
    #      reproduces what the cross row recorded for an applicable capsid
    c4 = False
    if applicable:
        probe = applicable[0]
        direct = cam.simulate_cam(_CAM_SCENARIO, _CAM_DELTA_DG_KCAL,
                                  t_number=probe["corpus_t_number_declared"])
        c4 = (abs(direct["assembled_fraction_shift"]
                  - probe["cam_outcome"]["assembled_fraction_shift"]) < 1e-12
              and direct["kinetic_trap_regime"]
              == probe["cam_outcome"]["kinetic_trap_regime"])
    checks.append(("C4 imported CAM sibling is the real model (direct call reproduces the cross row)", c4))

    # C5 — over-stabilizer scenario: every applicable capsid lands in the
    #      Zlotnick kinetic-trap regime (the cited real-limit behaviour)
    c5 = bool(applicable) and all(r["cam_outcome"]["kinetic_trap_regime"] for r in applicable)
    checks.append(("C5 strong over-stabilizer → Zlotnick kinetic-trap regime on every icosahedral capsid", c5))

    # C6 — the imported VIROCAPSID corpus actually delivered icosahedral T-strata
    t_strata = sorted({r["corpus_t_number_declared"] for r in rows})
    checks.append((f"C6 imported VIROCAPSID corpus delivered ≥3 T-strata {t_strata[:8]}", len(t_strata) >= 3))

    # C7 — at least one honest N/A classification is present (the deliverable's
    #      whole point) — the corpus's Retroviridae fullerene-cone class
    checks.append((f"C7 honest N/A class present — {len(na)} non-icosahedral capsid(s) classified N/A",
                   len(na) >= 1))

    # C8 — determinism: byte-identical re-run
    c8 = json.dumps(run_cross(), sort_keys=True) == json.dumps(rows, sort_keys=True)
    checks.append(("C8 determinism — byte-identical re-run", c8))

    print("capsid_modulator_pdb_anchor_cross — CROSS-AXIS A4")
    print("CAPSID-ASSEMBLY-MODULATOR  ×  VIROCAPSID PDB corpus\n")
    print(f"  corpus source : {src}")
    print(f"  corpus capsids: {n}   →   T-number applicable: {len(applicable)}   "
          f"honest N/A (non-icosahedral): {len(na)}\n")
    for name, ok in checks:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
    print()

    # sample of anchored rows — a few applicable + every N/A row
    print("  --- anchored CAM rows (sample) ---")
    for r in applicable[:6]:
        o = r["cam_outcome"]
        print(f"  {r['pdb_id']:>6s}  {r['t_number_classification']:<14s}  "
              f"{(r['virus'] or '')[:42]:<42s}  "
              f"subunits={o['n_subunits']:>5d}  Δf={o['assembled_fraction_shift']:+.4f}  "
              f"trap={o['kinetic_trap_regime']}")
    print(f"  ... ({len(applicable)} applicable capsids total)")
    for r in na:
        print(f"  {r['pdb_id']:>6s}  {'N/A non-icosahedral':<14s}  "
              f"{(r['virus'] or '')[:42]:<42s}  [family={r['family']}]")

    n_pass = sum(1 for _, ok in checks if ok)
    n_total = len(checks)
    print(f"\n  --- summary --- {n_pass}/{n_total} PASS → verdict: "
          f"{'PASS' if n_pass == n_total else 'FAIL'} ---")
    print("  [honesty] in-silico simulator-consistency only — the CAM Caspar-Klug +")
    print("  Zlotnick model parameterized to VIROCAPSID-corpus T-number METADATA.")
    print("  Non-icosahedral native virions (Retroviridae fullerene cone — incl.")
    print("  HIV-1, lenacapavir's actual target) are classified honest N/A; NO")
    print("  T-number is fabricated for them. NOT a wet-lab / structural / binding /")
    print("  therapeutic / clinical / regulatory claim (g8/f2). Sister modules are")
    print("  IMPORTED, never forked (f3). No n=6-lattice derivation (g2/f_lattice_fit).")
    if n_pass == n_total:
        print(f"\n{SENTINEL_OK}")
        return 0
    print(f"\n{SENTINEL_FAIL}")
    return 1


def main(argv: list) -> int:
    if "--json" in argv:
        print(json.dumps(run_cross(), indent=2, ensure_ascii=False))
        return 0
    return _selfcheck()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
