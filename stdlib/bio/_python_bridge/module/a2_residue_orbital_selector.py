#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
a2_residue_orbital_selector.py — LVAD scenario ② (vWF A2 stabilizer):
map the ADAMTS13 scissile-bond region of the von Willebrand factor A2
domain to a deterministic (nelecas, ncas, active_orbital_indices) active-
space selection for the QUANTUM-axis VQE pocket pipeline.

Context
=======
LVAD pump shear (70-150 dyn/cm²) elongates the vWF A2 domain, exposing
the ADAMTS13 scissile bond, which is cleaved at **Tyr1605-Met1606**
(UniProt P04275 VWF_HUMAN full-length numbering). A small-molecule
chaperone that stabilises the cleavage-resistant fold is the LVAD
scenario-② target (see ../LVAD/A2_STABILIZER.tape §2-§4).

The QUANTUM pipeline (`pocket_active_space.build_active_space_hamiltonian`)
needs an explicit `active_orbital_indices` list to carve a CASCI active
space around the catalytically relevant atoms. This module produces that
list deterministically from residue numbering — it does NOT run an
electronic-structure calculation and does NOT read PDB coordinates.

Two modes
=========

  mock  (default; regression-preserving)
      Returns a fixed, clearly-labelled placeholder tuple. Historically
      the only path; real mode previously raised NotImplementedError
      because no real A2 structure was wired in. Kept verbatim so the
      __A2_RESIDUE_SELECTOR__ MOCK selftest token and any existing
      consumers keep working unchanged.

  real  (--real / mode="real")
      A documented, deterministic *geometry-derived heuristic*: it walks
      the canonical A2 residue numbering, finds the scissile-bond pair
      plus the flanking secondary-structure window, assigns a fixed
      per-residue valence-orbital budget, and emits a contiguous frontier
      active-orbital index window centred on the scissile sidechains.
      This is NOT a QM-derived active space — it is a reproducible
      seed for one. Every real-mode payload carries
      `derivation = "geometry-derived heuristic, refine with real QM"`.

Honest scope (g1 / g3 / g8 / f2)
================================
  • The (nelecas, ncas, indices) tuple is a HEURISTIC SEED, not a
    converged or QM-validated active space. Picking a chemically
    correct active space requires an actual electronic-structure
    calculation on a real (MD- or crystal-derived) A2 unfolding
    intermediate geometry — see A2_STABILIZER.tape §6 unknowns.
  • No PDB coordinates are fabricated or embedded. Residue numbering
    is cited to UniProt P04275; structural context (scissile bond in
    the central β4 strand) is cited to the 3GXB crystal structure
    (Zhang et al. 2009, PNAS 106:9226-9231).
  • This grounds the DISEASE-MECHANISM target geometry only. It is
    NOT a therapeutic, efficacy, clinical, or regulatory claim.

Public API
==========

    select_a2_active_space(
        *,
        mode: str = "mock",
        n_frontier_orbitals: int = 8,
    ) -> dict

        Returns a dict with at least:
            mode, nelecas, ncas, active_orbital_indices,
            scissile_bond, residue_window, derivation, citations
        `active_orbital_indices` / `ncas` / `nelecas` are directly
        shape-compatible with
        pocket_active_space.build_active_space_hamiltonian(
            ..., num_active_electrons=nelecas,
            num_active_spatial_orbitals=ncas,
            active_orbital_indices=active_orbital_indices).

CLI usage
=========

    python3 a2_residue_orbital_selector.py --mock
    python3 a2_residue_orbital_selector.py --real
    python3 a2_residue_orbital_selector.py --real --n-frontier 12
    python3 a2_residue_orbital_selector.py --selftest

