#!/usr/bin/env python3
"""LANE 2 — multi-⊞ universal characterization.

census_blank_classify.py partitions the 2145-cell @F grid into
  filled-🔵 64 + closed-⚪ 1654 + multi-⊞ 321 + degenerate 106.

The 321 multi-⊞ cells each hold A*B = C*D for >=2 values of n. This sweep splits
those 321 into:
  UNIVERSAL    — holds for EVERY n in [2, N]  (a candidate TRUE for-all-n identity:
                 a real multiplicative-function relation, NOT a coincidence);
  PARTIAL-multi — holds for several n but FAILS at some n in range.

Reuses af() VERBATIM from blue_harvest_12fn.py (reference-match), restricted to the
11 census functions (sig3 excluded — never appears in census atoms). Same 66-product /
2145-cell construction as census_blank_classify.py so the partition is comparable.

The UNIVERSAL set are the @F/@L "true-forever" promotion candidates.
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

# The 11 census functions (sig3 never appears in census atoms → excluded).
keys = ['sig', 'sig2', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']
sym = {'sig': 'σ', 'sig2': 'σ₂', 'phi': 'φ', 'tau': 'τ', 'n': 'n', 'sopfr': 'sopfr',
       'rad': 'rad', 'J2': 'J₂', 'psi': 'ψ', 'Om': 'Ω', 'om': 'ω'}
products = [(a, b) for i, a in enumerate(keys) for b in keys[i:]]  # 66 unordered products
MIN_N = 4

universal = []      # holds for EVERY n in [2, N]
partial = []        # >=2 solutions but fails at some n

# Re-derive the multi-⊞ set EXACTLY as census_blank_classify.py does (>=2 solutions),
# then for each multi cell decide universal-vs-partial with a FULL sweep.
for (a, b), (c, d) in itertools.combinations(products, 2):
    # quick solution-count probe (matches classify: count up to 3)
    sol = []
    for n in range(2, N + 1):
        if F[n][a] * F[n][b] == F[n][c] * F[n][d]:
            sol.append(n)
            if len(sol) > 2:
                break
    if len(sol) < 2:
        continue  # filled / degenerate / closed — not a multi-⊞ cell

    # this IS a multi-⊞ cell — now classify universal vs partial via full sweep
    holds_all = True
    first_fail = None
    for n in range(2, N + 1):
        if F[n][a] * F[n][b] != F[n][c] * F[n][d]:
            holds_all = False
            first_fail = n
            break
    label = f"{sym[a]}·{sym[b]} = {sym[c]}·{sym[d]}"
    if holds_all:
        universal.append(label)
    else:
        partial.append((label, first_fail))

nuni = len(universal)
npart = len(partial)
print(f"=== LANE 2 — multi-⊞ universal characterization (11 funcs, N={N}) ===")
print(f"  multi-⊞ total      = {nuni + npart}   (must == 321)")
print(f"  UNIVERSAL (all n)  = {nuni}")
print(f"  PARTIAL-multi      = {npart}")
print(f"  CHECK universal+partial = {nuni + npart} (== 321 ?)")
print()
print("  --- FULL UNIVERSAL list (candidate true-forever identities) ---")
for u in universal:
    print(f"    [U] {u}")
print()
print("  --- 3 PARTIAL examples (label · first failing n) ---")
for lbl, ff in partial[:3]:
    print(f"    [P] {lbl}   first-fail n={ff}")
