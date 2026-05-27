#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ribozyme_mfe_nussinov.py — pure-stdlib Nussinov base-pair-maximization
secondary-structure solver. Closes the R-R1 stub allowance from
`ribozyme/spec/ribozyme_output_v1.schema.json` (`structure_2d.dot_bracket`).

Algorithm (Nussinov 1978): classical O(n^3) dynamic programming. For an
input RNA string s of length n:

    N[i,j] = max base-pair count achievable in the subsequence s[i..j]
    N[i,j] = max(
        N[i+1, j],                  # i unpaired
        N[i, j-1],                  # j unpaired
        N[i+1, j-1] + pair(s[i], s[j]),    # (i,j) paired
        max_k N[i, k] + N[k+1, j]   # bifurcation
    )
    pair(a,b) = 1 if (a,b) ∈ {AU, UA, GC, CG, GU, UG}, else 0
    min hairpin loop = 3 nt (j-i >= 4 required for pairing)

Outputs `(dot_bracket, num_pairs)` where dot_bracket is Vienna notation.

Determinism: stdlib only, no random/network/time/env. Re-running on the
same input produces byte-identical output. → §11 deductive verification
contract (`AXIS_CLOSURE_PLAN.md` §0/§11; no human judgment, no live sim).

Honest scope (C3): this is a *combinatorial pair-maximization*
solver, not a thermodynamic ΔG calculator. It produces a structurally
valid dot-bracket but does NOT report kcal/mol energies. For ΔG, the
Turner-NN partition surrogate (cycle-24 MVP) or full Zuker port is
required. Sufficient to remove the `dot_bracket = 'stub'` allowance —
not sufficient to retire `turner_nn_subset` as the canonical ΔG path.