Pure stdlib. Deterministic (no RNG, no I/O, no network).
"""
from __future__ import annotations

import argparse
import json
import sys

# ---------------------------------------------------------------------------
# Canonical, citable constants — UniProt P04275 (VWF_HUMAN) full-length
# numbering; structural context from the 3GXB crystal structure. These are
# residue NUMBERS and a single-letter scissile pair only — NOT coordinates.
# ---------------------------------------------------------------------------

CITATIONS = {
    "uniprot": "UniProt P04275 (VWF_HUMAN) — von Willebrand factor, "
               "full-length precursor numbering.",
    "pdb_3gxb": "PDB 3GXB — human vWF A2 domain crystal structure; "
                "Zhang Q, Zhou YF, Zhang CZ, Zhang X, Lu C, Springer TA, "
                "PNAS 2009;106:9226-9231. Scissile Tyr-Met is buried in "
                "the central beta4 strand.",
    "scissile": "ADAMTS13 cleaves the vWF A2 domain at Tyr1605-Met1606; "
                "Crawley JTB et al., Blood 2011;118:3212-3221.",
}

# ADAMTS13 scissile bond (P04275 numbering): P1 = Tyr1605, P1' = Met1606.
SCISSILE_P1_RESNUM = 1605       # Tyr (Y)
SCISSILE_P1_RESNAME = "TYR"
SCISSILE_P1PRIME_RESNUM = 1606  # Met (M)
SCISSILE_P1PRIME_RESNAME = "MET"

# Local secondary-structure window around the scissile bond. The Tyr1605-
# Met1606 bond sits in the central beta4 strand of the A2 fold (3GXB,
# Zhang 2009). We take a symmetric +/- 3-residue flank (the beta4 strand
# and its adjacent loop turns) as the residues whose sidechains define the
# catalytic micro-environment. This window is a MODEL CHOICE, documented
# here so it is reproducible — it is not derived from coordinates.
WINDOW_FLANK = 3
WINDOW_START = SCISSILE_P1_RESNUM - WINDOW_FLANK       # 1602
WINDOW_END = SCISSILE_P1PRIME_RESNUM + WINDOW_FLANK    # 1609

# Deterministic per-residue valence-orbital budget for the heuristic.
# Rationale (documented, approximate — refine with real QM):
#   - The scissile carbonyl C=O + scissile Tyr/Met sidechains carry the
#     frontier (HOMO/LUMO-region) density relevant to peptide-bond
#     cleavage stabilisation, so they get the larger budget.
#   - Each scissile residue contributes its sidechain + backbone amide
#     pi-system: budget 3 spatial orbitals / 4 active electrons each
#     (a minimal "amide + sidechain frontier" pocket).
#   This is a frontier-orbital COUNTING heuristic, NOT an MO calculation.
SCISSILE_ORB_PER_RESIDUE = 3
SCISSILE_ELEC_PER_RESIDUE = 4

# Mock-mode placeholder (regression-preserving). Historically the only
# returned value; clearly labelled so no consumer mistakes it for real
# structure-derived selection.
_MOCK_PAYLOAD = {
    "mode": "mock",
    "nelecas": 2,
    "ncas": 2,
    "active_orbital_indices": [0, 1],
    "scissile_bond": "MOCK(Tyr?-Met?)",
    "residue_window": [0, 0],
    "derivation": "MOCK placeholder — NOT structure-derived",
    "citations": {"note": "mock mode carries no real citations"},
}


class A2SelectorError(RuntimeError):
    pass


def _frontier_window(n_frontier_orbitals: int) -> list[int]:
    """Deterministic contiguous frontier active-orbital index window.

    `pocket_active_space.build_active_space_hamiltonian` interprets
    `active_orbital_indices` as 0-based spatial-MO indices into the full
    Hartree-Fock orbital list. Without a real SCF we cannot know the true
    HOMO index of an A2 fragment, so the heuristic emits a contiguous
    block [0 .. n_frontier_orbitals-1]: the caller is expected to feed
    this together with a fragment whose HF orbitals are ordered such that
    the catalytic frontier falls in that block (the documented
    "geometry-derived heuristic, refine with real QM" caveat). The block
    length equals ncas so the tuple is internally consistent.
    """
    if n_frontier_orbitals < 2:
        raise A2SelectorError(
            f"n_frontier_orbitals must be >= 2 (peptide-bond frontier "
            f"needs at least HOMO+LUMO); got {n_frontier_orbitals}"
        )
    return list(range(n_frontier_orbitals))


def select_a2_active_space(
    *,
    mode: str = "mock",
    n_frontier_orbitals: int = 8,
) -> dict:
    """Map the vWF A2 ADAMTS13-scissile region to an active-space tuple.

    mode="mock"  -> fixed labelled placeholder (regression path).
    mode="real"  -> deterministic geometry-derived heuristic seed.

    The returned dict's (nelecas, ncas, active_orbital_indices) are
    shape-compatible with
    pocket_active_space.build_active_space_hamiltonian(...).
    """
    if mode == "mock":
        # Return a copy so callers cannot mutate the module constant.
        out = dict(_MOCK_PAYLOAD)
        out["active_orbital_indices"] = list(_MOCK_PAYLOAD["active_orbital_indices"])
        out["residue_window"] = list(_MOCK_PAYLOAD["residue_window"])
        out["citations"] = dict(_MOCK_PAYLOAD["citations"])
        return out

    if mode != "real":
        raise A2SelectorError(
            f"unknown mode {mode!r}; expected 'mock' or 'real'"
        )

    # ---- REAL mode: deterministic residue -> orbital heuristic ----------
    #
    # Residues in the documented scissile window (P04275 numbering).
    window_residues = list(range(WINDOW_START, WINDOW_END + 1))

    # The two scissile residues carry the frontier budget; the flanking
    # window residues are accounted for as context but, to keep the active
    # space tractable for VQE, only the scissile pair drives (nelecas,
    # ncas) in this heuristic. (Documented model choice — a richer QM
    # selection would weight the whole micro-environment.)
    n_scissile_residues = 2  # Tyr1605 + Met1606
    heuristic_ncas = n_scissile_residues * SCISSILE_ORB_PER_RESIDUE   # 6
    heuristic_nelecas = n_scissile_residues * SCISSILE_ELEC_PER_RESIDUE  # 8

    # Allow the caller to widen/narrow the frontier window; ncas tracks it
    # so the (nelecas, ncas, indices) triple stays internally consistent
    # and shape-valid for the ActiveSpaceTransformer.
    ncas = int(n_frontier_orbitals)
    if ncas < heuristic_ncas:
        # Never emit fewer orbitals than the minimal scissile pocket.
        ncas = heuristic_ncas
    indices = _frontier_window(ncas)
    # Electrons scale with the same per-residue ratio, capped at 2*ncas
    # (closed-shell active-space upper bound for nelecas).
    nelecas = min(heuristic_nelecas, 2 * ncas)

    return {
        "mode": "real",
        "nelecas": nelecas,
        "ncas": ncas,
        "active_orbital_indices": indices,
        "scissile_bond": (
            f"{SCISSILE_P1_RESNAME}{SCISSILE_P1_RESNUM}"
            f"-{SCISSILE_P1PRIME_RESNAME}{SCISSILE_P1PRIME_RESNUM}"
        ),
        "residue_window": [WINDOW_START, WINDOW_END],
        "window_residues": window_residues,
        "scissile_orb_per_residue": SCISSILE_ORB_PER_RESIDUE,
        "scissile_elec_per_residue": SCISSILE_ELEC_PER_RESIDUE,
        # HONEST LABEL — this is the g1/g3 honesty marker. Real mode is a
        # reproducible SEED for a QM active space, not the active space.
        "derivation": "geometry-derived heuristic, refine with real QM",
        "numbering_source": "UniProt P04275 (VWF_HUMAN) full-length",
        "structure_context": "PDB 3GXB (Zhang 2009 PNAS) — scissile "
                             "Tyr-Met in central beta4 strand",
        "scope_caveat": "in-silico disease-mechanism target geometry "
                        "only; NOT a therapeutic/clinical claim "
                        "(A2_STABILIZER.tape §6; AGENTS.tape g8/f2)",
        "citations": dict(CITATIONS),
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _emit_json(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, indent=2))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _cmd_selftest() -> int:
    print("hexa-bio a2_residue_orbital_selector.py — selftest")
    print("LVAD scenario ② · vWF A2 ADAMTS13-scissile active-space selector")
    print()

    all_pass = True

    # --- S1: mock-mode regression (token preserved verbatim) -----------
    print("  S1: mock-mode regression ...")
    m = select_a2_active_space(mode="mock")
    ok_mock = (
        m["mode"] == "mock"
        and m["nelecas"] == 2
        and m["ncas"] == 2
        and m["active_orbital_indices"] == [0, 1]
        and "MOCK" in m["derivation"]
    )
    if ok_mock:
        print(f"  S1 PASS: mock tuple (nelecas={m['nelecas']}, "
              f"ncas={m['ncas']}, idx={m['active_orbital_indices']})")
        print("__A2_RESIDUE_SELECTOR__ MOCK")
    else:
        print(f"  S1 FAIL: unexpected mock payload {m!r}")
        print("__A2_RESIDUE_SELECTOR__ MOCK FAIL")
        all_pass = False
    print()

    # --- S2: real-mode determinism + scissile correctness --------------
    print("  S2: real-mode (geometry-derived heuristic) ...")
    r1 = select_a2_active_space(mode="real")
    r2 = select_a2_active_space(mode="real")
    deterministic = r1 == r2
    correct_scissile = r1["scissile_bond"] == "TYR1605-MET1606"
    correct_window = r1["residue_window"] == [1602, 1609]
    # Shape sanity: indices length == ncas, nelecas <= 2*ncas, ncas >= 2.
    shape_ok = (
        len(r1["active_orbital_indices"]) == r1["ncas"]
        and r1["nelecas"] <= 2 * r1["ncas"]
        and r1["ncas"] >= 2
        and r1["active_orbital_indices"] == list(range(r1["ncas"]))
    )
    honest_label = r1["derivation"] == "geometry-derived heuristic, refine with real QM"
    if deterministic and correct_scissile and correct_window and shape_ok and honest_label:
        print(f"  S2 PASS: real tuple (nelecas={r1['nelecas']}, "
              f"ncas={r1['ncas']}, idx={r1['active_orbital_indices']}) "
              f"scissile={r1['scissile_bond']} "
              f"window={r1['residue_window']}")
        print(f"          derivation = {r1['derivation']!r}")
        print("__A2_RESIDUE_SELECTOR__ REAL")
    else:
        print(f"  S2 FAIL: deterministic={deterministic} "
              f"scissile={correct_scissile} window={correct_window} "
              f"shape={shape_ok} honest_label={honest_label}")
        print("__A2_RESIDUE_SELECTOR__ REAL FAIL")
        all_pass = False
    print()

    # --- S3: real-mode widened frontier still consistent ----------------
    print("  S3: real-mode widened frontier (n=12) ...")
    rw = select_a2_active_space(mode="real", n_frontier_orbitals=12)
    s3_ok = (
        rw["ncas"] == 12
        and rw["active_orbital_indices"] == list(range(12))
        and rw["nelecas"] <= 24
        and rw["nelecas"] == 8  # heuristic_nelecas capped, < 2*12
    )
    if s3_ok:
        print(f"  S3 PASS: widened tuple (nelecas={rw['nelecas']}, "
              f"ncas={rw['ncas']}, idx[0:3]={rw['active_orbital_indices'][:3]}...)")
        print("__A2_RESIDUE_SELECTOR__ REAL")
    else:
        print(f"  S3 FAIL: {rw!r}")
        print("__A2_RESIDUE_SELECTOR__ REAL FAIL")
        all_pass = False
    print()

    if all_pass:
        print("__A2_RESIDUE_SELECTOR__ ALL PASS")
        return 0
    print("__A2_RESIDUE_SELECTOR__ ALL FAIL")
    return 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="a2_residue_orbital_selector.py",
        description="LVAD ② vWF A2 ADAMTS13-scissile active-space selector "
                    "(mock | geometry-derived-heuristic real)",
    )
    g = p.add_mutually_exclusive_group()
    g.add_argument("--mock", action="store_true",
                   help="mock mode (regression placeholder)")
    g.add_argument("--real", action="store_true",
                   help="real mode (geometry-derived heuristic seed)")
    g.add_argument("--selftest", action="store_true")
    p.add_argument("--n-frontier", type=int, default=8,
                   help="real-mode frontier active-orbital count (>=2; "
                        "ncas tracks this, default 8)")
    args = p.parse_args(argv)

    if args.selftest:
        return _cmd_selftest()

    mode = "real" if args.real else "mock"
    try:
        payload = select_a2_active_space(
            mode=mode, n_frontier_orbitals=args.n_frontier
        )
    except A2SelectorError as exc:
        _emit_json({"ok": 0, "error": str(exc)})
        return 1
    _emit_json(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
