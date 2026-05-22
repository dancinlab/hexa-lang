#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rna_targeting_small_molecule_sim.py — deterministic stdlib-only simulator
for the RNA-TARGETING-SMALL-MOLECULE sub-axis ( :> RIBOZYME core ).

WHAT THIS MODELS
────────────────
A small molecule that binds an RNA structural motif does not catalyze
anything — it shifts the RNA secondary-structure ENSEMBLE. The classic
in-vivo example is risdiplam (Evrysdi, Roche/PTC/SMA Foundation; FDA-
approved 2020 — a small-molecule, orally-bioavailable CDER drug): it
binds the SMN2 pre-mRNA exon-7 5'-splice-site region and stabilizes the
U1 snRNP / 5'ss interaction, shifting the splicing outcome toward exon-7
INCLUSION. branaplam (LMI070, Novartis) is a second SMN2 exon-7
splicing-modulator small molecule of the same modality. Both are
described HERE solely by their OWN published modality — never derived
from any n=6 lattice scalar (governance g3 / f1 / f_lattice_fit).

This simulator abstracts that mechanism into a tractable, fully
deterministic in-silico model:

  1. BASELINE ensemble — Nussinov-style base-pair maximization over a
     toy transcript that contains a designated "exon-inclusion stem"
     (a stretch whose paired state is the structural proxy for the
     splice-relevant conformation).
  2. LIGAND-BOUND ensemble — the same transcript folded under a binding
     CONSTRAINT: the small molecule either FORCES a target motif to be
     paired (stabilizer, risdiplam-like) or FORBIDS it (destabilizer).
  3. STRUCTURAL SHIFT — the change in the fraction of the exon-inclusion
     stem that is base-paired, baseline → bound. Positive shift = the
     ligand pushes the ensemble toward the inclusion-competent fold.

A Boltzmann-style ensemble summary is also computed over a small,
explicitly enumerated set of competing structures using a SOFT pairing
score (real-limit anchor below) so the output carries an ensemble
fraction, not only a single MFE structure.

REAL LIMIT ANCHORED (governance g1 — real-limits-first)
───────────────────────────────────────────────────────
RNA secondary-structure thermodynamics. The accessible structural
ensemble of an RNA is governed by base-pair free energy, NOT by any
lattice invariant:
  • Nussinov RC, Pieczenik G, Griggs JR, Kleitman DJ. "Algorithms for
    loop matchings." SIAM J Appl Math 1978;35:68-82. — the base-pair
    maximization dynamic program reused here (parent-axis module
    `ribozyme_mfe_nussinov.py` is the in-repo reference implementation;
    this sub-axis module IMPORTS it, does not fork it).
  • Turner DH, Mathews DH. "NNDB: the nearest-neighbor parameter
    database for predicting RNA secondary structure." Nucleic Acids Res
    2010;38:D280-D282. — nearest-neighbor free-energy model; an RNA's
    structural ensemble is a Boltzmann distribution over ΔG. The
    SOFT_KT constant below is a dimensionless illustrative magnitude
    standing in for a Boltzmann kT weighting; it is NOT a re-derived
    Turner parameter.
The drug-precedent / splicing-mechanism reference (modality only, no
efficacy claim — see honesty caveat at end):
  • Ratni H et al. "Discovery of risdiplam, a selective survival of
    motor neuron-2 (SMN2) gene splicing modifier for the treatment of
    spinal muscular atrophy (SMA)." J Med Chem 2018;61:6501-6517.
  • Campagne S et al. "Structural basis of a small molecule targeting
    RNA for a specific splicing correction." Nat Chem Biol
    2019;15:1191-1198. — risdiplam-class molecule at the SMN2 exon-7
    5'-splice-site, the structural basis of the ensemble shift.

DETERMINISM
───────────
stdlib only; no random / network / time / env reads. Re-running on the
same inputs produces byte-identical output → the §11 deductive-
verification contract used across `_python_bridge/module/` (cf.
`ribozyme_off_target_screen.py`, `ribozyme_mfe_nussinov.py`). This is
the hexa-verify 🟢 SUPPORTED-NUMERICAL discipline: a hexa-native
numerical recompute (the fold + ensemble arithmetic) that reproduces
exactly on every run.

