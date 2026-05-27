#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/cmt_smiles_validation.py — Tier-2 placeholder-SMILES validation gate.

Implements the Tier-2 ("placeholder structure proposed") rung of the CMT
closure ladder in `.roadmap.disease_cmt_specific` §6, and the SMILES-self-
consistency leg of F-disease-cmt-Q-1..6 readiness (the live pocket-VQE step
is qmirror-side / PySCF-backend-blocked — see cmt_vqe_ladder_readiness.sh).

What this DOES (in-repo, deterministic, stdlib-only — per cross-cutting
Require R5 raw 9 hexa-only):

  For each of the 4 small-molecule (axis Q) CMT candidates that carry a
  placeholder SMILES in the roadmap (hd6-001, clc1-001, sar1-001, mfn2-001):

    (1) parse the SMILES with a self-contained organic-subset parser
        (atoms, branches, ring-closure bonds, explicit-H, charges);
    (2) verify the string is *syntactically well-formed*: balanced parens,
        every ring-closure digit opened-and-closed exactly once, only
        recognised element symbols, no dangling bond operators;
    (3) compute heavy-atom count, molecular formula, and monoisotopic mass;
    (4) cross-check those against the roadmap's own inline annotation
        `(<formula>, heavy <N>, monoisotopic <M>; ...)` next to the SMILES —
        the roadmap must be self-consistent with the structure it states;
    (5) sanity-bound the structure (10 ≤ heavy ≤ 60, MW ≤ 700 — Lipinski-ish
        small-molecule envelope; a placeholder outside that is a defect).

What this does NOT do: 3D conformer generation, docking, QM — those are the
qmirror chemistry-VQE / external-backend steps (out of a pure in-repo gate's
scope; see CHEMISTRY_VQE_PYSCF_BACKEND_PLAN at ~/core/qmirror/).

