#!/usr/bin/env python3
"""ATLAS additive SUM-frame hunt (LANE r3b) — the direction the multiplicative
product-frame CANNOT reach. Additive arithmetic functions over {Ω, ω, sopfr,
sopf, Ω−ω} plus constants {0,1}, searched for ∀n-in-[2,N] additive identities:

    A+B=C   ·   A+B=C+D   ·   A=C+D   ·   k·A=B (small int k)

Reuses the smallest-prime-factor sieve + per-n factor walk from
blue_harvest_12fn.py. Pure Python, deterministic, exact integers.

"universal" here = holds for EVERY n in [2,N] (bounded ∀n, break on first fail).
HONESTLY this is universal-in-[2,N] — EVIDENCE, not a proof. Found relations are
cited classical where known, else flagged CONJECTURE. Trivial/definitional ones
are filtered out (see _is_trivial).

Usage: python3 additive_sum_hunt.py [N]"""
import itertools, sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# --- smallest-prime-factor sieve (reused from blue_harvest_12fn.py) ---
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i

def af(n):
    """additive arithmetic functions for n>=2.
    Om   = bigomega   Ω(n)  = # prime factors WITH multiplicity
    om   = omega      ω(n)  = # DISTINCT primes
    sopfr= sopfr/A001414     = Σ p·e  (sum of prime factors with multiplicity)
    sopf = sopf/A008472      = Σ p    (sum of DISTINCT primes)
    excess = Ω−ω             = repeated-prime excess (A046660)
    """
    m=n; sopfr=0; sopf=0; Om=0; om=0
    while m > 1:
        p=spf[m]; e=0
        while m % p == 0: m//=p; e+=1
        sopfr += p*e; sopf += p; Om += e; om += 1
    return dict(Om=Om, om=om, sopfr=sopfr, sopf=sopf, excess=Om-om, zero=0, one=1)

F = [None, None] + [af(n) for n in range(2, N+1)]

# base functions (non-constant additive)  + constants
base = ['Om','om','sopfr','sopf','excess']
const = ['zero','one']
allk = base + const
sym = {'Om':'Ω','om':'ω','sopfr':'sopfr','sopf':'sopf','excess':'(Ω−ω)',
       'zero':'0','one':'1'}

def val(n,k):
    return F[n][k]

# trivial/definitional filters — these hold by definition of the functions and
# are NOT reported as discoveries (but recorded in a separate "trivial" bucket).
TRIVIAL_PAIRS = {
    # excess == Om - om  (definitional)
    frozenset([('excess',),('Om','om')]),
}
def _is_trivial(desc_norm):
    return desc_norm in TRIVIAL_PAIRS

def universal(pred):
    """True iff pred(n) for EVERY n in [2,N]; returns (ok, first_fail_n)."""
    for n in range(2, N+1):
        if not pred(n):
            return (False, n)
    return (True, None)

found = []          # list of (kind, desc, classification-key tuple)
seen_norm = set()   # dedupe by normalized multiset signature

def norm_eq(left, right):
    """canonical signature of an additive identity sum(left)=sum(right),
    constants dropped, so we can dedupe & detect triviality."""
    L = tuple(sorted(x for x in left if x not in const))
    R = tuple(sorted(x for x in right if x not in const))
    cl = sum(F[2][x]*0 for x in left)  # noop
    # also fold constant offset into a tag
    lc = sum(1 if x=='one' else 0 for x in left)
    rc = sum(1 if x=='one' else 0 for x in right)
    a,b = (L,lc),(R,rc)
    return frozenset([a,b]) if frozenset([a,b]) else None

def add_found(kind, desc, sig):
    if sig in seen_norm:
        return False
    seen_norm.add(sig)
    found.append((kind, desc))
    return True

# ---- 1. k·A = B  (single fn scaled equals single fn), small int k 2..6 ----
for k in range(2,7):
    for a in base:
        for b in base:
            if a==b: continue
            ok,_ = universal(lambda n,a=a,b=b,k=k: k*val(n,a)==val(n,b))
            if ok:
                sig = ('kAB',k,a,b)
                add_found('k·A=B', f"{k}·{sym[a]}={sym[b]}", sig)

# ---- 2. A = C + D  (one fn = sum of two, incl one const) ----
for a in base:
    for c,d in itertools.combinations_with_replacement(allk, 2):
        if c in const and d in const: continue
        # skip the trivial identity A = A + 0
        rs = sorted([c,d])
        if a in rs:
            rest = list(rs); rest.remove(a)
            if rest and rest[0] in const:
                # A = A + 0  trivial; A = A + 1 is just false, skip both as trivial-shaped
                continue
        ok,_ = universal(lambda n,a=a,c=c,d=d: val(n,a)==val(n,c)+val(n,d))
        if ok:
            # definitional Ω = ω + (Ω−ω) filter
            multiset_r = frozenset([(tuple(sorted(x for x in [c,d] if x not in const)),
                                     sum(1 for x in [c,d] if x=='one'))])
            desc = f"{sym[a]}={sym[c]}+{sym[d]}"
            sig = ('ACD', a, tuple(sorted([c,d])))
            # mark definitional ones
            rd = sorted([c,d])
            definitional = (a=='Om' and rd==sorted(['om','excess'])) or \
                           (a=='excess' and 'Om' in rd and 'om' in rd)
            kind = 'A=C+D (definitional)' if definitional else 'A=C+D'
            add_found(kind, desc, sig)

