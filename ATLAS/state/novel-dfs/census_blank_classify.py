#!/usr/bin/env python3
"""Classify EVERY cell of the @F census grid — turn the 2081 BLANK cells into verdicts.

`hexa atlas census` reports the @F identity grid as 2145 cells / 64 filled / 2081 BLANK,
where "blank" pools two genuinely different states (untested vs tested-false). Unlike rtsc's
material-candidate gaps (which need EXTERNAL evidence to close), every @F blank is MECHANICALLY
decidable: just sweep n and count solutions of A*B=C*D. So this sweep RESOLVES all 2081 blanks
into verdicts — the data that an @N (refuted/⚪) atom fold would carry. Reuses af() verbatim
from blue_harvest_12fn.py (reference-match), restricted to the 11 census functions.

Verdict per cell (solution count over n in [2, N]):
  filled-🔵     : exactly 1 solution, n>=4   (the bounded-unique novelty = the 64 @F atoms)
  degenerate    : exactly 1 solution, n<4    (excluded by the harvest's MIN_N=4)
  multi-⊞       : >=2 solutions              (a looser identity — holds for several n)
  closed-⚪      : 0 solutions                (genuinely NEVER an identity in range = a real negative)
"""
import itertools
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
spf = list(range(N + 1))
for i in range(2, int(N ** 0.5) + 1):
    if spf[i] == i:
        for j in range(i * i, N + 1, i):
            if spf[j] == j:
                spf[j] = i


def af(n):  # verbatim from blue_harvest_12fn.py
    if n == 1:
        return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1, J2=1, psi=1, Om=0, om=0)
    m = n
    sig = sig2 = sig3 = tau = phi = psi = J2 = 1
    sopfr = 0
    rad = 1
    Om = 0
    om = 0
    while m > 1:
        p = spf[m]
        e = 0
        while m % p == 0:
            m //= p
            e += 1
        sig *= (p ** (e + 1) - 1) // (p - 1)
        sig2 *= (p ** (2 * (e + 1)) - 1) // (p ** 2 - 1)
        sig3 *= (p ** (3 * (e + 1)) - 1) // (p ** 3 - 1)
        tau *= (e + 1)
        phi *= p ** (e - 1) * (p - 1)
        psi *= p ** (e - 1) * (p + 1)
        J2 *= p ** (2 * e) - p ** (2 * (e - 1))
        sopfr += p * e
        rad *= p
        Om += e
        om += 1
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n, sopfr=sopfr, rad=rad, J2=J2, psi=psi, Om=Om, om=om)


F = [None] + [af(n) for n in range(1, N + 1)]

# The 11 census functions (atom-derived vocabulary; blue_harvest's sig3 never appeared → excluded).
keys = ['sig', 'sig2', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']
products = [(a, b) for i, a in enumerate(keys) for b in keys[i:]]  # 66 unordered products A*B
MIN_N = 4

filled = degenerate = multi = closed = 0
closed_examples = []
multi_examples = []
for (a, b), (c, d) in itertools.combinations(products, 2):  # 2145 distinct-product cells
    sol = []
    for n in range(2, N + 1):
        if F[n][a] * F[n][b] == F[n][c] * F[n][d]:
            sol.append(n)
            if len(sol) > 2:
                break
    label = f"{a}*{b} = {c}*{d}"
    if len(sol) == 0:
        closed += 1
        if len(closed_examples) < 6:
            closed_examples.append(label)
    elif len(sol) == 1 and sol[0] >= MIN_N:
        filled += 1
    elif len(sol) == 1:
        degenerate += 1
    else:
        multi += 1
        if len(multi_examples) < 6:
            multi_examples.append(f"{label}  (holds for >=2 n)")

total = len(products) * (len(products) - 1) // 2
blank = total - filled
print(f"=== @F census grid — FULL classification (11 funcs, N={N}) ===")
print(f"  denominator (cells)        = {total}")
print(f"  filled-🔵 (1-sol, n>=4)     = {filled}   <- the @F atoms")
print(f"  --- the {blank} 'blank' cells split into: ---")
print(f"  closed-⚪ (0 solutions)     = {closed}   genuine non-identity (a REAL negative, foldable as @N)")
print(f"  multi-⊞  (>=2 solutions)   = {multi}   looser identity (holds for several n)")
print(f"  degenerate (1-sol, n<4)    = {degenerate}   excluded by MIN_N=4")
print(f"  CHECK filled+closed+multi+degenerate = {filled + closed + multi + degenerate} (== denominator {total})")
print(f"  sample closed-⚪: {closed_examples}")
print(f"  sample multi-⊞ : {multi_examples}")