Sentinel: __CMT_SMILES_VALIDATION__ PASS|FAIL  (exit 0 / 1).
A malformed placeholder, or a roadmap annotation that disagrees with its own
SMILES, is a real defect → FAIL. There is no SKIP state (the roadmap file is
always present in-repo).
"""

from __future__ import annotations

import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROADMAP = os.path.join(REPO_ROOT, ".roadmap.disease_cmt_specific")

# Monoisotopic masses (most-abundant isotope), u.
MONO = {
    "H": 1.0078250319, "C": 12.0, "N": 14.0030740052, "O": 15.9949146221,
    "S": 31.97207069, "F": 18.9984031627, "Cl": 34.96885271,
    "Br": 78.9183376, "I": 126.904473, "P": 30.97376151, "B": 11.0093055,
}
NORMAL_VALENCE = {
    "B": 3, "C": 4, "N": 3, "O": 2, "P": 3, "S": 2,
    "F": 1, "Cl": 1, "Br": 1, "I": 1,
}
ORGANIC_SUBSET = {"B", "C", "N", "O", "P", "S", "F", "Cl", "Br", "I"}
AROMATIC_LOWER = {"b", "c", "n", "o", "p", "s"}
BOND_ORDER = {"-": 1.0, "=": 2.0, "#": 3.0, ":": 1.5, "$": 4.0, "/": 1.0, "\\": 1.0, "~": 1.0}
FORMULA_ORDER = ["C", "H", "N", "O", "S", "P", "F", "Cl", "Br", "I", "B"]


class SmilesError(ValueError):
    pass


def parse_smiles(smiles: str):
    """Return (heavy_count, formula_dict, monoisotopic_mass, n_bonds).

    Raises SmilesError on any structural malformation.
    """
    atoms = []          # list of {"sym","arom","charge","explH"}
    bonds = []          # list of (a_idx, b_idx, order)
    branch_stack = []   # list of prev-atom-idx snapshots
    ring = {}           # digit/%-key -> (atom_idx, pending_bond_order or None)
    prev = None
    pending_bond = None
    i, n = 0, len(smiles)

    def new_atom(sym, arom, charge=0, explH=0):
        atoms.append({"sym": sym, "arom": arom, "charge": charge, "explH": explH})
        return len(atoms) - 1

    def link(a, b):
        if pending_bond is not None:
            o = pending_bond
        elif atoms[a]["arom"] and atoms[b]["arom"]:
            o = 1.5
        else:
            o = 1.0
        bonds.append((a, b, o))

    while i < n:
        c = smiles[i]
        if c == "(":
            if prev is None:
                raise SmilesError("'(' with no preceding atom")
            branch_stack.append(prev)
            i += 1
            continue
        if c == ")":
            if not branch_stack:
                raise SmilesError("unbalanced ')'")
            prev = branch_stack.pop()
            i += 1
            continue
        if c in BOND_ORDER:
            if pending_bond is not None:
                raise SmilesError("two bond operators in a row")
            pending_bond = BOND_ORDER[c]
            i += 1
            continue
        if c == ".":  # disconnected component — fine, just reset chain
            prev = None
            pending_bond = None
            i += 1
            continue
        if c == "[":
            j = smiles.find("]", i)
            if j < 0:
                raise SmilesError("unclosed '['")
            inner = smiles[i + 1:j]
            m = re.match(
                r"^(?P<iso>\d*)(?P<sym>[A-Z][a-z]?|se|as|[bcnops])"
                r"(?P<chir>@{0,2}|@TH[12]|@AL[12]|@SP[123]|@TB\d+|@OH\d+)?"
                r"(?P<h>H\d*)?(?P<chg>(?:[+-]\d+)|\++|-+)?(?P<cls>:\d+)?$",
                inner,
            )
            if not m:
                raise SmilesError(f"unparseable bracket atom '[{inner}]'")
            sym = m.group("sym")
            sym_norm = sym[:1].upper() + sym[1:].lower()
            arom = sym[0].islower()
            hh = m.group("h")
            explH = 0 if not hh else (1 if hh == "H" else int(hh[1:]))
            chg_s = m.group("chg")
            charge = 0
            if chg_s:
                if set(chg_s) == {"+"}:
                    charge = len(chg_s)
                elif set(chg_s) == {"-"}:
                    charge = -len(chg_s)
                else:
                    charge = int(chg_s)
            idx = new_atom(sym_norm, arom, charge, explH)
            if prev is not None:
                link(prev, idx)
            elif pending_bond is not None:
                raise SmilesError("bond operator at start of chain")
            prev = idx
            pending_bond = None
            i = j + 1
            continue
        if c == "%":
            key = smiles[i + 1:i + 3]
            if len(key) != 2 or not key.isdigit():
                raise SmilesError("malformed %NN ring closure")
            i += 3
            _ring_closure(key, prev, pending_bond, ring, bonds, atoms)
            pending_bond = None
            continue
        if c.isdigit():
            i += 1
            _ring_closure(c, prev, pending_bond, ring, bonds, atoms)
            pending_bond = None
            continue
        # organic-subset bare atom
        two = smiles[i:i + 2]
        if two in ("Cl", "Br"):
            sym = two
            i += 2
        elif c in ORGANIC_SUBSET or c in AROMATIC_LOWER:
            sym = c
            i += 1
        elif c in "/\\@%H+-":
            raise SmilesError(f"stray '{c}' outside a bracket atom")
        else:
            raise SmilesError(f"unexpected character {c!r} at position {i}")
        arom = sym.islower()
        sym_norm = sym.capitalize()
        idx = new_atom(sym_norm, arom)
        if prev is not None:
            link(prev, idx)
        elif pending_bond is not None:
            raise SmilesError("bond operator at start of chain")
        prev = idx
        pending_bond = None

    if branch_stack:
        raise SmilesError("unbalanced '(' — branch never closed")
    if ring:
        raise SmilesError(f"ring-closure label(s) opened but never closed: {sorted(ring)}")
    if pending_bond is not None:
        raise SmilesError("trailing bond operator")
    if not atoms:
        raise SmilesError("empty molecule")

    bsum = [0.0] * len(atoms)
    for a, b, o in bonds:
        bsum[a] += o
        bsum[b] += o

    formula = {}
    for k, at in enumerate(atoms):
        sym = at["sym"]
        formula[sym] = formula.get(sym, 0) + 1
        if at["explH"]:
            hh = at["explH"]
        else:
            base = NORMAL_VALENCE.get(sym, 0)
            # crude implicit-H: normal valence minus bond-order sum, plus charge
            # bonus for the common heteroatom cations (NH4+, etc.); aromatic atoms
            # fall out correctly because aromatic bonds carry order 1.5.
            need = base - bsum[k]
            if sym in ("N", "O", "S", "P") and at["charge"] > 0:
                need += at["charge"]
            hh = max(0, int(round(need)))
        formula["H"] = formula.get("H", 0) + hh

    heavy = sum(v for s, v in formula.items() if s != "H")
    unknown = [s for s in formula if s not in MONO]
    if unknown:
        raise SmilesError(f"no monoisotopic mass for element(s): {unknown}")
    mono = sum(MONO[s] * v for s, v in formula.items())
    return heavy, formula, mono, len(bonds)


def _ring_closure(key, prev, pending_bond, ring, bonds, atoms):
    if prev is None:
        raise SmilesError(f"ring-closure label {key} with no preceding atom")
    if key in ring:
        a0, bo = ring.pop(key)
        if a0 == prev:
            raise SmilesError(f"ring-closure label {key} bonds an atom to itself")
        if pending_bond is not None:
            o = pending_bond
        elif bo is not None:
            o = bo
        elif atoms[a0]["arom"] and atoms[prev]["arom"]:
            o = 1.5
        else:
            o = 1.0
        bonds.append((a0, prev, o))
    else:
        ring[key] = (prev, pending_bond)


def formula_str(formula: dict) -> str:
    parts = []
    for s in FORMULA_ORDER:
        if formula.get(s):
            parts.append(s + (str(formula[s]) if formula[s] > 1 else ""))
    # any element not in the canonical order (shouldn't happen for organics)
    for s in sorted(formula):
        if s not in FORMULA_ORDER and formula[s]:
            parts.append(s + (str(formula[s]) if formula[s] > 1 else ""))
    return "".join(parts)


# Which candidates carry a placeholder SMILES that this gate validates.
# The roadmap is the source of truth for the SMILES *string*; this list just
# says which rows to look for and gives the structural envelope.
CANDIDATE_IDS = [
    "hxq-cmt-hd6-001",
    "hxq-cmt-clc1-001",
    "hxq-cmt-sar1-001",
    "hxq-cmt-mfn2-001",
]
HEAVY_MIN, HEAVY_MAX = 10, 60
MW_MAX = 700.0
# tolerance for "monoisotopic <M>" annotation vs. computed (rounding to 2dp).
MW_TOL = 0.06


def extract_roadmap_rows(text: str):
    """Return {candidate_id: {'smiles':..., 'formula':..., 'heavy':int, 'mono':float, 'raw':...}}.

    Parses the inline annotation we keep next to each placeholder SMILES, of the
    form:  `<SMILES>` (<FORMULA>, heavy <N>, monoisotopic <M>; <note>)
    Tolerates the legacy short form `<SMILES>` (heavy <N>; <note>) by leaving the
    formula/mono fields as None (the gate then only cross-checks the heavy count).
    """
    rows = {}
    for cid in CANDIDATE_IDS:
        # find the row mentioning this candidate id, grab the backticked SMILES
        # and the parenthetical that immediately follows it.
        # SMILES backtick can't itself contain a backtick.
        pat = re.compile(
            re.escape(cid) + r"`.*?`(?P<smiles>[^`]+)`\s*\((?P<ann>[^)]*)\)",
            re.DOTALL,
        )
        m = pat.search(text)
        if not m:
            rows[cid] = None
            continue
        smiles = m.group("smiles").strip()
        ann = m.group("ann")
        heavy_m = re.search(r"heavy\s+(\d+)", ann)
        formula_m = re.search(r"\b([CHNOSPF][A-Za-z0-9]*\d[A-Za-z0-9]*)\b", ann)
        mono_m = re.search(r"monoisotopic\s+([\d.]+)", ann)
        rows[cid] = {
            "smiles": smiles,
            "heavy": int(heavy_m.group(1)) if heavy_m else None,
            "formula": formula_m.group(1) if formula_m else None,
            "mono": float(mono_m.group(1)) if mono_m else None,
            "raw_ann": ann.strip(),
        }
    return rows


def main() -> int:
    if not os.path.exists(ROADMAP):
        print(f"FAIL: roadmap not found: {ROADMAP}")
        print("__CMT_SMILES_VALIDATION__ FAIL")
        return 1
    with open(ROADMAP, "r", encoding="utf-8") as fh:
        text = fh.read()

    rows = extract_roadmap_rows(text)
    print("CMT Tier-2 placeholder-SMILES validation")
    print("=" * 64)
    n_pass = 0
    n_fail = 0
    for cid in CANDIDATE_IDS:
        row = rows.get(cid)
        if row is None:
            print(f"  ✗ {cid}: no backticked SMILES + annotation found in roadmap")
            n_fail += 1
            continue
        smiles = row["smiles"]
        try:
            heavy, formula, mono, nb = parse_smiles(smiles)
        except SmilesError as e:
            print(f"  ✗ {cid}: SMILES `{smiles}` malformed — {e}")
            n_fail += 1
            continue
        fstr = formula_str(formula)
        mono_r = round(mono, 2)
        problems = []
        if not (HEAVY_MIN <= heavy <= HEAVY_MAX):
            problems.append(f"heavy {heavy} outside small-molecule envelope [{HEAVY_MIN},{HEAVY_MAX}]")
        if mono_r > MW_MAX:
            problems.append(f"monoisotopic {mono_r} > {MW_MAX} (too large for the stated oral-small-molecule modality)")
        if row["heavy"] is not None and row["heavy"] != heavy:
            problems.append(f"roadmap annotation says 'heavy {row['heavy']}' but the SMILES has {heavy} heavy atoms")
        if row["formula"] is not None and row["formula"].replace(" ", "") != fstr:
            problems.append(f"roadmap annotation formula '{row['formula']}' ≠ computed {fstr}")
        if row["mono"] is not None and abs(row["mono"] - mono_r) > MW_TOL:
            problems.append(f"roadmap annotation 'monoisotopic {row['mono']}' ≠ computed {mono_r} (Δ={abs(row['mono']-mono_r):.3f} > {MW_TOL})")
        if problems:
            print(f"  ✗ {cid}: `{smiles}`")
            for p in problems:
                print(f"      - {p}")
            n_fail += 1
        else:
            extra = []
            if row["formula"] is None:
                extra.append("formula not yet annotated in roadmap")
            if row["mono"] is None:
                extra.append("monoisotopic mass not yet annotated in roadmap")
            tag = ("  [" + "; ".join(extra) + "]") if extra else ""
            print(f"  ✓ {cid}: `{smiles}`")
            print(f"      → {fstr}  heavy={heavy}  bonds={nb}  monoisotopic={mono_r}{tag}")
            n_pass += 1

    print("-" * 64)
    print(f"  {n_pass}/{len(CANDIDATE_IDS)} placeholder SMILES validated "
          f"(syntactically well-formed + roadmap-self-consistent + in small-molecule envelope)")
    print(f"  Tier-2 (placeholder structure) closure leg for axis-Q CMT candidates "
          f"hd6/clc1/sar1/mfn2. Downstream: F-Q-1..6 pocket VQE binding is LIVE at "
          f"the 2e/2o tier (qmirror chemistry_vqe_cmt_hamiltonians.hexa, vendored "
          f"Hamiltonians vs CASCI(2,2)) — gated by cmt_vqe_ladder_readiness.sh; "
          f"4e/4o+ / final-molecule / pocket-embedded VQE = next ramp "
          f"(see ~/core/qmirror/CHEMISTRY_VQE_PYSCF_BACKEND_PLAN_2026_05_12.md §4-5)")

    if n_fail == 0:
        print("__CMT_SMILES_VALIDATION__ PASS")
        return 0
    print("__CMT_SMILES_VALIDATION__ FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