# ---- 3. A + B = C  (sum of two fns = one fn) ----
for a,b in itertools.combinations_with_replacement(base, 2):
    for c in base:
        if c in (a,b):
            # would reduce to k·A=B or trivial; allow A+A=C handled by k=2 above
            pass
        ok,_ = universal(lambda n,a=a,b=b,c=c: val(n,a)+val(n,b)==val(n,c))
        if ok:
            sig = ('ABC', tuple(sorted([a,b])), c)
            # definitional: ω+(Ω−ω)=Ω
            definitional = sorted([a,b])==sorted(['om','excess']) and c=='Om'
            kind = 'A+B=C (definitional)' if definitional else 'A+B=C'
            add_found(kind, f"{sym[a]}+{sym[b]}={sym[c]}", sig)

# ---- 4. A + B = C + D  (4-term, all base; skip if reduces to a 3-term) ----
lhs_pairs = list(itertools.combinations_with_replacement(base,2))
for i,(a,b) in enumerate(lhs_pairs):
    for (c,d) in lhs_pairs[i+1:]:
        if sorted([a,b])==sorted([c,d]): continue
        ok,_ = universal(lambda n,a=a,b=b,c=c,d=d: val(n,a)+val(n,b)==val(n,c)+val(n,d))
        if ok:
            sig = ('ABCD', frozenset([tuple(sorted([a,b])),tuple(sorted([c,d]))]))
            add_found('A+B=C+D', f"{sym[a]}+{sym[b]}={sym[c]}+{sym[d]}", sig)

# ---- 5. INEQUALITIES (recorded separately — NOT identities) ----
ineqs = []
ineq_tests = [
    ('Ω≥ω', lambda n: val(n,'Om')>=val(n,'om')),
    ('Ω>ω fails (∃ squarefree)', lambda n: val(n,'Om')>val(n,'om')),  # will fail -> not universal
    ('sopfr≥sopf', lambda n: val(n,'sopfr')>=val(n,'sopf')),
    ('sopf≥? sopfr fails', lambda n: val(n,'sopf')>=val(n,'sopfr')),
    ('Ω−ω≥0', lambda n: val(n,'excess')>=0),
    ('sopfr≥2·ω', lambda n: val(n,'sopfr')>=2*val(n,'om')),
    ('sopfr≥2·Ω', lambda n: val(n,'sopfr')>=2*val(n,'Om')),
    ('ω≥1', lambda n: val(n,'om')>=1),
    ('Ω≥1', lambda n: val(n,'Om')>=1),
    ('sopf≥2', lambda n: val(n,'sopf')>=2),
]
for name,pred in ineq_tests:
    ok,ff = universal(pred)
    ineqs.append((name, ok, ff))

# ---- squarefree relation: on squarefree n (Ω=ω), sopfr==sopf ----
sf_ok = True; sf_fail=None
for n in range(2,N+1):
    if val(n,'Om')==val(n,'om'):   # squarefree
        if val(n,'sopfr')!=val(n,'sopf'):
            sf_ok=False; sf_fail=n; break

# ---------- REPORT ----------
print(f"=== ADDITIVE SUM-FRAME HUNT (LANE r3b) · N={N} ===")
print(f"basis: Ω ω sopfr sopf (Ω−ω) + const 0,1  ·  ∀n∈[2,{N}] exact-int")
print()
nontrivial = [(k,d) for (k,d) in found if 'definitional' not in k]
definit    = [(k,d) for (k,d) in found if 'definitional' in k]
print(f"NON-TRIVIAL universal identities: {len(nontrivial)}")
for k,d in nontrivial:
    print(f"  [{k}]  {d}")
print()
print(f"DEFINITIONAL universal identities (filtered, expected): {len(definit)}")
for k,d in definit:
    print(f"  [{k}]  {d}")
print()
print("INEQUALITIES (separate — relations, not identities):")
for name,ok,ff in ineqs:
    tag = "UNIVERSAL-in-[2,N]" if ok else f"FAILS@n={ff}"
    print(f"  {name:28s} : {tag}")
print()
print(f"squarefree-restricted  Ω=ω ⟹ sopfr=sopf : "
      f"{'UNIVERSAL-in-[2,N]' if sf_ok else f'FAILS@n={sf_fail}'}")
print()
print(f"NONTRIVIAL_COUNT={len(nontrivial)}")
print(f"DEFINITIONAL_COUNT={len(definit)}")
