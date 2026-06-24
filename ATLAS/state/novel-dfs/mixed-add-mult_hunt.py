#!/usr/bin/env python3
"""ATLAS DFS — MIXED additive×multiplicative frame (NEGATIVE CONTROL · expect 0 NOVEL).

Reuses blue_harvest_12fn.py / vocab_universal_hunt.py's smallest-prime-factor sieve
+ multiplicative af() generator VERBATIM, extended with the convolution unit/sign atoms
(mu, lam, eps) and additive functions {Om, om, sopfr}.

FRAME (the control question):
  Does ANY multiplicative-function value equal a function of the *additive* ones
  (Ω, ω, sopfr) for EVERY n in [2,N], beyond the trivial?  e.g. is τ ever = f(Ω,ω) ∀n?
  Expectation: NO. τ,σ,φ,… depend on the prime EXPONENT MULTISET (and the primes
  themselves), whereas Ω,ω,sopfr collapse that multiset to scalar sums — so the
  additive class cannot reconstruct a multiplicative value universally. This lane is
  a NEGATIVE CONTROL: confirming the search does NOT over-fire by bridging the two
  function CLASSES proves it has discriminating power.

Method (exact integer arithmetic, signs exact — NO abs):
  Partition the vocabulary into MULT (multiplicative, exponent-multiset-sensitive) and
  ADD  (additive scalars: Ω, ω, sopfr; plus the additive-side helpers 1,n? — see below).
  Scan SUM-frames  m = c0 + c1·Ω + c2·ω + c3·sopfr  (small-integer affine combos, the
  natural shape for an additive→scalar predictor) AND PRODUCT/POLY frames where a single
  multiplicative target equals a low-degree polynomial in (Ω,ω,sopfr). A "bridge" = an
  additive-only expression matching a non-trivially-multiplicative target ∀n in [2,N].
  Report any universal hit (re-verified on the reduced primitive + 2 hand-checks +
  negative-control near-miss), and the STRONGEST near-miss (max coverage fraction) for
  every multiplicative target — which is where the bridge must fail.

Deterministic. LOCAL pure-Python only. Usage: python3 mixed-add-mult_hunt.py [N]
"""
import itertools, sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# ---- smallest-prime-factor sieve (VERBATIM from blue_harvest_12fn.py) ----
spf = list(range(N + 1))
for i in range(2, int(N**0.5) + 1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j:
                spf[j] = i

def af(n):
    """Per-prime multiplicative + additive arithmetic-function values (exact int).
    Multiplicative block VERBATIM from blue_harvest_12fn.py / vocab_universal_hunt.py;
    plus mu/lam/eps convolution atoms and the additive scalars Om,om,sopfr."""
    if n == 1:
        return dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1,
                    J2=1, psi=1, Om=0, om=0, mu=1, lam=1, eps=1, one=1)
    m = n
    sig = sig2 = sig3 = tau = phi = psi = J2 = 1
    sopfr = 0; rad = 1; Om = 0; om = 0
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
        sopfr += p*e; rad *= p; Om += e; om += 1
    mu  = 0 if Om != om else (1 if om % 2 == 0 else -1)   # μ: 0 unless squarefree
    lam = 1 if Om % 2 == 0 else -1                        # λ(n) = (-1)^Ω
    eps = 1 if n == 1 else 0                              # ε = [n==1]
    return dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n,
                sopfr=sopfr, rad=rad, J2=J2, psi=psi, Om=Om, om=om,
                mu=mu, lam=lam, eps=eps, one=1)

F = [None] + [af(n) for n in range(1, N+1)]

sym = {'sig':'σ','sig2':'σ₂','sig3':'σ₃','phi':'φ','tau':'τ','n':'n','sopfr':'sopfr',
       'rad':'rad','J2':'J₂','psi':'ψ','Om':'Ω','om':'ω','mu':'μ','lam':'λ','eps':'ε','one':'1'}

# multiplicative targets (exponent-multiset/prime-sensitive — the things we ask the
# additive class to reconstruct). Exclude the additive scalars themselves + units.
MULT = ['sig','sig2','sig3','phi','tau','n','rad','J2','psi','mu','lam']
ADD  = ['Om','om','sopfr']   # the additive predictors

# ================= SANITY GATES =================
# (a) classical additive identity must hold: Ω(n) >= ω(n) ∀n, equal iff squarefree.
g_omega = all(F[n]['Om'] >= F[n]['om'] for n in range(2, N+1))
g_omega_eq = all((F[n]['Om'] == F[n]['om']) == (F[n]['rad'] == F[n]['n'])
                 for n in range(2, N+1))
