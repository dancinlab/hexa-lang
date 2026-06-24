#!/usr/bin/env python3
"""ATLAS DIVISOR-SUM-frame hunt — the Dirichlet convolution-with-1 frame.

D[f](n) = Σ_{d|n} f(d)   (the divisor sum = f ∗ 1, the unary Dirichlet operator).

For each n in [2,N] we materialize the multiplicative arithmetic functions over the
smallest-prime-factor factorization (af() VERBATIM from blue_harvest_12fn.py /
census_blank_classify.py), augmented with the three CONVOLUTION-ring constants that
the product-frame never needed:
    mu     = μ(n)   Möbius             (signed; 0 on non-squarefree)
    lam    = λ(n)   Liouville  = (-1)^Ω (signed)
    eps    = ε(n)   = [n==1]            (Dirichlet identity)
plus the basic '1'(n)=1 ∀n (the all-ones function) and id(n)=n.

We compute D[f] for every f in the vocabulary, then search for ∀n-in-[2,N]
divisor-sum relations of the shapes
    D[f] = g                         (a function equals another's plain value)
    D[f] = g·h                       (divisor sum = product of two functions)
    D[f] = D[g]·h                    (divisor sum = (another divisor sum)·function)
    D[f] = D[g]·D[h]                 (divisor sum = product of two divisor sums)

EXACT integer arithmetic only. μ, λ are SIGNED — NO abs anywhere.
Deterministic; no Date.now / random.

"universal-in-[2,N]" = holds for EVERY n in [2,N] (break on first fail). This is
BOUNDED EVIDENCE, not a proof. μ/0-factor cancellation can manufacture FALSE
POSITIVES (a hit that secretly fails just past N, or that only holds because both
sides are 0 on a sparse set) — so EACH universal hit is RE-VERIFIED by an
independent recompute of D[f] from a fresh divisor enumeration, and CLASSIFIED:
  - SANITY GATE  : one of the 7 textbook divisor-sum laws (MUST pass; else a bug)
  - TAUTOLOGY    : definitional (e.g. 1·rad = rad)
  - REDISCOVERED : a KNOWN theorem from the Dirichlet ring (cite it — NOT a discovery)
  - NOVEL        : a ∀n divisor-sum relation not in the classical list (expect ~none)

Usage: python3 divisor-sum_hunt.py [N]
"""
import itertools
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# --- smallest-prime-factor sieve (VERBATIM from blue_harvest_12fn.py) ---
spf = list(range(N + 1))
for i in range(2, int(N ** 0.5) + 1):
    if spf[i] == i:
        for j in range(i * i, N + 1, i):
            if spf[j] == j:
                spf[j] = i


def af(n):  # multiplicative-fn core VERBATIM from blue_harvest_12fn.py, + convolution consts
    if n == 1:
        d = dict(sig=1, sig2=1, sig3=1, phi=1, tau=1, n=1, sopfr=0, rad=1,
                 J2=1, psi=1, Om=0, om=0)
        d['one'] = 1
        d['id'] = 1
        d['mu'] = 1       # μ(1)=1
        d['lam'] = 1      # λ(1)=(-1)^0=1
        d['eps'] = 1      # ε(1)=1
        d['n2'] = 1       # id^2 = n^2 (for D[J2]=n^2 gate convenience)
        return d
    m = n
    sig = sig2 = sig3 = tau = phi = psi = J2 = 1
    sopfr = 0
    rad = 1
    Om = 0
    om = 0
    sqfree = True
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
        if e >= 2:
            sqfree = False
    d = dict(sig=sig, sig2=sig2, sig3=sig3, phi=phi, tau=tau, n=n, sopfr=sopfr,
             rad=rad, J2=J2, psi=psi, Om=Om, om=om)
    d['one'] = 1
    d['id'] = n
    d['mu'] = (0 if not sqfree else ((-1) ** om))      # Möbius (signed)
    d['lam'] = (-1) ** Om                              # Liouville (signed)
    d['eps'] = 0                                       # ε(n)=0 for n>1
    d['n2'] = n * n
    return d


