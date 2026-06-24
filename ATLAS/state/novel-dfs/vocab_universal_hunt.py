#!/usr/bin/env python3
"""ATLAS r3a — extended-vocabulary ∀n-universal multiplicative identity hunt.

EXTENDS blue_harvest_12fn.py's af() generator (smallest-prime-factor sieve +
multiplicative per-prime formulas) with standard multiplicative functions
BEYOND the current 11/12:
    sig3 (σ₃), lam (λ Liouville =(-1)^Ω), mu (μ Möbius), mu2 (μ² squarefree
    indicator), tw_om (2^ω = #unitary divisors), J3 (Jordan k=3), psi (Dedekind ψ),
    core (n/rad), one (the unit 1).
plus the prior basis {sig,sig2,phi,tau,n,sopfr,rad,J2,om,Om}.

GOAL: scan 2-term / 3-term PRODUCT frames for identities that hold for EVERY n
in [2,N] ("universal-in-[2,N]" — evidence, NOT a proof):
    AB = CD          (2v=2v)
    AB = CDE         (2v=3v)
    ABC = DEF        (3v=3v)
Signs handled EXACTLY (μ, λ take negative values; products may be negative; no abs).
Deterministic: same output every run. LOCAL pure-Python only.

Usage: python3 vocab_universal_hunt.py [N]   (default N=20000)
"""
import itertools, sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# smallest-prime-factor sieve (reused from blue_harvest_12fn.py)
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j:
                spf[j] = i

def af(n):
    """Per-prime multiplicative arithmetic-function values (exact int)."""
    if n == 1:
        return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1,
                    J2=1, J3=1, psi=1, Om=0, om=0, mu=1, mu2=1, lam=1,
                    tw_om=1, core=1, one=1)
    m = n
    sig = sig2 = sig3 = tau = phi = psi = J2 = J3 = 1
    sopfr = 0; rad = 1; Om = 0; om = 0
    squarefree = True
    while m > 1:
        p = spf[m]; e = 0
        while m % p == 0:
            m //= p; e += 1
        sig  *= (p**(e+1)-1)//(p-1)
        sig2 *= (p**(2*(e+1))-1)//(p**2-1)
        sig3 *= (p**(3*(e+1))-1)//(p**3-1)
        tau  *= (e+1)
        phi  *= p**(e-1)*(p-1)
        psi  *= p**(e-1)*(p+1)
        J2   *= p**(2*e) - p**(2*(e-1))
        J3   *= p**(3*e) - p**(3*(e-1))
        sopfr += p*e; rad *= p; Om += e; om += 1
        if e >= 2:
            squarefree = False
    mu2 = 1 if squarefree else 0
    mu = (mu2 and (1 if om % 2 == 0 else -1))  # μ: 0 if not squarefree else (-1)^ω
    lam = 1 if Om % 2 == 0 else -1             # λ(n) = (-1)^Ω(n)
    tw_om = 2**om                              # 2^ω = #unitary divisors
    core = n // rad                            # n/rad  (powerfull-core complement)
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n,
                sopfr=sopfr, rad=rad, J2=J2, J3=J3, psi=psi, Om=Om, om=om,
                mu=mu, mu2=mu2, lam=lam, tw_om=tw_om, core=core, one=1)

# precompute all rows
F = [None] + [af(n) for n in range(1, N+1)]

keys = ['one','sig','sig2','sig3','phi','tau','n','sopfr','rad','J2','J3','psi',
        'Om','om','mu','mu2','lam','tw_om','core']
sym = {'one':'1','sig':'σ','sig2':'σ₂','sig3':'σ₃','phi':'φ','tau':'τ','n':'n',
       'sopfr':'sopfr','rad':'rad','J2':'J₂','J3':'J₃','psi':'ψ','Om':'Ω','om':'ω',
       'mu':'μ','mu2':'μ²','lam':'λ','tw_om':'2^ω','core':'core'}

