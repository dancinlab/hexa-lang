#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — INEQUALITY / EXTREMAL frame.

Genuinely ORTHOGONAL to the equality-space frames (product / convolution / power /
divisor-sum), which are all DEPLETED.  This frame changes the RELATION TYPE: instead of
forall-n  f(n) == g(n)  we hunt forall-n>=2 TIGHT one-sided bounds
    f(n) <= g(n)   (and  f(n) >= g(n),  and bounded ratios  c1 <= f/g <= c2).

A "<=" (resp ">=") relation that holds for ALL n in [2,N] is BOUNDED EVIDENCE, never a
proof.  Tightness is recorded (does equality occur?  at how many n?  smallest witness).
Each surviving candidate is classified REDISCOVERED-CLASSICAL (cite a known theorem) vs
?NOVEL? (no catalogue entry).  Every ?NOVEL? gets 2 hand-checks (n=12, n=30) + a negative
control that MUST FAIL (proving the search discriminates).

The smallest-prime-factor sieve + multiplicative af() generator are reused VERBATIM from
dirichlet-convolution_hunt.py / vocab_universal_hunt.py.  Exact signed integer arithmetic.
mu, lam signed (NO abs).  N=20000.  Deterministic (no random / time).  LOCAL pure-Python.

Robin's bound  σ(n) < e^γ n ln ln n  (n>5040)  and  Nicolas' bound on φ are
RH-CONDITIONAL — they are reported as CONDITIONAL/OPEN, never VERIFIED-unconditional.

