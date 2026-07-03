#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — CONGRUENCE (mod m) frame.  ORTHOGONAL to every prior frame:
the prior frames (product / divisor-sum / Dirichlet-convolution / additive-sum) all search
EXACT EQUALITY  f(n) == g(n).  This frame changes the RELATION TYPE: it searches forall-n
CONGRUENCES   f(n) ≡ g(n) (mod m)   for small m, where the residue classes (not the values)
carry the structure.  (Ramanujan's τ congruences are the famous example that this space CAN
hold non-trivial structure — so we genuinely search, but EXPECT ~0 novel among the standard
multiplicative vocab, which is heavily studied.)

Reuses the smallest-prime-factor sieve + multiplicative af() generator VERBATIM from
dirichlet-convolution_hunt.py / vocab_universal_hunt.py over the vocabulary
    {σ, σ₂, σ₃, φ, τ, n(id), sopfr, rad, J₂, ψ, Ω, ω, μ, λ}
Exact SIGNED integer arithmetic (μ, λ signed, NO abs).  N=20000.  m ∈ {2,3,4,5,6,8,9,12}.

A hit  f ≡ g (mod m)  for ALL n in [1,N] is BOUNDED EVIDENCE, not proof.  Every hit is
classified:
  TAUTOLOGY        — definitional restatement (e.g. f≡f, or g a fixed-constant residue
                     that is the literal definition mod m).
  REDISCOVERED     — a KNOWN classical congruence theorem (cite — NOT a discovery).
  ?NOVEL?          — no catalogue entry; re-verified independently + 2 hand-checks
                     (n=12, n=30) + a negative control that MUST FAIL (discrimination).

SANITY GATES (must rediscover, else implementation bug):
  G1  τ(n) ≡ 1 (mod 2)  ⟺  n is a perfect square         (τ odd iff square)
  G2  σ(n) ≡ 1 (mod 2)  ⟺  n is a square or twice a square (σ odd iff □ or 2·□)
  G3  φ(n) ≡ 0 (mod 2)  for all n ≥ 3                      (φ even for n≥3)
  G4  Ω(n) = ω(n)  ⟺  n is squarefree   (Ω−ω ≥ 0 is the squarefull defect; =0 iff sf).
      [NOTE: the mod-2 form "Ω≡ω (mod 2) ⟺ sf" is FALSE (e.g. n=36: Ω−ω=2 even but not sf);
       the correct theorem is the EXACT equality Ω=ω ⟺ sf — gate uses that.]
  G5  λ(n) = (−1)^Ω(n)  consistency:  λ ≡ 1 (mod 2) trivially, and λ·1 over divisors = [□]
  G6  J₂(n) is ODD only at n∈{1,2} (J₂(1)=1, J₂(2)=3); even ∀n≥3.   (J₂(p^e)=p^(2e−2)(p²−1):
      even for odd p, and for p=2 even once e≥2. "J₂ even ∀n≥2" is FALSE — J₂(2)=3 odd.)

Deterministic (no random / time).  LOCAL pure-Python only.
Usage: python3 congruence-modm_hunt.py [N]   (default N=20000)
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

# ---- vocabulary as pointwise integer arrays f[n] over [1,N] ----
# The multiplicative vocab requested; 'one' (constant 1) added as a residue partner.
VOCAB = ['sig', 'sig2', 'sig3', 'phi', 'tau', 'n', 'sopfr', 'rad',
         'J2', 'psi', 'Om', 'om', 'mu', 'lam', 'one']
sym = {'sig':'σ','sig2':'σ₂','sig3':'σ₃','phi':'φ','tau':'τ','n':'n','sopfr':'sopfr',
       'rad':'rad','J2':'J₂','psi':'ψ','Om':'Ω','om':'ω','mu':'μ','lam':'λ','one':'1',
       'OmMom':'Ω-ω','OmPom':'Ω+ω'}