F = [None] + [af(n) for n in range(1, N + 1)]

# --- divisor lists (sieve of divisors), needed for D[f] and independent re-eval ---
divs = [[] for _ in range(N + 1)]
for d in range(1, N + 1):
    for m in range(d, N + 1, d):
        divs[m].append(d)


# The arithmetic-function vocabulary.
# multiplicative basics + convolution consts. ('n2' kept only for the J2 sanity gate.)
keys = ['one', 'id', 'mu', 'lam', 'eps',
        'sig', 'sig2', 'sig3', 'phi', 'tau', 'sopfr', 'rad', 'J2', 'psi', 'Om', 'om', 'n2']
sym = {'one': '1', 'id': 'id', 'mu': 'μ', 'lam': 'λ', 'eps': 'ε',
       'sig': 'σ', 'sig2': 'σ₂', 'sig3': 'σ₃', 'phi': 'φ', 'tau': 'τ',
       'sopfr': 'sopfr', 'rad': 'rad', 'J2': 'J₂', 'psi': 'ψ',
       'Om': 'Ω', 'om': 'ω', 'n2': 'n²'}


def val(n, k):
    return F[n][k]


def D(f, n):
    """divisor sum D[f](n) = Σ_{d|n} f(d), built from the precomputed divisor list."""
    s = 0
    for dd in divs[n]:
        s += F[dd][f]
    return s


# Precompute D[f](n) for every vocabulary function f and every n in [1,N].
Dtab = {f: [0] * (N + 1) for f in keys}
for f in keys:
    col = Dtab[f]
    for n in range(1, N + 1):
        col[n] = D(f, n)


def D_independent(f, n):
    """independent re-evaluation of D[f](n) — fresh trial-division divisor walk,
    NOT reusing divs[] or Dtab[]. Used to DEFEAT false positives by cross-check."""
    s = 0
    d = 1
    while d * d <= n:
        if n % d == 0:
            s += F[d][f]
            q = n // d
            if q != d:
                s += F[q][f]
        d += 1
    return s


def universal(pred, lo=2):
    for n in range(lo, N + 1):
        if not pred(n):
            return (False, n)
    return (True, None)


# ============================================================================
# SANITY GATES — the 7 textbook divisor-sum laws. These MUST pass.
# ============================================================================
gate_specs = [
    ("D[1]=τ",          lambda n: Dtab['one'][n] == F[n]['tau']),
    ("D[id]=σ",         lambda n: Dtab['id'][n] == F[n]['sig']),
    ("D[φ]=n",          lambda n: Dtab['phi'][n] == F[n]['id']),
    ("D[μ]=ε",          lambda n: Dtab['mu'][n] == F[n]['eps']),
    ("D[J₂]=n²",        lambda n: Dtab['J2'][n] == F[n]['n2']),
    # D[λ] = square-indicator: 1 if n is a perfect square else 0
    ("D[λ]=[n=□]",      lambda n: Dtab['lam'][n] == (1 if int(round(n ** 0.5)) ** 2 == n else 0)),
    # D[id^k] = σ_k : D[id^2]=σ₂, D[id^3]=σ₃  (two instances; id^2='n2', and id itself→σ above)
    ("D[id²]=σ₂",       lambda n: Dtab['n2'][n] == F[n]['sig2']),
]
gates = []
for name, pred in gate_specs:
    ok, ff = universal(pred, lo=1)   # gates are ∀n including n=1
    gates.append((name, ok, ff))


