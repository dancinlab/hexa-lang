#!/usr/bin/env python3
"""ATLAS r4 — NON-MULTIPLICATIVE integer function: r₂(n) sum-of-two-squares.

VOCABULARY CHANGE (the standard multiplicative-function ring is DEPLETED across
r1-r3 — product/sum/convolution/divisor-sum/ratio-power/mixed all measured-closed,
see frame-expansion-dfs-2026-06-25.md). r₂ is NOT multiplicative (r₂/4 is), so it
lives OUTSIDE the closed multiplicative space and is a genuine new frame.

FRAME:
    r₂(n) = #{(a,b)∈ℤ²: a²+b²=n}   (sign-counted, ordered pairs)

Computed EXACTLY to N (default 20000) by brute force: for each n, count integer
(a,b) with a²+b²=n by iterating a over [-⌊√n⌋,⌊√n⌋] and testing whether n−a² is a
perfect square (then ±b). Pure Python bignum, deterministic, integer-exact.

SANITY GATES (MUST rediscover — proves the engine works on a new function class):
  G1  Jacobi:  r₂(n) = 4·Σ_{d|n} χ₄(d) = 4·(d₁(n) − d₃(n))
               χ₄(d)=+1 if d≡1(4), −1 if d≡3(4), 0 if d even.
               d₁,d₃ = #divisors ≡1, ≡3 (mod 4).
  G2  Zero criterion: r₂(n)=0  ⟺  some prime p≡3(mod4) divides n to ODD power.
  G3  Non-multiplicativity: r₂ itself is NOT multiplicative (∃ coprime m,k:
        r₂(mk) ≠ r₂(m)r₂(k)), but g(n):=r₂(n)/4 IS multiplicative on the n with
        r₂>0 — exhibit BOTH.
  G4  r₂(n) ≡ 0 (mod 4) for n≥1 (every rep comes in a 4-fold sign orbit when a,b≠0,
        and the on-axis reps also group in 4s). Equivalently d₁−d₃ counts.

SEARCH (∀n∈[1,N], break on first fail = bounded-universal EVIDENCE, not a proof):
  S1  r₂(n) vs 4·(standard divisor-count restricted-residue) identities.
  S2  r₂(n) = 4·Σ_{d|n} f(d) for standard f (recover χ₄; test τ,σ,μ,id,1,λ as
        negative controls — these MUST fail).
  S3  Σ_{k=1}^{n} r₂(k) ≈ πn (Gauss circle) — recover the average order (NOT an
        exact ∀n identity; reported as asymptotic, not folded).
  S4  r₂(n) vs 4·χ₄-Dirichlet-series-coefficient combos with other mult fns.
  S5  Local identity on prime-power / special-n classes.
  S6  Mod-m congruences r₂(n)≡c (mod m) on residue classes of n.

NEGATIVE CONTROLS (must FAIL — proves the sweep has resolution):
  C1  r₂(n) = 4·τ(n)        [fails: τ counts ALL divisors, not χ₄-weighted]
  C2  r₂ multiplicative      [fails on coprime split]
  C3  r₂(n) = 4·(d₁(n))      [fails: missing −d₃]
  C4  r₂(n) = 8·χ₄-sum       [fails: wrong constant]

NOVEL = any ∀n r₂-identity NOT in the Jacobi/Gauss classical catalog. EXPECT 0 —
r₂ is among the most-studied functions in number theory (Jacobi 1834, Gauss).
RUTHLESS: classical rediscovery is cited, NOT claimed novel. No fabricated novelty.

Usage:  python3 r2-sum-two-squares_hunt.py [N]
"""
import sys, math
from math import isqrt

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000