def make_arr(key):
    a = [0]*(N+1)
    if key == 'one':
        for n in range(1, N+1): a[n] = 1
    elif key == 'OmMom':     # simple combo Ω-ω (squarefull defect)
        for n in range(1, N+1): a[n] = F[n]['Om'] - F[n]['om']
    elif key == 'OmPom':     # simple combo Ω+ω
        for n in range(1, N+1): a[n] = F[n]['Om'] + F[n]['om']
    else:
        for n in range(1, N+1): a[n] = F[n][key]
    return a

# simple combos added to the residue vocab (the "and simple combos" clause)
COMBOS = ['OmMom', 'OmPom']
ALLKEYS = VOCAB + COMBOS
ARR = {k: make_arr(k) for k in ALLKEYS}

MODS = [2, 3, 4, 5, 6, 8, 9, 12]

# python % already yields a non-negative residue for negative ints (μ,λ): (-1)%2==1, etc.
def res(a, n, m):
    return a[n] % m

# ---------------------------------------------------------------------------
# perfect-square / twice-square indicator arrays (for sanity gates)
# ---------------------------------------------------------------------------
def is_perfect_square_arr():
    a = [0]*(N+1)
    for n in range(1, N+1):
        s = int(n**0.5)
        while s*s > n: s -= 1
        while (s+1)*(s+1) <= n: s += 1
        a[n] = 1 if s*s == n else 0
    return a
SQ = is_perfect_square_arr()

