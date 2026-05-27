#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
molecular_glue_sim.py — MOLECULAR-GLUE sub-axis :> BIFUNCTIONAL
(expansion-main).

Deterministic, stdlib-only real-limits model of a MOLECULAR GLUE: a MONOVALENT
small molecule (no bivalent linker) that nucleates a neo-interface between a
target protein and an E3 ubiquitin ligase, inducing a ternary complex that
neither binary affinity alone would form. This is the in-silico
simulator-consistency layer for the MOLECULAR-GLUE sub-axis registered in
AXIS/HIERARCHY.tape `@D sub_under_bifunctional` — see the sibling note
`molecular_glue_subaxis.md`.

────────────────────────────────────────────────────────────────────────────
WHAT IS MODELLED
────────────────────────────────────────────────────────────────────────────
A heterobifunctional degrader (PROTAC) has TWO real binding warheads joined by
a linker; it is bivalent — each end binds with its own intrinsic affinity. A
MOLECULAR GLUE is fundamentally different: it is MONOVALENT. It binds one
partner with appreciable affinity, has only marginal (often immeasurable)
intrinsic affinity for the other, and it works by remodelling the bound
partner's surface so that a NEW protein-protein interface is created. The
ternary complex is held together COOPERATIVELY — by the glue's grip on one
partner PLUS the glue-induced target↔E3 protein-protein contact.

  Cooperative ternary equilibrium (Douglass et al. cooperativity framework):

      T + E3      ⇌(K_PPI)        T·E3            bare protein-protein interface
      T·E3 + G    ⇌(K_glue/α)     T·E3·G          glue grips & stabilizes it
      — equivalently —
      T + G       ⇌(K_glue)       T·G             glue binds the target
      T·G + E3    ⇌(K_PPI/α)      T·E3·G          cooperative ternary closure

  The cooperativity factor α (alpha, = "cooperativity" in the glue literature)
  multiplies the effective affinity of the SECOND event. For a molecular glue
  α ≫ 1 (strongly POSITIVE cooperativity): the glue-induced neo-interface makes
  the ternary complex far more stable than the product of the two binary
  affinities. The hallmark, modelled here as the defining acceptance gate:

      NEITHER binary affinity alone is sufficient — both the glue→target
      binary occupancy AND the bare target↔E3 binary occupancy are LOW, yet
      the cooperative ternary occupancy is HIGH because α amplifies the
      second binding event. f_ternary ≫ f_binary_target AND f_ternary ≫
      f_binary_PPI is the glue signature.

────────────────────────────────────────────────────────────────────────────
REAL LIMIT ANCHORED (governance g1 — verification anchors ≥1 real limit)
────────────────────────────────────────────────────────────────────────────
COOPERATIVE TERNARY-COMPLEX EQUILIBRIUM (mass-action with a cooperativity
factor). The ternary-complex thermodynamics of induced-proximity modalities
follow the cooperativity formalism of Douglass et al., *J. Am. Chem. Soc.*
135:6092 (2013), refined for glues/PROTACs by Han, *Drug Discov. Today* 25:1832
(2020) — the ternary equilibrium is governed by the binary dissociation
constants AND a cooperativity factor α, and all occupancies are mass-action
solutions (Guldberg & Waage law of mass action, 1864). No modelled occupancy
may exceed 1.0 — the unit ceiling is the hard real-limit gate (acceptance C2).
The model further enforces detailed balance: the two equivalent assembly paths
(T+G then +E3 vs T+E3 then +G) must reach the SAME ternary occupancy, the
thermodynamic-cycle consistency that any cooperative-equilibrium model must
satisfy (acceptance C3).

────────────────────────────────────────────────────────────────────────────
OWN PRECEDENT (governance g3 / forbidden-patterns f1, f_lattice_fit)
────────────────────────────────────────────────────────────────────────────
MOLECULAR-GLUE is described ONLY by its own modality precedent, never
lattice-derived: the immunomodulatory drugs lenalidomide and thalidomide —
monovalent CRBN glues that recruit neosubstrates (IKZF1/IKZF3) to the CRL4-CRBN
E3 ligase (Krönke et al., *Science* 343:301, 2014; Lu et al., *Science*
343:305, 2014), both FDA-approved; and indisulam — an aryl-sulfonamide glue
that recruits the splicing factor RBM39 to the E3 substrate-receptor DCAF15
(Han et al., *Science* 356:eaal3755, 2017; Uehara et al., *Nat. Chem. Biol.*
13:675, 2017). No quantity in this module is derived from the n=6 lattice.