# ---------------------------------------------------------------------------
# r₂(n) by EXACT brute force (sign-counted ordered integer pairs a²+b²=n).
# ---------------------------------------------------------------------------
def r2_brute(n):
    if n == 0:
        return 1  # only (0,0)
    cnt = 0
    s = isqrt(n)
    for a in range(-s, s + 1):
        rem = n - a * a
        if rem < 0:
            continue
        b = isqrt(rem)
        if b * b == rem:
            cnt += 1 if b == 0 else 2   # ±b (b=0 once)
    return cnt

R2 = [0] * (N + 1)
for n in range(1, N + 1):
    R2[n] = r2_brute(n)

# ---------------------------------------------------------------------------
# smallest-prime-factor sieve → factorizations → standard arithmetic functions.
# ---------------------------------------------------------------------------
spf = list(range(N + 1))
for i in range(2, isqrt(N) + 1):
    if spf[i] == i:
        for j in range(i * i, N + 1, i):
            if spf[j] == j:
                spf[j] = i

def factor(n):
    f = {}
    while n > 1:
        p = spf[n]; e = 0
        while n % p == 0:
            n //= p; e += 1
        f[p] = e
    return f

# divisors of n (sorted), built from factorization
def divisors(n):
    f = factor(n)
    divs = [1]
    for p, e in f.items():
        divs = [d * p**k for d in divs for k in range(e + 1)]
    return divs

# χ₄ non-principal character mod 4
def chi4(d):
    r = d & 3
    if r == 1: return 1
    if r == 3: return -1
    return 0  # even

# Jacobi RHS pieces
def d1_minus_d3(n):
    s = 0
    for d in divisors(n):
        s += chi4(d)
    return s

def d1(n):
    return sum(1 for d in divisors(n) if (d & 3) == 1)
def d3(n):
    return sum(1 for d in divisors(n) if (d & 3) == 3)

# standard mult functions for negative-control divisor sums
def tau(n):  return len(divisors(n))
def sigma(n):return sum(divisors(n))
def mu(n):
    f = factor(n)
    if any(e > 1 for e in f.values()): return 0
    return -1 if (len(f) & 1) else 1
def lam(n):  # Liouville
    return -1 if (sum(factor(n).values()) & 1) else 1

# ---------------------------------------------------------------------------
# bounded-universal helper
# ---------------------------------------------------------------------------
def universal(pred, lo=1, hi=None):
    hi = N if hi is None else hi
    for n in range(lo, hi + 1):
        if not pred(n):
            return (False, n)
    return (True, None)

OUT = []
def p(s=""):
    OUT.append(s)

p(f"=== r₂ SUM-OF-TWO-SQUARES HUNT (r4 · NON-MULTIPLICATIVE) · N={N} ===")
p(f"r₂(n)=#{{(a,b)∈ℤ²:a²+b²=n}} brute-force exact · ∀n∈[1,{N}] integer-exact")
p("")

# ===========================================================================
# SANITY GATES
# ===========================================================================
gates = []   # (name, ok, detail)

# G1 — Jacobi r₂(n) = 4(d₁−d₃)
ok, ff = universal(lambda n: R2[n] == 4 * d1_minus_d3(n))
gates.append(("G1 Jacobi  r₂=4(d₁−d₃)", ok, "" if ok else f"FAIL@n={ff}"))

# G2 — zero criterion: r₂=0 ⟺ ∃ p≡3(4) | n with ODD exponent
def has_3mod4_odd(n):
    for q, e in factor(n).items():
        if (q & 3) == 3 and (e & 1):
            return True
    return False
ok, ff = universal(lambda n: (R2[n] == 0) == has_3mod4_odd(n))
gates.append(("G2 zero ⟺ p≡3(4)^odd", ok, "" if ok else f"FAIL@n={ff}"))

# G3 — non-multiplicativity of r₂ (exhibit a coprime counterexample) +
#       multiplicativity of g=r₂/4 on r₂>0 support.
nonmult_witness = None
for m in range(2, 200):
    for k in range(2, 200):
        if math.gcd(m, k) == 1 and m * k <= N:
            if R2[m * k] != R2[m] * R2[k]:
                nonmult_witness = (m, k, R2[m * k], R2[m], R2[k])
                break
    if nonmult_witness: break