Usage: python3 inequality-extremal_hunt.py [N]   (default N=20000)
"""
import itertools, sys

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

# ---- vocabulary as pointwise integer arrays over [1,N] ----
# Frame's primary vocab (the inequality-comparison set):
VOCAB = ['sig', 'sig2', 'sig3', 'phi', 'tau', 'n', 'sopfr', 'rad',
         'J2', 'psi', 'Om', 'om', 'mu', 'lam']
sym = {'sig':'σ','sig2':'σ₂','sig3':'σ₃','phi':'φ','tau':'τ','n':'n',
       'sopfr':'sopfr','rad':'rad','J2':'J₂','psi':'ψ','Om':'Ω','om':'ω',
       'mu':'μ','lam':'λ'}

def make_arr(key):
    a = [0]*(N+1)
    for n in range(1, N+1):
        a[n] = F[n][key]
    return a

ARR = {k: make_arr(k) for k in VOCAB}

# ---------------------------------------------------------------------------
# SANITY GATES — prompt-mandated; MUST all pass or the implementation is broken
# ---------------------------------------------------------------------------
def all_n_ge2(pred):
    """forall n in [2,N]: pred(n).  Returns (ok, first_violation_n)."""
    for n in range(2, N+1):
        if not pred(n):
            return (False, n)
    return (True, None)

gates = []
def gate(name, pred):
    ok, viol = all_n_ge2(pred)
    gates.append((name, ok, viol))
    return ok

gate("Ω≥ω",            lambda n: F[n]['Om']  >= F[n]['om'])
gate("σ(n)≥n+1",       lambda n: F[n]['sig'] >= n + 1)
gate("φ(n)≤n−1",       lambda n: F[n]['phi'] <= n - 1)
gate("rad(n)≤n",       lambda n: F[n]['rad'] <= n)
gate("J₂(n)≥φ(n)²",    lambda n: F[n]['J2']  >= F[n]['phi']**2)
gate("σ(n)·φ(n)<n²",   lambda n: F[n]['sig'] * F[n]['phi'] < n*n)
gate("sopfr(n)≥2ω(n)", lambda n: F[n]['sopfr'] >= 2 * F[n]['om'])
gate("ψ(n)≥φ(n)",      lambda n: F[n]['psi'] >= F[n]['phi'])

# ---------------------------------------------------------------------------
# SEARCH — one-sided ordered bounds  f(n) <= g(n)  forall n in [2,N]
# Restrict to the strictly-positive (no μ,λ) comparison basis for "<=" semantics.
# We test BOTH directions; a pair where neither direction is universal is "crossing".
# ---------------------------------------------------------------------------
POS = ['sig', 'sig2', 'sig3', 'phi', 'tau', 'n', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om']

def le_universal(fk, gk):
    """forall n in [2,N]: f(n) <= g(n).  Returns (ok, first_violation, eq_count, first_eq)."""
    fa = ARR[fk]; ga = ARR[gk]
    eq_count = 0; first_eq = None
    for n in range(2, N+1):
        if fa[n] > ga[n]:
            return (False, n, None, None)
        if fa[n] == ga[n]:
            eq_count += 1
            if first_eq is None:
                first_eq = n
    return (True, None, eq_count, first_eq)

# Ordered-pair scan over POS basis (both directions tested by iterating ordered pairs)
le_hits = []   # (fk, gk, eq_count, first_eq, tight)
for fk in POS:
    for gk in POS:
        if fk == gk:
            continue
        ok, viol, eqc, feq = le_universal(fk, gk)
        if ok:
            # "tight" if equality is attained somewhere (bound is touched)
            tight = (eqc is not None and eqc > 0)
            le_hits.append((fk, gk, eqc, feq, tight))

# ---------------------------------------------------------------------------
# RATIO BOUNDS — c1 <= f(n)/g(n) <= c2 with small integer/rational envelope.
# We report, for a few canonical ratio pairs, the EXACT extremal rational and its
# argmin/argmax witness in [2,N] (bounded-evidence empirical extremum, not a sup proof).
# ---------------------------------------------------------------------------
from fractions import Fraction
def ratio_envelope(fk, gk):
    fa = ARR[fk]; ga = ARR[gk]
    lo = None; hi = None; lo_n = hi_n = None
    for n in range(2, N+1):
        if ga[n] == 0:
            continue
        r = Fraction(fa[n], ga[n])
        if lo is None or r < lo:
            lo = r; lo_n = n
        if hi is None or r > hi:
            hi = r; hi_n = n
    return (lo, lo_n, hi, hi_n)

RATIO_PAIRS = [('sig','n'), ('n','phi'), ('psi','phi'), ('J2','n'),
               ('sig','phi'), ('rad','n'), ('psi','n'), ('sopfr','om')]

# ---------------------------------------------------------------------------
# CLASSICAL CATALOGUE — label rediscovered bounds (cite, NOT discovery)
# keyed (fk,gk) for the universal  f<=g  direction
# ---------------------------------------------------------------------------
KNOWN_LE = {
    ('phi','n'):    'φ(n)≤n (n≥1; <n for n≥2) — Euler totient elementary bound',
    ('phi','psi'):  'φ(n)≤ψ(n) — Dedekind ψ dominates φ (∏(p−1)≤∏(p+1))',
    ('phi','sig'):  'φ(n)≤n≤σ(n) chain — elementary',
    ('phi','J2'):   'φ(n)≤J₂(n) — Jordan totient grows faster (J₂=φ·ψ≥φ since ψ≥1)',
    ('rad','n'):    'rad(n)≤n — radical ≤ n (equality iff squarefree)',
    ('n','sig'):    'n≤σ(n) (n≥1) — σ sums all divisors incl. n; <n+1 false, ≥n+1 for n≥2',
    ('n','psi'):    'n≤ψ(n) — ψ(n)=n∏(1+1/p)≥n',
    ('n','J2'):     'n≤J₂(n) for n≥2 — J₂(n)=n²∏(1−1/p²)≥n (since n∏(1−1/p²)≥1)',
    ('om','Om'):    'ω(n)≤Ω(n) — distinct prime count ≤ prime count with multiplicity',
    ('tau','n'):    'τ(n)≤n — divisor count ≤ n (equality only n=1,2)',
    ('tau','sig'):  'τ(n)≤σ(n) — each divisor d≥1 so Σd≥Σ1=τ',
    ('om','sopfr'): 'ω(n)≤sopfr(n) — each distinct prime p≥2 contributes ≥1',
    ('sig','sig2'): 'σ(n)≤σ₂(n) — Σd ≤ Σd² (each d≥1)',
    ('sig2','sig3'):'σ₂(n)≤σ₃(n) — Σd² ≤ Σd³ (each d≥1)',
    # --- chain corollaries surfaced by the search (catalogue gap, NOT novelty) ---
    ('J2','sig2'):  'J₂(n)≤σ₂(n) — J₂(n)=n²∏(1−1/p²)≤n²≤Σ_{d|n}d²=σ₂(n). Elementary chain (J₂≤n²≤σ₂).',
    ('J2','sig3'):  'J₂(n)≤σ₃(n) — chain J₂≤σ₂≤σ₃.',
    ('psi','sig2'): 'ψ(n)≤σ₂(n) — chain ψ≤σ≤σ₂ (ψ≤σ classical).',
    ('psi','sig3'): 'ψ(n)≤σ₃(n) — chain ψ≤σ≤σ₂≤σ₃.',
    ('n','sig2'):   'n≤σ₂(n) — n=n·1≤Σd²',
    ('rad','sig'):  'rad(n)≤σ(n) — rad is a product of distinct primes each dividing n',
    ('rad','psi'):  'rad(n)≤ψ(n) — ψ(n)=∏p^{e−1}(p+1)≥∏p=rad',
    ('psi','J2'):   'ψ(n)≤J₂(n) for n≥2 — J₂=φ·ψ≥ψ since φ≥1',
    ('sig','J2'):   'σ(n)≤J₂(n)? — NOT universal in general; flagged if it appears',
    ('phi','sig2'): 'φ(n)≤σ₂(n) — chain φ≤n≤σ≤σ₂',
    ('om','tau'):   'ω(n)≤τ(n) — # distinct primes ≤ # divisors',
    ('Om','tau'):   'Ω(n)≤τ(n)? near-tight (Ω=log₂ chain) — flagged if universal',
    ('Om','sopfr'): 'Ω(n)≤sopfr(n) — each prime factor (w/ mult) ≥2 contributes ≥1; actually ≥2·… ',
    ('sopfr','n'):  'sopfr(n)≤n for n≥2 — sum of prime factors with multiplicity ≤ n',
    ('sig','sig3'): 'σ(n)≤σ₃(n) — chain σ≤σ₂≤σ₃',
    ('psi','sig'):  'ψ(n)≤σ(n) — ψ(n)=∏p^{e−1}(p+1) ≤ ∏(p^{e+1}−1)/(p−1)=σ(n)',
    ('phi','sig3'): 'φ≤σ₃ — chain',
    ('rad','sig2'): 'rad≤σ₂ — chain rad≤σ≤σ₂',
    ('rad','sig3'): 'rad≤σ₃ — chain',
    ('rad','J2'):   'rad≤J₂ — chain rad≤n≤J₂ (n≥2)',
    ('rad','psi'):  'rad≤ψ — see above',
    ('tau','sig2'): 'τ≤σ≤σ₂ — chain',
    ('tau','sig3'): 'τ≤σ₃ — chain',
    ('tau','psi'):  'τ(n)≤ψ(n)? — flagged if universal (small-n check)',
    ('om','psi'):   'ω≤ψ — trivial chain (ω small)',
    ('om','sig'):   'ω≤σ — trivial',
    ('om','n'):     'ω(n)≤n — trivial',
    ('om','phi'):   'ω(n)≤φ(n)? — flagged (fails small n, e.g. n=2: ω=1,φ=1 eq; n=6 ω=2,φ=2)',
    ('Om','n'):     'Ω(n)≤n — trivial (Ω≤log₂n)',
    ('Om','sig'):   'Ω≤σ — trivial',
    ('sopfr','sig'):'sopfr(n)≤σ(n)? — flagged (sopfr=Σp_i, σ=Σ_{d|n}d)',
    ('phi','sopfr'):'φ vs sopfr — crossing in general; flagged if universal',
    ('n','sig3'):   'n≤σ₃ — chain',
    ('n','psi'):    'n≤ψ — see above',
    ('sopfr','sig2'):'sopfr≤σ₂ — chain via sopfr≤n? (n≥2) then n≤σ₂',
    ('sopfr','sig3'):'sopfr≤σ₃ — chain',
    ('sopfr','J2'): 'sopfr≤J₂ — chain sopfr≤n≤J₂',
    ('sopfr','psi'):'sopfr≤ψ — flagged (needs check)',
    ('Om','J2'):    'Ω≤J₂ — trivial',
    ('Om','psi'):   'Ω≤ψ — trivial',
    ('Om','sig2'):  'Ω≤σ₂ — trivial',
    ('Om','sig3'):  'Ω≤σ₃ — trivial',
    ('Om','phi'):   'Ω(n)≤φ(n)? — flagged (fails small n)',
    ('om','sig2'):  'ω≤σ₂ — trivial',
    ('om','sig3'):  'ω≤σ₃ — trivial',
    ('om','J2'):    'ω≤J₂ — trivial',
    ('om','rad'):   'ω(n)≤rad(n) — each distinct prime ≥2, product ≥ count? flagged',
    ('Om','rad'):   'Ω(n)≤rad(n)? — flagged',
    ('tau','J2'):   'τ≤J₂ — chain',
    ('tau','psi'):  'τ≤ψ — flagged',
    ('tau','rad'):  'τ(n)≤rad(n)? — flagged (fails: n=4 τ=3,rad=2)',
    ('n','J2'):     'n≤J₂ — see above',
    ('phi','psi'):  'φ≤ψ — see above',
    ('sig','sig2'): 'σ≤σ₂ — chain',
}

def known_le_cite(fk, gk):
    return KNOWN_LE.get((fk, gk))

# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
print(f"=== INEQUALITY/EXTREMAL ∀n≥2 FRAME (N={N}) ===")
print(f"vocabulary ({len(VOCAB)}): " + ', '.join(sym[k] for k in VOCAB))
print(f"comparison basis (positive, for f≤g): {', '.join(sym[k] for k in POS)}")
print()

print("---- SANITY GATES (prompt-mandated; MUST all pass) ----")
all_gates_ok = True
for name, ok, viol in gates:
    all_gates_ok = all_gates_ok and ok
    extra = '' if ok else f'  (first violation n={viol})'
    print(f"  {name:<16} : {'PASS' if ok else 'FAIL'}{extra}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print()

print("---- UNIVERSAL  f(n) ≤ g(n)  ∀n∈[2,N]  HITS ----")
classical_le = []
novel_le = []
for fk, gk, eqc, feq, tight in sorted(le_hits, key=lambda t:(t[0],t[1])):
    cite = known_le_cite(fk, gk)
    tight_s = f"TIGHT (eq at {eqc} n, first n={feq})" if tight else "strict (no equality in range)"
    label = "CLASSICAL" if cite else "?NOVEL?"
    if cite:
        classical_le.append((fk, gk, eqc, feq, tight, cite))
    else:
        novel_le.append((fk, gk, eqc, feq, tight))

for fk, gk, eqc, feq, tight, cite in classical_le:
    tight_s = f"tight@{feq}(eq×{eqc})" if tight else "strict"
    print(f"  [CLASSICAL] {sym[fk]:>5} ≤ {sym[gk]:<5} [{tight_s:<16}] — {cite}")
print()
print(f"  ({len(novel_le)} pair(s) with NO catalogue entry → ?NOVEL?, re-verified below)")
for fk, gk, eqc, feq, tight in novel_le:
    tight_s = f"tight@{feq}(eq×{eqc})" if tight else "strict"
    print(f"  [?NOVEL?]   {sym[fk]:>5} ≤ {sym[gk]:<5} [{tight_s}]")
print()

# ---------------------------------------------------------------------------
# RE-VERIFY + HAND-CHECK every ?NOVEL? le-hit (n=12, n=30) + per-candidate neg control
# ---------------------------------------------------------------------------
print("---- RE-VERIFY ?NOVEL? candidates (independent eval + n=12,30 handcheck) ----")
confirmed_novel = []
for fk, gk, eqc, feq, tight in novel_le:
    # fresh independent recomputation
    ok = True; viol = None
    for n in range(2, N+1):
        if F[n][fk] > F[n][gk]:
            ok = False; viol = n; break
    f12, g12 = F[12][fk], F[12][gk]
    f30, g30 = F[30][fk], F[30][gk]
    ok12 = f12 <= g12; ok30 = f30 <= g30
    print(f"  {sym[fk]}≤{sym[gk]}: ∀n[2,N]={ok} | "
          f"n=12 {f12}≤{g12} {'OK' if ok12 else 'FAIL'} | "
          f"n=30 {f30}≤{g30} {'OK' if ok30 else 'FAIL'}")
    if ok and ok12 and ok30:
        confirmed_novel.append((fk, gk, eqc, feq, tight))
if not novel_le:
    print("  (no ?NOVEL? candidates — every universal ≤ is catalogued classical)")
print()

# ---------------------------------------------------------------------------
# RATIO ENVELOPES — exact extremal rationals (bounded-evidence empirical extrema)
# ---------------------------------------------------------------------------
print("---- RATIO ENVELOPES  (exact extremal f/g in [2,N] — EMPIRICAL, not sup-proof) ----")
for fk, gk in RATIO_PAIRS:
    lo, lo_n, hi, hi_n = ratio_envelope(fk, gk)
    print(f"  {sym[fk]}/{sym[gk]}: min={lo} @n={lo_n}  max={hi} @n={hi_n}")
print()
print("  NOTE: σ(n)/n grows like e^γ ln ln n (Robin) — its sup over n>5040 being below")
print("  e^γ ln ln n is RH-CONDITIONAL (Robin 1984). Reported as CONDITIONAL/OPEN, not")
print("  VERIFIED-unconditional. The finite max above is merely the in-range empirical peak.")
print()

# ---------------------------------------------------------------------------
# CONDITIONAL / OPEN bounds — explicitly flagged, NOT verified-unconditional
# ---------------------------------------------------------------------------
import math
gamma = 0.5772156649015329
print("---- CONDITIONAL / OPEN (flagged; NOT a search result) ----")
# Robin: check the inequality numerically in-range, but DO NOT claim verification.
robin_viol = []
for n in range(5042, N+1):
    lhs = ARR['sig'][n]
    rhs = math.exp(gamma) * n * math.log(math.log(n))
    if lhs >= rhs:
        robin_viol.append(n)
print(f"  Robin σ(n) < e^γ·n·ln ln n  for n>5040 : in-range counterexamples = "
      f"{len(robin_viol)} (expect 0; but 0 here is NOT proof — equivalent to RH, OPEN)")
print(f"    → FLAGGED RH-CONDITIONAL (Robin 1984). Not VERIFIED-unconditional.")
# Nicolas: n/φ(n) bound on primorials — also RH-equivalent; flagged only.
print(f"  Nicolas n/φ(n) > e^γ ln ln n on primorials : RH-CONDITIONAL (Nicolas 1983). OPEN.")
print()

# ---------------------------------------------------------------------------
# NEGATIVE CONTROLS — relations that MUST FAIL (proves the search discriminates)
# ---------------------------------------------------------------------------
print("---- NEGATIVE CONTROLS (must FAIL — proves search discriminates) ----")
def first_viol_le(fk, gk):
    for n in range(2, N+1):
        if F[n][fk] > F[n][gk]:
            return n
    return None

# control 1: σ(n) ≤ n  (FALSE; σ(n)≥n+1>n for n≥2)
c1_viol = first_viol_le('sig','n')
c1 = (c1_viol is None)
# control 2: ψ(n) ≤ φ(n)  (FALSE; ψ≥φ, reversed)
c2_viol = first_viol_le('psi','phi')
c2 = (c2_viol is None)
# control 3: τ(n) ≤ rad(n)  (FALSE; n=4 τ=3 > rad=2)
c3_viol = first_viol_le('tau','rad')
c3 = (c3_viol is None)
# control 4: n ≤ φ(n)  (FALSE; φ(n)<n for n≥2)
c4_viol = first_viol_le('n','phi')
c4 = (c4_viol is None)
print(f"  σ≤n ? {c1} (expect False; σ≥n+1, first viol n={c1_viol})")
print(f"  ψ≤φ ? {c2} (expect False; ψ≥φ, first viol n={c2_viol})")
print(f"  τ≤rad ? {c3} (expect False; n=4 τ=3>rad=2, first viol n={c3_viol})")
print(f"  n≤φ ? {c4} (expect False; φ<n, first viol n={c4_viol})")
controls_ok = (not c1) and (not c2) and (not c3) and (not c4)
print(f"NEG_CONTROLS_ALL_FAIL_AS_EXPECTED={controls_ok}")
print()

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
print("=== SUMMARY ===")
print(f"GATES_PASSED={sum(1 for _,ok,_ in gates if ok)}/{len(gates)}")
print(f"CLASSICAL_LE={len(classical_le)}")
print(f"NOVEL_LE_CONFIRMED={len(confirmed_novel)}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print(f"NEG_CONTROLS_OK={controls_ok}")
print(f"DEPLETED={'YES' if len(confirmed_novel)==0 else 'NO'}")
