#!/usr/bin/env python3
"""LANE A — 3-factor grid 4-WAY CENSUS (expanded-grid blank structure).

The 3-factor identity grid A·B·C = D·E·F over the 11 census funcs has C(286,2)=40755
distinct-triple-product cells (r1 grid_expand_sweep.py found 1431 bounded-unique among them).

This script classifies ALL 40755 cells the SAME 4 ways as the 2-factor census:
  filled-🔵     : exactly 1 solution n, with n>=4      (the 1431 — MUST reproduce r1)
  closed-⚪     : 0 solutions in n in [2,N]            (@N candidates — never-equal)
  multi-⊞       : >=2 solutions                         (identity-like / family)
  degenerate    : exactly 1 solution n, with n<4        (n=2 or n=3 only)

af() reused VERBATIM from blue_harvest_12fn.py (reference-match, exact integer arithmetic).
Triple-products = multisets size-3 with repetition = C(13,3) = 286 distinct products.
Cells = C(286,2) = 40755 unordered product PAIRS (no identical-multiset pair → no tautology).

Classification needs >=2 solutions to separate filled from multi, so we early-exit on the
SECOND solution (cannot stop at the first like a pure bounded-unique sweep). For closed-⚪ we
must scan the full [2,N] range (a 0-solution cell forces a full pass — this is the heavy part).

Determinism: pure integer arithmetic, fixed N, fixed key order → identical output every run.

Usage: python3 grid3_classify.py [N]   (default N=20000, matches r1 baseline).
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

sym = {'sig': 'σ', 'sig2': 'σ₂', 'sig3': 'σ₃', 'phi': 'φ', 'tau': 'τ', 'n': 'n',
       'sopfr': 'sopfr', 'rad': 'rad', 'J2': 'J₂', 'psi': 'ψ', 'Om': 'Ω', 'om': 'ω'}
MIN_N = 4

CENSUS11 = ['sig', 'sig2', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']

# Triple-products as flat per-n value vectors so the hot inner loop is plain int mult (fast).
triples = list(itertools.combinations_with_replacement(CENSUS11, 3))  # 286 distinct products
n_triples = len(triples)
cells3 = n_triples * (n_triples - 1) // 2

# Precompute, for each triple t and each n, the product value: prodval[t_index][n].
# 286 triples * (N+1) ints. At N=20000 that is ~5.7M python ints — acceptable in memory.
prodval = []
for t in triples:
    k0, k1, k2 = t
    col = [0] * (N + 1)
    for n in range(2, N + 1):
        Fn = F[n]
        col[n] = Fn[k0] * Fn[k1] * Fn[k2]
    prodval.append(col)


def fmt3(tL, tR, x):
    L = "·".join(sym[k] for k in tL)
    R = "·".join(sym[k] for k in tR)
    return f"{L} = {R}   (n={x})"


filled = []      # (tL, tR, n)  exactly 1 sol, n>=4
closed = []      # (tL, tR)     0 sol
multi = []       # (tL, tR, [n0, n1])  >=2 sol (first two recorded)
degen = []       # (tL, tR, n)  exactly 1 sol, n<4

idx = range(n_triples)
for iL in idx:
    colL = prodval[iL]
    for iR in range(iL + 1, n_triples):
        colR = prodval[iR]
        first = -1
        second = -1
        for n in range(2, N + 1):
            if colL[n] == colR[n]:
                if first < 0:
                    first = n
                else:
                    second = n
                    break
        if first < 0:
            closed.append((triples[iL], triples[iR]))
        elif second < 0:
            if first >= MIN_N:
                filled.append((triples[iL], triples[iR], first))
            else:
                degen.append((triples[iL], triples[iR], first))
        else:
            multi.append((triples[iL], triples[iR], (first, second)))

total = len(filled) + len(closed) + len(multi) + len(degen)

print(f"=== LANE A — 3-FACTOR GRID 4-WAY CENSUS (11 census funcs, N={N}) ===")
print(f"  triple-products (multiset size-3, repetition) = C(13,3) = {n_triples}")
print(f"  cells (unordered product pairs) = C({n_triples},2) = {cells3}   [EXHAUSTIVE, no sampling]")
print(f"  classified total = {total}  (must == {cells3})")
print()
print(f"  filled-🔵  (1-sol, n>=4) = {len(filled)}")
print(f"  closed-⚪  (0-sol)       = {len(closed)}")
print(f"  multi-⊞    (>=2-sol)     = {len(multi)}")
print(f"  degenerate (1-sol, n<4)  = {len(degen)}")
print()
print(f"  filled-🔵 cross-check vs r1 bounded3 = 1431 : {'PASS' if len(filled) == 1431 else 'FAIL'}")
print(f"  coverage (filled / cells) = {len(filled)}/{cells3} = {100.0*len(filled)/cells3:.4f}%")
print()
print("  --- 3 examples per category ---")
print("  filled-🔵:")
for tL, tR, x in filled[:3]:
    print("    " + fmt3(tL, tR, x))
print("  closed-⚪:")
for tL, tR in closed[:3]:
    L = "·".join(sym[k] for k in tL)
    R = "·".join(sym[k] for k in tR)
    print(f"    {L} = {R}   (no n in [2,{N}])")
print("  multi-⊞:")
for tL, tR, (n0, n1) in multi[:3]:
    L = "·".join(sym[k] for k in tL)
    R = "·".join(sym[k] for k in tR)
    print(f"    {L} = {R}   (sol n={n0},{n1},...)")
print("  degenerate:")
for tL, tR, x in degen[:3]:
    print("    " + fmt3(tL, tR, x))

print()
print("=== LANE A KEY NUMBERS ===")
print(f"GRID3_CELLS={cells3}")
print(f"GRID3_FILLED={len(filled)}")
print(f"GRID3_CLOSED={len(closed)}")
print(f"GRID3_MULTI={len(multi)}")
print(f"GRID3_DEGEN={len(degen)}")
print(f"GRID3_TOTAL={total}")
print(f"GRID3_COVERAGE_PCT={100.0*len(filled)/cells3:.4f}")