g3a = nonmult_witness is not None  # we WANT a witness (non-mult is true)
# g=r₂/4 multiplicative on coprime pairs where both r₂>0
g3b_ok = True; g3b_ff = None
for m in range(1, 300):
    if R2[m] == 0: continue
    for k in range(1, 300):
        if R2[k] == 0 or m * k > N or math.gcd(m, k) != 1: continue
        gm, gk, gmk = R2[m] // 4, R2[k] // 4, R2[m * k] // 4
        if gmk != gm * gk:
            g3b_ok = False; g3b_ff = (m, k); break
    if not g3b_ok: break
gates.append(("G3a r₂ NON-multiplicative (witness exists)", g3a,
              "" if g3a else "no witness?!"))
gates.append(("G3b (r₂/4) multiplicative on coprime support", g3b_ok,
              "" if g3b_ok else f"FAIL@{g3b_ff}"))

# G4 — r₂(n) ≡ 0 (mod 4) for n≥1
ok, ff = universal(lambda n: R2[n] % 4 == 0)
gates.append(("G4 r₂(n)≡0 (mod 4)", ok, "" if ok else f"FAIL@n={ff}"))

p("SANITY GATES (rediscover classical = proof engine works on new fn class):")
all_gates_pass = True
for name, ok, det in gates:
    tag = "PASS" if ok else f"**FAIL** {det}"
    if not ok: all_gates_pass = False
    p(f"  [{ 'PASS' if ok else 'FAIL'}] {name:46s} {('' if ok else det)}")
p("")
if nonmult_witness:
    m, k, rmk, rm, rk = nonmult_witness
    p(f"  G3 non-mult witness: r₂({m}·{k})=r₂({m*k})={rmk} ≠ r₂({m})·r₂({k})={rm}·{rk}={rm*rk}")
p("")

# ===========================================================================
# S2 — recover χ₄ as the UNIQUE divisor-sum kernel giving r₂; standard fns FAIL
# ===========================================================================
p("S2 · r₂(n) = 4·Σ_{d|n} f(d) — which kernel f works? (χ₄ should; others fail)")
kernels = {
    "χ₄ (≡1→+1,≡3→−1,even→0)": chi4,
    "1 (constant) → 4τ":        lambda d: 1,
    "id → 4σ":                  lambda d: d,
    "μ (Möbius)":               lambda d: mu(d),
    "λ (Liouville)":            lambda d: lam(d),
    "[d odd] (1 if odd)":       lambda d: 1 if (d & 1) else 0,
}
s2_results = []
for name, f in kernels.items():
    ok, ff = universal(lambda n, f=f: R2[n] == 4 * sum(f(d) for d in divisors(n)))
    s2_results.append((name, ok, ff))
    p(f"  {name:30s} : {'UNIVERSAL-in-[1,N]' if ok else f'FAILS@n={ff}'}")
p("")

# ===========================================================================
# S1/C — direct standard-function comparisons + negative controls
# ===========================================================================
p("S1/C · direct comparisons & NEGATIVE CONTROLS (controls MUST fail):")
direct = [
    ("C1  r₂=4·τ",            lambda n: R2[n] == 4 * tau(n)),
    ("C3  r₂=4·d₁",           lambda n: R2[n] == 4 * d1(n)),
    ("C4  r₂=8·(d₁−d₃)",      lambda n: R2[n] == 8 * d1_minus_d3(n)),
    ("    r₂=4·(d₁−d₃) [G1]", lambda n: R2[n] == 4 * d1_minus_d3(n)),
    ("    r₂=4·d₁−4·d₃",      lambda n: R2[n] == 4 * d1(n) - 4 * d3(n)),
]
for name, pred in direct:
    ok, ff = universal(pred)
    p(f"  {name:26s} : {'UNIVERSAL-in-[1,N]' if ok else f'FAILS@n={ff}'}")
