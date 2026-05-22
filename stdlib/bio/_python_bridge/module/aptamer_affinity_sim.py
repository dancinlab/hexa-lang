#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aptamer_affinity_sim.py — APTAMER sub-axis (:> RIBOZYME core) deterministic,
stdlib-only affinity simulator.

SUB-AXIS STATUS (honest)
------------------------
APTAMER is a SPECIALIZATION SUB-AXIS hanging off the core RIBOZYME axis — it
is NOT a 6th core axis (the hexa-bio core stays 5: QUANTUM · WEAVE · NANOBOT ·
RIBOZYME · VIROCAPSID — see AXIS.tape / AXIS/HIERARCHY.tape). Recorded per the
expansion-layer pattern in AXIS/HIERARCHY.tape.

RIBOZYME = catalytic RNA (Cech/Altman class — RNA that performs chemistry,
k_cat > 0). An APTAMER is a NON-catalytic structured oligonucleotide BINDER
(k_cat = 0): a folded RNA or DNA whose secondary/tertiary structure forms a
binding pocket for a ligand. The two share the parent axis's machinery — RNA
secondary-structure folding (cf. `ribozyme_mfe_nussinov.py`, Nussinov 1978) —
but the sub specializes that fold-modeling toward equilibrium AFFINITY rather
than catalytic turnover. The shared corpus context is the literature-anchored
`ribozyme/module/aptamer_null_corpus.hexa` negative-control set (binding-only
RNAs, k_cat = 0).