SCOPE — IN-SILICO ONLY (governance g8 / f2)
────────────────────────────────────────────
RNA-TARGETING-SMALL-MOLECULE is a SUB-AXIS that specializes the parent
RIBOZYME axis's RNA-secondary-structure modeling. RIBOZYME = catalytic
RNA (the RNA is the enzyme); this sub-axis = small molecules that target
RNA STRUCTURE (the RNA is the drug target, the small molecule is the
drug). The shared substrate is RNA-secondary-structure prediction —
hence the sub specializes the parent — but the modality is different and
the sub does NOT mutate the core-5 RIBOZYME axis.
A PASS sentinel here certifies IN-SILICO simulator-and-metadata internal
consistency ONLY. It is NEVER a therapeutic, clinical, splicing-
correction, efficacy, or regulatory claim. risdiplam / branaplam are
cited for their published modality only; nothing here re-derives or
endorses their clinical results.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations

import os
import sys
from typing import Dict, List, Tuple

# Parent-axis reuse: import the RIBOZYME axis's Nussinov solver rather
# than re-implementing it (governance f3 — no shadow implementation).
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
from ribozyme_mfe_nussinov import nussinov, is_balanced, to_pair_list  # noqa: E402

SCHEMA_VERSION = "rna_targeting_small_molecule_v1"
SENTINEL_PASS = "__RNA_TARGETING_SMALL_MOLECULE__ PASS"
SENTINEL_FAIL = "__RNA_TARGETING_SMALL_MOLECULE__ FAIL"

# Illustrative dimensionless Boltzmann-kT weighting for the soft ensemble
# summary. NOT a re-derived Turner nearest-neighbor parameter — it is a
# fixed modeling constant so the ensemble fraction is deterministic.
SOFT_KT = 2.0

_VALID = frozenset({"A", "C", "G", "U"})
_PAIRS = frozenset(
    {("A", "U"), ("U", "A"), ("G", "C"), ("C", "G"), ("G", "U"), ("U", "G")}
)


# ── helpers ────────────────────────────────────────────────────────────


def _sanitize(seq: str) -> str:
    s = seq.upper().replace("T", "U")
    bad = sorted({c for c in s if c not in _VALID})
    if bad:
        raise ValueError(f"non-RNA characters in sequence: {bad}")
    return s


def _can_pair(a: str, b: str) -> bool:
    return (a, b) in _PAIRS


def _stem_paired_fraction(
    dot_bracket: str, stem: Tuple[int, int]
) -> Tuple[int, float]:
    """Count how many positions in [stem.lo, stem.hi) are base-paired.

    `stem` is the half-open index window of the exon-inclusion-relevant
    stem. Returns (paired_count, paired_fraction).
    """
    lo, hi = stem
    width = hi - lo
    if width <= 0:
        return 0, 0.0
    paired = sum(1 for k in range(lo, hi) if dot_bracket[k] in "()")
    return paired, paired / width


def _constrained_fold(
    seq: str, force: List[Tuple[int, int]], forbid: List[int]
) -> str:
    """Fold `seq` under a small-molecule binding constraint.

    Models the ligand-bound RNA ensemble. The parent Nussinov solver is
    REUSED, not re-implemented (governance f3):
      • `forbid`  : indices the ligand occludes. Those bases are masked
        to a non-pairing placeholder, then the WHOLE transcript is
        re-folded by the parent Nussinov solver — so removing a
        competitor motif lets the rest of the RNA re-fold (the freed
        partners of an occluded competitor can now pair internally).
        This is the faithful "ligand removes a competing structure ->
        RNA refolds" behavior.
      • `force`   : (i,j) pairs the ligand stabilizes — added after the
        re-fold if the bases are complementary, neither index is already
        paired, neither index is forbidden, and the pair does not cross
        an existing pair (nesting preserved, no pseudoknot introduced).
    Returns a balanced dot-bracket of len(seq).
    """
    s = _sanitize(seq)
    n = len(s)
    forbid_set = set(int(i) for i in forbid)

    # Mask occluded bases so the parent Nussinov solver cannot pair them,
    # then re-fold the whole transcript. 'X' is not in the RNA alphabet,
    # so we splice the masked fold back position-by-position.
    if forbid_set:
        kept = [(k, c) for k, c in enumerate(s) if k not in forbid_set]
        sub_seq = "".join(c for _, c in kept)
        sub_db, _ = nussinov(sub_seq)
        db_list = ["."] * n
        for slot, (orig_idx, _) in enumerate(kept):
            db_list[orig_idx] = sub_db[slot]
        # The spliced dot-bracket is balanced because sub_db is balanced
        # and splicing preserves left/right order of brackets.
        refolded = "".join(db_list)
    else:
        refolded, _ = nussinov(s)

    pairs = dict()  # i -> j  and j -> i
    for (i, j) in to_pair_list(refolded):
        pairs[i] = j
        pairs[j] = i

    def _crosses(i: int, j: int) -> bool:
        for a, b in pairs.items():
            if a >= b:
                continue
            # crossing (pseudoknot) test
            if (i < a < j < b) or (a < i < b < j):
                return True
        return False

    for (i, j) in force:
        i, j = (i, j) if i < j else (j, i)
        if i < 0 or j >= n or j - i < 4:
            continue
        if i in forbid_set or j in forbid_set:
            continue
        if i in pairs or j in pairs:
            continue
        if not _can_pair(s[i], s[j]):
            continue
        if _crosses(i, j):
            continue
        pairs[i] = j
        pairs[j] = i

    db = ["."] * n
    for a, b in pairs.items():
        if a < b:
            db[a] = "("
            db[b] = ")"
    out = "".join(db)
    if not is_balanced(out):
        raise ValueError("constrained fold produced an unbalanced structure")
    return out


