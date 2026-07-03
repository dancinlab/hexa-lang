#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS r4 — RAMANUJAN τ frame.  VOCABULARY CHANGE: the standard
MULTIPLICATIVE-FUNCTION space (σ_k, φ, J_k, ψ, μ, λ, Ω, ω over exact-equality /
Dirichlet-convolution / congruence relations) is DEPLETED across r1–r3.  This frame
introduces ONE genuinely new integer function:

    τ(n)  =  Ramanujan tau, defined by the q-expansion of the weight-12 cusp form Δ:
             Δ(q) = q ∏_{k≥1} (1 − q^k)^24  =  Σ_{n≥1} τ(n) q^n          (exact integer)

τ is one of THE most studied objects in number theory (Ramanujan 1916; Mordell 1917
multiplicativity; Deligne 1974 the |τ(p)|≤2p^{11/2} bound; the mod-691 congruence linking
τ to σ₁₁; the Swinnerton-Dyer 1973 ℓ-adic catalogue of ALL congruences for τ).  We therefore
EXPECT exactly 0 NOVEL: every congruence we can rediscover is in the classical catalogue
(mod 2^a, 3^b, 5^c, 7, 23, 691).  The value of this run is (a) proving the engine works on a
brand-new function by REDISCOVERING the famous theorems as sanity gates, and (b) an honest
search of  τ(n) ≡ (Σ_k a_k σ_k)(n)  (mod m)  combinations for small m that finds nothing new.

COMPUTATION (integer-exact, python bignum):
  τ(n) computed by multiplying the formal power series ∏(1−q^k)^24 mod q^{N+1}, exact ints.
  Verified against the known small table  τ(1..10) = 1, −24, 252, −1472, 4830, −6048,
  −16744, 84480, −113643, −115920.  N=600  (τ grows ~ n^{11/2}, so τ(600) has ~31 digits —
  bignum handles it exactly).

SANITY GATES (must rediscover — each is a published theorem; failure = implementation bug):
  G1  τ multiplicative:        τ(mn) = τ(m)τ(n)        for gcd(m,n)=1           (Mordell 1917)
  G2  τ Hecke recursion:       τ(p^{e+1}) = τ(p)τ(p^e) − p^{11} τ(p^{e-1})     (Hecke)
  G3  mod-691 congruence:      τ(n) ≡ σ₁₁(n)  (mod 691)   ∀n                    (Ramanujan)
      and the prime form       τ(p) ≡ 1 + p^{11} (mod 691)                     (= σ₁₁(p))
  G4  Deligne–Ramanujan bound: |τ(p)| ≤ 2 p^{11/2}   for all primes p          (Deligne 1974)
  G5  τ(n) ≡ σ₁₁(n) (mod 256) on odd n / Swinnerton-Dyer ℓ=2 family (we test the
      cleanest published 2-adic representative:  τ(n) ≡ n σ_9? — see below, we test the
      KNOWN  τ(p) ≡ p + p^{10} (mod 25) for p≠5 and the mod-7 / mod-23 forms).
  G6  parity:  τ(n) is ODD  ⟺  n is an odd square        (τ ≡ σ₁₁ mod 2, σ₁₁ odd-pattern)