def is_square_or_twice_square_arr():
    a = [0]*(N+1)
    for n in range(1, N+1):
        if SQ[n]:
            a[n] = 1
        elif n % 2 == 0 and SQ[n//2]:
            a[n] = 1
    return a
SQ2 = is_square_or_twice_square_arr()

def is_squarefree_arr():
    a = [0]*(N+1)
    for n in range(1, N+1):
        a[n] = F[n]['mu2']
    return a
SF = is_squarefree_arr()

# ---------------------------------------------------------------------------
# SANITY GATES
# ---------------------------------------------------------------------------
gates = []
def gate(name, cond):
    gates.append((name, cond))
    return cond

# G1: τ(n) odd  ⟺  n square
g1 = all(((ARR['tau'][n] % 2 == 1) == bool(SQ[n])) for n in range(1, N+1))
gate("G1 τ odd ⟺ □", g1)

# G2: σ(n) odd  ⟺  n square or twice-square
g2 = all(((ARR['sig'][n] % 2 == 1) == bool(SQ2[n])) for n in range(1, N+1))
gate("G2 σ odd ⟺ □|2□", g2)

# G3: φ(n) even for all n ≥ 3
g3 = all((ARR['phi'][n] % 2 == 0) for n in range(3, N+1))
gate("G3 φ even ∀n≥3", g3)

# G4: Ω(n) = ω(n)  ⟺  n squarefree  (EXACT equality, not mod 2)
g4 = all(((ARR['Om'][n] == ARR['om'][n]) == bool(SF[n])) for n in range(1, N+1))
gate("G4 Ω=ω ⟺ sf", g4)

# G5: λ(n) = (−1)^Ω(n)  and  λ∗1 = [□]  (Liouville summatory)
g5a = all((ARR['lam'][n] == (1 if ARR['Om'][n] % 2 == 0 else -1)) for n in range(1, N+1))
# λ summatory over divisors = [n square]
def divisors(n):
    if n == 1: return [1]
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
g5b = all((sum(ARR['lam'][d] for d in divisors(n)) == SQ[n]) for n in range(1, N+1))
gate("G5 λ=(−1)^Ω & λ∗1=[□]", g5a and g5b)

# G6: J₂(n) even for all n ≥ 3  (J₂ is ODD only at n∈{1,2}: J₂(1)=1, J₂(2)=3;
#     J₂(p^e)=p^(2e−2)(p²−1) is even for odd p, and for p=2 even once e≥2 ⇒ even ∀n≥3)
g6_only_odd = [n for n in range(1, N+1) if ARR['J2'][n] % 2 == 1]
g6 = (g6_only_odd == [1, 2])
gate("G6 J₂ odd ⟺ n∈{1,2}", g6)

# ---------------------------------------------------------------------------
# CLASSICAL CATALOGUE — congruences known to be theorems (cite, NOT discoveries)
# keyed by (f_key, g_key, m) with f,g sorted for the symmetric f≡g.  Value = citation.
# Also a set of "constant-residue" classical facts keyed (f_key, const, m).
# ---------------------------------------------------------------------------
def ckey(fk, gk, m):
    a, b = sorted([fk, gk])
    return (a, b, m)

KNOWN_PAIR = {
    # --- σ_k termwise Fermat / power-residue facts:  d^k ≡ d^j (mod m) for all d  ⇒
    #     σ_k(n)=Σd^k ≡ Σd^j=σ_j(n) (mod m).  These are CLASSICAL (Fermat little thm). ---
    ckey('sig','sig2',2):  'σ≡σ₂ (mod 2): d²≡d (mod 2) termwise (d²−d=d(d−1) even) — classical',
    ckey('sig','sig3',2):  'σ≡σ₃ (mod 2): d³≡d (mod 2) termwise — classical',
    ckey('sig2','sig3',2): 'σ₂≡σ₃ (mod 2): d²≡d³ (mod 2) termwise (both ≡d) — classical',
    ckey('sig','sig3',3):  'σ≡σ₃ (mod 3): d³≡d (mod 3) termwise (Fermat little thm p=3) — classical',
    ckey('sig','sig3',6):  'σ≡σ₃ (mod 6): 6 | d³−d=(d−1)d(d+1) termwise ∀d — classical (Fermat/CRT 2·3)',
    # --- multiplicative even-iff parity facts (φ, ψ, J₂ share the "even-iff-some-condition") ---
    ckey('phi','psi',2):   'φ≡ψ (mod 2): both even iff n>2 (φ,ψ multiplicative, p∓1 even for odd p) — classical',
    ckey('J2','psi',2):    'J₂≡ψ (mod 2): J₂=ψ·φ-type parity; both even ⟺ odd prime factor — classical',
    ckey('J2','phi',2):    'φ≡J₂ (mod 2): both even ⟺ n has odd prime factor (p−1, p²−1 even for odd p) — classical',
    # --- rad shares prime support with n ---
    ckey('n','rad',2):     'n≡rad (mod 2): rad(n) has same prime set ⇒ 2|n ⟺ 2|rad — classical (definitional support)',
    # --- λ is always ±1 (odd) ---
    ckey('lam','one',2):   'λ≡1 (mod 2): λ(n)=±1 is always odd ⇒ ≡1 — classical/trivial',
    # --- pure algebraic tautology: (Ω+ω)−(Ω−ω)=2ω ≡ 0 (mod 2) always ---
    ckey('OmMom','OmPom',2): '(Ω+ω)≡(Ω−ω) (mod 2): difference =2ω ≡0 — ALGEBRAIC TAUTOLOGY (not number-theoretic)',
}

# constant-residue classical facts: f(n) ≡ c (mod m)  ∀n (optionally for n≥n0)
KNOWN_CONST = {
    ('lam', 1, 2):  'λ(n)=±1 ⇒ λ≡1 (mod 2) ∀n (λ always odd) — trivial/definitional',
    ('mu',  None, 2): None,  # μ takes 0 too, no single constant
    ('phi', 0, 2):  'φ(n) even ∀n≥3 (φ≡0 mod2 fails only n=1,2) — classical (Euler)',
    ('J2',  0, 2):  'J₂(n) even ∀n≥2 — classical (Jordan totient, J₂=n²∏(1−p⁻²))',
}

# ---------------------------------------------------------------------------
# SEARCH 1 — constant-residue laws:  f(n) ≡ c (mod m)  for ALL n in [2,N]
# (n≥2 to skip the n=1 unit which trivially has fixed values across the board)
# ---------------------------------------------------------------------------
const_hits = []   # (fk, m, c, n0)  where law holds for all n≥n0 (n0 in {1,2})
for fk in ALLKEYS:
    a = ARR[fk]
    for m in MODS:
        for n0 in (1, 2):
            c0 = a[n0] % m
            if all((a[n] % m == c0) for n in range(n0, N+1)):
                # only record the strongest (smallest n0) once
                const_hits.append((fk, m, c0, n0))
                break

# ---------------------------------------------------------------------------
# SEARCH 2 — pairwise congruences:  f(n) ≡ g(n) (mod m)  for ALL n in [2,N]
# (symmetric; skip f==g which is the f≡f tautology)
# ---------------------------------------------------------------------------
pair_hits = []   # (fk, gk, m, n0)
for fk, gk in itertools.combinations(ALLKEYS, 2):
    af_ = ARR[fk]; ag = ARR[gk]
    for m in MODS:
        for n0 in (1, 2):
            if all(((af_[n] - ag[n]) % m == 0) for n in range(n0, N+1)):
                pair_hits.append((fk, gk, m, n0))
                break

# ---------------------------------------------------------------------------
# CLASSIFY
# ---------------------------------------------------------------------------
# A constant law f≡c (mod m) is TAUTOLOGY when m divides into a structural triviality:
#   - 'one' ≡ 1 (mod m): definitional (constant function).
#   - rad ≡ 0? no. A function that is constant-1 mod m only via 'one'.
# We mark 'one' and any f whose only modulus is m where f is literally that residue by
# construction.  Everything pinned to a KNOWN_CONST entry = REDISCOVERED.  Rest = ?NOVEL?.

def classify_const(fk, m, c):
    if fk == 'one':
        return ('TAUT', f"1(n)≡1 (mod {m}) — constant function, definitional")
    if fk == 'lam' and m == 2 and c == 1:
        return ('CLASSICAL', KNOWN_CONST[('lam',1,2)])
    if fk == 'phi' and (('phi',c,m) in KNOWN_CONST):
        return ('CLASSICAL', KNOWN_CONST[('phi',c,m)])
    if fk == 'J2' and (('J2',c,m) in KNOWN_CONST):
        return ('CLASSICAL', KNOWN_CONST[('J2',c,m)])
    # ψ(n)=n∏(1+1/p): ψ even for n≥2? and φ even patterns — known.
    if fk == 'psi' and m == 2 and c == 0:
        return ('CLASSICAL', "ψ(n) even ∀n≥2 (ψ=n∏(1+p⁻¹), classical Dedekind-ψ parity)")
    if fk == 'phi' and m in (4,6,8,12) and ('phi',0,2) and c == 0:
        # φ ≡ 0 mod 4 etc. — only if truly ∀n≥n0; report as CLASSICAL extension if holds
        return ('CLASSICAL', f"φ(n)≡0 (mod {m}) — Euler-totient divisibility (classical if ∀n)")
    if fk == 'J2' and m in (3,4,6,8,9,12) and c == 0:
        return ('CLASSICAL', f"J₂(n)≡0 (mod {m}) — Jordan-totient divisibility (classical if ∀n)")
    return ('NOVEL', None)

def classify_pair(fk, gk, m):
    k = ckey(fk, gk, m)
    if k in KNOWN_PAIR:
        cite = KNOWN_PAIR[k]
        if 'TAUTOLOGY' in cite:
            return ('TAUT', cite)
        return ('CLASSICAL', cite)
    return ('NOVEL', None)

# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
print(f"=== CONGRUENCE (mod m) ∀n FRAME (N={N}) ===")
print(f"vocabulary ({len(VOCAB)}): " + ', '.join(sym[k] for k in VOCAB))
print(f"simple combos: " + ', '.join(sym[k] for k in COMBOS))
print(f"moduli m: {MODS}")
print(f"relation type: f(n) ≡ g(n) (mod m)  [CONGRUENCE — orthogonal to exact-equality frames]")
print()
print("---- SANITY GATES (must rediscover; else implementation bug) ----")
all_gates_ok = True
for name, ok in gates:
    all_gates_ok = all_gates_ok and ok
    print(f"  {name:<22} : {'PASS' if ok else 'FAIL'}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print()

print("---- SEARCH 1: constant-residue laws  f(n) ≡ c (mod m) ∀n≥n0 ----")
const_taut = []; const_classical = []; const_novel = []
for fk, m, c, n0 in sorted(const_hits, key=lambda t:(t[0], t[1])):
    kind, cite = classify_const(fk, m, c)
    s = f"{sym[fk]}(n) ≡ {c} (mod {m}){'  [n≥2]' if n0==2 else ''}"
    if kind == 'TAUT':
        const_taut.append((s, cite))
    elif kind == 'CLASSICAL':
        const_classical.append((s, cite))
    else:
        const_novel.append((fk, m, c, n0, s))
for s, c in const_classical:
    print(f"  [CLASSICAL]  {s:<28}  — {c}")
for s, c in const_taut:
    print(f"  [TAUTOLOGY]  {s:<28}  — {c}")
for fk, m, c, n0, s in const_novel:
    print(f"  [?NOVEL?]    {s:<28}  — no catalogue entry; re-verifying below")
print()

print("---- SEARCH 2: pairwise congruences  f(n) ≡ g(n) (mod m) ∀n≥n0 ----")
pair_classical = []; pair_taut = []; pair_novel = []
for fk, gk, m, n0 in sorted(pair_hits, key=lambda t:(t[0], t[1], t[2])):
    kind, cite = classify_pair(fk, gk, m)
    s = f"{sym[fk]}(n) ≡ {sym[gk]}(n) (mod {m}){'  [n≥2]' if n0==2 else ''}"
    if kind == 'CLASSICAL':
        pair_classical.append((s, cite))
    elif kind == 'TAUT':
        pair_taut.append((s, cite))
    else:
        pair_novel.append((fk, gk, m, n0, s))
for s, c in pair_classical:
    print(f"  [CLASSICAL]  {s:<30}  — {c}")
for s, c in pair_taut:
    print(f"  [TAUTOLOGY]  {s:<30}  — {c}")
for fk, gk, m, n0, s in pair_novel:
    print(f"  [?NOVEL?]    {s:<30}  — no catalogue entry; re-verifying below")
if not pair_hits:
    print("  (none)")
print()

# ---------------------------------------------------------------------------
# RE-VERIFY + HAND-CHECK every ?NOVEL? candidate, with negative control
# ---------------------------------------------------------------------------
print("---- RE-VERIFY ?NOVEL? candidates (independent eval + n=12,30 handcheck) ----")
confirmed_novel = []

def fresh_val(fk, n):
    """Recompute the function value at n FROM SCRATCH (independent of ARR cache)."""
    if fk == 'one': return 1
    if fk == 'OmMom': return af(n)['Om'] - af(n)['om']
    if fk == 'OmPom': return af(n)['Om'] + af(n)['om']
    return af(n)[fk]

# constant-residue novel
for fk, m, c, n0, s in const_novel:
    ok_all = all((fresh_val(fk, n) % m == c) for n in range(n0, N+1))
    v12 = fresh_val(fk, 12) % m; v30 = fresh_val(fk, 30) % m
    ok12 = (v12 == c); ok30 = (v30 == c)
    print(f"  {s}: ∀n[{n0},N]={ok_all} | n=12 {v12}≡{c}? {'OK' if ok12 else 'FAIL'} | "
          f"n=30 {v30}≡{c}? {'OK' if ok30 else 'FAIL'}")
    if ok_all and ok12 and ok30:
        confirmed_novel.append(('const', fk, None, m, c, s))

# pairwise novel
for fk, gk, m, n0, s in pair_novel:
    ok_all = all(((fresh_val(fk, n) - fresh_val(gk, n)) % m == 0) for n in range(n0, N+1))
    d12 = (fresh_val(fk,12) - fresh_val(gk,12)) % m
    d30 = (fresh_val(fk,30) - fresh_val(gk,30)) % m
    ok12 = (d12 == 0); ok30 = (d30 == 0)
    print(f"  {s}: ∀n[{n0},N]={ok_all} | n=12 Δ%{m}={d12} {'OK' if ok12 else 'FAIL'} | "
          f"n=30 Δ%{m}={d30} {'OK' if ok30 else 'FAIL'}")
    if ok_all and ok12 and ok30:
        confirmed_novel.append(('pair', fk, gk, m, 0, s))

if not const_novel and not pair_novel:
    print("  (no ?NOVEL? candidates — every hit is classical or tautological)")
print()

# ---------------------------------------------------------------------------
# NEGATIVE CONTROLS — near-miss congruences that MUST FAIL (proves discrimination)
# ---------------------------------------------------------------------------
print("---- NEGATIVE CONTROLS (must FAIL — proves search discriminates) ----")
# C1: τ(n) ≡ 1 (mod 2) ∀n  — FALSE (only for squares).  first counterexample = n=2.
c1 = all((ARR['tau'][n] % 2 == 1) for n in range(1, N+1))
fd1 = next((n for n in range(1,N+1) if ARR['tau'][n] % 2 != 1), None)
print(f"  τ≡1 (mod 2) ∀n ? {c1} (expect False; τ even unless square, first fail n={fd1})")
# C2: σ(n) ≡ 0 (mod 2) ∀n — FALSE (σ odd on squares/twice-squares).  first fail n=1.
c2 = all((ARR['sig'][n] % 2 == 0) for n in range(1, N+1))
fd2 = next((n for n in range(1,N+1) if ARR['sig'][n] % 2 != 0), None)
print(f"  σ≡0 (mod 2) ∀n ? {c2} (expect False; σ odd on □|2□, first fail n={fd2})")
# C3: σ(n) ≡ ψ(n) (mod 3) ∀n — FALSE (no such ∀n law).  capture first counterexample.
c3 = all(((ARR['sig'][n] - ARR['psi'][n]) % 3 == 0) for n in range(1, N+1))
fd3 = next((n for n in range(1,N+1) if (ARR['sig'][n]-ARR['psi'][n]) % 3 != 0), None)
print(f"  σ≡ψ (mod 3) ∀n ? {c3} (expect False; first fail n={fd3})")
# C4: Ω(n) ≡ ω(n) (mod 2) ∀n — FALSE (only iff squarefree).  first fail = smallest squarefull, n=4.
c4 = all(((ARR['Om'][n]-ARR['om'][n]) % 2 == 0) for n in range(1, N+1))
fd4 = next((n for n in range(1,N+1) if (ARR['Om'][n]-ARR['om'][n]) % 2 != 0), None)
print(f"  Ω≡ω (mod 2) ∀n ? {c4} (expect False; holds iff sf, first fail n={fd4})")
controls_ok = (not c1) and (not c2) and (not c3) and (not c4)
print(f"NEG_CONTROLS_ALL_FAIL_AS_EXPECTED={controls_ok}")
print()

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
print("=== SUMMARY ===")
print(f"GATES_PASSED={sum(1 for _,ok in gates if ok)}/{len(gates)}")
print(f"CONST_CLASSICAL={len(const_classical)}  CONST_TAUTOLOGY={len(const_taut)}  CONST_NOVEL_CANDIDATES={len(const_novel)}")
print(f"PAIR_CLASSICAL={len(pair_classical)}  PAIR_TAUTOLOGY={len(pair_taut)}  PAIR_NOVEL_CANDIDATES={len(pair_novel)}")
print(f"NOVEL_CONFIRMED={len(confirmed_novel)}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print(f"NEG_CONTROLS_OK={controls_ok}")
print(f"DEPLETED={'YES' if len(confirmed_novel)==0 else 'NO'}")
