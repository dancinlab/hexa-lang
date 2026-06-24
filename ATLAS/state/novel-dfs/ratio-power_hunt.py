#!/usr/bin/env python3
"""ATLAS RATIO/POWER frame — ∀n-universal POWER identities among multiplicative fns.

ORTHOGONAL to the prior AB=CD product hunt (vocab_universal_hunt.py): here a SINGLE
function may be raised to a power. Frame:

    f^a = g^b · h^c          (a,b,c integer exponents in [1,3])
    f^a · g^b = h^c          (and the symmetric monomial-balance forms)

Concretely we search for universal-in-[2,N] monomial relations
    ∏ f^{e_f} = 1   ∀n∈[2,N]      with exponents e_f ∈ [-3,3], small support
restricted to the STRICTLY-POSITIVE multiplicative basis
    {σ, σ₂, φ, τ, n, rad, J₂, ψ}     (the FRAME's target set)
so logarithm/ratio reasoning is exact (no sign/zero subtlety — μ,λ,ε are EXCLUDED
from the power frame on purpose; they live in the product/convolution frame).

The af() generator + smallest-prime-factor sieve are reused VERBATIM from
blue_harvest_12fn.py / vocab_universal_hunt.py. Exact integer arithmetic only.

SANITY GATE: J₂ = φ·ψ (known Jordan-totient factorization) MUST reappear.
Also checked: ψ·φ = J₂ (same), and the σ↔σ₂ multiplicative relation.

Method (ruthless false-positive control):
 (1) Enumerate every monomial vector e over the 8-fn basis with |e_f|<=3 and
     total positive-degree <=3 and total negative-degree <=3 (support <=4),
     normalized so the first nonzero coord is positive (dedup ±).
 (2) A vector is a UNIVERSAL relation iff ∏ f^{e_f} == 1 for all n in [2,N]
     (tested exactly via cross-multiplication: ∏_{e>0} f^e == ∏_{e<0} f^{-e}).
 (3) Lattice-basis dedup: relations form a Z-module; extract a minimal
     independent generating set via fraction-free Gaussian elimination over Q
     (a "hit" that is an integer combination of simpler hits is DERIVED, not new).
 (4) Classify each generator REDISCOVERED-CLASSICAL (cite) vs NOVEL-candidate vs
     TAUTOLOGY (definitional, e.g. core·rad=n — but core not in this basis).
 (5) Two hand-checks per generator: n=12 (=2²·3) and n=30 (=2·3·5).
 (6) Negative control: a near-miss monomial that FAILS, proving discrimination.

Deterministic. LOCAL pure-Python. Usage: python3 ratio-power_hunt.py [N]   (default 20000)
"""
import itertools, sys
from collections import Counter
from fractions import Fraction as Fr

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# ---- smallest-prime-factor sieve (VERBATIM reuse) ----
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j:
                spf[j] = i

# ---- multiplicative af() generator (VERBATIM reuse, restricted-positive basis) ----
def af(n):
    if n == 1:
        return dict(sig=1, sig2=1, phi=1, tau=1, n=1, rad=1, J2=1, psi=1)
    m = n
    sig = sig2 = tau = phi = psi = J2 = 1
    rad = 1
    while m > 1:
        p = spf[m]; e = 0
        while m % p == 0:
            m //= p; e += 1
        sig  *= (p**(e+1)-1)//(p-1)
        sig2 *= (p**(2*(e+1))-1)//(p**2-1)
        tau  *= (e+1)
        phi  *= p**(e-1)*(p-1)
        psi  *= p**(e-1)*(p+1)
        J2   *= p**(2*e) - p**(2*(e-1))
        rad  *= p
    return dict(sig=sig, sig2=sig2, phi=phi, tau=tau, n=n, rad=rad, J2=J2, psi=psi)

F = [None] + [af(n) for n in range(1, N+1)]

keys = ['sig', 'sig2', 'phi', 'tau', 'n', 'rad', 'J2', 'psi']
sym = {'sig':'σ', 'sig2':'σ₂', 'phi':'φ', 'tau':'τ', 'n':'n',
       'rad':'rad', 'J2':'J₂', 'psi':'ψ'}

# ---- exact universal test of a monomial relation e (dict fn->exp) ----
def universal_relation(e):
    """True iff ∏ f^{e_f} == 1 ∀n∈[2,N], via cross-multiplication (exact int)."""
    pos = [(k, v) for k, v in e.items() if v > 0]
    neg = [(k, -v) for k, v in e.items() if v < 0]
    for n in range(2, N+1):
        row = F[n]
        lhs = 1
        for k, v in pos:
            lhs *= row[k] ** v
        rhs = 1
        for k, v in neg:
            rhs *= row[k] ** v
        if lhs != rhs:
            return False
    return True