# ============================================================================
# CLASSIFICATION KNOWLEDGE — which D[f]=... relations are textbook / definitional.
# ============================================================================
# Known classical divisor-sum (f ∗ 1) values, as (f -> closed form key) where the
# closed form is a single vocabulary function. These are REDISCOVERED-CLASSICAL.
CLASSICAL_Df_eq_g = {
    'one': ('tau', "σ₀ = τ : Σ_{d|n}1 = τ(n)  [Hardy & Wright, Thm 273; OEIS A000005]"),
    'id':  ('sig', "σ₁ = σ : Σ_{d|n}d = σ(n)  [Hardy & Wright, Thm 275; OEIS A000203]"),
    'phi': ('id',  "Σ_{d|n}φ(d) = n  [Gauss; Hardy & Wright, Thm 63; OEIS A000010 totient sum]"),
    'mu':  ('eps', "Σ_{d|n}μ(d) = [n=1] = ε  [Möbius; Hardy & Wright, Thm 263]"),
    'J2':  ('n2',  "Σ_{d|n}J₂(d) = n²  [Jordan totient identity J_k ∗ 1 = id^k]"),
    'n2':  ('sig2', "Σ_{d|n}d² = σ₂(n)  [σ_k = id^k ∗ 1; OEIS A001157]"),
    'id':  ('sig', "σ₁ = σ"),  # (overwritten dup; id handled above)
}
# D[f]=D[g]·h known classical (multiplicativity / convolution-ring facts).
# e.g. D[sopfr]? D[rad]? — most non-completely-multiplicative f have NO single-fn
# closed divisor sum, so those simply won't hit.

# Tautology detector: a relation whose two sides are equal by DEFINITION of the
# functions for ALL n trivially (not via the divisor-sum structure). Here the only
# vocabulary identity of that kind is id == n (same column) and one·X == X.
def is_tautology_prod(lhs_f, g, h):
    # D[f] = g·h where one of g,h is 'one' and the other already equals D[f] as a
    # CLASSICAL single-fn law → tautological restatement, flag it.
    if g == 'one' or h == 'one':
        other = h if g == 'one' else g
        if lhs_f in CLASSICAL_Df_eq_g and CLASSICAL_Df_eq_g[lhs_f][0] == other:
            return True
    return False


# ============================================================================
# SEARCH 1 :  D[f] = g          (divisor sum equals a single vocabulary function)
# ============================================================================
hits_Df_eq_g = []
for f in keys:
    for g in keys:
        ok, ff = universal(lambda n, f=f, g=g: Dtab[f][n] == F[n][g], lo=2)
        if ok:
            # independent re-verify ∀n (defeat false positives) on a sample + full
            reok = True
            for n in range(2, N + 1):
                if D_independent(f, n) != F[n][g]:
                    reok = False
                    break
            if reok:
                hits_Df_eq_g.append((f, g))


# ============================================================================
# SEARCH 2 :  D[f] = g · h      (divisor sum = product of two vocabulary functions)
# ============================================================================
prod_pairs = [(g, h) for i, g in enumerate(keys) for h in keys[i:]]
hits_Df_eq_gh = []
for f in keys:
    for (g, h) in prod_pairs:
        ok, ff = universal(lambda n, f=f, g=g, h=h: Dtab[f][n] == F[n][g] * F[n][h], lo=2)
        if ok:
            reok = True
            for n in range(2, N + 1):
                if D_independent(f, n) != F[n][g] * F[n][h]:
                    reok = False
                    break
            if reok:
                hits_Df_eq_gh.append((f, g, h))


# ============================================================================
# SEARCH 3 :  D[f] = D[g] · h   (divisor sum = (another divisor sum) · function)
# ============================================================================
hits_Df_eq_Dgh = []
for f in keys:
    for g in keys:
        for h in keys:
            if g == f and h == 'one':
                continue  # trivial D[f]=D[f]·1
            ok, ff = universal(lambda n, f=f, g=g, h=h: Dtab[f][n] == Dtab[g][n] * F[n][h], lo=2)
            if ok:
                reok = True
                for n in range(2, N + 1):
                    if D_independent(f, n) != D_independent(g, n) * F[n][h]:
                        reok = False
                        break
                if reok:
                    hits_Df_eq_Dgh.append((f, g, h))