License: Apache-2.0 (hexa-bio core).
"""

from __future__ import annotations
from typing import Tuple, List

MIN_HAIRPIN_LOOP = 3  # j - i must be >= 4 for (i,j) to pair


_VALID = frozenset({"A", "C", "G", "U"})
_PAIRS = frozenset({("A", "U"), ("U", "A"), ("G", "C"), ("C", "G"), ("G", "U"), ("U", "G")})


def _pair(a: str, b: str) -> int:
    return 1 if (a, b) in _PAIRS else 0


def _sanitize(seq: str) -> str:
    s = seq.upper().replace("T", "U")
    bad = sorted({c for c in s if c not in _VALID})
    if bad:
        raise ValueError(f"non-RNA characters in sequence: {bad}")
    return s


def nussinov(seq: str) -> Tuple[str, int]:
    """Run Nussinov base-pair-maximization on `seq`.

    Returns (dot_bracket, num_pairs). dot_bracket length == len(seq).
    Empty / length-1 / length-2 / length-3 inputs return all-dots.
    """
    s = _sanitize(seq)
    n = len(s)
    if n < MIN_HAIRPIN_LOOP + 2:
        return "." * n, 0

    # N[i][j] = max pairs in s[i..j] inclusive
    N: List[List[int]] = [[0] * n for _ in range(n)]
    for length in range(MIN_HAIRPIN_LOOP + 1, n):
        for i in range(0, n - length):
            j = i + length
            best = N[i + 1][j]                  # i unpaired
            if N[i][j - 1] > best:
                best = N[i][j - 1]              # j unpaired
            if j - i >= MIN_HAIRPIN_LOOP + 1:
                cand = N[i + 1][j - 1] + _pair(s[i], s[j])
                if cand > best:
                    best = cand
            for k in range(i + 1, j):
                cand = N[i][k] + N[k + 1][j]    # bifurcation
                if cand > best:
                    best = cand
            N[i][j] = best

    # Traceback — deterministic priority: i unpaired, j unpaired, (i,j) pair, bifurcation.
    pairs: List[Tuple[int, int]] = []
    stack: List[Tuple[int, int]] = [(0, n - 1)]
    while stack:
        i, j = stack.pop()
        if i >= j:
            continue
        if N[i][j] == 0:
            continue
        if N[i + 1][j] == N[i][j]:
            stack.append((i + 1, j))
        elif N[i][j - 1] == N[i][j]:
            stack.append((i, j - 1))
        elif j - i >= MIN_HAIRPIN_LOOP + 1 and N[i + 1][j - 1] + _pair(s[i], s[j]) == N[i][j] and _pair(s[i], s[j]) == 1:
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


def to_pair_list(dot_bracket: str) -> List[Tuple[int, int]]:
    """Convert dot-bracket to a sorted list of (i,j) pair indices."""
    stk: List[int] = []
    pairs: List[Tuple[int, int]] = []
    for k, c in enumerate(dot_bracket):
        if c == "(":
            stk.append(k)
        elif c == ")":
            if not stk:
                raise ValueError("unbalanced dot-bracket")
            i = stk.pop()
            pairs.append((i, k))
    if stk:
        raise ValueError("unbalanced dot-bracket")
    return sorted(pairs)


# --- self-check / demo --------------------------------------------------

_DEMO_CASES = [
    # (name, sequence, expected_min_pairs)
    ("hammerhead_min_12nt_core",   "CUGAUGAGGCCG",                  1),
    ("trna_acceptor_arm",           "GGGGCCAUAGCUCAGUGGUAGAGCGCAUGCUUUGCAUGUAUGAGGCCCCGGUUCAAUUCCGGGUGGUCCACCA", 15),
    ("simple_hairpin",              "GGGAAAUCCC",                    3),
    ("palindrome_8nt",              "GCGCGCGC",                      2),  # hairpin>=3 caps at (0,7)+(1,6); (2,5)/(3,4) infeasible
    ("no_pair_possible",            "AAAAAAAA",                       0),
    ("wobble_only",                 "GUGUGUGUGU",                    2),
]


def _selfcheck() -> int:
    """Returns 0 on PASS, 1 on FAIL. Prints a one-line summary per case."""
    print("ribozyme_mfe_nussinov.py — Nussinov MFE solver self-check")
    print("  (pair set: AU/UA/GC/CG/GU/UG · min hairpin loop = 3 nt)")
    print()
    fails = 0
    for name, seq, min_pairs in _DEMO_CASES:
        db, np_ = nussinov(seq)
        ok_len = len(db) == len(seq)
        ok_bal = is_balanced(db)
        ok_min = np_ >= min_pairs
        verdict = "PASS" if (ok_len and ok_bal and ok_min) else "FAIL"
        if verdict == "FAIL":
            fails += 1
        print(f"  [{verdict}] {name:<28} n={len(seq):>3}  pairs={np_:>2}  "
              f"(min={min_pairs})  db={db}")
        if not ok_len:
            print(f"         ✗ length mismatch: db={len(db)} seq={len(seq)}")
        if not ok_bal:
            print(f"         ✗ unbalanced dot-bracket")
        if not ok_min:
            print(f"         ✗ fewer pairs than min ({np_} < {min_pairs})")

    # Deterministic-rerun check: byte-identical output across two calls.
    print()
    seq_repro = "CUGAUGAGGCCGAUCGAAGCUUGCAA"
    db1, p1 = nussinov(seq_repro)
    db2, p2 = nussinov(seq_repro)
    if db1 == db2 and p1 == p2:
        print(f"  [PASS] determinism — byte-identical re-run on n={len(seq_repro)} sequence")
    else:
        fails += 1
        print(f"  [FAIL] determinism — output drift between runs")

    print()
    if fails == 0:
        print(f"  --- summary --- {len(_DEMO_CASES) + 1} / {len(_DEMO_CASES) + 1} PASS → verdict: PASS")
        print("__RIBOZYME_MFE_NUSSINOV__ PASS")
        return 0
    else:
        print(f"  --- summary --- {fails} FAIL → verdict: FAIL")
        print("__RIBOZYME_MFE_NUSSINOV__ FAIL")
        return 1


if __name__ == "__main__":
    import sys
    sys.exit(_selfcheck())