def prod(row, names):
    v = 1
    for nm in names:
        v *= row[nm]
    return v

def universal(left_names, right_names):
    """True iff prod(left)==prod(right) for EVERY n in [2,N]. break on first fail."""
    for n in range(2, N+1):
        if prod(F[n], left_names) != prod(F[n], right_names):
            return False
    return True

# ---- canonical-form dedup: collapse common-factor variants to a primitive ----
# Represent an identity by the multiset difference of its two sides.
# Cancel factors that appear on both sides; sort remainder; that signed
# (left_remainder, right_remainder) bag (orient so left<=right lexicographically)
# is the primitive key. Trivial (empty after cancel) is skipped.
from collections import Counter

def primitive_key(left, right):
    lc, rc = Counter(left), Counter(right)
    common = lc & rc
    lrem = sorted((lc - common).elements())
    rrem = sorted((rc - common).elements())
    if not lrem and not rrem:
        return None  # trivially A=A
    a, b = tuple(lrem), tuple(rrem)
    return (a, b) if a <= b else (b, a)

# ---- algebraic normalizer over the sign/indicator subalgebra ----
# EXACT pointwise identities used to fold a side into a canonical multiset:
#   one=1 (unit, drop) · λ·λ=1 (involution) · μ²·μ²=μ² (idempotent)
#   μ·μ=μ² · λ·μ=μ² · λ·μ²=μ · μ·μ²=μ  (all verified exact, incl. zeros & signs)
def normalize_side(names):
    c = Counter(names)
    c.pop('one', None)                       # drop units
    # fold λ pairs to identity
    c['lam'] %= 2 if c.get('lam') else 1
    if c.get('lam', 0) == 0: c.pop('lam', None)
    # collapse μ multiplicities: μ·μ=μ², so even μ-count -> μ²'s, odd -> one μ + μ²'s
    mu = c.pop('mu', 0)
    mu2_from_mu = mu // 2
    rem_mu = mu % 2
    c['mu2'] = c.get('mu2', 0) + mu2_from_mu
    if rem_mu: c['mu'] = 1
    # one leftover λ with a μ -> μ² ;  λ with μ² -> μ  (apply once, then re-fold)
    changed = True
    while changed:
        changed = False
        if c.get('lam', 0) and c.get('mu', 0):
            c['lam'] -= 1; c['mu'] -= 1; c['mu2'] = c.get('mu2', 0) + 1
            changed = True
        elif c.get('lam', 0) and c.get('mu2', 0):
            c['lam'] -= 1; c['mu2'] -= 1; c['mu'] = c.get('mu', 0) + 1
            changed = True
        # μ·μ² = μ  (μ absorbs an μ²)
        if c.get('mu', 0) and c.get('mu2', 0):
            c['mu2'] -= 1
            changed = True
        # clean zeros / re-idempotent μ²
        for k in ('lam','mu','mu2'):
            if c.get(k, 0) <= 0: c.pop(k, None)
        if c.get('mu2', 0) > 1:
            c['mu2'] = 1
            changed = True
    return tuple(sorted(c.elements()))

def canon_key(left, right):
    a = normalize_side(left); b = normalize_side(right)
    # cancel common (non-zero-risky) factors that survive normalization
    ac, bc = Counter(a), Counter(b)
    common = ac & bc
    a = tuple(sorted((ac - common).elements()))
    b = tuple(sorted((bc - common).elements()))
    if a == b:
        return None
    return (a, b) if a <= b else (b, a)

candidate_keys = set()   # raw primitive keys seen from a holding raw frame
found = {}               # ACCEPTED canon key -> (pretty, classification)

def record(left, right):
    """Note a primitive key whose RAW frame held; final acceptance re-tests the
    ALGEBRAICALLY-NORMALIZED primitive on its own (zero-cancellation can't leak)."""
    pk = primitive_key(left, right)
    if pk is None:
        return
    candidate_keys.add(pk)

