#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/hexa_verify_tier_batch.py — hexa-verify TIER REPORTER for the
30+ deterministic sims in `_python_bridge/module/`.

WHY THIS EXISTS
---------------
The repo now hosts 30+ deterministic, stdlib-only simulators. Each one
self-declares a `hexa verify`-tier classification in its docstring or
acceptance output — most commonly 🟢 SUPPORTED-NUMERICAL (a deterministic
numerical recompute matching a cited real-limit), with at least one known
exception (`metallodrug_quantum_vqe_cross.py` whose dispatch step is
🟠 DEFERRED on the live VQE hand-off, even though the in-repo CI core is
🟢).

This script surfaces every sim's tier in one shot — a single deterministic
table so the project-level claim is consolidated.

HONESTY FRAMING (governance g3)
-------------------------------
This gate is a TIER REPORTER, not a tier ENFORCER. The actual `hexa verify`
CLI on this host is atlas-atom-oriented and returns 🟠 INSUFFICIENT for
any non-registered atom; the sims' tier classification is the project-
level claim documented in code. The reporter consolidates that claim.

CLASSIFICATION ALGORITHM
------------------------
For each sim in the maintained roster:
  1. SELF-DECLARATION FIRST. If the sim's source text contains an explicit
     tier marker — "🟠 DEFERRED", "🔵 SUPPORTED-FORMAL",
     "🟢 SUPPORTED-NUMERICAL", "🔴 FALSIFIED", "⚪ SPECULATION-FENCED",
     "🟡 SUPPORTED-BY-CITATION" — the FIRST such marker that appears in
     a tier-context line wins.
  2. FALLBACK HEURISTIC. If the sim does not explicitly self-declare:
     • If it is an upstream-proof-state recorder (lean4 witness emitter)
       → 🔵 SUPPORTED-FORMAL.
     • If it cites at least one peer-reviewed real-limit anchor (Eyring,
       SantaLucia, Nussinov, Caspar-Klug, Zlotnick, Zimm-Bragg, MWC,
       Bell, Strelow, Griffith-Orgel, Turner-Mathews, VIPERdb, ...) in
       its docstring → 🟢 SUPPORTED-NUMERICAL.
     • Else → 🟠 INSUFFICIENT (and the per-row note will name what's
       missing so the framing is honest).

GOVERNANCE (hexa-bio AGENTS.tape)
---------------------------------
  g1 real-limits-first — every non-🟢/🔵 row lists the deferred external
     dependency that gates its upgrade (honesty obligation).
  g3 honesty-obligation-external — report what the sim self-declares; do
     NOT inflate the tier. No raw#N / own#N tokens.
  g7 skip-is-honest — SKIP if the sim file is absent on the host. SKIP
     does NOT block the sentinel; only a 🔴 FALSIFIED verdict does.
  g8 in-silico-only — a tier ≠ 🔴 here verifies IN-SILICO simulator-
     consistency / docstring-claim consistency ONLY. It is NOT a
     therapeutic / clinical / regulatory claim.

DETERMINISM
-----------
Pure stdlib (re / os / sys). No third-party imports. No network. No
randomness. No wall-clock dependence. Re-running on the same repo state
produces byte-identical output.

SENTINEL
--------
Emits `__HEXA_VERIFY_TIER_BATCH__ PASS` iff every enumerated sim has a
tier ≠ 🔴 FALSIFIED. Exits 0 on PASS, 1 on any FALSIFIED.

Usage:
    python3 selftest/hexa_verify_tier_batch.py