# (b) classical multiplicative identity J₂ = φ·ψ must reappear (sieve correctness).
g_jordan = all(F[n]['J2'] == F[n]['phi']*F[n]['psi'] for n in range(2, N+1))
# (c) τ for a prime p = 2 (additive-blind sanity: same Ω,ω different τ exists).
g_tau_struct = (F[16]['tau'] != F[12]['tau']) and \
               (F[16]['Om'], F[16]['om']) != (F[12]['Om'], F[12]['om'])  # 16:Ω4ω1 vs 12:Ω3ω2

# ================= FRAME A: AFFINE additive predictor =================
# m(n) ?= c0 + c1*Om + c2*om + c3*sopfr  ∀n  for each multiplicative target m.
# Small bounded integer coefficients (the honest affine shape an additive→scalar
# bridge would take). We SOLVE rather than brute-force: pick 4 anchor n with an
# invertible (Om,om,sopfr,1) design, fit exact-integer/rational coeffs if any, then
# VERIFY ∀n. This avoids a blind coefficient sweep (per CLAUDE.md no black-box sweep).
from fractions import Fraction as Fr

def fit_affine_and_verify(target):
    """Try to fit m = c0 + c1*Om + c2*om + c3*sopfr exactly using a well-conditioned
    anchor set; return (coeffs, coverage_fraction, first_fail_n) — coeffs=None if the
    linear system is rank-deficient / no exact rational solution / fails ∀n."""
    # anchors chosen to span the (Om,om,sopfr) lattice: n with distinct profiles
    anchors = [2, 4, 6, 12]   # 2:(1,1,2) 4:(2,1,4) 6:(2,2,5) 12:(3,2,7)
    A = [[1, F[a]['Om'], F[a]['om'], F[a]['sopfr']] for a in anchors]
    bvec = [Fr(F[a][target]) for a in anchors]
    # Gaussian elimination over Fractions
    M = [[Fr(x) for x in row] + [bvec[i]] for i, row in enumerate(A)]
    nrows = len(M); ncols = 4
    piv = []
    r = 0
    for c in range(ncols):
        pr = next((i for i in range(r, nrows) if M[i][c] != 0), None)
        if pr is None:
            continue
        M[r], M[pr] = M[pr], M[r]
        pivval = M[r][c]
        M[r] = [x / pivval for x in M[r]]
        for i in range(nrows):
            if i != r and M[i][c] != 0:
                f = M[i][c]
                M[i] = [a - f*b for a, b in zip(M[i], M[r])]
        piv.append(c); r += 1
        if r == nrows:
            break
    # check consistency (no 0=nonzero row)
    for i in range(nrows):
        if all(M[i][c] == 0 for c in range(ncols)) and M[i][ncols] != 0:
            return (None, 0.0, None)
    if len(piv) < ncols:
        return (None, 0.0, None)  # rank-deficient: no unique affine fit
    coeffs = [M[piv.index(c)][ncols] if c in piv else Fr(0) for c in range(ncols)]
    # coeffs must be the unique solution; verify ∀n exactly
    hits = 0; first_fail = None
    for n in range(2, N+1):
        pred = coeffs[0] + coeffs[1]*F[n]['Om'] + coeffs[2]*F[n]['om'] + coeffs[3]*F[n]['sopfr']
        if pred == F[n][target]:
            hits += 1
        elif first_fail is None:
            first_fail = n
    cov = hits / (N - 1)
    return (coeffs, cov, first_fail)

frameA = {}
for t in MULT:
    coeffs, cov, ff = fit_affine_and_verify(t)
    frameA[t] = (coeffs, cov, ff)

# ================= FRAME B: τ ?= f(Ω,ω) — exponent-multiset collapse probe =======
# The canonical bridge candidate named in the frame: is τ a function of (Ω,ω) ∀n?
# A function exists iff τ is CONSTANT on every (Ω,ω) class. Find a collision: two n
# with identical (Ω,ω) but different τ (or σ, φ, …) — that's the structural wall.
def class_collision(target):
    """Return (n1,n2) sharing (Om,om) but differing in target, plus #(Om,om) classes
    that are non-constant in target / total classes touched."""
    by_class = {}
    for n in range(2, N+1):
        key = (F[n]['Om'], F[n]['om'])
        by_class.setdefault(key, []).append(n)
    nonconst = 0; total = 0; witness = None
    for key, ns in by_class.items():
        if len(ns) < 2:
            continue
        total += 1
        vals = {F[x][target] for x in ns}
        if len(vals) > 1:
            nonconst += 1
            if witness is None:
                # smallest pair differing
                seen = {}
                for x in ns:
                    v = F[x][target]
                    if v in seen:
                        continue
                    seen[v] = x
                w = sorted(seen.values())
                witness = (w[0], w[1])
    return witness, nonconst, total