# ---- enumerate candidate monomial vectors ----
# support up to 4 fns; each exponent in [-3,3]\{0}; positive-degree<=3, neg-degree<=3.
# Normalize sign so first nonzero (in keys order) is positive -> dedup ±.
def normalized(e):
    for k in keys:
        c = e.get(k, 0)
        if c != 0:
            if c < 0:
                return {kk: -vv for kk, vv in e.items()}
            return dict(e)
    return None

seen_vecs = set()
candidates = []
EXPS = [-3, -2, -1, 1, 2, 3]
for r in range(2, 5):  # support 2..4
    for combo in itertools.combinations(keys, r):
        for exps in itertools.product(EXPS, repeat=r):
            posdeg = sum(x for x in exps if x > 0)
            negdeg = -sum(x for x in exps if x < 0)
            if posdeg == 0 or negdeg == 0:
                continue  # need genuine ratio/power balance (both sides nonempty)
            if posdeg > 3 or negdeg > 3:
                continue
            e = {k: x for k, x in zip(combo, exps)}
            en = normalized(e)
            key = tuple(sorted(en.items()))
            if key in seen_vecs:
                continue
            seen_vecs.add(key)
            candidates.append(en)

scanned = len(candidates)
hits = [e for e in candidates if universal_relation(e)]

# ---- lattice-basis dedup: relations span a Z-module; keep independent generators ----
def vec(e):
    return [e.get(k, 0) for k in keys]

def total_abs(e):
    return sum(abs(v) for v in e.values())

def independent_basis(items):
    """Greedy rank-revealing over Q; keep a relation iff it raises the rank."""
    basis_rows = []
    kept = []
    for e in items:
        row = [Fr(x) for x in vec(e)]
        r = row[:]
        for br in basis_rows:
            pc = next(i for i, x in enumerate(br) if x != 0)
            if r[pc] != 0:
                f = r[pc] / br[pc]
                r = [ri - f*bi for ri, bi in zip(r, br)]
        if any(x != 0 for x in r):
            pc = next(i for i, x in enumerate(r) if x != 0)
            r = [x / r[pc] for x in r]
            basis_rows.append(r)
            basis_rows.sort(key=lambda rr: next(i for i, x in enumerate(rr) if x != 0))
            kept.append(e)
    return kept

# order simplest-first (smallest total abs degree) so primitive relations survive
hits_sorted = sorted(hits, key=lambda e: (total_abs(e), len(e), tuple(sorted(e.items()))))
basis = independent_basis(hits_sorted)
basis_keyset = {tuple(sorted(e.items())) for e in basis}

# ---- pretty printing as  f^a · g^b = h^c · ...  (positive=LHS, negative=RHS) ----
def fmt_side(items):
    parts = []
    for k, v in items:
        s = sym[k]
        parts.append(s if v == 1 else f"{s}^{v}")
    return '·'.join(parts) if parts else '1'

def pretty(e):
    pos = sorted([(k, v) for k, v in e.items() if v > 0], key=lambda kv: keys.index(kv[0]))
    neg = sorted([(k, -v) for k, v in e.items() if v < 0], key=lambda kv: keys.index(kv[0]))
    return f"{fmt_side(pos)} = {fmt_side(neg)}"

# ---- classification ----
# Known multiplicative facts in this basis:
#   J₂ = φ·ψ              (Jordan totient factorization — CLASSICAL)
#   any derived rearrangement of the above (e.g. φ = J₂·ψ^{-1}) — same fact
# We mark a generator CLASSICAL if its primitive is exactly J₂=φ·ψ (or sign-flip).
JORDAN = {'J2': 1, 'phi': -1, 'psi': -1}  # J₂ φ^{-1} ψ^{-1} = 1
def is_jordan(e):
    return normalized(e) == normalized(JORDAN) or e == JORDAN

def classify(e):
    if is_jordan(e):
        return 'CLASSICAL', 'Jordan totient J₂(n)=φ(n)·ψ(n) (Apostol, Intro. Analytic NT, ch.2; J_k=∏ over primes, J_2=φ·ψ)'
    return 'NOVEL?', ''

# ---- run ----
print(f"=== RATIO/POWER frame ∀n-UNIVERSAL hunt (N={N}) ===")
print(f"basis ({len(keys)} strictly-positive multiplicative fns): " + ', '.join(sym[k] for k in keys))
print(f"monomial candidates scanned (support 2..4, |exp|<=3, posdeg<=3, negdeg<=3): {scanned}")
print(f"universal-in-[2,N] monomial relations (raw): {len(hits)}")
print(f"independent lattice generators: {len(basis)}")
print()