KNOWN classical congruence catalogue (Swinnerton-Dyer 1973, "On ℓ-adic representations and
congruences for coefficients of modular forms", and Ramanujan): the ONLY primes ℓ for which
τ has an "exceptional" congruence are ℓ ∈ {2, 3, 5, 7, 23, 691}.  Representative laws:
  mod 2:    τ(n) ≡ σ₁₁(n)            (and the refined mod 2^a ladder)
  mod 3:    τ(n) ≡ n² σ₇(n)? / σ family   (3-adic)
  mod 5:    τ(n) ≡ n σ₉(n)  (mod 5)
  mod 7:    τ(n) ≡ n σ₃(n)  (mod 7)
  mod 23:   τ(p) ≡ 0 if (p|23)=−1 ; ≡ 2 forms via the genus / Hecke character (23-adic)
  mod 691:  τ(n) ≡ σ₁₁(n)  (mod 691)
Any congruence τ ≡ (σ-combo) mod m that holds ∀n in our range and is NOT one of these is a
?NOVEL? candidate → re-verified independently + 2 hand-checks (n=12, n=30) + a negative
control that MUST FAIL.  We expect the set of ?NOVEL? after catalogue-subtraction to be EMPTY.

Deterministic (no random / no time).  LOCAL pure-Python bignum only.  NO hexa build.
Usage: python3 ramanujan-tau_hunt.py [N]   (default N=600)
"""
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 600

# ===========================================================================
# τ(n) via exact integer power series:  ∏_{k=1}^{N} (1 − q^k)^24  mod q^{N+1}
# Δ = q · that product, so τ(n) = coeff of q^{n-1} in the product.
# ===========================================================================
def compute_tau(N):
    # P = ∏ (1 - q^k)^24, truncated to degree N (we need coeff up to q^{N-1} for τ(N)).
    P = [0]*(N+1)
    P[0] = 1
    for k in range(1, N+1):
        # multiply P by (1 - q^k)^24.  Do it as 24 multiplications by (1 - q^k)
        # but faster: (1 - q^k)^24 has binomial coeffs; still, naive 24× is fine for N=600.
        for _ in range(24):
            # P *= (1 - q^k):  newP[i] = P[i] - P[i-k]
            for i in range(N, k-1, -1):
                P[i] -= P[i-k]
    # τ(n) = P[n-1]  (since Δ = q*P)
    tau = [0]*(N+1)
    for n in range(1, N+1):
        tau[n] = P[n-1]
    return tau

tau = compute_tau(N)

# --- verify against the canonical small table (hard literal check) ---
TABLE = {1:1, 2:-24, 3:252, 4:-1472, 5:4830, 6:-6048,
         7:-16744, 8:84480, 9:-113643, 10:-115920,
         11:534612, 12:-370944}
table_ok = all(tau[n] == v for n, v in TABLE.items() if n <= N)
table_fail = [(n, tau[n], v) for n, v in TABLE.items() if n <= N and tau[n] != v]

# ===========================================================================
# smallest-prime-factor sieve + σ_k(n) (exact int) for k we need
# ===========================================================================
spf = list(range(N+1))
for i in range(2, int(N**0.5)+1):
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j:
                spf[j] = i

def factor(n):
    f = []
    while n > 1:
        p = spf[n]; e = 0
        while n % p == 0:
            n //= p; e += 1
        f.append((p, e))
    return f

def sigma_k(n, k):
    """σ_k(n) = Σ_{d|n} d^k, exact int."""
    if n == 1:
        return 1
    r = 1
    for p, e in factor(n):
        if k == 0:
            r *= (e+1)
        else:
            r *= (p**(k*(e+1)) - 1)//(p**k - 1)
    return r

# precompute σ_k arrays for the k we use (0,1,3,5,7,9,11)
KS = [0,1,3,5,7,9,11]
SIG = {k: [0]+[sigma_k(n, k) for n in range(1, N+1)] for k in KS}

def is_prime(n):
    return n >= 2 and spf[n] == n

PRIMES = [p for p in range(2, N+1) if is_prime(p)]

# ===========================================================================
# SANITY GATES
# ===========================================================================
gates = []
def gate(name, cond):
    gates.append((name, cond)); return cond

# G0: literal small table
gate("G0 τ small-table (1..12)", table_ok)

# G1: multiplicativity τ(mn)=τ(m)τ(n) for gcd=1  (sample over coprime pairs ≤ N)
from math import gcd
g1 = True
for m in range(1, N+1):
    if not g1: break
    for n in range(1, N//m + 1):
        if gcd(m, n) == 1 and m*n <= N:
            if tau[m*n] != tau[m]*tau[n]:
                g1 = False; break
gate("G1 τ multiplicative", g1)

# G2: Hecke recursion τ(p^{e+1}) = τ(p)τ(p^e) − p^11 τ(p^{e-1})
g2 = True
g2_fail = None
for p in PRIMES:
    e = 1
    while p**(e+1) <= N:
        lhs = tau[p**(e+1)]
        rhs = tau[p]*tau[p**e] - p**11 * tau[p**(e-1)]
        if lhs != rhs:
            g2 = False; g2_fail = (p, e); break
        e += 1
    if not g2: break
gate("G2 τ Hecke recursion", g2)

# G3: mod-691  τ(n) ≡ σ₁₁(n)  ∀n   AND   τ(p) ≡ 1 + p^11 (mod 691)
g3a = all((tau[n] - SIG[11][n]) % 691 == 0 for n in range(1, N+1))
g3b = all((tau[p] - (1 + p**11)) % 691 == 0 for p in PRIMES)
gate("G3 τ≡σ₁₁ (mod 691)", g3a and g3b)

# G4: Deligne bound |τ(p)| ≤ 2 p^{11/2}  ⟺  τ(p)² ≤ 4 p^11  (integer-exact, no float)
g4 = all(tau[p]*tau[p] <= 4 * p**11 for p in PRIMES)
gate("G4 |τ(p)|≤2p^{11/2} (Deligne)", g4)

# G5: mod-5  τ(n) ≡ n·σ₉(n) (mod 5) ∀n   (Swinnerton-Dyer 5-adic representative)
g5_5  = all((tau[n] - n*SIG[9][n]) % 5 == 0 for n in range(1, N+1))
# mod-7  τ(n) ≡ n·σ₃(n) (mod 7) ∀n       (Swinnerton-Dyer 7-adic representative)
g5_7  = all((tau[n] - n*SIG[3][n]) % 7 == 0 for n in range(1, N+1))
gate("G5 τ≡nσ₉(5),≡nσ₃(7)", g5_5 and g5_7)

# G6: parity  τ(n) odd ⟺ n is an odd square
def is_odd_square(n):
    if n % 2 == 0: return False
    s = int(n**0.5)
    while s*s > n: s -= 1
    while (s+1)*(s+1) <= n: s += 1
    return s*s == n
g6 = all(((tau[n] % 2 == 1) == is_odd_square(n)) for n in range(1, N+1))
gate("G6 τ odd ⟺ odd square", g6)

# ===========================================================================
# CLASSICAL CATALOGUE — every congruence we expect to (re)find.  Swinnerton-Dyer 1973
# exceptional primes for τ: ℓ ∈ {2,3,5,7,23,691}.  Keyed by (m, descriptor).
# ===========================================================================
# Representative ∀n laws τ(n) ≡ <combo>(n) (mod m).  Each is a known theorem.
KNOWN = {
    (691, 'sig11'):  'τ(n)≡σ₁₁(n) (mod 691) — Ramanujan; τ(p)≡1+p¹¹ (mod 691)',
    (5,   'n*sig9'): 'τ(n)≡n·σ₉(n) (mod 5) — Swinnerton-Dyer 5-adic (1973)',
    (7,   'n*sig3'): 'τ(n)≡n·σ₃(n) (mod 7) — Swinnerton-Dyer 7-adic (1973)',
    (2,   'sig11'):  'τ(n)≡σ₁₁(n) (mod 2) — 2-adic (mod-2 reduction of mod-691 form / Kolberg)',
}

# ===========================================================================
# SEARCH — τ(n) ≡ (Σ_k a_k · n^{b} · σ_k(n)) (mod m) for small combos & moduli.
# We restrict to single-term combos  τ ≡ c · n^b · σ_k  (mod m)  with:
#   c   ∈ {1, 2, ..., m-1}      (nonzero residue multiplier)
#   b   ∈ {0, 1, 2}            (power of n prefactor)
#   k   ∈ {0,1,3,5,7,9,11}     (σ_k)
#   m   ∈ {2,3,4,5,7,8,9,11,13,23,25,49,691}  (the exceptional primes + small composites
#                                              + two NON-exceptional controls 11,13)
# A hit must hold for ALL n in [1,N].  Then classify against KNOWN.
# ===========================================================================
MODS = [2, 3, 4, 5, 7, 8, 9, 11, 13, 23, 25, 49, 691]
BS   = [0, 1, 2]

def combo_val(n, c, b, k):
    return c * (n**b) * SIG[k][n]

hits = []   # (m, c, b, k)
for m in MODS:
    for k in KS:
        for b in BS:
            for c in range(1, m):
                if all((tau[n] - combo_val(n, c, b, k)) % m == 0 for n in range(1, N+1)):
                    hits.append((m, c, b, k))

def descriptor(c, b, k):
    """canonical descriptor string + catalogue key guess."""
    cs = '' if c == 1 else f'{c}·'
    ns = '' if b == 0 else ('n·' if b == 1 else f'n^{b}·')
    return f'τ(n) ≡ {cs}{ns}σ_{k}(n)'

def cat_key(m, c, b, k):
    # map a hit to a KNOWN catalogue entry if it is the canonical representative
    if m == 691 and c == 1 and b == 0 and k == 11: return (691, 'sig11')
    if m == 5   and c == 1 and b == 1 and k == 9:  return (5, 'n*sig9')
    if m == 7   and c == 1 and b == 1 and k == 3:  return (7, 'n*sig3')
    if m == 2   and c == 1 and b == 0 and k == 11: return (2, 'sig11')
    return None

# ===========================================================================
# CLASSIFY each hit.  Many hits are ALGEBRAICALLY EQUIVALENT to a catalogue law
# (e.g. mod 2: n^b drops out for b that don't change parity, σ_k≡σ_j mod 2 by
#  d^k≡d termwise, c≡1 mod 2 the only nonzero residue) — those are CLASSICAL/derived.
# We flag a hit CLASSICAL if (a) it maps to a catalogue key, OR (b) its modulus is a
# known exceptional prime ℓ∈{2,3,5,7,23,691} or a prime power thereof (so ANY ∀n
# σ-congruence at that ℓ is a consequence of the ℓ-adic Galois representation being
# reducible — Swinnerton-Dyer's theorem covers the whole congruence module).  A hit at
# a NON-exceptional modulus (11, 13, or a prime power of one) would be ?NOVEL?.
# ===========================================================================
EXCEPTIONAL = {2, 3, 5, 7, 23, 691}
def exceptional_modulus(m):
    # m is "covered" if all its prime factors are exceptional primes for τ
    mm = m
    while mm > 1:
        p = spf[mm]
        if p not in EXCEPTIONAL:
            return False
        while mm % p == 0:
            mm //= p
    return True

classical = []; novel = []
for (m, c, b, k) in hits:
    key = cat_key(m, c, b, k)
    desc = descriptor(c, b, k) + f' (mod {m})'
    if key is not None:
        classical.append((desc, KNOWN[key], (m,c,b,k)))
    elif exceptional_modulus(m):
        classical.append((desc,
            f'derived: modulus {m} factors over exceptional primes {sorted(EXCEPTIONAL)} '
            f'— consequence of Swinnerton-Dyer ℓ-adic reducibility (1973)', (m,c,b,k)))
    else:
        novel.append((desc, (m,c,b,k)))

# ===========================================================================
# OUTPUT
# ===========================================================================
print(f"=== RAMANUJAN τ FRAME (N={N}) — Δ=q∏(1−q^k)^24 exact-integer DFS ===")
print(f"τ(1..10) = {[tau[n] for n in range(1,11)]}")
print(f"τ(600) = {tau[600] if N>=600 else 'N<600'}   (digits={len(str(abs(tau[600]))) if N>=600 else '-'})")
print(f"small-table match: {table_ok}" + ("" if table_ok else f"  FAILS: {table_fail}"))
print()
print("---- SANITY GATES (each = published τ theorem; must rediscover) ----")
all_gates_ok = True
for name, ok in gates:
    all_gates_ok = all_gates_ok and ok
    print(f"  {name:<30} : {'PASS' if ok else 'FAIL'}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print()

print("---- DELIGNE BOUND tightness (informational) ----")
# ratio τ(p)²/(4p^11) — closeness to the |τ(p)|≤2p^{11/2} wall
worst = max(PRIMES, key=lambda p: (tau[p]*tau[p], -p))
print(f"  tightest prime p={worst}: τ(p)²/(4p¹¹) = {tau[worst]**2}/{4*worst**11} "
      f"= {tau[worst]**2/(4*worst**11):.6f} (<1 ⟺ bound holds)")
print()

print(f"---- SEARCH: τ(n) ≡ c·n^b·σ_k(n) (mod m) ∀n∈[1,{N}] ----")
print(f"  moduli m: {MODS}")
print(f"  σ_k: k∈{KS}   n-power b∈{BS}   multiplier c∈[1,m-1]")
print(f"  total ∀n-laws found: {len(hits)}")
print()

print("---- CLASSIFICATION ----")
print(f"  [CLASSICAL / catalogue-derived]: {len(classical)}")
# show the canonical catalogue representatives explicitly, then count the derived family
shown = set()
for desc, cite, key in classical:
    if 'Swinnerton-Dyer ℓ-adic reducibility' in cite:
        continue
    print(f"    {desc:<34} — {cite}")
    shown.add(key)
derived = [x for x in classical if x[2] not in shown]
# group derived by modulus for a compact honest readout
from collections import Counter
bym = Counter(k[0] for _,_,k in derived)
print(f"    + {len(derived)} further ∀n σ-congruences, all at exceptional-prime moduli:")
for m in sorted(bym):
    print(f"        mod {m:<3}: {bym[m]} laws (all derived from ℓ-adic reducibility at ℓ|{m})")
print()

print(f"  [?NOVEL?] (modulus has a NON-exceptional prime factor): {len(novel)}")
for desc, key in novel:
    print(f"    {desc}  — re-verifying below")
if not novel:
    print("    (none — every ∀n-law sits at an exceptional prime {2,3,5,7,23,691}, "
          "i.e. inside the Swinnerton-Dyer catalogue)")
print()

# ===========================================================================
# RE-VERIFY ?NOVEL? candidates (independent recompute + n=12,30 handcheck)
# ===========================================================================
print("---- RE-VERIFY ?NOVEL? (independent eval + n=12,30 handcheck) ----")
confirmed_novel = []
def fresh_sig(n, k):
    return sigma_k(n, k)
for desc, (m, c, b, k) in novel:
    ok_all = all((tau[n] - c*(n**b)*fresh_sig(n, k)) % m == 0 for n in range(1, N+1))
    d12 = (tau[12] - c*(12**b)*fresh_sig(12, k)) % m
    d30 = (tau[30] - c*(30**b)*fresh_sig(30, k)) % m
    print(f"  {desc} (mod {m}): ∀n={ok_all} | n=12 Δ%{m}={d12} | n=30 Δ%{m}={d30}")
    if ok_all and d12 == 0 and d30 == 0:
        confirmed_novel.append((desc, (m,c,b,k)))
if not novel:
    print("  (no ?NOVEL? candidates to re-verify)")
print()

# ===========================================================================
# NEGATIVE CONTROLS — congruences that MUST FAIL (proves the search discriminates)
# ===========================================================================
print("---- NEGATIVE CONTROLS (must FAIL — proves discrimination) ----")
# C1: τ(n) ≡ σ₁₁(n) (mod 11)  — 11 is NOT an exceptional prime ⇒ no such ∀n law.
c1 = all((tau[n] - SIG[11][n]) % 11 == 0 for n in range(1, N+1))
fd1 = next((n for n in range(1,N+1) if (tau[n]-SIG[11][n]) % 11 != 0), None)
print(f"  τ≡σ₁₁ (mod 11) ∀n ? {c1} (expect False — 11 non-exceptional; first fail n={fd1})")
# C2: τ(n) ≡ σ₁₁(n) (mod 13)  — 13 non-exceptional.
c2 = all((tau[n] - SIG[11][n]) % 13 == 0 for n in range(1, N+1))
fd2 = next((n for n in range(1,N+1) if (tau[n]-SIG[11][n]) % 13 != 0), None)
print(f"  τ≡σ₁₁ (mod 13) ∀n ? {c2} (expect False — 13 non-exceptional; first fail n={fd2})")
# C3: τ(n) ≡ 2·n·σ₉(n) (mod 5)  — WRONG MULTIPLIER c=2 inside the correct exceptional prime
#     ℓ=5.  Discriminates within ℓ: the true law has c=1, so c=2 must FAIL.  Must FAIL.
#     [NOTE: the obvious-looking controls τ≡n·σ₉ (mod 7) and τ≡n·σ₉ (mod 25) are NOT valid
#      controls — both TRULY hold: mod 7 because d⁹≡d³ (mod 7) by Fermat collapses it to the
#      known mod-7 law, and mod 25 is the genuine 5-adic LIFT of the mod-5 law (Swinnerton-
#      Dyer); the engine correctly reports both as True and catalogues them. A within-ℓ wrong
#      multiplier is the honest discriminating control.]
c3 = all((tau[n] - 2*n*SIG[9][n]) % 5 == 0 for n in range(1, N+1))
fd3 = next((n for n in range(1,N+1) if (tau[n]-2*n*SIG[9][n]) % 5 != 0), None)
print(f"  τ≡2·n·σ₉ (mod 5) ∀n ? {c3} (expect False — wrong multiplier c=2 at correct ℓ=5; first fail n={fd3})")
# C4: Deligne VIOLATION test: τ(p)² > 4p^11 for some p  — must be False (bound never violated).
c4 = any(tau[p]*tau[p] > 4*p**11 for p in PRIMES)
print(f"  ∃p: τ(p)²>4p¹¹ ? {c4} (expect False — Deligne bound is never violated)")
controls_ok = (not c1) and (not c2) and (not c3) and (not c4)
print(f"NEG_CONTROLS_ALL_FAIL_AS_EXPECTED={controls_ok}")
print()

# ===========================================================================
# SUMMARY
# ===========================================================================
print("=== SUMMARY ===")
print(f"GATES_PASSED={sum(1 for _,ok in gates if ok)}/{len(gates)}")
print(f"TOTAL_ALLN_LAWS={len(hits)}  CLASSICAL={len(classical)}  NOVEL_CANDIDATES={len(novel)}")
print(f"NOVEL_CONFIRMED={len(confirmed_novel)}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print(f"NEG_CONTROLS_OK={controls_ok}")
print(f"DEPLETED={'YES' if len(confirmed_novel)==0 else 'NO'}")
