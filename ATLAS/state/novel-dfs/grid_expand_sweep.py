#!/usr/bin/env python3
"""LANE 4 — @F grid EXPANSION (discover more identities beyond the 11-func / 64-cell census).

Two expansions, both reusing af() VERBATIM from blue_harvest_12fn.py (reference-match):

  (a) 12-func basis: ADD 'sig3' to the 11 census funcs (→ 12 funcs). Products P=78,
      cells = C(78,2) = 3003. Sweep bounded-unique (exactly 1 solution, n>=4) and count how
      many NEW ones appear BEYOND the 11-func 64 — i.e. cells whose product set *involves* sig3
      (sig3 cannot appear in the 11-func grid, so every sig3-touching bounded-unique cell is new).

  (b) 3-factor identities: A*B*C = D*E*F over the 11 census funcs. Triple-products are unordered
      multisets-with-repetition: C(11+2,3) = C(13,3) = 286 distinct products. Cells = C(286,2)
      = 40755 unordered product PAIRS. This is a HONESTLY larger sweep than the 2-factor grid;
      we run it EXHAUSTIVELY (no sampling) over n in [2, N] but only keep bounded-unique
      (exactly 1 solution, n>=4). We skip trivially-equal product multisets (A*B*C ≡ D*E*F as
      the SAME multiset) since those are tautologies (hold for all n), not identities.

Determinism: pure integer arithmetic, fixed N, fixed key order → identical output every run.

Usage: python3 grid_expand_sweep.py [N]   (default N=20000, matches census/classify baseline).
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
BASIS12 = ['sig', 'sig2', 'sig3', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']


def val_pair(keys_in_pair, n):
    r = 1
    for k in keys_in_pair:
        r *= F[n][k]
    return r


# ----------------------------------------------------------------------------------------
# (a) 12-func basis: add sig3.  2-factor products, bounded-unique, count those involving sig3.
# ----------------------------------------------------------------------------------------
def sweep_2factor(keys):
    products = [(a, b) for i, a in enumerate(keys) for b in keys[i:]]
    cells = len(products) * (len(products) - 1) // 2
    bounded = []  # (left_prod, right_prod, n)
    for (a, b), (c, d) in itertools.combinations(products, 2):
        sol = []
        for n in range(2, N + 1):
            if F[n][a] * F[n][b] == F[n][c] * F[n][d]:
                sol.append(n)
                if len(sol) > 1:
                    break
        if len(sol) == 1 and sol[0] >= MIN_N:
            bounded.append(((a, b), (c, d), sol[0]))
    return products, cells, bounded


prod11, cells11, bounded11 = sweep_2factor(CENSUS11)
prod12, cells12, bounded12 = sweep_2factor(BASIS12)

# NEW = bounded-unique cells in the 12-func grid that involve sig3 (cannot exist in 11-func grid).
new_sig3 = [b for b in bounded12 if 'sig3' in (b[0][0], b[0][1], b[1][0], b[1][1])]


def fmt2(b):
    (a, bb), (c, d), x = b
    return f"{sym[a]}·{sym[bb]} = {sym[c]}·{sym[d]}   (unique n={x})"


print(f"=== LANE 4 (a) — 12-func basis (+sig3), 2-factor grid (N={N}) ===")
print(f"  11-func: products P=11→{len(prod11)}, cells={cells11}, bounded-unique 🔵={len(bounded11)}")
print(f"  12-func: products P=12→{len(prod12)}, cells={cells12}, bounded-unique 🔵={len(bounded12)}")
print(f"  NEW identities involving σ₃ (beyond the 11-func {len(bounded11)})= {len(new_sig3)}")
print(f"  total 12-func bounded-unique = 11-func {len(bounded11)} + σ₃-new {len(new_sig3)} = {len(bounded11) + len(new_sig3)}")
print("  3 examples of NEW σ₃ identities:")
for b in new_sig3[:3]:
    print("    " + fmt2(b))

# ----------------------------------------------------------------------------------------
# (b) 3-factor identities: A*B*C = D*E*F over the 11 census funcs. EXHAUSTIVE (no sampling).
#     Products = multisets of size 3 with repetition = C(13,3)=286. Cells = C(286,2)=40755 pairs.
#     Skip pairs whose two multisets are IDENTICAL (tautology). Keep bounded-unique (1 sol, n>=4).
# ----------------------------------------------------------------------------------------
triples = list(itertools.combinations_with_replacement(CENSUS11, 3))  # 286 distinct products
n_triples = len(triples)
cells3 = n_triples * (n_triples - 1) // 2
bounded3 = []
for tL, tR in itertools.combinations(triples, 2):
    # tL != tR guaranteed by combinations over distinct multisets (no identical-multiset pair).
    sol = []
    for n in range(2, N + 1):
        if val_pair(tL, n) == val_pair(tR, n):
            sol.append(n)
            if len(sol) > 1:
                break
    if len(sol) == 1 and sol[0] >= MIN_N:
        bounded3.append((tL, tR, sol[0]))


def fmt3(b):
    tL, tR, x = b
    L = "·".join(sym[k] for k in tL)
    R = "·".join(sym[k] for k in tR)
    return f"{L} = {R}   (unique n={x})"


print()
print(f"=== LANE 4 (b) — 3-factor identities A·B·C = D·E·F, 11 census funcs (N={N}) ===")
print(f"  triple-products (multiset size-3, repetition) = C(13,3) = {n_triples}")
print(f"  cells (unordered product pairs) = C({n_triples},2) = {cells3}   [EXHAUSTIVE, no sampling]")
print(f"  bounded-unique 🔵 (1-sol, n>=4) = {len(bounded3)}")
print("  3 examples:")
for b in bounded3[:3]:
    print("    " + fmt3(b))

print()
print("=== LANE 4 KEY NUMBERS ===")
print(f"GRID_A_12FUNC_CELLS={cells12}")
print(f"GRID_A_12FUNC_BOUNDED={len(bounded12)}")
print(f"GRID_A_SIG3_NEW={len(new_sig3)}")
print(f"GRID_B_3FACTOR_PRODUCTS={n_triples}")
print(f"GRID_B_3FACTOR_CELLS={cells3}")
print(f"GRID_B_3FACTOR_BOUNDED={len(bounded3)}")