WHAT THIS MODULE COMPUTES (two deterministic real-limits computations)
----------------------------------------------------------------------
1. Secondary-structure folding free energy
   - Nussinov-style base-pair maximization (combinatorial; same algorithm
     family as the parent axis's `ribozyme_mfe_nussinov.py`).
   - A Turner-style nearest-neighbour STACK-SUM ΔG surrogate: each stacked
     adjacent base-pair step contributes a negative free-energy increment;
     this is the structure-thermodynamics anchor (Turner & Mathews
     nearest-neighbour model). The fold defines the binding-competent pocket.

2. Equilibrium binding model
   - A 1:1 (Langmuir) binding equilibrium  A + L  <=>(kon, koff)  A.L
   - Dissociation constant  Kd = koff / kon  (units M).
   - Fraction bound  theta = [L] / (Kd + [L])  — the standard saturation
     isotherm. theta = 0.5 exactly at [L] = Kd (the operational definition
     of Kd). This is law-of-mass-action equilibrium, no fitting.

REAL LIMITS ANCHORED (governance g1 — real-limits-first)
--------------------------------------------------------
* RNA/DNA secondary-structure folding thermodynamics — the nearest-neighbour
  free-energy model: SantaLucia (1998) "A unified view of polymer, dumbbell,
  and oligonucleotide DNA nearest-neighbor thermodynamics", PNAS 95:1460-1465;
  and the RNA Turner parameter set: Turner & Mathews (2010) "NNDB: the nearest
  neighbor parameter database", Nucleic Acids Research 38:D280-D282. Folding
  free energy is a sum of stacked nearest-neighbour increments — a measured
  thermodynamic quantity, not a derived/lattice value.
* A published aptamer dissociation constant — the thrombin-binding DNA
  aptamer (the 15-mer G-quadruplex "TBA"): Bock, Griffin, Latham, Vermaas &
  Toole (1992) "Selection of single-stranded DNA molecules that bind and
  inhibit human thrombin", Nature 355:564-566. The TBA binds human alpha-
  thrombin with a reported Kd in the low-to-mid nanomolar regime (~25-200 nM
  across assay conditions in the subsequent literature). Used here as the
  literature anchor for the binding-equilibrium check.
* Drug precedent for the modality (described ONLY by its own precedent —
  governance g3/f1/f_lattice_fit; NEVER lattice-derived): pegaptanib sodium
  (Macugen), a PEGylated anti-VEGF165 RNA aptamer, FDA-approved 2004 for
  neovascular age-related macular degeneration; and avacincaptad pegol
  (Izervay/Zimura), an anti-complement-C5 RNA aptamer, FDA-approved 2023 for
  geographic atrophy. These establish the aptamer as a real, independent
  therapeutic modality with its own clinical track record.

HONESTY / SCOPE (governance g8 / f2 — in-silico-only)
-----------------------------------------------------
A PASS here verifies IN-SILICO SIMULATOR-CONSISTENCY ONLY: that the folding
and binding models are internally self-consistent and reproduce textbook
identities (theta = 0.5 at [L] = Kd; Kd = koff/kon; monotone saturation;
balanced dot-bracket). It is NOT a wet-lab, structural, binding-affinity,
therapeutic, clinical, or regulatory claim about any aptamer. The parameters
are literature-informed illustrative magnitudes, not fits to a specific
experimental dataset. Crossing the wet-lab boundary is out of repo scope
(AGENTS.tape g8_in_silico_only · f2 · CLOSURE_RESIDUAL_BACKLOG.md §0).

NO LATTICE DERIVATION (governance g2 / f_lattice_fit): nothing in this module
derives a count, energy, rate, or Kd from the n=6 lattice (sigma/tau/phi/J2).
Folding ΔG comes from nearest-neighbour thermodynamics; Kd comes from the
law of mass action. Any numeric coincidence with a lattice scalar would be
observation only, never a derivation.

Determinism: pure stdlib (math, json, sys only); no random / network / time /
env. Re-running on the same input produces byte-identical output.

License: Apache-2.0 (hexa-bio core).
"""
from __future__ import annotations

import json
import math
import sys
from typing import Dict, List, Tuple

SCHEMA_ID = "aptamer_affinity_v1"
SENTINEL_OK = "__APTAMER_AFFINITY__ PASS"
SENTINEL_FAIL = "__APTAMER_AFFINITY__ FAIL"

# ── nucleic-acid pairing (RNA + DNA; T folded to U) ───────────────────
MIN_HAIRPIN_LOOP = 3  # j - i must be >= 4 for (i,j) to pair
_VALID = frozenset({"A", "C", "G", "U"})
_PAIRS = frozenset({
    ("A", "U"), ("U", "A"), ("G", "C"), ("C", "G"), ("G", "U"), ("U", "G"),
})

# ── Turner-style nearest-neighbour STACK free-energy increments ───────
# Illustrative magnitudes (kcal/mol, 37 C) in the spirit of the Turner /
# SantaLucia nearest-neighbour model: a G:C-rich stacked step is more
# stabilizing than an A:U-rich step. NOT a verbatim parameter-table copy
# and NOT a lattice value — a literature-informed surrogate keyed by the
# two pair "strengths" of an adjacent stacked base-pair step.
_NN_STACK_DG = {
    # (pair_strength_outer, pair_strength_inner) -> dG kcal/mol per stack
    ("GC", "GC"): -3.4,   # strongest stacked step
    ("GC", "AU"): -2.2,
    ("AU", "GC"): -2.2,
    ("AU", "AU"): -1.1,
    ("GC", "GU"): -1.5,
    ("GU", "GC"): -1.5,
    ("AU", "GU"): -0.7,
    ("GU", "AU"): -0.7,
    ("GU", "GU"): -0.5,   # weakest (wobble:wobble)
}
_PAIR_CLASS = {
    ("G", "C"): "GC", ("C", "G"): "GC",
    ("A", "U"): "AU", ("U", "A"): "AU",
    ("G", "U"): "GU", ("U", "G"): "GU",
}


# ── input sanitation ──────────────────────────────────────────────────

def sanitize(seq: str) -> str:
    """Uppercase, fold DNA T -> U, reject non-nucleic-acid characters."""
    s = seq.upper().replace("T", "U")
    bad = sorted({c for c in s if c not in _VALID})
    if bad:
        raise ValueError(f"non-nucleic-acid characters in sequence: {bad}")
    return s


def _pair(a: str, b: str) -> int:
    return 1 if (a, b) in _PAIRS else 0


# ── (1a) Nussinov base-pair maximization (combinatorial fold) ─────────

def nussinov(seq: str) -> Tuple[str, int]:
    """Nussinov 1978 base-pair-maximization fold.

    Returns (dot_bracket, num_pairs). Deterministic traceback priority:
    i unpaired, j unpaired, (i,j) paired, bifurcation.
    """
    s = sanitize(seq)
    n = len(s)
    if n < MIN_HAIRPIN_LOOP + 2:
        return "." * n, 0

    N: List[List[int]] = [[0] * n for _ in range(n)]
    for length in range(MIN_HAIRPIN_LOOP + 1, n):
        for i in range(0, n - length):
            j = i + length
            best = N[i + 1][j]
            if N[i][j - 1] > best:
                best = N[i][j - 1]
            if j - i >= MIN_HAIRPIN_LOOP + 1:
                cand = N[i + 1][j - 1] + _pair(s[i], s[j])
                if cand > best:
                    best = cand
            for k in range(i + 1, j):
                cand = N[i][k] + N[k + 1][j]
                if cand > best:
                    best = cand
            N[i][j] = best

    pairs: List[Tuple[int, int]] = []
    stack: List[Tuple[int, int]] = [(0, n - 1)]
    while stack:
        i, j = stack.pop()
        if i >= j or N[i][j] == 0:
            continue
        if N[i + 1][j] == N[i][j]:
            stack.append((i + 1, j))
        elif N[i][j - 1] == N[i][j]:
            stack.append((i, j - 1))
        elif (j - i >= MIN_HAIRPIN_LOOP + 1
              and _pair(s[i], s[j]) == 1
              and N[i + 1][j - 1] + 1 == N[i][j]):
            pairs.append((i, j))
            stack.append((i + 1, j - 1))
        else:
            for k in range(i + 1, j):
                if N[i][k] + N[k + 1][j] == N[i][j]:
                    stack.append((i, k))
                    stack.append((k + 1, j))
                    break

    db = ["."] * n
    for i, j in pairs:
        db[i] = "("
        db[j] = ")"
    return "".join(db), len(pairs)


def is_balanced(dot_bracket: str) -> bool:
    """Verify dot-bracket parentheses are balanced and properly nested."""
    depth = 0
    for c in dot_bracket:
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth < 0:
                return False
        elif c != ".":
            return False
    return depth == 0


def pair_list(dot_bracket: str) -> List[Tuple[int, int]]:
    """Dot-bracket -> sorted list of (i, j) pair indices."""
    stk: List[int] = []
    out: List[Tuple[int, int]] = []
    for k, c in enumerate(dot_bracket):
        if c == "(":
            stk.append(k)
        elif c == ")":
            if not stk:
                raise ValueError("unbalanced dot-bracket")
            out.append((stk.pop(), k))
    if stk:
        raise ValueError("unbalanced dot-bracket")
    return sorted(out)


# ── (1b) Turner-style nearest-neighbour STACK-SUM folding free energy ─

def folding_free_energy(seq: str, dot_bracket: str) -> float:
    """Sum nearest-neighbour stack increments for the Nussinov fold.

    A 'stack' is a pair (i, j) whose inner neighbour (i+1, j-1) is also a
    pair. Each stacked step contributes a negative dG from `_NN_STACK_DG`.
    Returns total folding free energy in kcal/mol (more negative = more
    stable). An unpaired / unstacked fold returns 0.0 kcal/mol.
    """
    s = sanitize(seq)
    pairs = set(pair_list(dot_bracket))
    dg = 0.0
    for (i, j) in sorted(pairs):
        if (i + 1, j - 1) in pairs:
            outer = _PAIR_CLASS.get((s[i], s[j]))
            inner = _PAIR_CLASS.get((s[i + 1], s[j - 1]))
            if outer is None or inner is None:
                continue
            dg += _NN_STACK_DG.get((outer, inner), -0.5)
    return round(dg, 4)


# ── (2) equilibrium 1:1 binding model ─────────────────────────────────

def kd_from_rate_constants(kon_M_inv_s: float, koff_s: float) -> float:
    """Dissociation constant Kd = koff / kon  (units M).

    kon  : association rate constant (M^-1 s^-1)
    koff : dissociation rate constant (s^-1)
    """
    if kon_M_inv_s <= 0.0:
        raise ValueError("kon must be positive")
    return koff_s / kon_M_inv_s


def fraction_bound(ligand_M: float, kd_M: float) -> float:
    """1:1 Langmuir saturation isotherm:  theta = [L] / (Kd + [L]).

    theta = 0.5 exactly at [L] = Kd. Monotone increasing in [L],
    bounded in [0, 1].
    """
    if kd_M <= 0.0:
        raise ValueError("Kd must be positive")
    if ligand_M < 0.0:
        raise ValueError("ligand concentration must be non-negative")
    return ligand_M / (kd_M + ligand_M)


def binding_isotherm(kd_M: float, ligand_grid_M: List[float]) -> List[Tuple[float, float]]:
    """Compute (ligand_M, fraction_bound) over a concentration grid."""
    return [(c, fraction_bound(c, kd_M)) for c in ligand_grid_M]


# ── modeled aptamer corpus (literature-anchored magnitudes) ───────────
# Each entry: (name, sequence, ligand, literature Kd in nM, paper_ref).
# k_cat is implicitly 0 for ALL of these — aptamers are NON-catalytic
# binders, the defining distinction from the parent RIBOZYME axis.
_APTAMER_CORPUS = [
    (
        "thrombin_binding_aptamer_TBA",
        # 15-mer G-quadruplex DNA aptamer (T folded to U for the RNA-style
        # folder; the fold/Kd anchor is the DNA aptamer literature).
        "GGTTGGTGTGGTTGG",
        "human alpha-thrombin",
        100.0,  # nM — low/mid-nanomolar regime (Bock et al. 1992 + later assays)
        "Bock LC et al. 1992 Nature 355:564-566",
    ),
    (
        "theophylline_aptamer_core",
        "GGCGAUACCAGCCGAAAGGCCCUUGGCAGCGUC",
        "theophylline",
        100.0,  # nM — Jenison-Ellington high-affinity theophylline aptamer
        "Jenison RD et al. 1994 Science 263:1425-1429",
    ),
    (
        "atp_aptamer_core",
        "GGGAUACUUCACUGCAGACUUGACGAAGCUU",
        "ATP",
        6000.0,  # nM — Sassanfar-Szostak ATP/adenosine aptamer regime
        "Sassanfar M, Szostak JW 1993 Nature 364:550-553",
    ),
]


def model_aptamer(name: str, seq: str, ligand: str, kd_nM: float,
                  paper_ref: str) -> Dict:
    """Fold one aptamer and run its equilibrium-binding model.

    Returns one output row conforming to aptamer_affinity_v1.schema.json.
    """
    s = sanitize(seq)
    db, num_pairs = nussinov(s)
    dg_fold = folding_free_energy(s, db)

    kd_M = kd_nM * 1.0e-9
    # Decompose Kd into a (kon, koff) pair: fix kon at a representative
    # near-diffusion-limited value, derive koff = Kd * kon. This makes the
    # identity Kd = koff / kon exact by construction and checkable.
    kon = 1.0e6                       # M^-1 s^-1 (representative, sub-diffusion)
    koff = kd_M * kon                 # s^-1
    kd_recovered = kd_from_rate_constants(kon, koff)

    # Saturation isotherm over a decade-spaced ligand grid bracketing Kd.
    grid = [kd_M * f for f in (0.01, 0.1, 0.5, 1.0, 2.0, 10.0, 100.0)]
    iso = binding_isotherm(kd_M, grid)
    theta_at_kd = fraction_bound(kd_M, kd_M)

    return {
        "schema": SCHEMA_ID,
        "name": name,
        "sequence": s,
        "length_nt": len(s),
        "ligand": ligand,
        "fold": {
            "dot_bracket": db,
            "num_base_pairs": num_pairs,
            "balanced": is_balanced(db),
            "folding_free_energy_kcal_per_mol": dg_fold,
            "model": "nussinov_1978_bp_max + turner_style_nn_stack_sum",
        },
        "binding": {
            "kd_nM": kd_nM,
            "kd_M": kd_M,
            "kon_M_inv_s": kon,
            "koff_s": koff,
            "kd_recovered_M": kd_recovered,
            "kd_identity_holds": abs(kd_recovered - kd_M) < 1e-18 + 1e-9 * kd_M,
            "theta_at_ligand_eq_kd": theta_at_kd,
            "isotherm": [
                {"ligand_M": c, "fraction_bound": round(t, 12)}
                for (c, t) in iso
            ],
            "model": "1:1 Langmuir equilibrium  theta = [L]/(Kd+[L])",
        },
        "kcat_per_s": 0.0,  # aptamer = NON-catalytic binder (sub :> RIBOZYME)
        "paper_ref": paper_ref,
        "in_silico_caveat": (
            "in-silico simulator-consistency only (AGENTS.tape g8/f2) — "
            "NOT a wet-lab, binding-affinity, therapeutic or regulatory claim"
        ),
    }


# ── consistency checks (per-row PASS/FAIL) ────────────────────────────

def check_row(row: Dict) -> Tuple[bool, List[str]]:
    """Verify one output row's internal simulator-consistency.

    Returns (ok, [failure messages]).
    """
    fails: List[str] = []
    fold = row["fold"]
    binding = row["binding"]

    if len(fold["dot_bracket"]) != row["length_nt"]:
        fails.append("dot_bracket length != sequence length")
    if not fold["balanced"]:
        fails.append("dot_bracket not balanced")
    if fold["num_base_pairs"] < 0:
        fails.append("negative base-pair count")
    # Folding free energy must be <= 0 (stabilizing or neutral; a stacked
    # fold can only lower free energy in this NN-stack-sum surrogate).
    if fold["folding_free_energy_kcal_per_mol"] > 0.0:
        fails.append("folding free energy positive (NN stack sum must be <= 0)")

    # Kd = koff/kon identity.
    if not binding["kd_identity_holds"]:
        fails.append("Kd = koff/kon identity violated")
    # theta = 0.5 exactly at [L] = Kd.
    if abs(binding["theta_at_ligand_eq_kd"] - 0.5) > 1e-12:
        fails.append("theta != 0.5 at [L] = Kd")
    # Isotherm monotone increasing and bounded in [0, 1].
    iso = binding["isotherm"]
    prev = -1.0
    for point in iso:
        t = point["fraction_bound"]
        if t < 0.0 or t > 1.0:
            fails.append("fraction_bound out of [0,1]")
        if t < prev - 1e-15:
            fails.append("isotherm not monotone increasing")
        prev = t

    # Aptamer is a non-catalytic binder — k_cat must be exactly 0.
    if row["kcat_per_s"] != 0.0:
        fails.append("aptamer kcat != 0 (aptamers are non-catalytic binders)")

    return (len(fails) == 0, fails)


def determinism_check() -> bool:
    """Re-run the full model twice; require byte-identical JSON."""
    a = json.dumps([model_aptamer(*e) for e in _APTAMER_CORPUS],
                    sort_keys=True, ensure_ascii=False)
    b = json.dumps([model_aptamer(*e) for e in _APTAMER_CORPUS],
                    sort_keys=True, ensure_ascii=False)
    return a == b


def build_rows() -> List[Dict]:
    """Build the full APTAMER sub-axis output-row set."""
    return [model_aptamer(*e) for e in _APTAMER_CORPUS]


# ── CLI / self-check ──────────────────────────────────────────────────

def main() -> int:
    print("aptamer_affinity_sim.py — APTAMER sub-axis (:> RIBOZYME core)")
    print("  fold model : Nussinov 1978 bp-max + Turner-style NN stack-sum dG")
    print("  bind model : 1:1 Langmuir equilibrium  theta = [L]/(Kd+[L]);  Kd = koff/kon")
    print()
    print("  REAL LIMITS (g1 real-limits-first):")
    print("   - RNA/DNA folding thermodynamics — nearest-neighbour model")
    print("     (SantaLucia 1998 PNAS 95:1460-1465; Turner & Mathews 2010 NAR 38:D280)")
    print("   - published aptamer Kd anchor — thrombin DNA aptamer, low/mid-nM")
    print("     (Bock LC et al. 1992 Nature 355:564-566)")
    print("  MODALITY PRECEDENT (g3/f1 — own precedent, NOT lattice-derived):")
    print("   - pegaptanib/Macugen (anti-VEGF165 RNA aptamer, FDA 2004)")
    print("   - avacincaptad pegol/Izervay (anti-C5 RNA aptamer, FDA 2023)")
    print()
    print("  SCOPE (g8/f2): every PASS = in-silico simulator-consistency ONLY —")
    print("  NOT a wet-lab, binding-affinity, therapeutic, clinical or regulatory")
    print("  claim. APTAMER is a SUB-AXIS specializing RIBOZYME's RNA-folding")
    print("  machinery toward affinity; core-5 axis set is UNCHANGED. No count,")
    print("  energy, or Kd is derived from the n=6 lattice (g2/f_lattice_fit).")
    print()

    rows = build_rows()
    fails = 0
    for row in rows:
        ok, msgs = check_row(row)
        if not ok:
            fails += 1
        fold = row["fold"]
        binding = row["binding"]
        verdict = "PASS" if ok else "FAIL"
        print(f"  [{verdict}] {row['name']:<30} n={row['length_nt']:>3}  "
              f"pairs={fold['num_base_pairs']:>2}  "
              f"dG_fold={fold['folding_free_energy_kcal_per_mol']:>8.3f} kcal/mol  "
              f"Kd={binding['kd_nM']:>8.1f} nM")
        print(f"         ligand={row['ligand']}  "
              f"theta(@[L]=Kd)={binding['theta_at_ligand_eq_kd']:.6f}  "
              f"Kd=koff/kon: {binding['kd_identity_holds']}")
        print(f"         db={fold['dot_bracket']}")
        for m in msgs:
            print(f"         x {m}")

    print()
    det_ok = determinism_check()
    if det_ok:
        print(f"  [PASS] determinism — byte-identical re-run over {len(rows)} aptamers")
    else:
        fails += 1
        print("  [FAIL] determinism — output drift between runs")

    total = len(rows) + 1
    npass = total - fails
    print()
    print(f"  --- summary --- {npass} / {total} PASS")
    print()

    if "--json" in sys.argv:
        print("## output rows (aptamer_affinity_v1)")
        print(json.dumps(rows, indent=2, ensure_ascii=False))
        print()

    if fails == 0:
        print(SENTINEL_OK)
        return 0
    print(SENTINEL_FAIL)
    return 1


if __name__ == "__main__":
    sys.exit(main())