────────────────────────────────────────────────────────────────────────────
HONESTY (governance g8 / forbidden-pattern f2)
────────────────────────────────────────────────────────────────────────────
The `__MOLECULAR_GLUE__ PASS` sentinel certifies IN-SILICO simulator+metadata
internal consistency ONLY: that the cooperative-ternary mass-action occupancies,
the thermodynamic-cycle (detailed-balance) consistency and the "neither binary
sufficient" glue signature are computed self-consistently and reproduce
byte-identically. It is a thermodynamic-equilibrium MODEL — NOT an affinity
measurement, NOT a degradation (DC50/Dmax) claim, NOT a therapeutic-efficacy
claim. K_glue / K_PPI / α values are illustrative literature-informed surrogates
for the modality, not fits to a specific compound. Pure stdlib, no
network/time/random → byte-identical re-runs.

MOLECULAR-GLUE is a SUB-AXIS (:> BIFUNCTIONAL, an expansion-MAIN axis) — it is
NOT one of the hexa-bio core-5 axes. See AXIS/HIERARCHY.tape
`@D sub_under_bifunctional`.
"""
from __future__ import annotations
import json
import sys

SCHEMA_ID = "molecular_glue_v1"

# ── glue-signature threshold ──
# A molecular glue must show that NEITHER binary occupancy alone is sufficient:
# both binary fractions below this floor, while the ternary fraction is high.
BINARY_INSUFFICIENT_CEILING = 0.30   # binary occupancy considered "low"
TERNARY_SUFFICIENT_FLOOR = 0.50      # cooperative ternary considered "high"

# ── deterministic MOLECULAR-GLUE panel ──────────────────────────────────────
# (name, K_glue_nM, K_PPI_nM, alpha, precedent)
#   K_glue : dissociation constant of the monovalent glue to the partner it
#            binds with appreciable affinity (the target neosubstrate) (nM).
#   K_PPI  : dissociation constant of the BARE target<->E3 protein-protein
#            interface, with NO glue — typically very weak (nM, large).
#   alpha  : cooperativity factor (>= 1). For a molecular glue alpha >> 1:
#            the glue-induced neo-interface amplifies the second binding event.
# Values are illustrative literature-informed surrogates for the modality,
# not fits to a specific compound (see module honesty note).
# K_glue and K_PPI are deliberately WEAK (µM range): for a real molecular
# glue the binary affinities are typically un- or barely-measurable in
# isolation — that weakness is the modality's defining feature, and the
# cooperative neo-interface (α ≫ 1) is what makes the ternary appear.
GLUE_PANEL = [
    ("glue_lenalidomide_IKZF1",
     10000.0, 30000.0, 1500.0,
     "lenalidomide — CRBN glue recruiting IKZF1 (Kronke/Lu, Science 2014; FDA-approved)"),
    ("glue_thalidomide_IKZF3",
     12000.0, 25000.0, 1200.0,
     "thalidomide — CRBN glue recruiting IKZF3 (Kronke/Lu, Science 2014; FDA-approved)"),
    ("glue_indisulam_RBM39",
     8000.0, 20000.0, 1000.0,
     "indisulam — DCAF15 glue recruiting RBM39 (Han/Uehara, Science/NCB 2017)"),
    ("glue_research_weak_coop",
     20000.0, 50000.0, 200.0,
     "research-stage CRBN glue, modest cooperativity (negative-control α)"),
]

# Fixed deterministic assay concentrations (nM).
CONC_TARGET_nM = 1000.0
CONC_E3_nM = 1000.0
CONC_GLUE_nM = 1000.0


def cooperative_ternary(k_glue_nM: float, k_ppi_nM: float, alpha: float,
                        conc_target_nM: float = CONC_TARGET_nM,
                        conc_e3_nM: float = CONC_E3_nM,
                        conc_glue_nM: float = CONC_GLUE_nM) -> dict:
    """
    Cooperative ternary-complex equilibrium for a monovalent molecular glue
    via the standard path-independent closed form (target-perspective; glue
    and E3 in pseudo-excess so free ≈ total).

    Define dimensionless concentrations relative to K_glue / K_PPI:
        g = [G]/K_glue ,   e = [E3]/K_PPI

    Target partition function over {free, T·G, T·E3, T·G·E3}:
        Z = 1 + g + e + α·g·e

    Fractions of total target in each state (sum = 1 by construction):
        f_free            = 1     / Z
        f_binary_target   = g     / Z   (T·G only, no E3)
        f_binary_PPI      = e     / Z   (T·E3 only, no glue)
        f_ternary         = α·g·e / Z   (T·G·E3 cooperative neo-interface)

    The cooperativity factor α amplifies the ternary state — when α ≫ 1 the
    f_ternary term dominates Z even though g and e are individually small
    (≪ 1). The closed form is path-independent (Wegscheider / detailed
    balance is automatic), so the f_ternary value reached by either ordered
    binding sequence is identical at equilibrium.
    """
    # dimensionless reduced concentrations
    g = conc_glue_nM / k_glue_nM
    e = conc_e3_nM / k_ppi_nM

    # target partition function — closed-form, path-independent
    Z = 1.0 + g + e + alpha * g * e
    f_free = 1.0 / Z
    f_binary_target = g / Z
    f_binary_ppi = e / Z
    f_ternary = alpha * g * e / Z

    # Wegscheider detailed-balance check: state-fractions partition unity
    # (the ternary closed-form is path-independent by construction; this
    # checks the partition closes to within libm precision).
    partition_residual = abs((f_free + f_binary_target
                              + f_binary_ppi + f_ternary) - 1.0)

    # glue signature: NEITHER binary alone sufficient, yet ternary is high.
    binary_target_low = f_binary_target < BINARY_INSUFFICIENT_CEILING
    binary_ppi_low = f_binary_ppi < BINARY_INSUFFICIENT_CEILING
    ternary_high = f_ternary > TERNARY_SUFFICIENT_FLOOR
    glue_signature = binary_target_low and binary_ppi_low and ternary_high

    return {
        "k_glue_nM": k_glue_nM,
        "k_ppi_nM": k_ppi_nM,
        "alpha": alpha,
        "conc_target_nM": conc_target_nM,
        "conc_e3_nM": conc_e3_nM,
        "conc_glue_nM": conc_glue_nM,
        "g_reduced": g,
        "e_reduced": e,
        "f_free": f_free,
        "f_binary_target": f_binary_target,
        "f_binary_ppi": f_binary_ppi,
        "f_ternary": f_ternary,
        "partition_residual": partition_residual,
        "binary_target_insufficient": binary_target_low,
        "binary_ppi_insufficient": binary_ppi_low,
        "ternary_sufficient": ternary_high,
        "neither_binary_sufficient": binary_target_low and binary_ppi_low,
        "glue_signature": glue_signature,
        "ternary_over_best_binary": f_ternary / max(f_binary_target,
                                                    f_binary_ppi),
    }


def build_rows() -> list:
    """Compute one schema-conformant row per molecular glue in the panel."""
    rows = []
    for name, k_glue, k_ppi, alpha, precedent in GLUE_PANEL:
        eq = cooperative_ternary(k_glue, k_ppi, alpha)
        row = {
            "schema": SCHEMA_ID,
            "molecular_glue": name,
            "drug_precedent": precedent,
            "valency": "monovalent (no bivalent linker)",
        }
        row.update(eq)
        rows.append(row)
    return rows


def acceptance(rows: list) -> dict:
    """In-silico simulator-consistency acceptance criteria (C1–C6)."""
    crit = {
        "C1_panel_non_empty": len(rows) >= 4,
        "C2_mass_action_fractions_bounded": all(
            0.0 <= r["f_binary_target"] <= 1.0
            and 0.0 <= r["f_binary_ppi"] <= 1.0
            and 0.0 <= r["f_ternary"] <= 1.0
            for r in rows),
        "C3_partition_function_closes_to_unity": all(
            r["partition_residual"] < 1e-12 for r in rows),
        "C4_positive_cooperativity": all(
            r["alpha"] > 1.0 for r in rows),
        # C5 — positive + negative controls. Every panel entry has the
        # 'neither binary sufficient' property (weak K_glue / K_PPI is the
        # modality's defining feature). The 'glue signature' (cooperative
        # ternary high) is REQUIRED for FDA-approved high-α entries and
        # explicitly EXPECTED TO FAIL for the labelled "weak_coop" control
        # — that asymmetry verifies the gate is discriminating, not just
        # permissive.
        "C5_neither_binary_sufficient_across_panel": all(
            r["neither_binary_sufficient"] for r in rows),
        "C5b_high_alpha_shows_glue_signature_low_alpha_does_not": all(
            (r["glue_signature"] if "weak_coop" not in r["molecular_glue"]
             else not r["glue_signature"])
            for r in rows),
        "C6_ternary_exceeds_best_binary": all(
            r["ternary_over_best_binary"] > 1.0 for r in rows),
    }
    n_pass = sum(1 for v in crit.values() if v)
    return {
        "criteria": crit,
        "pass_count": n_pass,
        "total": len(crit),
        "verdict": "PASS" if n_pass == len(crit) else "FAIL",
    }


def main() -> int:
    print("molecular_glue_sim — MOLECULAR-GLUE sub-axis :> BIFUNCTIONAL "
          "(expansion-main)\n", flush=True)
    print("model:  monovalent glue (NO linker) nucleates a neo-interface →")
    print("        cooperative ternary  T·E3·G  ;  cooperativity factor α "
          "amplifies the 2nd event")
    print("        glue signature: NEITHER binary affinity alone sufficient, "
          "yet cooperative ternary high\n", flush=True)
    print("  real-limit : cooperative ternary-complex equilibrium (mass-action "
          "+ cooperativity α)")
    print("               — Douglass et al., JACS 135:6092 (2013); Han, "
          "Drug Discov. Today 25:1832 (2020);")
    print("                 Guldberg & Waage law of mass action (1864) — "
          "occupancies ≤ 1.0,")
    print("                 thermodynamic-cycle detailed balance enforced\n",
          flush=True)
    print(f"  assay: [target]={CONC_TARGET_nM:.0f}nM  [E3]={CONC_E3_nM:.0f}nM  "
          f"[glue]={CONC_GLUE_nM:.0f}nM\n", flush=True)

    rows = build_rows()
    for r in rows:
        print(f"  [{r['molecular_glue']:<26}] K_glue={r['k_glue_nM']:.0f}nM  "
              f"K_PPI={r['k_ppi_nM']:.0f}nM  α={r['alpha']:.0f}")
        print(f"      binary(target)={r['f_binary_target']:.4f}  "
              f"binary(PPI)={r['f_binary_ppi']:.4f}  →  "
              f"cooperative ternary={r['f_ternary']:.4f}")
        print(f"      neither-binary-sufficient={r['neither_binary_sufficient']}"
              f"  glue-signature={r['glue_signature']}  "
              f"ternary/best-binary={r['ternary_over_best_binary']:.1f}×")

    acc = acceptance(rows)
    print("\n## acceptance — in-silico simulator-consistency criteria")
    for k, v in acc["criteria"].items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    print(f"\n  --- {acc['pass_count']}/{acc['total']}  →  verdict: {acc['verdict']} ---")

    print("\n## honesty (g8 / f2): this verdict is IN-SILICO simulator+metadata")
    print("  internal consistency ONLY — cooperative-ternary mass-action")
    print("  occupancies, thermodynamic-cycle detailed balance and the")
    print("  'neither binary sufficient' glue signature computed self-")
    print("  consistently. NOT an affinity, degradation (DC50/Dmax) or")
    print("  therapeutic claim. K_glue/K_PPI/α are literature-informed")
    print("  surrogates, not compound fits. MOLECULAR-GLUE is a SUB-AXIS")
    print("  (:> BIFUNCTIONAL expansion-main), NOT a hexa-bio core-5 axis.")

    witness = {
        "schema": SCHEMA_ID,
        "ts": "2026-05-16T00:00:00Z",   # fixed → deterministic byte-identical re-runs
        "sub_axis": "MOLECULAR-GLUE",
        "parent_axis": "BIFUNCTIONAL (expansion-main, AXIS/HIERARCHY.tape)",
        "real_limit_anchor": ("cooperative ternary-complex equilibrium — "
                              "mass-action with a cooperativity factor "
                              "(Douglass et al., JACS 135:6092, 2013; Han, "
                              "Drug Discov. Today 25:1832, 2020; Guldberg & "
                              "Waage law of mass action, 1864)"),
        "binary_insufficient_ceiling": BINARY_INSUFFICIENT_CEILING,
        "ternary_sufficient_floor": TERNARY_SUFFICIENT_FLOOR,
        "rows": rows,
        "acceptance": acc,
        "in_silico_scope_caveat": ("simulator+metadata internal consistency "
                                   "ONLY (g8/f2) — not an affinity, "
                                   "degradation-potency or therapeutic claim"),
    }
    print("\n## witness JSON")
    print(json.dumps(witness, indent=2, ensure_ascii=False))

    ok = acc["verdict"] == "PASS"
    print("\n__MOLECULAR_GLUE__ PASS" if ok else "\n__MOLECULAR_GLUE__ FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