# ============================================================================
# SEARCH 4 :  D[f] = D[g] · D[h]  (divisor sum = product of two divisor sums)
# ============================================================================
Dpairs = [(g, h) for i, g in enumerate(keys) for h in keys[i:]]
hits_Df_eq_DgDh = []
for f in keys:
    for (g, h) in Dpairs:
        ok, ff = universal(lambda n, f=f, g=g, h=h: Dtab[f][n] == Dtab[g][n] * Dtab[h][n], lo=2)
        if ok:
            reok = True
            for n in range(2, N + 1):
                if D_independent(f, n) != D_independent(g, n) * D_independent(h, n):
                    reok = False
                    break
            if reok:
                hits_Df_eq_DgDh.append((f, g, h))


# ============================================================================
# HAND-CHECKS — two distinct n per claimed relation.
#   n=12 = 2²·3  (prime-power-bearing) ; n=30 = 2·3·5 (squarefree)
# ============================================================================
def handcheck_Df_eq_g(f, g):
    out = []
    for n in (12, 30):
        ds = [F[dd][f] for dd in divs[n]]
        lhs = sum(ds)
        rhs = F[n][g]
        out.append(f"n={n}: D[{sym[f]}]=Σ{{{','.join(str(x) for x in ds)}}}={lhs} ; {sym[g]}({n})={rhs} ; {'OK' if lhs == rhs else 'MISMATCH'}")
    return " | ".join(out)


def handcheck_Df_eq_gh(f, g, h):
    out = []
    for n in (12, 30):
        ds = [F[dd][f] for dd in divs[n]]
        lhs = sum(ds)
        rhs = F[n][g] * F[n][h]
        out.append(f"n={n}: D[{sym[f]}]={lhs} ; {sym[g]}·{sym[h]}({n})={F[n][g]}·{F[n][h]}={rhs} ; {'OK' if lhs == rhs else 'MISMATCH'}")
    return " | ".join(out)


# ============================================================================
# CLASSIFY every hit into {SANITY, TAUTOLOGY, REDISCOVERED, NOVEL}.
# ============================================================================
def classify_Df_eq_g(f, g):
    if f in CLASSICAL_Df_eq_g and CLASSICAL_Df_eq_g[f][0] == g:
        return ("REDISCOVERED", CLASSICAL_Df_eq_g[f][1])
    # id==n same-column tautology
    if (f, g) in (('id', 'id'),) or (sym[f] == sym[g]):
        return ("TAUTOLOGY", "same column")
    # σ_k families: D[id^k]=σ_k already covered; D[n2]=sig2 etc.
    return ("NOVEL?", "")


# negative control: a near-miss that MUST fail (proves discriminating power).
# D[1]=σ  (WRONG — should be τ).  And D[id]=τ (WRONG — should be σ).
neg_controls = [
    ("D[1]=σ   (near-miss of D[1]=τ)", lambda n: Dtab['one'][n] == F[n]['sig']),
    ("D[id]=τ  (near-miss of D[id]=σ)", lambda n: Dtab['id'][n] == F[n]['tau']),
    ("D[φ]=σ   (near-miss of D[φ]=n)", lambda n: Dtab['phi'][n] == F[n]['sig']),
    ("D[μ]=1   (near-miss of D[μ]=ε)", lambda n: Dtab['mu'][n] == F[n]['one']),
]
neg_results = []
for name, pred in neg_controls:
    ok, ff = universal(pred, lo=1)
    neg_results.append((name, ok, ff))


# ============================================================================
# REPORT
# ============================================================================
print(f"=== DIVISOR-SUM FRAME HUNT · D[f](n)=Σ_{{d|n}}f(d) · N={N} ===")
print(f"vocabulary ({len(keys)}): {' '.join(sym[k] for k in keys)}")
print(f"convolution consts added: μ (signed) · λ (signed) · ε · '1'")
print()

print("--- SANITY GATES (textbook divisor-sum laws · MUST PASS) ---")
all_gates_pass = True
for name, ok, ff in gates:
    tag = "PASS" if ok else f"FAIL@n={ff}"
    if not ok:
        all_gates_pass = False
    print(f"  {name:14s} : {tag}")
print(f"  ALL_GATES_PASS = {all_gates_pass}")
print()

