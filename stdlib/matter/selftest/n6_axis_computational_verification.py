#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
selftest/n6_axis_computational_verification.py — n=6 lattice arithmetic sanity.

Per `LATTICE_POLICY.md §1.3`, the n=6 invariant lattice is **auxiliary** in
hexa-matter — NOT load-bearing. This gate is therefore a *sanity-only* check
that the four lattice constants used in `verify/lattice_arithmetic.hexa`
remain mathematically true:

  σ(6) = 1 + 2 + 3 + 6 = 12   (sum of divisors)
  τ(6) = |{1, 2, 3, 6}| = 4   (number of divisors)
  φ(6) = |{1, 5}| = 2         (Euler totient — coprime residues)
  J₂(6) = 24                  (Jordan totient J_k(n) = n^k · ∏(1 − p^{−k}))

Master identity: σ·φ = n·τ = J₂ = 24 ✓

This gate must NOT be used to certify any material-property claim — per
LATTICE_POLICY §1.2, real ceilings are anchored in LIMIT_BREAKTHROUGH.md
(NIST WebBook / CRC Handbook / Hales / Frenkel). This is arithmetic.

Pure stdlib. Exit 0 PASS / 1 FAIL.
"""
from __future__ import annotations

import math
import sys


def divisors(n: int) -> list[int]:
    return [d for d in range(1, n + 1) if n % d == 0]


def sigma(n: int) -> int:
    return sum(divisors(n))


def tau(n: int) -> int:
    return len(divisors(n))


def totient(n: int) -> int:
    return sum(1 for k in range(1, n + 1) if math.gcd(k, n) == 1)


def jordan_totient_2(n: int) -> int:
    """J_2(n) = n^2 · ∏_{p|n} (1 − p^{−2}) — for n=6: 36 · (1−1/4) · (1−1/9) = 36·(3/4)·(8/9) = 24."""
    if n <= 0:
        return 0
    # Find distinct prime factors.
    primes: list[int] = []
    nn = n
    p = 2
    while p * p <= nn:
        if nn % p == 0:
            primes.append(p)
            while nn % p == 0:
                nn //= p
        p += 1
    if nn > 1:
        primes.append(nn)
    # Use fractions for exactness.
    from fractions import Fraction

    val = Fraction(n) ** 2
    for q in primes:
        val *= Fraction(1) - Fraction(1, q * q)
    assert val.denominator == 1, f"J_2({n}) not integer: {val}"
    return val.numerator


def main() -> int:
    print("hexa-matter/selftest/n6_axis_computational_verification")
    print("  scope (LATTICE_POLICY §1.3): AUXILIARY sanity only — not a")
    print("  material-property certification. Real anchors live in")
    print("  LIMIT_BREAKTHROUGH.md (NIST/CRC/ASM/Hales/Frenkel).")
    print("")

    N = 6
    expected = {"σ(6)": 12, "τ(6)": 4, "φ(6)": 2, "J₂(6)": 24}
    actual = {
        "σ(6)": sigma(N),
        "τ(6)": tau(N),
        "φ(6)": totient(N),
        "J₂(6)": jordan_totient_2(N),
    }

    fail = 0
    for k, exp in expected.items():
        got = actual[k]
        ok = got == exp
        mark = "PASS" if ok else "FAIL"
        print(f"  [{mark}] {k} = {got}  (expected {exp})")
        if not ok:
            fail += 1

    # Master identity σ·φ = n·τ = J₂
    sigma_phi = actual["σ(6)"] * actual["φ(6)"]
    n_tau = N * actual["τ(6)"]
    j2 = actual["J₂(6)"]
    master_ok = sigma_phi == n_tau == j2 == 24
    print(f"  [{'PASS' if master_ok else 'FAIL'}] master identity σ·φ = n·τ = J₂ = "
          f"{sigma_phi} = {n_tau} = {j2}")
    if not master_ok:
        fail += 1

    print("")
    if fail > 0:
        print(f"__HEXA_MATTER_N6_AXIS__ FAIL  ({fail} arithmetic mismatch)")
        return 1
    print("__HEXA_MATTER_N6_AXIS__ PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
