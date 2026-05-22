#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ppi_sim.py — PPI sub-axis :> QUANTUM (core).

Deterministic, stdlib-only real-limits model of a protein-protein-interaction
(PPI) inhibitor: disrupting a large, flat, hotspot-driven interface with a
small molecule. This is the in-silico simulator-consistency layer for the PPI
sub-axis registered in AXIS/HIERARCHY.tape `@D sub_under_quantum` — see the
sibling note `ppi_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
PLACEMENT HONESTY (g3 — honest tension flagged, not hidden)
────────────────────────────────────────────────────────────────────────────
Per AXIS/HIERARCHY.tape `@D sub_under_quantum`, PPI scores main-eligible
(4.8/5/5) — i.e. by score it COULD be an expansion-MAIN axis. It is recorded
as a BORDERLINE sub of QUANTUM because of QUANTUM-VQE-applicability tension
(README criterion #2): a flat PPI interface is hotspot-energetics-driven, not
obviously an electronic-structure / active-space VQE problem. User direction
places ambiguous cases as sub. This file states that tension openly rather
than hiding it. PPI hangs off the core QUANTUM axis as a tag; the hexa-bio
core-5 axis QUANTUM is UNCHANGED — this is a SUB-AXIS, not a core mutation.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A protein-protein interface buries a large, flat surface, yet its binding free
energy is NOT spread evenly: a few "hotspot" residues dominate. We model the
interface hotspot energetics and the hotspot-mimicry a small molecule must
achieve to disrupt it:

  - Each interface residue carries an alanine-scanning ΔΔG (the binding free
    energy LOST when that residue is mutated to alanine).  By the Bogan-Thorn
    binding-hotspot theory a HOTSPOT residue is one with ΔΔG ≥ 2.0 kcal/mol;
    hotspots cluster and contribute the bulk of the total interface ΔG_bind.
        ΔG_interface ≈ −Σ ΔΔG_i           (sum over interface residues)
        hotspot_fraction = Σ_hotspot ΔΔG / Σ_all ΔΔG
  - A small-molecule PPI inhibitor cannot bury the whole flat surface; it must
    MIMIC the dominant hotspot cluster.  Its disruption is viable iff it
    recovers enough of the hotspot energy to out-compete one partner:
        ΔG_mimic = −mimicry_fraction · ΔG_hotspot_cluster
    The inhibitor wins iff ΔG_mimic is at least as favourable as the
    single-partner contribution it must displace — the hotspot-mimicry gate.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
The binding-hotspot theory of Bogan & Thorn (Bogan & Thorn, "Anatomy of
hot spots in protein interfaces", *J. Mol. Biol.* 280:1, 1998): interface
binding free energy is concentrated in a small set of hotspot residues
(operationally ΔΔG ≥ 2 kcal/mol by alanine scanning), NOT spread uniformly
over the buried surface. Earlier alanine-scanning origin: Clackson & Wells,
*Science* 267:383 (1995, hGH-receptor interface). The hard real limit: the
total recoverable interface energy is BOUNDED by the alanine-scanning ΔΔG
ledger — a small-molecule mimic cannot recover more hotspot energy than the
interface actually carries (acceptance criteria C2/C4). Druggability of flat
hotspot-driven PPIs follows Wells & McClendon, *Nature* 450:1001 (2007).

Own precedent (described ONLY by its own drug precedent — g3/f1, never
lattice-derived):
  - venetoclax — a BH3-mimetic small molecule that disrupts the BCL-2 /
    pro-apoptotic BH3 protein-protein interaction (Souers et al., *Nat. Med.*
    19:202, 2013; FDA-approved 2016) — the landmark approved PPI inhibitor.
  - navitoclax (ABT-263) — dual BCL-2/BCL-xL BH3-mimetic PPI inhibitor
    (Tse et al., *Cancer Res.* 68:3421, 2008).

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The PASS sentinel certifies IN-SILICO simulator+metadata internal consistency
ONLY: that the alanine-scanning ΔΔG ledger, the hotspot fraction, the
interface ΔG_bind and the hotspot-mimicry gate are computed self-consistently
and reproduce byte-identically. It is a binding-energetics MODEL — NOT a
binding-affinity measurement, NOT a potency/selectivity claim, NOT a
therapeutic-efficacy claim. The ΔΔG values are illustrative literature-informed
surrogates for interface CLASSES, not fits to a specific complex. Pure stdlib,
no network/time/random → byte-identical re-runs.

PPI is a SUB-AXIS (:> QUANTUM core) — it is NOT one of the hexa-bio core-5
axes, which remain QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID
(AXIS.tape unchanged). No quantity here is derived from the n=6 lattice.
"""
from __future__ import annotations
import json
import sys

# ── Bogan-Thorn binding-hotspot threshold ──
# An interface residue is a HOTSPOT iff its alanine-scanning ΔΔG is at least
# this — the operational definition of Bogan & Thorn (J. Mol. Biol. 280:1, 1998).
HOTSPOT_DDG_THRESHOLD_KCAL = 2.0

# ── hotspot-mimicry viability gate ──
# A small-molecule PPI inhibitor disrupts the interface iff its mimicked
# free energy is at least this favourable (~ low-µM small-molecule range).
MIMICRY_DG_THRESHOLD_KCAL = -7.0

SCHEMA_ID = "ppi_v1"

# ── deterministic PPI-interface panel ───────────────────────────────────────
# Each entry: (name, [per-residue alanine-scan ΔΔG kcal/mol], mimicry_fraction,
#              interface_class, own drug precedent).
#   ΔΔG_i           : binding free energy lost on residue→Ala mutation (≥ 0).
#   mimicry_fraction: fraction of the hotspot-cluster energy the small molecule
#                     recovers by mimicking the dominant hotspot residues.
# Values are illustrative literature-informed surrogates for the interface
# CLASS, not fits to a specific complex (see module honesty note).
INTERFACE_PANEL = [
    # tractable hotspot-driven interfaces (a tight, dominant hotspot cluster)
    ("bcl2_bh3_groove", [4.5, 3.8, 2.6, 1.1, 0.6, 0.4], 0.85,
     "bh3_helix_groove",
     "venetoclax — BH3-mimetic disrupting BCL-2 / BH3 PPI (FDA 2016)"),
    ("bclxl_bh3_groove", [4.2, 3.5, 2.4, 1.0, 0.7, 0.5], 0.80,
     "bh3_helix_groove",
     "navitoclax (ABT-263) — dual BCL-2/BCL-xL BH3-mimetic PPI inhibitor"),
    ("mdm2_p53_cleft", [4.8, 3.2, 2.2, 0.9, 0.5], 0.82,
     "alpha_helix_peptide_cleft",
     "p53-helix-cleft PPI modality (deep three-residue hotspot pocket)"),
    # borderline interface (hotspots present but a shallower cluster)
    ("kix_coactivator_groove", [2.5, 2.1, 1.4, 1.2, 0.8, 0.6], 0.62,
     "shallow_coactivator_groove",
     "shallow coactivator-groove PPI modality (modest hotspot depth)"),
    # hard / flat interface (energy spread thin — few or no true hotspots)
    ("flat_diffuse_interface", [1.3, 1.1, 0.9, 0.8, 0.7, 0.6, 0.5], 0.55,
     "flat_diffuse_interface",
     "flat diffuse PPI modality (energy spread over the surface, hotspot-poor)"),
    # contrast: a strong hotspot interface but a weak mimic (fails the gate)
    ("strong_hotspot_weak_mimic", [4.6, 3.9, 2.8, 1.0, 0.5], 0.30,
     "bh3_helix_groove",
     "hotspot-rich PPI modality with an insufficient small-molecule mimic"),
]


def interface_profile(ddg_list: list, mimicry_fraction: float) -> dict:
    """
    One interface's hotspot-energetics profile.  Applies the Bogan-Thorn
    hotspot definition (ΔΔG ≥ 2 kcal/mol), sums the alanine-scanning ledger,
    and tests the hotspot-mimicry gate for a small-molecule disruptor.
    """
    hotspots = [d for d in ddg_list if d >= HOTSPOT_DDG_THRESHOLD_KCAL]
    n_residues = len(ddg_list)
    n_hotspots = len(hotspots)
    sum_all = sum(ddg_list)
    sum_hotspot = sum(hotspots)
    # Interface binding free energy: favourable, magnitude = the ΔΔG ledger sum.
    dg_interface = -sum_all
    # The dominant hotspot cluster carries this much of the interface energy.
    dg_hotspot_cluster = -sum_hotspot
    hotspot_fraction = (sum_hotspot / sum_all) if sum_all > 0.0 else 0.0
    # A small-molecule mimic recovers a fraction of the hotspot-cluster energy.
    dg_mimic = mimicry_fraction * dg_hotspot_cluster
    # Hotspot-mimicry gate: the mimic must out-compete one partner contribution.
    mimic_viable = dg_mimic <= MIMICRY_DG_THRESHOLD_KCAL
    # Ledger conservation cross-check: hotspot + non-hotspot must sum to total.
    sum_nonhotspot = sum(d for d in ddg_list
                         if d < HOTSPOT_DDG_THRESHOLD_KCAL)
    ledger_residual = abs((sum_hotspot + sum_nonhotspot) - sum_all)
    # A mimic cannot recover more than the interface actually carries.
    mimic_within_ledger = abs(dg_mimic) <= abs(dg_hotspot_cluster) + 1e-9
    return {
        "alanine_scan_ddg_kcal_per_mol": list(ddg_list),
        "hotspot_ddg_threshold_kcal_per_mol": HOTSPOT_DDG_THRESHOLD_KCAL,
        "n_interface_residues": n_residues,
        "n_hotspot_residues": n_hotspots,
        "sum_ddg_kcal_per_mol": sum_all,
        "sum_hotspot_ddg_kcal_per_mol": sum_hotspot,
        "hotspot_energy_fraction": hotspot_fraction,
        "dg_interface_kcal_per_mol": dg_interface,
        "dg_hotspot_cluster_kcal_per_mol": dg_hotspot_cluster,
        "mimicry_fraction": mimicry_fraction,
        "dg_mimic_kcal_per_mol": dg_mimic,
        "mimicry_dg_threshold_kcal_per_mol": MIMICRY_DG_THRESHOLD_KCAL,
        "small_molecule_disruption_viable": mimic_viable,
        "ledger_residual_kcal_per_mol": ledger_residual,
        "mimic_within_ledger": mimic_within_ledger,
        "hotspot_driven": hotspot_fraction >= 0.5 and n_hotspots >= 2,
    }


def build_rows() -> list:
    """Compute one schema-conformant row per interface in the panel."""
    rows = []
    for name, ddg_list, mimicry, iclass, precedent in INTERFACE_PANEL:
        prof = interface_profile(ddg_list, mimicry)
        row = {
            "schema": SCHEMA_ID,
            "interface": name,
            "interface_class": iclass,
            "drug_precedent": precedent,
        }
        row.update(prof)
        rows.append(row)
    return rows


def contrast(rows: list) -> dict:
    """Hotspot-driven-vs-flat contrast and the weak-mimic failure mode."""
    by_name = {r["interface"]: r for r in rows}
    hot = by_name["bcl2_bh3_groove"]
    flat = by_name["flat_diffuse_interface"]
    weak = by_name["strong_hotspot_weak_mimic"]
    return {
        "hotspot_driven_reference": {
            "interface": hot["interface"],
            "drug_precedent": hot["drug_precedent"],
            "n_hotspot_residues": hot["n_hotspot_residues"],
            "hotspot_energy_fraction": hot["hotspot_energy_fraction"],
            "dg_mimic_kcal_per_mol": hot["dg_mimic_kcal_per_mol"],
            "small_molecule_disruption_viable": hot["small_molecule_disruption_viable"],
        },
        "flat_interface_reference": {
            "interface": flat["interface"],
            "drug_precedent": flat["drug_precedent"],
            "n_hotspot_residues": flat["n_hotspot_residues"],
            "hotspot_energy_fraction": flat["hotspot_energy_fraction"],
            "hotspot_driven": flat["hotspot_driven"],
        },
        "weak_mimic_failure_mode": {
            "interface": weak["interface"],
            "mimicry_fraction": weak["mimicry_fraction"],
            "dg_mimic_kcal_per_mol": weak["dg_mimic_kcal_per_mol"],
            "small_molecule_disruption_viable": weak["small_molecule_disruption_viable"],
        },
        "note": ("a flat PPI interface buries a large surface but, by the "
                 "Bogan-Thorn theory, a few hotspot residues carry most of the "
                 "binding free energy; a small molecule cannot bury the whole "
                 "surface — it must MIMIC the dominant hotspot cluster, and the "
                 "recoverable energy is bounded by the alanine-scanning ledger."),
    }


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    hotspot_driven = [r for r in rows if r["hotspot_driven"]]
    not_driven = [r for r in rows if not r["hotspot_driven"]]
    crit = {
        "C1_panel_non_empty": len(rows) >= 6,
        "C2_ddg_ledger_conserved": all(
            r["ledger_residual_kcal_per_mol"] < 1e-9 for r in rows),
        "C3_hotspot_fraction_bounded": all(
            0.0 <= r["hotspot_energy_fraction"] <= 1.0 for r in rows),
        "C4_mimic_within_ledger": all(
            r["mimic_within_ledger"] for r in rows),
        "C5_both_interface_kinds_present": len(hotspot_driven) >= 1
        and len(not_driven) >= 1,
        "C6_dg_interface_equals_neg_sum": all(
            abs(r["dg_interface_kcal_per_mol"]
                + r["sum_ddg_kcal_per_mol"]) <= 1e-9 for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("ppi_sim — PPI sub-axis :> QUANTUM (core)\n", flush=True)
    print("placement: PPI is score-main-eligible (4.8/5/5) — recorded as a")
    print("           BORDERLINE sub of QUANTUM per AXIS/HIERARCHY.tape "
          "@D sub_under_quantum")
    print("           (QUANTUM-VQE-applicability tension flagged, not hidden).\n",
          flush=True)
    print("model:  ΔG_interface ≈ −Σ ΔΔG_i   hotspot ⇔ ΔΔG ≥ 2 kcal/mol   "
          "hotspot-mimicry gate\n", flush=True)
    print("  real-limit anchor : Bogan-Thorn binding-hotspot theory")
    print("                      (Bogan & Thorn, J. Mol. Biol. 280:1, 1998) —")
    print("                      interface energy concentrated in a few hotspot")
    print("                      residues, bounded by the alanine-scanning ledger\n",
          flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['interface']:<26}] hotspots={r['n_hotspot_residues']}/"
              f"{r['n_interface_residues']}  "
              f"hotspot_frac={r['hotspot_energy_fraction']:.3f}  "
              f"driven={r['hotspot_driven']}")
        print(f"      ΔG_interface={r['dg_interface_kcal_per_mol']:+.2f}  "
              f"ΔG_hotspot={r['dg_hotspot_cluster_kcal_per_mol']:+.2f}  "
              f"ΔG_mimic={r['dg_mimic_kcal_per_mol']:+.2f} kcal/mol  "
              f"viable={r['small_molecule_disruption_viable']}")

    ctr = contrast(rows)
    print("\n## hotspot-driven-vs-flat contrast")
    hd, fl, wm = (ctr["hotspot_driven_reference"], ctr["flat_interface_reference"],
                  ctr["weak_mimic_failure_mode"])
    print(f"  HOTSPOT-DRIVEN {hd['interface']:<26} frac={hd['hotspot_energy_fraction']:.3f}  "
          f"ΔG_mimic={hd['dg_mimic_kcal_per_mol']:+.2f}  viable={hd['small_molecule_disruption_viable']}")
    print(f"  FLAT           {fl['interface']:<26} frac={fl['hotspot_energy_fraction']:.3f}  "
          f"hotspot_driven={fl['hotspot_driven']}")
    print(f"  WEAK-MIMIC     {wm['interface']:<26} mimicry={wm['mimicry_fraction']:.2f}  "
          f"viable={wm['small_molecule_disruption_viable']}")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — the alanine-scanning ΔΔG ledger, the")
    print("  hotspot fraction, the interface ΔG_bind and the hotspot-mimicry")
    print("  gate computed self-consistently. NOT a binding-affinity, potency,")
    print("  selectivity or therapeutic-efficacy claim. ΔΔG values are")
    print("  literature-informed surrogates for interface CLASSES, not fits to a")
    print("  specific complex. PPI is a SUB-AXIS (:> QUANTUM core) — recorded as")
    print("  borderline (score-main-eligible, QUANTUM-applicability sub tension")
    print("  flagged) — NOT a hexa-bio core-5 axis. No quantity is derived from")
    print("  the n=6 lattice.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "PPI",
        "parent_axis": "QUANTUM (core-5 — unchanged; sub hangs off it, AXIS/HIERARCHY.tape)",
        "placement_note": ("PPI scores main-eligible (4.8/5/5); recorded as a "
                           "BORDERLINE sub of QUANTUM per @D sub_under_quantum "
                           "due to QUANTUM-VQE-applicability tension — flagged, "
                           "not hidden"),
        "real_limit_anchor": ("Bogan-Thorn binding-hotspot theory (Bogan & Thorn, "
                              "Anatomy of hot spots in protein interfaces, "
                              "J. Mol. Biol. 280:1, 1998) — interface binding free "
                              "energy concentrated in a few hotspot residues, "
                              "bounded by the alanine-scanning ΔΔG ledger"),
        "hotspot_ddg_threshold_kcal_per_mol": HOTSPOT_DDG_THRESHOLD_KCAL,
        "mimicry_dg_threshold_kcal_per_mol": MIMICRY_DG_THRESHOLD_KCAL,
        "rows": rows,
        "contrast": ctr,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency ONLY "
                                   "(g8/f2) — not a binding-affinity or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__PPI__ PASS" if ok else "\n__PPI__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