def pretty(names):
    return '·'.join(sym[x] for x in names) if names else '1'

def classify(lrem, rrem):
    """CLEAN = equality never relies on both sides being 0 simultaneously
    (i.e. there is no n in [2,N] where both sides are 0 while the 'stripped'
    non-vanishing comparison would differ). Practically: if removing the
    sign/indicator factors {μ,λ,μ²} from BOTH sides still yields a universal
    equality, it's CLEAN; otherwise the identity only holds via shared zeros
    -> ZERO-DEGENERATE."""
    SIGN = {'mu', 'lam', 'mu2'}
    has_sign = any(x in SIGN for x in lrem) or any(x in SIGN for x in rrem)
    if not has_sign:
        return 'CLEAN'
    lbase = [x for x in lrem if x not in SIGN]
    rbase = [x for x in rrem if x not in SIGN]
    # if the magnitude/base parts are equal as a universal identity, the sign
    # factors are doing real (non-zero) algebra -> CLEAN; else ZERO-DEGENERATE
    return 'CLEAN' if universal(lbase, rbase) else 'ZERO-DEGENERATE'

def finalize():
    seen = set()
    for pk in candidate_keys:
        lrem, rrem = pk
        if not universal(list(lrem) if lrem else [], list(rrem) if rrem else []):
            continue
        ck = canon_key(lrem, rrem)
        if ck is None or ck in seen:
            continue
        a, b = ck
        # the normalized primitive must itself hold universally
        if not universal(list(a) if a else [], list(b) if b else []):
            continue
        seen.add(ck)
        found[ck] = (f"{pretty(a)} = {pretty(b)}", classify(a, b))

# generate all multisets of given size from keys (with repetition, sorted)
def msets(size):
    return itertools.combinations_with_replacement(keys, size)

scanned = 0
# Frame 1: AB = CD  (2 vs 2)
m2 = list(msets(2))
for li in range(len(m2)):
    L = m2[li]
    for ri in range(li, len(m2)):
        R = m2[ri]
        if L == R:
            continue
        if primitive_key(L, R) is None:
            continue
        scanned += 1
        if universal(L, R):
            record(L, R)

# Frame 2: AB = CDE  (2 vs 3)
m3 = list(msets(3))
for L in m2:
    for R in m3:
        if primitive_key(L, R) is None:
            continue
        scanned += 1
        if universal(L, R):
            record(L, R)

# Frame 3: ABC = DEF  (3 vs 3)
for li in range(len(m3)):
    L = m3[li]
    for ri in range(li, len(m3)):
        R = m3[ri]
        if L == R:
            continue
        if primitive_key(L, R) is None:
            continue
        scanned += 1
        if universal(L, R):
            record(L, R)

finalize()

clean = {k: v for k, v in found.items() if v[1] == 'CLEAN'}
degen = {k: v for k, v in found.items() if v[1] == 'ZERO-DEGENERATE'}

# ---- independence reduction: an identity A=B is a vector d[f]=#A(f)-#B(f) in
# Z^vocab (since ∏f^{d}=1 ∀n). Composite identities (products of others) are
# integer combinations of the rest. Extract a minimal generating BASIS via
# fraction-free Gaussian elimination over the rationals (rank-revealing). ----
from fractions import Fraction as Fr
def diff_vec(pk):
    a, b = pk
    c = Counter(a); c.subtract(Counter(b))
    return [c.get(k, 0) for k in keys]