frameB = {}
for t in MULT:
    w, nc, tot = class_collision(t)
    frameB[t] = (w, nc, tot)

# Also probe the FINER class (Ω,ω,sopfr): does adding sopfr rescue any target?
def class_collision3(target):
    by_class = {}
    for n in range(2, N+1):
        key = (F[n]['Om'], F[n]['om'], F[n]['sopfr'])
        by_class.setdefault(key, []).append(n)
    nonconst = 0; total = 0; witness = None
    for key, ns in by_class.items():
        if len(ns) < 2:
            continue
        total += 1
        vals = {F[x][target] for x in ns}
        if len(vals) > 1:
            nonconst += 1
            if witness is None:
                seen = {}
                for x in ns:
                    v = F[x][target]
                    if v in seen: continue
                    seen[v] = x
                wlist = sorted(seen.values())
                witness = (wlist[0], wlist[1])
    return witness, nonconst, total

frameB3 = {}
for t in MULT:
    w, nc, tot = class_collision3(t)
    frameB3[t] = (w, nc, tot)

# ================= REPORT =================
def fr_str(c):
    return str(c.numerator) if c.denominator == 1 else f"{c.numerator}/{c.denominator}"

print(f"=== MIXED additive×multiplicative FRAME (NEGATIVE CONTROL, N={N}) ===")
print(f"vocabulary: MULT={[sym[k] for k in MULT]}  ADD(predictors)={[sym[k] for k in ADD]}")
print("--- SANITY GATES ---")
print(f"  G1 Ω(n)>=ω(n) ∀n: {g_omega}")
print(f"  G2 Ω==ω ⟺ squarefree (rad==n) ∀n: {g_omega_eq}")
print(f"  G3 J₂=φ·ψ universal-in-[2,N] (sieve correctness): {g_jordan}")
print(f"  G4 τ structure-sensitive (n=16 vs n=12 differ): {g_tau_struct}")
ALL_GATES = g_omega and g_omega_eq and g_jordan and g_tau_struct
print(f"  GATES_PASS={ALL_GATES}")

print("--- FRAME A: affine additive predictor  m ?= c0+c1·Ω+c2·ω+c3·sopfr  ∀n ---")
bridgesA = []
for t in MULT:
    coeffs, cov, ff = frameA[t]
    if coeffs is not None and ff is None:
        # universal hit!
        bridgesA.append(t)
        cs = ', '.join(fr_str(c) for c in coeffs)
        print(f"  {sym[t]:<4}: UNIVERSAL BRIDGE  coeffs(c0,cΩ,cω,csopfr)=({cs})  cov=1.000")
    elif coeffs is not None:
        cs = ', '.join(fr_str(c) for c in coeffs)
        print(f"  {sym[t]:<4}: near-miss fit ({cs})  cov={cov:.4f}  first_fail n={ff} "
              f"(target={F[ff][t]} pred≠)")
    else:
        print(f"  {sym[t]:<4}: NO affine fit (rank-deficient / inconsistent) — class-blind")
print(f"FRAME_A_UNIVERSAL_BRIDGES={len(bridgesA)}")

print("--- FRAME B: is target a function of (Ω,ω)? collision ⇒ NO bridge ---")
strongest_nearmiss = None
for t in MULT:
    w, nc, tot = frameB[t]
    if w is None:
        # every (Ω,ω) class is constant in target -> target IS a function of (Ω,ω)!
        print(f"  {sym[t]:<4}: NO collision in [2,N] — constant on every (Ω,ω) class "
              f"(possible bridge, classes touched={tot})")
    else:
        n1, n2 = w
        frac = nc / tot if tot else 0
        print(f"  {sym[t]:<4}: collision n={n1}({sym[t]}={F[n1][t]}) vs n={n2}({sym[t]}={F[n2][t]}) "
              f"same (Ω,ω)=({F[n1]['Om']},{F[n1]['om']}); {nc}/{tot} classes non-constant")
        # strongest near-miss = the target whose (Ω,ω)-classes are MOST often constant
        const_frac = 1 - frac
        if strongest_nearmiss is None or const_frac > strongest_nearmiss[1]:
            strongest_nearmiss = (t, const_frac, w)

print("--- FRAME B3: finer class (Ω,ω,sopfr) — does sopfr rescue any target? ---")
for t in MULT:
    w, nc, tot = frameB3[t]
    if w is None:
        print(f"  {sym[t]:<4}: NO collision under (Ω,ω,sopfr) (classes={tot}) — sopfr-determined?")
    else:
        n1, n2 = w
        print(f"  {sym[t]:<4}: STILL collides n={n1} vs n={n2} (same Ω,ω,sopfr) — "
              f"{nc}/{tot} classes non-constant")