# ---- SANITY GATE ----
g_J2_phipsi = universal_relation({'J2': 1, 'phi': -1, 'psi': -1})   # J₂=φ·ψ
g_psiphi_J2 = universal_relation({'psi': 1, 'phi': 1, 'J2': -1})    # ψ·φ=J₂ (same)
# σ↔σ₂ relation check: is σ₂ a monomial in {σ,...}? (it is NOT — sanity that NO
# spurious σ₂=σ^2 / σ₂=σ·rad etc. universal relation exists)
g_sig2_sigsq = universal_relation({'sig2': 1, 'sig': -2})            # σ₂ =? σ²  (must be FALSE)
print("---- SANITY GATES ----")
print(f"  J₂=φ·ψ  universal-in-[2,N]: {g_J2_phipsi}  (MUST be True)")
print(f"  ψ·φ=J₂  universal-in-[2,N]: {g_psiphi_J2}  (MUST be True — same fact)")
print(f"  σ₂=σ²   universal-in-[2,N]: {g_sig2_sigsq}  (MUST be False — σ₂≠σ², near-miss control)")
jordan_in_basis = any(is_jordan(e) for e in basis) or any(is_jordan(e) for e in hits)
print(f"  J₂=φ·ψ present among universal relations: {jordan_in_basis}  (MUST be True)")
sanity_ok = g_J2_phipsi and g_psiphi_J2 and (not g_sig2_sigsq) and jordan_in_basis
print(f"  ALL_SANITY_GATES_PASS={sanity_ok}")
print()

# ---- list generators with classification + hand-checks ----
def evalmono(n, e):
    pos = 1; neg = 1
    row = F[n]
    for k, v in e.items():
        if v > 0: pos *= row[k] ** v
        else:     neg *= row[k] ** (-v)
    return pos, neg

print("---- INDEPENDENT GENERATORS (classified) ----")
classical_list = []
novel_list = []
allok = True
for i, e in enumerate(sorted(basis, key=lambda e: (total_abs(e), pretty(e))), 1):
    cls, cite = classify(e)
    p = pretty(e)
    l12, r12 = evalmono(12, e)
    l30, r30 = evalmono(30, e)
    ok12 = (l12 == r12); ok30 = (l30 == r30)
    allok = allok and ok12 and ok30
    tag = cls if cls != 'CLASSICAL' else 'CLASSICAL'
    print(f"  [{i}] {p:<22} [{tag}]")
    print(f"        hand-check n=12(2²·3): {l12}=={r12} {'OK' if ok12 else 'FAIL'} | "
          f"n=30(2·3·5): {l30}=={r30} {'OK' if ok30 else 'FAIL'}")
    if cls == 'CLASSICAL':
        print(f"        cite: {cite}")
        classical_list.append((p, cite))
    else:
        novel_list.append(e)

print()
print("---- DERIVED relations (integer combos of generators — NOT new) ----")
derived = [e for e in hits_sorted if tuple(sorted(e.items())) not in basis_keyset]
for i, e in enumerate(sorted(derived, key=lambda e: (total_abs(e), pretty(e)))[:40], 1):
    print(f"  [{i}] {pretty(e)}")
if len(derived) > 40:
    print(f"  ... (+{len(derived)-40} more derived)")

print()
print("---- NEGATIVE CONTROL (near-miss that FAILS — proves discrimination) ----")
# σ·φ =? n²  (a plausible-looking power relation) — must FAIL
nc1 = universal_relation({'sig': 1, 'phi': 1, 'n': -2})
fn12 = F[12]; fn30 = F[30]
print(f"  σ·φ = n²  universal: {nc1}  (FAILS as expected)")
print(f"     n=12: σ·φ={fn12['sig']*fn12['phi']} vs n²={12*12} -> "
      f"{'EQUAL' if fn12['sig']*fn12['phi']==144 else 'DIFFER (good)'}")
# J₂ =? n·rad  — must FAIL
nc2 = universal_relation({'J2': 1, 'n': -1, 'rad': -1})
print(f"  J₂ = n·rad universal: {nc2}  (FAILS as expected)")
print(f"     n=12: J₂={fn12['J2']} vs n·rad={12*fn12['rad']} -> "
      f"{'EQUAL' if fn12['J2']==12*fn12['rad'] else 'DIFFER (good)'}")
neg_control_ok = (not nc1) and (not nc2)
print(f"  NEG_CONTROL_DISCRIMINATES={neg_control_ok}")

print()
print(f"SCANNED={scanned}")
print(f"RAW_HITS={len(hits)}")
print(f"GENERATORS={len(basis)}")
print(f"CLASSICAL={len(classical_list)}")
print(f"NOVEL_CANDIDATES={len(novel_list)}")
print(f"ALL_HANDCHECK_PASS={allok}")
print(f"SANITY_OK={sanity_ok}")
print(f"NEG_CONTROL_OK={neg_control_ok}")