p("")

# C2 — r₂ multiplicative as a global control (must fail; reuse G3 witness)
p(f"  C2  r₂ multiplicative      : "
  f"{'(unexpected!) holds' if nonmult_witness is None else 'FAILS (non-mult, witness above)'}")
p("")

# ===========================================================================
# S3 — Gauss circle / average order (asymptotic — NOT an exact ∀n identity)
# ===========================================================================
p("S3 · Gauss circle problem — Σ_{k=0}^{n} r₂(k) ~ π·n (average order, asymptotic):")
cum = 1  # include r₂(0)=1 (the point (0,0)) for the lattice-count interpretation
checks = []
for M in [100, 1000, 5000, 10000, 20000]:
    if M > N: break
    cum_M = 1 + sum(R2[k] for k in range(1, M + 1))   # lattice points in disk radius √M
    ratio = cum_M / M
    checks.append((M, cum_M, ratio))
    p(f"  M={M:6d}  Σr₂(0..M)={cum_M:9d}  /M = {ratio:.6f}  (→ π≈{math.pi:.6f})")
p("  [asymptotic average order — NOT folded as an exact ∀n identity]")
p("")

# ===========================================================================
# S6 — mod-m congruences on residue classes of n (Ramanujan-style search)
# ===========================================================================
# r₂(n)/4 = d₁−d₃. Search: does (r₂(n)/4) mod m depend ONLY on n mod M for small m,M?
# A genuine ∀n congruence would be: r₂(n) ≡ c (mod m) for all n ≡ r (mod M).
p("S6 · mod-m congruence search: r₂(n) ≡ const (mod m) on n≡r (mod M)?")
cong_found = []
for m in range(2, 9):
    for M in range(2, 13):
        for r in range(M):
            vals = set()
            ok = True
            cnt = 0
            for n in range(1, N + 1):
                if n % M == r:
                    vals.add(R2[n] % m)
                    cnt += 1
                    if len(vals) > 1:
                        ok = False
                        break
            if ok and cnt >= 5 and len(vals) == 1:
                c = next(iter(vals))
                # filter trivial: r₂≡0 (mod 4) always (G4) → c=0,m|4 on EVERY class is trivial
                trivial = (m in (2, 4) and c == 0)  # implied by G4
                cong_found.append((m, M, r, c, cnt, trivial))
# --- REDUCTION FILTER: classify each non-G4 congruence by its CLASSICAL cause ---
# Mechanism A (zero-class / G2 Gauss): r₂ ≡ 0 IDENTICALLY on the class because the
#   residue forces a prime p≡3(mod4) to odd power. Then r₂≡0 (mod m) ∀m is trivial.
# Mechanism B (mod-8 refinement, classical Jacobi corollary): r₂(n)≡4 (mod 8) ⟺ n is
#   a square or twice a square; so on any class containing NO square & NO 2·square,
#   r₂≡0 (mod 8) is forced. Verified ∀n∈[1,N] below.
def is_sq(n):
    r = isqrt(n); return r * r == n
def is_twice_sq(n):
    return (n & 1) == 0 and is_sq(n >> 1)

# verify the classical mod-8 refinement holds (used by Mechanism B)
mod8_refine_ok, mod8_ff = universal(
    lambda n: (R2[n] % 8 == 4) == (is_sq(n) or is_twice_sq(n)))