# ---- DEFINITIONAL-TAUTOLOGY filter: λ,μ ARE additive-class functions BY DEFINITION ----
# λ(n)=(-1)^Ω(n) is a function of Ω alone; μ(n)=[Ω==ω]·(-1)^ω is a function of (Ω,ω).
# These are the constructions in af() itself, NOT discovered bridges. Confirm + flag.
lam_is_Om = all(F[n]['lam'] == (1 if F[n]['Om'] % 2 == 0 else -1) for n in range(2, N+1))
mu_is_Omom = all(F[n]['mu'] == (0 if F[n]['Om'] != F[n]['om']
                                else (1 if F[n]['om'] % 2 == 0 else -1)) for n in range(2, N+1))
print("--- DEFINITIONAL-TAUTOLOGY check (Frame-B 'functional bridges') ---")
print(f"  λ = (-1)^Ω  ∀n: {lam_is_Om}  -> TAUTOLOGY (λ defined via Ω; not a discovery)")
print(f"  μ = [Ω==ω]·(-1)^ω  ∀n: {mu_is_Omom}  -> TAUTOLOGY (μ defined via Ω,ω; not a discovery)")
GENUINE_B_BRIDGES = sum(1 for t in MULT if frameB[t][0] is None and t not in ('lam', 'mu'))
print(f"  genuine (non-definitional) Frame-B bridges: {GENUINE_B_BRIDGES}")

# strongest near-miss across the control: report the target closest to being an
# (Ω,ω) function, and WHERE it fails (the discriminating witness).
print("--- STRONGEST NEAR-MISS (control discriminating power) ---")
if strongest_nearmiss:
    t, cf, (n1, n2) = strongest_nearmiss
    print(f"  target {sym[t]}: {cf*100:.2f}% of (Ω,ω)-classes constant, but FAILS at "
          f"n={n1} vs n={n2} (same Ω={F[n1]['Om']},ω={F[n1]['om']}: "
          f"{sym[t]}={F[n1][t]} vs {F[n2][t]}) ⇒ NO ∀n bridge")

# ---- HAND-CHECKS n=12 (=2²·3) & n=30 (=2·3·5): show the class-collapse failure ----
print("--- HAND-CHECK n=12 (2²·3) & n=30 (2·3·5) ---")
for nn in (12, 30):
    r = F[nn]
    print(f"  n={nn}: Ω={r['Om']} ω={r['om']} sopfr={r['sopfr']} | "
          f"τ={r['tau']} σ={r['sig']} φ={r['phi']} μ={r['mu']} λ={r['lam']}")
# explicit τ vs (Ω,ω) collision hand-check: n=12 (Ω3ω2 τ6) vs n=18=2·3² (Ω3ω2 τ6) MATCH,
# but n=16=2⁴ (Ω4ω1 τ5) vs n=? share class with different τ — find the canonical pair.
# Canonical witness pair for τ as f(Ω,ω):
wtau, _, _ = frameB['tau']
if wtau:
    a, b = wtau
    print(f"  τ-bridge FAILS: n={a} (Ω={F[a]['Om']},ω={F[a]['om']},τ={F[a]['tau']}) vs "
          f"n={b} (Ω={F[b]['Om']},ω={F[b]['om']},τ={F[b]['tau']}) — same (Ω,ω), τ differs")

# GENUINE bridges = Frame-A universal affine fits + Frame-B functional bridges that are
# NOT definitional tautologies (λ via Ω, μ via Ω,ω). Expected control result = 0.
defin_taut = sum(1 for t in MULT if frameB[t][0] is None and t in ('lam', 'mu'))
TOTAL_GENUINE = len(bridgesA) + GENUINE_B_BRIDGES
print(f"GATES_PASS={ALL_GATES}")
print(f"FRAME_A_BRIDGES={len(bridgesA)}")
print(f"FRAME_B_FUNCTIONAL_BRIDGES_RAW={sum(1 for t in MULT if frameB[t][0] is None)}")
print(f"DEFINITIONAL_TAUTOLOGIES={defin_taut}  (λ=(-1)^Ω, μ=[Ω==ω](-1)^ω — by construction)")
print(f"GENUINE_NONTRIVIAL_BRIDGES={TOTAL_GENUINE}")
print(f"CONTROL_RESULT={'OVER-FIRED (BUG)' if TOTAL_GENUINE>0 else 'CLEAN-ZERO (expected · control has discriminating power)'}")
