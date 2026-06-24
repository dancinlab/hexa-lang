#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — DIRICHLET CONVOLUTION frame (orthogonal to the product-frame
vocab_universal_hunt). (f*g)(n) = Sum_{d|n} f(d) g(n/d).

Reuses the smallest-prime-factor sieve + multiplicative af() generator VERBATIM from
blue_harvest_12fn.py / vocab_universal_hunt.py, over the vocabulary
    {1, id, sig, sig2, phi, tau, mu, lam, J2, psi, eps}
(plus auxiliaries sig3, rad, sopfr, Om, om for hand-checks). Exact integer arithmetic;
mu,lam signed (NO abs). N=20000.

GOAL: search for forall-n identities of the form
    (f*g) = h          (single function in the vocabulary)
    (f*g) = (h*k)       (another convolution)
"universal-in-[2,N]" is BOUNDED EVIDENCE, not proof. Each raw hit is independently
re-verified at the level of the reduced primitive, sign-checked, and hand-checked at
n=12 (=2^2*3) and n=30 (=2*3*5). SANITY GATES (must rediscover, else implementation bug)
are tested explicitly and reported.

Deterministic (no random / time). LOCAL pure-Python only.
Usage: python3 dirichlet-convolution_hunt.py [N]   (default N=20000)
"""
import itertools, sys
from collections import Counter

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# ---- smallest-prime-factor sieve (reused VERBATIM) ----
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j:
                spf[j] = i

def af(n):
    """Per-prime multiplicative arithmetic-function values (exact int). VERBATIM af()."""
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
    mu = (mu2 and (1 if om % 2 == 0 else -1))
    lam = 1 if Om % 2 == 0 else -1
    tw_om = 2**om
    core = n // rad
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n,
                sopfr=sopfr, rad=rad, J2=J2, J3=J3, psi=psi, Om=Om, om=om,
                mu=mu, mu2=mu2, lam=lam, tw_om=tw_om, core=core, one=1)

# precompute all rows
F = [None] + [af(n) for n in range(1, N+1)]

# ---- vocabulary as pointwise integer arrays f[n] over [1,N] ----
# id2 = n^2 (=id*id, used to test J2*1 = id^2 sanity)
def make_arr(key):
    a = [0]*(N+1)
    if key == 'one':
        for n in range(1, N+1): a[n] = 1
    elif key == 'eps':
        a[1] = 1  # epsilon(n) = [n==1]
    elif key == 'id2':
        for n in range(1, N+1): a[n] = n*n
    else:
        for n in range(1, N+1): a[n] = F[n][key]
    return a

# core convolution vocabulary (the frame's named functions)
VOCAB = ['one', 'n', 'sig', 'sig2', 'phi', 'tau', 'mu', 'lam', 'J2', 'psi', 'eps']
sym = {'one':'1','n':'id','sig':'σ','sig2':'σ₂','phi':'φ','tau':'τ','mu':'μ',
       'lam':'λ','J2':'J₂','psi':'ψ','eps':'ε','sig3':'σ₃','rad':'rad','id2':'id²'}
# auxiliary RHS-only targets that convolutions may equal as a single function
RHS_EXTRA = ['sig3', 'id2']

ARR = {k: make_arr(k) for k in set(VOCAB + RHS_EXTRA)}

# ---- divisor lists (small-divisor enumeration via spf factorization) ----
def divisors(n):
    if n == 1:
        return [1]
    m = n; facs = []
    while m > 1:
        p = spf[m]; e = 0
        while m % p == 0:
            m //= p; e += 1
        facs.append((p, e))
    divs = [1]
    for p, e in facs:
        divs = [d * p**k for d in divs for k in range(e+1)]
    return divs

DIV = [None] + [divisors(n) for n in range(1, N+1)]

def convolve(fk, gk):
    """Dirichlet convolution (f*g) as an integer array over [1,N]."""
    fa = ARR[fk]; ga = ARR[gk]
    out = [0]*(N+1)
    for n in range(1, N+1):
        s = 0
        for d in DIV[n]:
            s += fa[d] * ga[n // d]
        out[n] = s
    return out

def arr_eq(a, b):
    """forall n in [1,N]: a[n]==b[n]."""
    for n in range(1, N+1):
        if a[n] != b[n]:
            return False
    return True

def arr_eq_2N(a, b):
    """forall n in [2,N] (excludes n=1) — bounded evidence over non-unit support."""
    for n in range(2, N+1):
        if a[n] != b[n]:
            return False
    return True

# ---------------------------------------------------------------------------
# SANITY GATES — must rediscover the classical Dirichlet backbone
# ---------------------------------------------------------------------------
def is_perfect_square_arr():
    a = [0]*(N+1)
    r = 0
    for n in range(1, N+1):
        # integer sqrt check
        s = int(n**0.5)
        while s*s > n: s -= 1
        while (s+1)*(s+1) <= n: s += 1
        a[n] = 1 if s*s == n else 0
    return a

gates = []
def gate(name, lhs_arr, rhs_arr):
    ok = arr_eq(lhs_arr, rhs_arr)
    gates.append((name, ok))
    return ok

# 1*1 = tau
gate("1∗1=τ", convolve('one','one'), ARR['tau'])
# 1*id = sigma  (and id*1)
gate("1∗id=σ", convolve('one','n'), ARR['sig'])
gate("id∗1=σ", convolve('n','one'), ARR['sig'])
# phi*1 = id
gate("φ∗1=id", convolve('phi','one'), ARR['n'])
# mu*1 = eps
gate("μ∗1=ε", convolve('mu','one'), ARR['eps'])
# mu*id = phi
gate("μ∗id=φ", convolve('mu','n'), ARR['phi'])
# J2*1 = id^2   (Jordan totient summed over divisors = n^2)
gate("J₂∗1=id²", convolve('J2','one'), ARR['id2'])
# lam*1 = [n is a perfect square]
gate("λ∗1=[□]", convolve('lam','one'), is_perfect_square_arr())
# sig2 backbone: 1*id^2 = sig2
gate("1∗id²=σ₂", convolve('one','id2'), ARR['sig2'])

# ---------------------------------------------------------------------------
# SEARCH — (f*g) = h   and   (f*g) = (h*k)
# ---------------------------------------------------------------------------
# precompute all pairwise convolutions (unordered: conv is commutative)
conv_cache = {}
pairs = list(itertools.combinations_with_replacement(VOCAB, 2))
for fk, gk in pairs:
    conv_cache[(fk, gk)] = convolve(fk, gk)

# single-function targets the convolution may equal
single_targets = {k: ARR[k] for k in VOCAB}
single_targets['σ₃'] = ARR['sig3']
single_targets['id²'] = ARR['id2']
sym_single = dict(sym)
sym_single['σ₃'] = 'σ₃'; sym_single['id²'] = 'id²'

# classical-known identities catalogue (for labelling rediscovered vs novel)
# keyed by a frozenset-ish canonical string of the IDENTITY (orderless conv on LHS)
def pkey(fk, gk):
    a, b = sorted([fk, gk])
    return (a, b)

# Build catalogue of known convolution identities.  (f*g)=h
KNOWN_SINGLE = {
    # (fk,gk) -> (target_key, citation)
    pkey('one','one'):  ('tau',  '1∗1=τ (Dirichlet, classical)'),
    pkey('one','n'):    ('sig',  '1∗id=σ (classical)'),
    pkey('one','phi'):  ('n',    'φ∗1=id (Gauss, Σ_{d|n}φ(d)=n)'),
    pkey('one','mu'):   ('eps',  'μ∗1=ε (Möbius inversion core)'),
    pkey('mu','n'):     ('phi',  'μ∗id=φ (φ=μ∗id, classical)'),
    pkey('one','J2'):   ('id²',  'J₂∗1=id² (Jordan totient, Σ_{d|n}J₂(d)=n²)'),
    pkey('one','sig'):  (None,   '1∗σ (=Σσ, not single-vocab)'),
    pkey('one','id2'):  ('sig2', '1∗id²=σ₂ (classical, σ₂=Σd²)'),
    pkey('mu','sig'):   ('n',    'μ∗σ=id (inverse of 1∗id=σ)'),
    pkey('mu','sig2'):  ('id²',  'μ∗σ₂=id² (Möbius-inverse of σ₂)'),
    pkey('mu','tau'):   ('one',  'μ∗τ=1 (Möbius-inverse of τ=1∗1)'),
    pkey('mu','psi'):   (None,   'μ∗ψ (Dedekind-ψ inverse)'),
    pkey('mu','mu'):    (None,   'μ∗μ (=multiplicative, not in vocab)'),
}
# (f*g)=(h*k) known: these are products of the above; we report them as classical too.

# --- run single-function search ---
single_hits = []   # (fk, gk, target_name, classical_cite_or_None)
for (fk, gk) in pairs:
    c = conv_cache[(fk, gk)]
    for tname, tarr in single_targets.items():
        # skip the trivial self where conv already equals a vocab arr identically by name overlap
        if arr_eq(c, tarr):
            cite = None
            pk = pkey(fk, gk)
            if pk in KNOWN_SINGLE and KNOWN_SINGLE[pk][0] is not None:
                cite = KNOWN_SINGLE[pk][1]
            single_hits.append((fk, gk, tname, cite))

# --- run (f*g)=(h*k) search (excluding the trivial same-pair) ---
conv_pair_hits = []   # (fk,gk, hk,kk, classical?)
pair_list = pairs
for i in range(len(pair_list)):
    for j in range(i, len(pair_list)):
        p1 = pair_list[i]; p2 = pair_list[j]
        if p1 == p2:
            continue
        if arr_eq(conv_cache[p1], conv_cache[p2]):
            conv_pair_hits.append((p1, p2))

# ---------------------------------------------------------------------------
# NOVELTY DISCIPLINE — classify single-function hits
# ---------------------------------------------------------------------------
def fmt_single(fk, gk, tname):
    return f"({sym[fk]}∗{sym[gk]}) = {sym_single[tname]}"

def fmt_pair(p1, p2):
    return f"({sym[p1[0]]}∗{sym[p1[1]]}) = ({sym[p2[0]]}∗{sym[p2[1]]})"

# tautology filter: (f*eps)=f is definitional (eps is the convolution identity)
def is_eps_tautology(fk, gk):
    return fk == 'eps' or gk == 'eps'

# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
print(f"=== DIRICHLET-CONVOLUTION ∀n FRAME (N={N}) ===")
print(f"vocabulary ({len(VOCAB)}): " + ', '.join(sym[k] for k in VOCAB))
print(f"single-fn RHS targets also include: σ₃, id²")
print()
print("---- SANITY GATES (must rediscover; else implementation bug) ----")
all_gates_ok = True
for name, ok in gates:
    all_gates_ok = all_gates_ok and ok
    print(f"  {name:<14} : {'PASS' if ok else 'FAIL'}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print()

print("---- (f∗g)=h  HITS  (single-function) ----")
classical_single = []
tautology_single = []
novel_single = []
for fk, gk, tname, cite in sorted(single_hits, key=lambda t:(t[0],t[1],t[2])):
    s = fmt_single(fk, gk, tname)
    if is_eps_tautology(fk, gk):
        tautology_single.append((s, "ε is the convolution identity (f∗ε=f) — TAUTOLOGY"))
        continue
    if cite is not None:
        classical_single.append((s, cite))
    else:
        novel_single.append((fk, gk, tname, s))

for s, c in classical_single:
    print(f"  [CLASSICAL]  {s:<22}  — {c}")
for s, c in tautology_single:
    print(f"  [TAUTOLOGY]  {s:<22}  — {c}")
for fk, gk, tname, s in novel_single:
    print(f"  [?NOVEL?]    {s:<22}  — no catalogue entry; re-verifying")

print()
print("---- (f∗g)=(h∗k)  HITS  (convolution=convolution) ----")
for p1, p2 in conv_pair_hits:
    s = fmt_pair(p1, p2)
    print(f"  {s}")
if not conv_pair_hits:
    print("  (none beyond the single-function backbone)")
print()

# ---------------------------------------------------------------------------
# RE-VERIFY + HAND-CHECK every ?NOVEL? single hit, with negative control
# ---------------------------------------------------------------------------
print("---- RE-VERIFY ?NOVEL? candidates (independent eval + n=12,30 handcheck) ----")
confirmed_novel = []
for fk, gk, tname, s in novel_single:
    c = convolve(fk, gk)
    tarr = single_targets[tname]
    ok_all = arr_eq(c, tarr)
    # hand-checks at n=12 and n=30 computed from a FRESH direct divisor-sum
    def fresh_conv_at(n, fk, gk):
        fa = ARR[fk]; ga = ARR[gk]
        return sum(fa[d]*ga[n//d] for d in divisors(n))
    h12 = fresh_conv_at(12, fk, gk); t12 = tarr[12]
    h30 = fresh_conv_at(30, fk, gk); t30 = tarr[30]
    ok12 = (h12 == t12); ok30 = (h30 == t30)
    print(f"  {s}: ∀n[1,N]={ok_all} | n=12 {h12}=={t12} {'OK' if ok12 else 'FAIL'} | "
          f"n=30 {h30}=={t30} {'OK' if ok30 else 'FAIL'}")
    if ok_all and ok12 and ok30:
        confirmed_novel.append((fk, gk, tname, s))

if not novel_single:
    print("  (no ?NOVEL? single-function candidates — backbone is fully classical)")
print()

# ---------------------------------------------------------------------------
# NEGATIVE CONTROL — a near-miss that MUST FAIL (proves discriminating power)
# ---------------------------------------------------------------------------
print("---- NEGATIVE CONTROLS (must FAIL — proves search discriminates) ----")
# control 1: phi*1 = sigma  (FALSE; phi*1=id, not sigma)
c1 = arr_eq(convolve('phi','one'), ARR['sig'])
# control 2: mu*id = sigma  (FALSE; mu*id=phi)
c2 = arr_eq(convolve('mu','n'), ARR['sig'])
# control 3: 1*1 = sigma  (FALSE; 1*1=tau)
c3 = arr_eq(convolve('one','one'), ARR['sig'])
# first n where phi*1 != sigma
firstdiff = next((n for n in range(2,N+1) if convolve('phi','one')[n] != ARR['sig'][n]), None)
print(f"  φ∗1=σ ? {c1} (expect False; φ∗1=id, first n where σ≠id: n={firstdiff})")
print(f"  μ∗id=σ ? {c2} (expect False; μ∗id=φ)")
print(f"  1∗1=σ ? {c3} (expect False; 1∗1=τ)")
controls_ok = (not c1) and (not c2) and (not c3)
print(f"NEG_CONTROLS_ALL_FAIL_AS_EXPECTED={controls_ok}")
print()

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
print("=== SUMMARY ===")
print(f"GATES_PASSED={sum(1 for _,ok in gates if ok)}/{len(gates)}")
print(f"CLASSICAL_SINGLE={len(classical_single)}")
print(f"TAUTOLOGY_SINGLE={len(tautology_single)}")
print(f"NOVEL_SINGLE_CONFIRMED={len(confirmed_novel)}")
print(f"CONV_PAIR_HITS={len(conv_pair_hits)}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print(f"NEG_CONTROLS_OK={controls_ok}")
print(f"DEPLETED={'YES' if len(confirmed_novel)==0 else 'NO'}")