def classify_cong(m, M, r):
    """return ('A'|'B'|'NOVEL', note) — which classical mechanism reduces it."""
    cls = [n for n in range(1, N + 1) if n % M == r]
    if all(R2[n] == 0 for n in cls):
        return ('A', "r₂≡0 identically (Gauss zero-criterion G2)")
    # Mechanism B: all nonzero ≡0 mod 8 AND class has no square / no 2·square
    if m % 8 == 0 or m == 8:
        if not any(is_sq(n) or is_twice_sq(n) for n in cls):
            return ('B', "no square/2·square in class → classical r₂≡0(mod8)")
    # mod m | 8 but value-set could still be B if reduces; general:
    if all(is_sq(n) == False and is_twice_sq(n) == False for n in cls):
        # nonzero r₂ are all multiples of 8 here ⇒ ≡0 mod m when m|8
        if 8 % m == 0:
            return ('B', "nonzero r₂∈8ℤ (no sq/2sq) → mod-8 refinement")
    return ('NOVEL', "not reduced by G2 or mod-8 refinement")

nontriv_cong = [t for t in cong_found if not t[5]]
reduced_A = reduced_B = genuinely_novel = 0
novel_cong = []
for m, M, r, c, cnt, _ in nontriv_cong:
    kind, note = classify_cong(m, M, r)
    if kind == 'A':   reduced_A += 1
    elif kind == 'B': reduced_B += 1
    else:
        genuinely_novel += 1
        novel_cong.append((m, M, r, c, cnt, note))
p(f"  total non-G4 'universal' congruence classes flagged: {len(nontriv_cong)}")
p(f"  → reduced to Mechanism A (Gauss zero-criterion, r₂≡0 identically): {reduced_A}")
p(f"  → reduced to Mechanism B (classical mod-8 refinement, no sq/2·sq): {reduced_B}")
p(f"  → GENUINELY NOVEL (unreduced): {genuinely_novel}")
for m, M, r, c, cnt, note in novel_cong[:40]:
    p(f"      r₂(n)≡{c}(mod {m}) on n≡{r}(mod {M})  — {note}")
p(f"  [classical mod-8 refinement r₂≡4(mod8)⟺n=sq or 2·sq verified ∀n∈[1,N]: "
  f"{'HOLDS' if mod8_refine_ok else f'FAILS@{mod8_ff}'}]")
p(f"  trivial-from-G4 classes (r₂≡0 mod 2/4, expected): "
  f"{sum(1 for t in cong_found if t[5])}")
p("")

# ===========================================================================
# S5 — special-n local identities (prime-power / 2^a / p≡1 mod 4)
# ===========================================================================
p("S5 · special-class local identities (local, NOT ∀n — recovering known forms):")
# r₂(2^a) = 4 for all a≥0  (classical: 2 is special, χ₄-sum telescopes)
ok2 = True; f2 = None
a = 0
while 2**a <= N:
    if R2[2**a] != 4:
        ok2 = False; f2 = 2**a; break
    a += 1
p(f"  r₂(2^a)=4 ∀a (2^a≤N)            : {'HOLDS' if ok2 else f'FAILS@{f2}'}")
# r₂(p)=8 for prime p≡1 mod 4 ; r₂(p)=0 for prime p≡3 mod 4
okp1 = True; okp3 = True; fp1 = fp3 = None
for n in range(2, N + 1):
    if len(factor(n)) == 1 and factor(n)[spf[n]] == 1:  # n prime
        if (n & 3) == 1 and R2[n] != 8:
            okp1 = False; fp1 = n
        if (n & 3) == 3 and R2[n] != 0:
            okp3 = False; fp3 = n
p(f"  r₂(p)=8 for prime p≡1(4)        : {'HOLDS' if okp1 else f'FAILS@{fp1}'}")
p(f"  r₂(p)=0 for prime p≡3(4)        : {'HOLDS' if okp3 else f'FAILS@{fp3}'}")
# r₂(p^k)=4(k+1) for p≡1 mod 4
okpk = True; fpk = None
for n in range(2, N + 1):
    fc = factor(n)
    if len(fc) == 1:
        pr = next(iter(fc)); k = fc[pr]
        if (pr & 3) == 1 and R2[n] != 4 * (k + 1):
            okpk = False; fpk = n; break