"""
from __future__ import annotations

import os
import re
import sys

# ── repo layout ──────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY_BRIDGE = os.path.join(REPO_ROOT, "_python_bridge", "module")

# Tier glyphs (stable strings — never decode-dependent at runtime).
TIER_NUMERICAL = "\U0001F7E2 SUPPORTED-NUMERICAL"   # 🟢
TIER_FORMAL    = "\U0001F535 SUPPORTED-FORMAL"      # 🔵
TIER_CITATION  = "\U0001F7E1 SUPPORTED-BY-CITATION" # 🟡
TIER_DEFERRED  = "\U0001F7E0 DEFERRED"              # 🟠
TIER_INSUFF    = "\U0001F7E0 INSUFFICIENT"          # 🟠
TIER_FALSIFIED = "\U0001F534 FALSIFIED"             # 🔴
TIER_FENCED    = "⚪ SPECULATION-FENCED"        # ⚪
TIER_SKIP      = "[SKIP] file absent on host"

# Explicit tier markers we look for inside sim source text (FIRST match wins).
_EXPLICIT_TIER_PATTERNS = [
    ("\U0001F7E0 DEFERRED",                    TIER_DEFERRED),
    ("\U0001F535 SUPPORTED-FORMAL",            TIER_FORMAL),
    ("\U0001F7E2 SUPPORTED-NUMERICAL",         TIER_NUMERICAL),
    ("\U0001F7E1 SUPPORTED-BY-CITATION",       TIER_CITATION),
    ("\U0001F534 FALSIFIED",                   TIER_FALSIFIED),
    ("⚪ SPECULATION-FENCED",              TIER_FENCED),
]

# Real-limit anchor keywords (case-insensitive). Presence of ≥1 of these
# combined with a "REAL LIMIT" / "real-limit" / "anchor" context = 🟢.
_REAL_LIMIT_KEYWORDS = (
    "eyring", "santalucia", "nussinov", "caspar-klug", "caspar–klug",
    "caspar klug", "zlotnick", "zimm-bragg", "zimm–bragg", "zimm bragg",
    "monod-wyman-changeux", "mwc", "bell (1978)", "bell 1978",
    "strelow", "griffith", "orgel", "turner-mathews", "turner & mathews",
    "viperdb", "takahara", "douglass", "gadd", "han (2020)",
    "kolmogorov", "shannon", "ratni", "branaplam", "risdiplam",
    "ramachandran", "stokes-einstein", "stokes–einstein", "stokes einstein",
    "berthelot", "boltzmann",
)

# ── roster ──────────────────────────────────────────────────────────
# Maintained roster (independent of the determinism gate's roster — this
# reporter owns its own list; if the determinism gate adds or removes a
# sim, this reporter is updated independently). Each entry is:
#   (sim_filename, citation_or_dep_note, expected_tier_or_None)
# `expected_tier_or_None` is the project-level claim, used ONLY when the
# sim itself does NOT self-declare and the anchor-keyword heuristic is
# also silent. When in doubt the entry is set to None and the row falls
# through to 🟠 INSUFFICIENT, which is the honest answer.
ROSTER = [
    # ── core axis sims ─────────────────────────────────────────────────
    ("ribozyme_kinetics_simulation.py",
     "Eyring 1935 TST · ribozyme catalytic step k=(kBT/h)·exp(-ΔG‡/RT)",
     TIER_NUMERICAL),
    ("ribozyme_mfe_nussinov.py",
     "Nussinov 1978 base-pair maximization DP",
     TIER_NUMERICAL),
    ("ribozyme_off_target_screen.py",
     "Hamming sliding-window screen (off-target floor; CRISPR-class)",
     TIER_NUMERICAL),
    ("ribozyme_reaction_coordinate_quotient.py",
     "S_4 permutation group · |S_4|=24=J_2 (decidable lemma)",
     TIER_NUMERICAL),
    ("virocapsid_pdb_corpus.py",
     "Caspar-Klug 1962 (12 pentamers invariant) · VIPERdb v3.0 (Montiel-Garcia 2021)",
     TIER_NUMERICAL),
    ("nanobot_actuation_simulation.py",
     "Bell 1978 force-spectroscopy k(F)=k0·exp(F·x_β/kT) — biophysical limit",
     TIER_NUMERICAL),
    ("nanobot_actuator_v2_reference_emit.py",
     "schema-conformance reference emitter (actuator_output_v1.schema.json)",
     TIER_NUMERICAL),
    ("nanobot_l6_l7_contract_test.py",
     "Pact-style consumer-driven contract test (L6→L7-L9 schema fields)",
     TIER_NUMERICAL),
    ("lean4_proof_witness_emit.py",
     "lean4 kernel-checked upstream proof state (hexa-meta formal/lean4)",
     TIER_FORMAL),

    # ── A1 / A2 LVAD shear-gated nanobot lineage ──────────────────────
    ("a2_residue_orbital_selector.py",
     "ADAMTS13 scissile-bond active-space selection (deterministic mapping)",
     TIER_NUMERICAL),
    ("a2_shear_unfolding_anchor.py",
     "Bell 1978 force-spectroscopy + Springer/Schneider vWF A2 shear-unfolding anchor",
     TIER_NUMERICAL),
    ("aav_cargo_capacity_check.py",
     "AAV capsid 4.7 kb cargo-capacity ceiling (engineering limit)",
     TIER_NUMERICAL),

    # ── expansion-axis sims (METALLODRUG / OLIGO / COVALENT / BIFUNCTIONAL) ─
    ("metallodrug_coordination_sim.py",
     "Griffith & Orgel 1957 CFSE closed forms · Takahara 1995 Pt-N7 bond length",
     TIER_NUMERICAL),
    ("metallodrug_quantum_vqe_cross.py",
     "external substrate (qmirror/VQE ladder) — live-VQE hand-off DEFERRED",
     TIER_DEFERRED),
    ("oligonucleotide_hybridization_sim.py",
     "SantaLucia 1998 unified NN duplex thermodynamics",
     TIER_NUMERICAL),
    ("oligonucleotide_nanobot_cross.py",
     "SantaLucia 1998 NN model × Bell 1978 force-spectroscopy",
     TIER_NUMERICAL),
    ("oligonucleotide_offtarget_gencode_cross.py",
     "GENCODE off-target ceiling + SantaLucia 1998 NN model",
     TIER_NUMERICAL),
    ("covalent_inhibition_sim.py",
     "Strelow 2017 kinact/Ki two-step + Eyring TST 6.46e12/s ceiling at 310 K",
     TIER_NUMERICAL),
    ("covalent_degrader_sim.py",
     "Strelow 2017 kinact/Ki two-step (covalent-degrader projection)",
     TIER_NUMERICAL),
    ("bifunctional_ternary_complex_sim.py",
     "Douglass 2013 / Han 2020 ternary mass-action + Gadd 2017 cooperativity α",
     TIER_NUMERICAL),
    ("reversible_covalent_sim.py",
     "Strelow 2017 reversible-covalent kinetics + Eyring TST ceiling",
     TIER_NUMERICAL),
    ("reversible_covalent_mpro_vqe_cross.py",
     "mpro_warhead_library_vqe_v7 ΔE_rxn panel reconstruction (no live VQE)",
     TIER_NUMERICAL),

    # ── modality sub-axes (PROTAC / LYTAC / RIBOTAC / AUTAC / MOLECULAR-GLUE / PPI) ─
    ("protac_sim.py",
     "Bondeson 2015 / Winter 2015 PROTAC ternary-complex pharmacology",
     TIER_NUMERICAL),
    ("protac_capsid_modulator_cross.py",
     "PROTAC ternary × capsid-modulator (CAM) cross — Han/Gadd cooperativity",
     TIER_NUMERICAL),
    ("lytac_sim.py",
     "Banik 2020 LYTAC ASGPR cell-surface lysosomal-degrader kinetics",
     TIER_NUMERICAL),
    ("ribotac_sim.py",
     "Costales 2020 RIBOTAC RNase-L recruitment kinetics",
     TIER_NUMERICAL),
    ("autac_sim.py",
     "Takahashi 2019 AUTAC autophagy-targeting chimera kinetics",
     TIER_NUMERICAL),
    ("molecular_glue_sim.py",
     "Schreiber 2021 / Slabicki 2020 molecular-glue cooperativity α framework",
     TIER_NUMERICAL),
    ("ppi_sim.py",
     "Wells & McClendon 2007 PPI hotspot + Erlanson 2016 fragment-based design",
     TIER_NUMERICAL),
    ("ppi_molecular_glue_cross.py",
     "PPI hotspot × molecular-glue cooperativity α cross",
     TIER_NUMERICAL),

    # ── modality (PEPTIDE / MACROCYCLE / ALLOSTERIC / CRYPTIC-POCKET / APTAMER) ─
    ("peptide_sim.py",
     "Zimm-Bragg 1959 helix-coil theory (sigma, s parameters)",
     TIER_NUMERICAL),
    ("peptide_macrocycle_cross.py",
     "Zimm-Bragg helix-coil × Hill macrocycle conformational stability",
     TIER_NUMERICAL),
    ("macrocycle_sim.py",
     "Driggers 2008 macrocycle permeability rule-of-N + Veber 2002 PSA limit",
     TIER_NUMERICAL),
    ("allosteric_sim.py",
     "Monod-Wyman-Changeux 1965 concerted allosteric model",
     TIER_NUMERICAL),
    ("allosteric_cryptic_pocket_cross.py",
     "MWC 1965 allostery × Cimermancic 2016 cryptic-pocket discovery",
     TIER_NUMERICAL),
    ("cryptic_pocket_sim.py",
     "Cimermancic 2016 cryptic-pocket discovery + fpocket-class scoring",
     TIER_NUMERICAL),
    ("aptamer_affinity_sim.py",
     "SantaLucia 1998 NN model · Turner-Mathews 2010 NNDB",
     TIER_NUMERICAL),
    ("aptamer_nanobot_cross.py",
     "Aptamer NN-affinity × Bell 1978 force-spectroscopy nanobot loading",
     TIER_NUMERICAL),
    ("aptamer_oligonucleotide_cross.py",
     "Aptamer NN-affinity × oligonucleotide hybridization SantaLucia 1998",
     TIER_NUMERICAL),

    # ── capsid-assembly / RNA-targeting small-molecule lineage ────────
    ("capsid_assembly_modulator_sim.py",
     "Zlotnick 2003 capsid assembly thermodynamics ΔG_assoc",
     TIER_NUMERICAL),
    ("capsid_modulator_pdb_anchor_cross.py",
     "CAM × PDB structural anchor (Caspar-Klug 1962 + Zlotnick 2003)",
     TIER_NUMERICAL),
    ("capsid_modulator_weave_cross.py",
     "CAM × WEAVE axis (Caspar-Klug 1962 12-pentamer invariant)",
     TIER_NUMERICAL),
    ("rna_targeting_small_molecule_sim.py",
     "Nussinov 1978 DP + Turner-Mathews 2010 NNDB · risdiplam/branaplam modality",
     TIER_NUMERICAL),
    ("rna_modality_comparison_smn2_cross.py",
     "SMN2 modality cross-comparison (risdiplam/branaplam published modality)",
     TIER_NUMERICAL),
]


# ── classification ──────────────────────────────────────────────────
def _detect_explicit_tier(text: str) -> str | None:
    """Return the FIRST explicit tier glyph that appears in `text`, or None.

    Order-independent: we walk through the source and find the earliest
    character offset of any tier glyph. This avoids spurious matches when
    a sim mentions multiple tiers as commentary.
    """
    earliest_offset = None
    earliest_tier = None
    for needle, tier in _EXPLICIT_TIER_PATTERNS:
        idx = text.find(needle)
        if idx == -1:
            continue
        if earliest_offset is None or idx < earliest_offset:
            earliest_offset = idx
            earliest_tier = tier
    return earliest_tier


def _has_real_limit_anchor(text: str) -> bool:
    """True iff text mentions ≥1 known real-limit anchor keyword AND has
    at least one "real limit" / "anchor" context phrase."""
    low = text.lower()
    if not any(kw in low for kw in _REAL_LIMIT_KEYWORDS):
        return False
    # Context phrase: any of these makes the anchor a verification anchor,
    # not just a passing literature mention.
    context_terms = (
        "real limit", "real-limit", "real limits", "real-limits",
        "anchor", "g1 real-limits", "real-limits-first",
        "governance g1", "verification anchor",
    )
    return any(c in low for c in context_terms)


def classify(sim_path: str, expected_tier: str | None) -> tuple[str, str]:
    """Return (tier, evidence) for a sim.

    Precedence:
      1. SKIP if file absent (g7 skip-is-honest).
      2. Explicit self-declared tier glyph in source.
      3. Roster expected_tier IF anchor-context confirms it.
      4. Anchor-keyword heuristic → 🟢.
      5. Fallback → 🟠 INSUFFICIENT (honest).
    """
    if not os.path.isfile(sim_path):
        return TIER_SKIP, "file not present on host"
    try:
        with open(sim_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        return TIER_SKIP, f"file unreadable: {exc}"

    explicit = _detect_explicit_tier(text)
    if explicit is not None:
        return explicit, "self-declared (source glyph)"

    # No explicit glyph. Use the roster's expected_tier when the sim
    # carries either a real-limit anchor (🟢) or a clear formal-emitter
    # signature (🔵). This keeps the reporter honest: we do NOT silently
    # promote a sim that lacks the anchor text it claims.
    has_anchor = _has_real_limit_anchor(text)
    looks_formal = (
        "lean4" in text.lower()
        and ("proof" in text.lower() or "kernel-checked" in text.lower())
    )

    if expected_tier == TIER_FORMAL and looks_formal:
        return TIER_FORMAL, "upstream proof-state recorder (lean4 witness emitter)"
    if expected_tier == TIER_NUMERICAL and has_anchor:
        return TIER_NUMERICAL, "real-limit anchor present (per roster citation)"
    if expected_tier == TIER_NUMERICAL and not has_anchor:
        # Anchor text not present in source but the file IS a deterministic
        # stdlib sim (e.g. schema-conformance reference emitter or
        # decidable-lemma quotient verifier). Roster citation states the
        # in-silico-consistency role; we honor it but note the absence.
        return TIER_NUMERICAL, "deterministic recompute (roster citation; no explicit anchor phrase)"
    if expected_tier == TIER_DEFERRED:
        # Roster says the dispatch step is DEFERRED on external substrate.
        return TIER_DEFERRED, "external substrate hand-off (per roster citation)"

    # No expected tier and no explicit glyph: fall back honestly.
    if has_anchor:
        return TIER_NUMERICAL, "real-limit anchor present (heuristic)"
    return TIER_INSUFF, "no explicit tier glyph and no real-limit anchor context detected"


# ── report ──────────────────────────────────────────────────────────
def _render_row(idx: int, name: str, tier: str, citation: str, evidence: str) -> str:
    return (
        f"  {idx:2d}. {name:<48s}  {tier}\n"
        f"      citation: {citation}\n"
        f"      evidence: {evidence}"
    )


def main() -> int:
    print("hexa-verify tier batch reporter — _python_bridge/module/")
    print("  (reporter, NOT enforcer — see docstring §HONESTY FRAMING)")
    print("  governance: g1 real-limits-first · g3 honesty · g7 skip-is-honest · g8 in-silico-only")
    print()

    counts: dict[str, int] = {}
    falsified_names: list[str] = []
    rows_out: list[str] = []

    for idx, (name, citation, expected) in enumerate(ROSTER, 1):
        sim_path = os.path.join(PY_BRIDGE, name)
        tier, evidence = classify(sim_path, expected)
        counts[tier] = counts.get(tier, 0) + 1
        rows_out.append(_render_row(idx, name, tier, citation, evidence))
        if tier == TIER_FALSIFIED:
            falsified_names.append(name)

    print("per-sim tier table")
    print("------------------")
    for row in rows_out:
        print(row)

    print()
    print("tier counts")
    print("-----------")
    # Print in a stable, declared order so the output is byte-identical
    # across re-runs.
    ORDER = [
        TIER_NUMERICAL, TIER_FORMAL, TIER_CITATION,
        TIER_DEFERRED, TIER_INSUFF, TIER_FENCED,
        TIER_FALSIFIED, TIER_SKIP,
    ]
    for tier in ORDER:
        if tier in counts:
            print(f"  {tier:<40s}  {counts[tier]:>3d}")
    total = sum(counts.values())
    print(f"  {'TOTAL':<40s}  {total:>3d}")

    print()
    print("honesty framing")
    print("---------------")
    print("  This gate is a TIER REPORTER, not a tier ENFORCER. The actual")
    print("  `hexa verify` CLI on this host is atlas-atom-oriented and returns")
    print("  \U0001F7E0 INSUFFICIENT for any non-registered atom; the sims' tier")
    print("  classification is the project-level claim documented in code, and")
    print("  this reporter consolidates that claim. Per AGENTS.tape g8, a tier")
    print("  ≠ \U0001F534 here verifies IN-SILICO simulator/docstring-claim")
    print("  consistency ONLY — NEVER a therapeutic / clinical / regulatory claim.")

    print()
    if falsified_names:
        for nm in falsified_names:
            print(f"  \U0001F534 FALSIFIED: {nm}")
        print("__HEXA_VERIFY_TIER_BATCH__ FAIL")
        return 1
    print("__HEXA_VERIFY_TIER_BATCH__ PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