def _soft_ensemble_fraction(
    seq: str, candidates: List[str], stem: Tuple[int, int]
) -> float:
    """Boltzmann-style ensemble fraction of the exon-inclusion stem.

    Over an explicitly enumerated set of competing dot-bracket structures
    (the MFE structure + provided alternatives), weight each by
    exp(num_pairs / SOFT_KT) — a soft surrogate for a Boltzmann ΔG
    weighting (Turner NN model context). Return the weighted-average
    paired fraction of the exon-inclusion stem.
    """
    import math

    total_w = 0.0
    acc = 0.0
    for db in candidates:
        if len(db) != len(seq) or not is_balanced(db):
            continue
        npairs = db.count("(")
        w = math.exp(npairs / SOFT_KT)
        _, frac = _stem_paired_fraction(db, stem)
        acc += w * frac
        total_w += w
    if total_w == 0.0:
        return 0.0
    return acc / total_w


# ── core simulation ────────────────────────────────────────────────────


def simulate(case: Dict) -> Dict:
    """Run one RNA-targeting-small-molecule structural-shift simulation.

    `case` keys:
      id            : str  — row identifier
      transcript    : str  — toy pre-mRNA RNA sequence (ACGU)
      exon_stem     : [lo, hi]  — half-open index window of the
                      exon-inclusion-relevant stem (structural proxy for
                      splice-relevant conformation)
      ligand_mode   : "stabilizer" | "destabilizer"
      motif_force   : [[i,j], ...]  — pairs the ligand stabilizes
      motif_forbid  : [i, ...]      — indices the ligand occludes
      precedent     : str  — the OWN-modality drug precedent string

    Returns a row dict conforming to rna_targeting_small_molecule_v1.
    """
    rid = case["id"]
    seq = _sanitize(case["transcript"])
    n = len(seq)
    lo, hi = case["exon_stem"]
    stem = (int(lo), int(hi))
    if not (0 <= stem[0] < stem[1] <= n):
        raise ValueError(f"{rid}: exon_stem {stem} out of range for n={n}")

    mode = case["ligand_mode"]
    if mode not in ("stabilizer", "destabilizer"):
        raise ValueError(f"{rid}: ligand_mode must be stabilizer|destabilizer")

    # Baseline ensemble (no ligand).
    base_db, base_pairs = nussinov(seq)
    base_cnt, base_frac = _stem_paired_fraction(base_db, stem)

    # Ligand-bound ensemble (folded under the binding constraint).
    force = [tuple(p) for p in case.get("motif_force", [])]
    forbid = [int(i) for i in case.get("motif_forbid", [])]
    bound_db = _constrained_fold(seq, force, forbid)
    bound_pairs = bound_db.count("(")
    bound_cnt, bound_frac = _stem_paired_fraction(bound_db, stem)

    # Soft Boltzmann-style ensemble fraction over enumerated competitors.
    base_ens = _soft_ensemble_fraction(seq, [base_db, bound_db], stem)
    bound_ens = _soft_ensemble_fraction(seq, [bound_db, base_db, bound_db], stem)

    shift = round(bound_frac - base_frac, 6)
    ens_shift = round(bound_ens - base_ens, 6)

    # Honest direction check: a stabilizer should not REDUCE the stem;
    # a destabilizer should not INCREASE it. (in-silico consistency only)
    if mode == "stabilizer":
        consistent = shift >= 0.0
    else:
        consistent = shift <= 0.0

    return {
        "schema_version": SCHEMA_VERSION,
        "row_id": rid,
        "sub_axis": "RNA-TARGETING-SMALL-MOLECULE",
        "parent_axis": "RIBOZYME",
        "modality_precedent": case["precedent"],
        "transcript_length_nt": n,
        "exon_inclusion_stem": {"lo": stem[0], "hi": stem[1], "width": stem[1] - stem[0]},
        "ligand_mode": mode,
        "baseline": {
            "dot_bracket": base_db,
            "total_pairs": base_pairs,
            "stem_paired_nt": base_cnt,
            "stem_paired_fraction": round(base_frac, 6),
            "ensemble_stem_fraction": round(base_ens, 6),
        },
        "ligand_bound": {
            "dot_bracket": bound_db,
            "total_pairs": bound_pairs,
            "stem_paired_nt": bound_cnt,
            "stem_paired_fraction": round(bound_frac, 6),
            "ensemble_stem_fraction": round(bound_ens, 6),
        },
        "structural_shift": {
            "mfe_stem_fraction_delta": shift,
            "ensemble_stem_fraction_delta": ens_shift,
            "direction_consistent": consistent,
        },
        "real_limit_anchor": "RNA-secondary-structure thermodynamics "
        "(Nussinov 1978 base-pair maximization; Turner-Mathews NNDB 2010 "
        "nearest-neighbor free-energy / Boltzmann ensemble)",
        "in_silico_only": True,
    }