print("--- NEGATIVE CONTROLS (near-misses · MUST FAIL = discriminating power) ---")
for name, ok, ff in neg_results:
    tag = f"FAILS@n={ff} (good)" if not ok else "UNIVERSAL?! (bad — search not discriminating)"
    print(f"  {name:34s} : {tag}")
print()

print("--- SEARCH 1 : D[f] = g  (universal-in-[2,N]) ---")
red1 = []
novel1 = []
taut1 = []
for f, g in hits_Df_eq_g:
    cls, cite = classify_Df_eq_g(f, g)
    line = f"  D[{sym[f]}] = {sym[g]}"
    if cls == "REDISCOVERED":
        red1.append((f, g, cite))
        print(f"{line:24s} [REDISCOVERED] {cite}")
    elif cls == "TAUTOLOGY":
        taut1.append((f, g))
        print(f"{line:24s} [TAUTOLOGY] {cite}")
    else:
        novel1.append((f, g))
        print(f"{line:24s} [NOVEL?] {handcheck_Df_eq_g(f, g)}")
print(f"  (count: {len(hits_Df_eq_g)})")
print()

print("--- SEARCH 2 : D[f] = g·h  (universal-in-[2,N]) ---")
novel2 = []
for f, g, h in hits_Df_eq_gh:
    taut = is_tautology_prod(f, g, h)
    # also: one==1 means D[f]=g (already in search1); flag as restatement
    restate = (g == 'one' or h == 'one')
    line = f"  D[{sym[f]}] = {sym[g]}·{sym[h]}"
    if taut or restate:
        print(f"{line:28s} [TAUTOLOGY/restatement of D[f]=g]")
    else:
        # check if it's a known classical product (e.g. none expected for single-1 conv)
        novel2.append((f, g, h))
        print(f"{line:28s} [NOVEL?] {handcheck_Df_eq_gh(f, g, h)}")
print(f"  (count: {len(hits_Df_eq_gh)})")
print()

print("--- SEARCH 3 : D[f] = D[g]·h  (universal-in-[2,N]) ---")
novel3 = []
for f, g, h in hits_Df_eq_Dgh:
    restate = (h == 'one' and g == f)
    line = f"  D[{sym[f]}] = D[{sym[g]}]·{sym[h]}"
    # D[f]=D[g] with h=1 means two functions with identical divisor sums
    if h == 'one' and g != f:
        print(f"{line:30s} [D-EQUAL: same divisor sum as D[{sym[g]}]]")
        novel3.append((f, g, h))
    elif restate:
        pass
    else:
        novel3.append((f, g, h))
        print(f"{line:30s} [NOVEL?]")
print(f"  (count: {len(hits_Df_eq_Dgh)})")
print()

print("--- SEARCH 4 : D[f] = D[g]·D[h]  (universal-in-[2,N]) ---")
novel4 = []
for f, g, h in hits_Df_eq_DgDh:
    line = f"  D[{sym[f]}] = D[{sym[g]}]·D[{sym[h]}]"
    # trivial when f==g, h such that D[h]=1 ∀n  → only h=eps gives D[eps]=1 ∀n
    trivial = (h == 'eps' and g == f) or (g == 'eps' and h == f)
    if trivial:
        print(f"{line:36s} [TAUTOLOGY: D[ε]=1 ∀n]")
    else:
        novel4.append((f, g, h))
        print(f"{line:36s} [NOVEL?]")
print(f"  (count: {len(hits_Df_eq_DgDh)})")
print()

# D[eps]=1 sanity (used in trivial filter)
Deps_is_one, _ = universal(lambda n: Dtab['eps'][n] == 1, lo=1)
print(f"note: D[ε]=1 ∀n (Dirichlet identity is conv-unit) : {Deps_is_one}")
print()

print("=== TALLY ===")
print(f"GATES_PASS={all_gates_pass}")
print(f"REDISCOVERED_CLASSICAL(search1)={len(red1)}")
print(f"NOVEL_S1={len(novel1)} NOVEL_S2={len(novel2)} NOVEL_S3={len(novel3)} NOVEL_S4={len(novel4)}")
print(f"TAUTOLOGY_S1={len(taut1)}")