p(f"  r₂(p^k)=4(k+1) for p≡1(4)       : {'HOLDS' if okpk else f'FAILS@{fpk}'}")
p("")

# ===========================================================================
# HAND-CHECKS (explicit small-n verification of the headline identity)
# ===========================================================================
p("HAND-CHECKS (explicit r₂ enumeration vs Jacobi 4(d₁−d₃)):")
def enum_pairs(n):
    out = []
    s = isqrt(n)
    for a in range(-s, s + 1):
        rem = n - a * a
        if rem < 0: continue
        b = isqrt(rem)
        if b * b == rem:
            if b == 0:
                out.append((a, 0))
            else:
                out.append((a, b)); out.append((a, -b))
    return out
for hc in [1, 5, 25, 65, 9, 21]:
    pairs = enum_pairs(hc)
    divs = divisors(hc)
    d1c = sum(1 for d in divs if (d & 3) == 1)
    d3c = sum(1 for d in divs if (d & 3) == 3)
    p(f"  n={hc:3d}: r₂={len(pairs):2d}  pairs={sorted(pairs)}")
    p(f"         divisors={divs}  d₁={d1c} d₃={d3c}  4(d₁−d₃)={4*(d1c-d3c)}  "
      f"{'OK' if len(pairs)==4*(d1c-d3c) else 'MISMATCH'}")
p("")

# ===========================================================================
# VERDICT
# ===========================================================================
# Determine NOVEL survivors: any UNIVERSAL identity in S2 beyond χ₄ kernel,
# any non-trivial congruence beyond G4, etc.
novel_candidates = []
# S2: only χ₄ should be universal; any OTHER universal kernel would be novel
for name, ok, ff in s2_results:
    if ok and not name.startswith("χ₄"):
        novel_candidates.append(f"S2 kernel {name} universal (UNEXPECTED)")
# S6 congruences: only those NOT reduced to Mechanism A/B are novel
for m, M, r, c, cnt, note in novel_cong:
    novel_candidates.append(f"S6 r₂≡{c}(mod {m}) on n≡{r}(mod {M})")

p("=" * 70)
p("VERDICT")
p("=" * 70)
p(f"sanity gates: {'ALL PASS' if all_gates_pass else 'SOME FAILED — engine broken'}")
p(f"  (G1 Jacobi, G2 zero-criterion, G3 non-mult+r₂/4-mult, G4 r₂≡0 mod4)")
p("")
p("REDISCOVERED-CLASSICAL (cite — grounding, NOT discovery):")
p("  · Jacobi (1834): r₂(n)=4·Σ_{d|n}χ₄(d)=4(d₁−d₃)  [G1; A004018]")
p("  · Gauss zero-criterion: r₂(n)>0 ⟺ no p≡3(4) to odd power  [G2]")
p("  · r₂/4 multiplicative (r₂ itself not)  [G3]")
p("  · r₂(p)=8 (p≡1·4), r₂(p)=0 (p≡3·4), r₂(2^a)=4, r₂(p^k)=4(k+1)  [S5]")
p("  · Gauss circle: Σr₂(k)~πn average order  [S3, asymptotic not ∀n]")
p("  · mod-8 refinement: r₂(n)≡4(mod8) ⟺ n=square or 2·square (else ≡0)  [S6 Jacobi cor.]")
p("")
p(f"NOVEL ∀n-identity candidates (beyond Jacobi/Gauss classical catalog): "
  f"{len(novel_candidates)}")
for nc in novel_candidates:
    p(f"  ?NOVEL? {nc}")
if not novel_candidates:
    p("  (none — EXPECTED. r₂ is among the most-studied fns; Jacobi/Gauss closed it.)")
p("")
p(f"NOVEL_COUNT={len(novel_candidates)}")
p(f"GATES_ALL_PASS={all_gates_pass}")

print("\n".join(OUT))