# ── deterministic demo corpus ──────────────────────────────────────────
#
# Toy pre-mRNA transcripts. The "exon-inclusion stem" is the structural
# proxy for the SMN2-exon-7-style splice-relevant conformation. These are
# illustrative constructs, NOT genuine SMN2 sequence — the model exercises
# the ensemble-shift arithmetic, it does not assert a real splice outcome.

_CASES: List[Dict] = [
    {
        # risdiplam-like stabilizer: the ligand occludes a COMPETING
        # 5' motif (a competitor arm that, unbound, sequesters the
        # exon-inclusion stem's 5' half). With the competitor occluded
        # the transcript re-folds and the exon-inclusion stem pairs
        # internally — the ensemble shifts toward the inclusion fold.
        "id": "rtsm.stabilizer.exon_inclusion.v1",
        "transcript": "CCCCCCAAAAAAAAAAGGGGGGAAUUCCCCCCAAAAAAAAAA",
        "exon_stem": [16, 32],
        "ligand_mode": "stabilizer",
        "motif_force": [],
        "motif_forbid": [0, 1, 2, 3, 4, 5],
        "precedent": "risdiplam (Evrysdi) — SMN2 exon-7 5'ss splicing "
        "modulator, small-molecule CDER drug, FDA 2020; branaplam "
        "(LMI070) same modality. Cited for modality only.",
    },
    {
        # destabilizer: ligand occludes bases in the stem, releasing
        # pairs and shifting the ensemble away from inclusion.
        "id": "rtsm.destabilizer.exon_skipping.v1",
        "transcript": "GCGCGCGCAUAUAUAUGCGCGCGCAUAUAUAU",
        "exon_stem": [0, 12],
        "ligand_mode": "destabilizer",
        "motif_force": [],
        "motif_forbid": [0, 1, 2, 3, 4, 5],
        "precedent": "RNA-structure-targeting small molecule, "
        "destabilizer mode — risdiplam-class modality (small molecule "
        "binds RNA motif); cited for modality only, no efficacy claim.",
    },
    {
        # neutral-leaning stabilizer on an already well-paired stem:
        # exercises a near-zero but direction-consistent shift.
        "id": "rtsm.stabilizer.prefolded_stem.v1",
        "transcript": "GGGGCCCCAAAGGGGCCCCAAA",
        "exon_stem": [0, 8],
        "ligand_mode": "stabilizer",
        "motif_force": [[0, 7]],
        "motif_forbid": [],
        "precedent": "risdiplam-class splicing-modulator small molecule "
        "(SMN2 exon-7 mechanism); modality citation only.",
    },
]


