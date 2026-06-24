#!/usr/bin/env python3
"""LANE B — UNIVERSAL-IDENTITY hunt (∀n multiplicative identities = true-forever theorem candidates).

r1 found the same-n 2x2 frame (A·B = C·D over 11 funcs) has ZERO ∀n-universal identities — a true
for-all-n multiplicative identity needs a UNIT factor or a 3-term frame (the surfaced near-miss:
φ·ψ = J₂, the Jordan-totient identity, TRUE ∀n). This script EXTENDS the frame to surface those:

  (1) add a unit function one(n)=1 → 12-entry vocabulary {one + 11 census}, and/or
  (2) use a 3-term LHS frame A·B·C and mixed-degree products (1·2, 2·2, 2·3, 3·3 terms),

then for EACH candidate equality test whether it holds for EVERY n in [2,N] (∀n-in-[2,N]).
A bounded ∀n check is "universal-in-[2,N]", NOT a proof for all n — reported honestly as such.
Break on FIRST failing n for speed.

CROSS-CHECK: the 3-factor bounded-unique count MUST reproduce r1's 1431 (grid_expand_sweep.py).

af() is reused VERBATIM from blue_harvest_12fn.py (reference-match). Determinism: pure integer
arithmetic, fixed N, fixed key order → identical output every run.

Usage: python3 universal_hunt.py [N]   (default N=20000).
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

# vocabulary: 11 census funcs + the unit function one(n)=1
CENSUS11 = ['sig', 'sig2', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']
VOCAB12 = ['one'] + CENSUS11

sym = {'one': '1', 'sig': 'σ', 'sig2': 'σ₂', 'sig3': 'σ₃', 'phi': 'φ', 'tau': 'τ', 'n': 'n',
       'sopfr': 'sopfr', 'rad': 'rad', 'J2': 'J₂', 'psi': 'ψ', 'Om': 'Ω', 'om': 'ω'}


def val(k, n):
    return 1 if k == 'one' else F[n][k]


def prod(keys, n):
    r = 1
    for k in keys:
        r *= val(k, n)
    return r


def is_universal(tL, tR):
    """True iff prod(tL,n) == prod(tR,n) for EVERY n in [2,N]. Break on first failure."""
    for n in range(2, N + 1):
        if prod(tL, n) != prod(tR, n):
            return False
    return True


def fmt(tL, tR):
    L = "·".join(sym[k] for k in tL) if tL else "1"
    R = "·".join(sym[k] for k in tR) if tR else "1"
    return f"{L} = {R}"


# Some additive funcs (sopfr,Om,om) being 0 at n=1 make multiplicative framing degenerate; we test
# over n in [2,N] only. Multisets are unordered (combinations_with_replacement). We skip pairs whose
# two multisets are IDENTICAL (tautology) — itertools.combinations over distinct multisets ensures
# tL != tR. We also DROP candidates that are universal ONLY because both sides are identically a
# trivial padding of 'one' onto an identical core (those are caught as identical-multiset-after-
# removing-'one'); reported separately as "trivial-unit" so REAL identities stand out.


def core(t):
    """multiset with 'one' entries stripped (for trivial-unit detection)."""
    return tuple(k for k in t if k != 'one')


found = []  # (tL, tR, kind)  kind in {'real','trivial'}
seen = set()  # canonical {frozen multiset pair} dedupe

# ---- Frame enumeration ---------------------------------------------------------------------------
# We enumerate product multisets of sizes 2 and 3 over VOCAB12, then test equalities BETWEEN any two
# DISTINCT multisets of sizes in {2,3} (so frames: 2=2, 2=3, 3=3). The unit 'one' lets a 2-term side
# match a higher-degree intent and lets the classic φ·ψ=J₂ surface in clean 2=2 form (no 'one').
prods2 = list(itertools.combinations_with_replacement(VOCAB12, 2))
prods3 = list(itertools.combinations_with_replacement(VOCAB12, 3))
all_prods = [('2', p) for p in prods2] + [('3', p) for p in prods3]


def canon_key(tL, tR):
    a = tuple(sorted(tL))
    b = tuple(sorted(tR))
    return frozenset([a, b]) if a != b else None


for (dL, tL), (dR, tR) in itertools.combinations(all_prods, 2):
    if sorted(tL) == sorted(tR):
        continue  # identical multiset = tautology
    ck = canon_key(tL, tR)
    if ck is None or ck in seen:
        continue
    seen.add(ck)
    if is_universal(tL, tR):
        kind = 'trivial' if core(tL) == core(tR) else 'real'
        found.append((tL, tR, kind))

real = [x for x in found if x[2] == 'real']
trivial = [x for x in found if x[2] == 'trivial']

# ---- REDUCE each real identity to PRIMITIVE form: strip 'one', then CANCEL common factors shared by
# both multiset sides (e.g.  J₂·X = φ·ψ·X  cancels X  →  J₂ = φ·ψ ; the genuine single identity).
# This collapses all multiplied-through / unit-padded variants of the SAME law to ONE printed entry.
from collections import Counter


def reduce_identity(tL, tR):
    cL = Counter(k for k in tL if k != 'one')
    cR = Counter(k for k in tR if k != 'one')
    common = cL & cR  # min-multiplicity intersection = cancellable common factor
    cL -= common
    cR -= common
    pL = tuple(sorted(cL.elements()))
    pR = tuple(sorted(cR.elements()))
    return pL, pR


def prim_key(tL, tR):
    pL, pR = reduce_identity(tL, tR)
    return frozenset([pL, pR]) if pL != pR else None


real_by_core = {}
for tL, tR, _ in real:
    pk = prim_key(tL, tR)
    if pk is None:  # cancelled down to A=A (a tautology after cancellation) — not a real law
        continue
    pL, pR = reduce_identity(tL, tR)
    cand = (pL, pR)  # store the PRIMITIVE (cancelled) form itself
    if pk not in real_by_core or (len(pL) + len(pR)) < (len(real_by_core[pk][0]) + len(real_by_core[pk][1])):
        real_by_core[pk] = cand

# ---- CROSS-CHECK: reproduce r1's 3-factor bounded-unique = 1431 (grid_expand_sweep.py) -----------
MIN_N = 4
triples = list(itertools.combinations_with_replacement(CENSUS11, 3))
bounded3 = 0
for tL, tR in itertools.combinations(triples, 2):
    sol = []
    for n in range(2, N + 1):
        if prod(tL, n) == prod(tR, n):
            sol.append(n)
            if len(sol) > 1:
                break
    if len(sol) == 1 and sol[0] >= MIN_N:
        bounded3 += 1

# ---- hand-pick cross-check on n=12 (prime power 2²·3) and n=30 (squarefree 2·3·5) ----------------
def handcheck(tL, tR, n):
    return prod(tL, n), prod(tR, n)


print(f"=== LANE B — UNIVERSAL-IDENTITY HUNT (∀n-in-[2,{N}], extended frame) ===")
print(f"  vocabulary (12, incl unit one(n)=1): {[sym[k] for k in VOCAB12]}")
print(f"  product multisets: size-2={len(prods2)}, size-3={len(prods3)}, total candidates(pairs tested, deduped)={len(seen)}")
print()
print(f"  ∀n-universal equalities found (raw): {len(found)}  =  REAL {len(real)} + trivial-unit-pad {len(trivial)}")
print(f"  DISTINCT real identities (collapsed over 'one'-padding, single orientation): {len(real_by_core)}")
print()
print("  --- FULL LIST of DISTINCT REAL universal identities (true-forever candidates) ---")
ordered = sorted(real_by_core.values(), key=lambda c: (len(c[0]) + len(c[1]), fmt(*c)))
for i, (tL, tR) in enumerate(ordered, 1):
    s = fmt(tL, tR)
    v12L, v12R = handcheck(tL, tR, 12)
    v30L, v30R = handcheck(tL, tR, 30)
    print(f"  [{i:>2}] {s}")
    print(f"        n=12: {v12L} = {v12R}  {'OK' if v12L == v12R else 'MISMATCH'}   |   n=30: {v30L} = {v30R}  {'OK' if v30L == v30R else 'MISMATCH'}")

print()
print(f"  φ·ψ = J₂ present among primitive real identities: "
      f"{frozenset([('J2',),('phi','psi')]) in real_by_core}")
print()
print("=== CROSS-CHECK vs r1 ===")
print(f"  3-factor bounded-unique (n>=4, N={N}) = {bounded3}   (r1 oracle target = 1431, MATCH={bounded3 == 1431})")
print()
print("=== LANE B KEY NUMBERS ===")
print(f"UNIVERSAL_RAW={len(found)}")
print(f"UNIVERSAL_REAL={len(real)}")
print(f"UNIVERSAL_TRIVIAL_UNITPAD={len(trivial)}")
print(f"UNIVERSAL_DISTINCT_REAL={len(real_by_core)}")
print(f"CROSSCHECK_3FACTOR_BOUNDED={bounded3}")