def independent_basis(items):
    """items: list of (pk,(pretty,cls)). Returns subset that is row-independent
    (greedy: keep a row iff it raises the rank)."""
    basis_rows = []   # reduced echelon rows (list of Fraction)
    kept = []
    for pk, meta in items:
        row = [Fr(x) for x in diff_vec(pk)]
        r = row[:]
        for br in basis_rows:
            # find pivot col of br
            pc = next(i for i, x in enumerate(br) if x != 0)
            if r[pc] != 0:
                f = r[pc] / br[pc]
                r = [ri - f * bi for ri, bi in zip(r, br)]
        if any(x != 0 for x in r):
            # normalize pivot to 1, reduce existing basis (RREF-lite)
            pc = next(i for i, x in enumerate(r) if x != 0)
            r = [x / r[pc] for x in r]
            basis_rows.append(r)
            basis_rows.sort(key=lambda rr: next(i for i, x in enumerate(rr) if x != 0))
            kept.append((pk, meta))
    return kept

# order so the simplest (shortest pretty) survive as generators
clean_sorted = sorted(clean.items(), key=lambda kv: (len(kv[1][0]), kv[1][0]))
clean_basis = independent_basis(clean_sorted)
basis_keys = {pk for pk, _ in clean_basis}

print(f"=== r3a EXTENDED-VOCAB ∀n-UNIVERSAL HUNT (N={N}) ===")
print(f"vocabulary ({len(keys)}): " + ', '.join(sym[k] for k in keys))
print(f"frames scanned (non-trivial, dedup-eligible): {scanned}")
print(f"distinct normalized universal-in-[2,N] primitives: {len(found)}  "
      f"(CLEAN={len(clean)} · ZERO-DEGENERATE={len(degen)})")
print(f"independent CLEAN generators (lattice basis): {len(clean_basis)}")

print("---- INDEPENDENT CLEAN GENERATORS (basis · the real identities) ----")
for i, (pk, (s, _)) in enumerate(sorted(clean_basis, key=lambda kv: kv[1][0]), 1):
    print(f"  [{i:>2}] {s}")

print("---- DERIVED CLEAN primitives (products of the generators) ----")
for i, (pk, (s, _)) in enumerate(
        sorted((kv for kv in clean.items() if kv[0] not in basis_keys),
               key=lambda kv: kv[1][0]), 1):
    print(f"  [{i:>2}] {s}")

print("---- ZERO-DEGENERATE PRIMITIVES (hold only via shared zeros of μ/μ²) ----")
for i, (pk, (s, _)) in enumerate(sorted(degen.items(), key=lambda kv: kv[1][0]), 1):
    print(f"  [{i:>2}] {s}")

# ---- SANITY GATE: J2 = phi*psi must reappear as universal ----
jg = universal(['J2'], ['phi', 'psi'])
jg_in_clean = any(s == 'J₂ = φ·ψ' for s, _ in clean.values())
print(f"SANITY J₂=φ·ψ universal-in-[2,N]: {jg} · present-as-CLEAN-primitive: {jg_in_clean}")

# ---- HAND-CHECK every CLEAN primitive at n=12 (2²·3 prime-power) & n=30 (2·3·5 squarefree) ----
def evalside(n, names):
    return prod(F[n], names)
print("---- HAND-CHECK n=12 (=2²·3) & n=30 (=2·3·5) — CLEAN primitives ----")
allok = True
for pk, (s, _) in sorted(clean.items(), key=lambda kv: kv[1][0]):
    l, r = pk
    v12l, v12r = evalside(12, l), evalside(12, r)
    v30l, v30r = evalside(30, l), evalside(30, r)
    ok12 = (v12l == v12r); ok30 = (v30l == v30r)
    allok = allok and ok12 and ok30
    print(f"  {s:<20} n=12: {v12l}=={v12r} {'OK' if ok12 else 'FAIL'} | "
          f"n=30: {v30l}=={v30r} {'OK' if ok30 else 'FAIL'}")
print(f"ALL_CLEAN_HANDCHECK_PASS={allok}")
print("UNIVERSAL_TOTAL=%d" % len(found))
print("CLEAN_TOTAL=%d" % len(clean))
print("CLEAN_GENERATORS=%d" % len(clean_basis))
print("ZERO_DEGENERATE_TOTAL=%d" % len(degen))