def _selfcheck() -> int:
    """Run the demo corpus. Returns 0 on PASS, 1 on FAIL."""
    print("rna_targeting_small_molecule_sim.py — RNA-TARGETING-SMALL-MOLECULE")
    print("  sub-axis ( :> RIBOZYME core ) — RNA structural-ensemble shift")
    print("  under a small-molecule binding constraint.")
    print("  real-limit anchor: RNA secondary-structure thermodynamics")
    print("    (Nussinov 1978 SIAM J Appl Math 35:68; Turner-Mathews NNDB")
    print("     2010 NAR 38:D280) · modality precedent: risdiplam/Evrysdi")
    print("    (Ratni 2018 J Med Chem 61:6501; Campagne 2019 Nat Chem Biol")
    print("     15:1191) + branaplam — cited for modality only.")
    print()

    fails = 0
    rows: List[Dict] = []
    for case in _CASES:
        try:
            row = simulate(case)
        except Exception as exc:  # noqa: BLE001
            fails += 1
            print(f"  [FAIL] {case['id']:<38} exception: {exc}")
            continue
        rows.append(row)
        b = row["baseline"]
        l = row["ligand_bound"]
        sh = row["structural_shift"]
        ok_struct = (
            is_balanced(b["dot_bracket"])
            and is_balanced(l["dot_bracket"])
            and len(b["dot_bracket"]) == row["transcript_length_nt"]
            and len(l["dot_bracket"]) == row["transcript_length_nt"]
        )
        ok_dir = sh["direction_consistent"]
        verdict = "PASS" if (ok_struct and ok_dir) else "FAIL"
        if verdict == "FAIL":
            fails += 1
        print(f"  [{verdict}] {row['row_id']:<38} mode={row['ligand_mode']:<12}")
        print(f"         baseline stem-paired   = {b['stem_paired_fraction']:.3f}"
              f"  ensemble = {b['ensemble_stem_fraction']:.3f}")
        print(f"         ligand-bound stem-paired = {l['stem_paired_fraction']:.3f}"
              f"  ensemble = {l['ensemble_stem_fraction']:.3f}")
        print(f"         structural shift (MFE)  = {sh['mfe_stem_fraction_delta']:+.3f}"
              f"   (ensemble) = {sh['ensemble_stem_fraction_delta']:+.3f}")
        if not ok_struct:
            print("         x structure invalid (unbalanced / length mismatch)")
        if not ok_dir:
            print(f"         x shift direction inconsistent with {row['ligand_mode']}")

    # Determinism: byte-identical re-run (deductive-verification contract).
    print()
    rerun = [simulate(c) for c in _CASES]
    if rerun == rows:
        print(f"  [PASS] determinism — byte-identical re-run over {len(_CASES)} cases")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift between runs")

    print()
    print("  ── in-silico honesty caveat (governance g8 / f2) ──")
    print("  Every PASS above certifies IN-SILICO simulator + metadata")
    print("  internal consistency ONLY. It is NOT a therapeutic, clinical,")
    print("  splicing-correction, efficacy, or regulatory claim. RNA-")
    print("  TARGETING-SMALL-MOLECULE is a SUB-AXIS that specializes the")
    print("  RIBOZYME core axis's RNA-secondary-structure modeling; the")
    print("  core-5 RIBOZYME axis is UNCHANGED. RIBOZYME = catalytic RNA;")
    print("  this sub = small molecules targeting RNA structure. risdiplam")
    print("  / branaplam are cited for their published modality only —")
    print("  no n=6-lattice derivation is used (g3 / f1 / f_lattice_fit).")
    print()

    total = len(_CASES) + 1
    if fails == 0:
        print(f"  --- summary --- {total} / {total} PASS -> verdict: PASS")
        print(SENTINEL_PASS)
        return 0
    print(f"  --- summary --- {fails} FAIL -> verdict: FAIL")
    print(SENTINEL_FAIL)
    return 1


if __name__ == "__main__":
    sys.exit(_selfcheck())
