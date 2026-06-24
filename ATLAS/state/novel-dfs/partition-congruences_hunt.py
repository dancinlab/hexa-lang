#!/usr/bin/env python3
"""ATLAS NOVEL math-DFS — PARTITION-FUNCTION CONGRUENCE frame.  VOCABULARY CHANGE:
the standard MULTIPLICATIVE-function space (σ,φ,τ,μ,…) is DEPLETED across r1-r3
(exact-equality / divisor-sum / Dirichlet / additive / mod-m frames).  This frame
moves to a NON-MULTIPLICATIVE integer function: the unrestricted partition function

    p(n) = #{ ways to write n as a sum of positive integers (order-insensitive) }

p is NOT multiplicative (p(6)=11, p(2)·p(3)=2·3=6 ≠ 11).  Computed EXACTLY (python
bignum) via Euler's PENTAGONAL-NUMBER recurrence

    p(n) = Σ_{k≥1} (−1)^{k+1} [ p(n − k(3k−1)/2) + p(n − k(3k+1)/2) ],   p(0)=1,

a finite alternating sum over generalized pentagonal numbers g_k = k(3k∓1)/2.
N=3000.

SANITY GATES (must rediscover Ramanujan's congruences + Euler's gen-function, else
the recurrence implementation is wrong):
  G1  p(5n+4) ≡ 0 (mod 5)        ∀n            (Ramanujan 1919)
  G2  p(7n+5) ≡ 0 (mod 7)        ∀n            (Ramanujan 1919)
  G3  p(11n+6) ≡ 0 (mod 11)      ∀n            (Ramanujan 1919)
  G4  generating function  Σ p(n) q^n  ==  1/∏_{k≥1}(1−q^k)   (Euler) — checked as a
      finite power series:  p ⊛ (Euler product coefficients) collapses to [1,0,0,…].
  G5  cross-check the SAME p(n) two independent ways (pentagonal recurrence vs the
      classic O(N·n) "coins / unrestricted-partition DP") — they MUST agree ∀n≤N.

SEARCH (∀-arithmetic-progression congruences):  for every modulus m and modular
class a, residue b with 0≤b<a≤A, test whether

    p(a·n + b) ≡ 0 (mod m)   for ALL n with a·n+b ≤ N.

Each hit is classified:
  RAMANUJAN   — one of the three p(5k+4),p(7k+5),p(11k+6) or a known mod-5²/7²/11²
                extension (Ramanujan/Watson — cite, NOT a discovery).
  WATSON/ATKIN/ONO — known prime-power-modulus congruence family (cite).
  TAUTOLOGY   — a≡b reduction or a divisibility forced by a SUPERSET class already
                listed (e.g. p(25n+24)≡0 mod5 is implied by p(5n+4)≡0 mod5).
  ?NOVEL?     — no catalogue entry; re-verified independently + 2 hand-checks +
                a negative control that MUST FAIL.

We EXPECT 0 novel: this is one of the most exhaustively studied spaces in number
theory (Ramanujan, Hardy, Watson, Atkin, Ono, Ahlgren).  Ono proved congruences
exist for every prime ≥5 but with LARGE moduli/classes beyond a small sweep.

Deterministic, integer-exact (python bignum).  LOCAL pure-Python.  NO hexa build.
Usage: python3 partition-congruences_hunt.py [N]   (default N=3000)
"""
import sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000

# ---------------------------------------------------------------------------
# p(n) via Euler's PENTAGONAL-NUMBER recurrence (exact bignum)
# ---------------------------------------------------------------------------
def partitions_pentagonal(N):
    p = [0] * (N + 1)
    p[0] = 1
    for n in range(1, N + 1):
        total = 0
        k = 1
        while True:
            g1 = k * (3 * k - 1) // 2      # generalized pentagonal  k(3k−1)/2
            g2 = k * (3 * k + 1) // 2      #                          k(3k+1)/2
            if g1 > n and g2 > n:
                break
            sign = 1 if (k % 2 == 1) else -1
            if g1 <= n:
                total += sign * p[n - g1]
            if g2 <= n:
                total += sign * p[n - g2]
            k += 1
        p[n] = total
    return p

P = partitions_pentagonal(N)

# ---------------------------------------------------------------------------
# INDEPENDENT cross-check: unrestricted-partition DP (coins 1..N) — O(N^2) but exact.
# dp[s] = number of partitions of s using parts from {1..k} after processing part k.
# Final dp[s] = p(s).  Distinct algorithm from the recurrence ⇒ a real discriminator.
# ---------------------------------------------------------------------------
def partitions_dp(N):
    dp = [0] * (N + 1)
    dp[0] = 1
    for part in range(1, N + 1):
        for s in range(part, N + 1):
            dp[s] += dp[s - part]
    return dp

P_DP = partitions_dp(N)

# ---------------------------------------------------------------------------
# SANITY GATES
# ---------------------------------------------------------------------------
gates = []
def gate(name, cond):
    gates.append((name, cond)); return cond

# G1/G2/G3: Ramanujan congruences
g1 = all(P[5*n + 4] % 5 == 0 for n in range((N - 4)//5 + 1))
gate("G1 p(5n+4)≡0 mod5", g1)
g2 = all(P[7*n + 5] % 7 == 0 for n in range((N - 5)//7 + 1))
gate("G2 p(7n+5)≡0 mod7", g2)
g3 = all(P[11*n + 6] % 11 == 0 for n in range((N - 6)//11 + 1))
gate("G3 p(11n+6)≡0 mod11", g3)

# G4: generating function  (Σ p(n) q^n)·(∏(1−q^k)) == 1   as a power series mod q^(M+1).
# Build Euler product coefficients E[j] = coeff of q^j in ∏_{k≥1}(1−q^k), truncated to M.
# Then convolution (P ⊛ E)[j] must be [1,0,0,...,0].  By the pentagonal-number theorem
# E itself is sparse (±1 at generalized pentagonals) — but we build it by direct product
# to keep this gate INDEPENDENT of the recurrence's pentagonal structure.
M = min(N, 400)   # power-series truncation for the gen-function identity (independent check)
E = [0] * (M + 1)
E[0] = 1
for k in range(1, M + 1):
    # multiply current E by (1 − q^k)  (mod q^(M+1))
    for j in range(M, k - 1, -1):
        E[j] -= E[j - k]
conv = [0] * (M + 1)
for i in range(M + 1):
    if P[i] == 0:
        continue
    pi = P[i]
    for j in range(M + 1 - i):
        conv[i + j] += pi * E[j]
g4 = (conv[0] == 1 and all(conv[j] == 0 for j in range(1, M + 1)))
gate("G4 Σp·∏(1−q^k)=1", g4)

# G5: pentagonal recurrence vs independent DP agree ∀n≤N
g5 = (P == P_DP)
gate("G5 pentagonal==coinDP", g5)

all_gates_ok = all(ok for _, ok in gates)

# ---------------------------------------------------------------------------
# CLASSICAL CATALOGUE of p(an+b)≡0 (mod m) congruences (cite, NOT discovery).
# Keyed by (a, b, m).  Ramanujan's 3 + their best-known prime-power extensions
# (Ramanujan/Watson) for the moduli reachable at N=3000.
# ---------------------------------------------------------------------------
KNOWN = {
    (5,  4,  5):  'Ramanujan 1919:  p(5n+4)≡0 (mod 5)',
    (7,  5,  7):  'Ramanujan 1919:  p(7n+5)≡0 (mod 7)',
    (11, 6,  11): 'Ramanujan 1919:  p(11n+6)≡0 (mod 11)',
    (25, 24, 25): 'Ramanujan/Watson: p(25n+24)≡0 (mod 25)  (mod-5² extension)',
    (49, 47, 49): 'Watson 1938:      p(49n+47)≡0 (mod 49)  (mod-7² extension)',
    (121,116,121):'Atkin 1967:       p(121n+116)≡0 (mod 121) (mod-11² extension)',
    (125,99, 125):'Watson 1938:      p(125n+99)≡0 (mod 125) (mod-5³ extension)',
}

def superset_known(a, b, m):
    """Return a citation if (a,b,m) is FORCED by an already-known coarser class with the
    SAME modulus m: i.e. there is a known (a0,b0,m) with a0 | a and b ≡ b0 (mod a0).
    Such a hit is a TAUTOLOGICAL refinement of the coarser theorem (sub-progression)."""
    for (a0, b0, m0), cite in KNOWN.items():
        if m0 != m:
            continue
        if (a0, b0, m0) == (a, b, m):
            continue
        if a % a0 == 0 and b % a0 == b0 % a0:
            return f"sub-progression of [{cite}] (a={a0}|{a}, b≡{b0} mod {a0})"
    return None

# ---------------------------------------------------------------------------
# SEARCH — p(a·n + b) ≡ 0 (mod m)  ∀n with a·n+b ≤ N
# ---------------------------------------------------------------------------
A_MAX = 30        # modular class modulus a
MODS  = [2, 3, 5, 7, 11, 13, 17, 19, 23, 25, 49, 121]
MIN_TERMS = 12    # require at least this many sampled n (reject thin/accidental classes)

def class_holds(a, b, m):
    cnt = 0
    n = 0
    while a*n + b <= N:
        if P[a*n + b] % m != 0:
            return (False, cnt)
        cnt += 1
        n += 1
    return (True, cnt)

hits = []   # (a,b,m,terms)
for a in range(1, A_MAX + 1):
    for b in range(0, a):
        for m in MODS:
            # m must be a meaningful divisor target; skip m=1 implicitly (not in MODS)
            ok, terms = class_holds(a, b, m)
            if ok and terms >= MIN_TERMS:
                hits.append((a, b, m, terms))

# ---------------------------------------------------------------------------
# CLASSIFY each hit
# ---------------------------------------------------------------------------
ramanujan = []; extension = []; superset = []; novel = []
for (a, b, m, terms) in hits:
    key = (a, b, m)
    if key in KNOWN:
        cite = KNOWN[key]
        if 'Ramanujan 1919' in cite:
            ramanujan.append((a, b, m, terms, cite))
        else:
            extension.append((a, b, m, terms, cite))
        continue
    sc = superset_known(a, b, m)
    if sc is not None:
        superset.append((a, b, m, terms, sc))
        continue
    novel.append((a, b, m, terms))

# ---------------------------------------------------------------------------
# RE-VERIFY ?NOVEL? candidates: recompute p independently (DP array) + 2 hand-checks
# + a negative control that MUST FAIL.
# ---------------------------------------------------------------------------
def fresh_p(n):
    """Independent recomputation of p(n) from the coin-DP array (distinct algorithm)."""
    return P_DP[n]

confirmed_novel = []
reverify_lines = []
for (a, b, m, terms) in novel:
    # full re-check using the INDEPENDENT DP array
    ok_all = all(fresh_p(a*n + b) % m == 0 for n in range((N - b)//a + 1) if a*n + b <= N)
    # two explicit hand-checks: the first two in-range members of the class
    members = [a*n + b for n in range(2) if a*n + b <= N]
    hc = [(x, fresh_p(x), fresh_p(x) % m) for x in members]
    reverify_lines.append((a, b, m, terms, ok_all, hc))
    if ok_all and all(r == 0 for _, _, r in hc):
        confirmed_novel.append((a, b, m, terms))

# ---------------------------------------------------------------------------
# NEGATIVE CONTROLS — near-miss progressions that MUST FAIL (proves discrimination).
# ---------------------------------------------------------------------------
neg = []
def neg_control(desc, a, b, m, expect_fail=True):
    fail_n = None
    n = 0
    while a*n + b <= N:
        if P[a*n + b] % m != 0:
            fail_n = a*n + b
            break
        n += 1
    holds = (fail_n is None)
    neg.append((desc, a, b, m, holds, fail_n))
    return holds

# C1: p(5n+3)≡0 mod5 — FALSE (only the residue-4 class is congruent to 0 mod5)
neg_control("p(5n+3)≡0 mod5", 5, 3, 5)
# C2: p(7n+4)≡0 mod7 — FALSE (only residue-5 class)
neg_control("p(7n+4)≡0 mod7", 7, 4, 7)
# C3: p(11n+5)≡0 mod11 — FALSE (only residue-6 class)
neg_control("p(11n+5)≡0 mod11", 11, 5, 11)
# C4: p(5n+4)≡0 mod7 — FALSE (right class, WRONG modulus)
neg_control("p(5n+4)≡0 mod7", 5, 4, 7)
controls_ok = all((not holds) for _, _, _, _, holds, _ in neg)

# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
print(f"=== PARTITION-FUNCTION CONGRUENCE FRAME (N={N}) ===")
print(f"function: p(n) = unrestricted integer partitions (NON-multiplicative)")
print(f"method:   Euler pentagonal-number recurrence (exact bignum)")
print(f"relation: p(a·n + b) ≡ 0 (mod m)   ∀n with a·n+b ≤ N")
print(f"search:   a∈[1,{A_MAX}], 0≤b<a, m∈{MODS}, ≥{MIN_TERMS} sampled terms")
print(f"sample:   p(0..10) = {P[0:11]}")
print(f"          p(100)={P[100]}  p(1000) has {len(str(P[1000]))} digits")
print()

print("---- SANITY GATES (must rediscover Ramanujan/Euler; else recurrence bug) ----")
for name, ok in gates:
    print(f"  {name:<22} : {'PASS' if ok else 'FAIL'}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print()

print("---- HITS: p(a·n+b)≡0 (mod m) classified ----")
print("  [RAMANUJAN] (the three 1919 congruences — rediscovered = engine works):")
for a, b, m, terms, cite in sorted(ramanujan):
    print(f"    p({a}n+{b}) ≡ 0 (mod {m})   [{terms} terms]  — {cite}")
print("  [KNOWN EXTENSION] (prime-power moduli — Ramanujan/Watson/Atkin):")
if extension:
    for a, b, m, terms, cite in sorted(extension):
        print(f"    p({a}n+{b}) ≡ 0 (mod {m})   [{terms} terms]  — {cite}")
else:
    print("    (none reached at this N / modulus set)")
print("  [TAUTOLOGY / sub-progression] (forced by a coarser known class):")
if superset:
    for a, b, m, terms, sc in sorted(superset):
        print(f"    p({a}n+{b}) ≡ 0 (mod {m})   [{terms} terms]  — {sc}")
else:
    print("    (none)")
print("  [?NOVEL?] (no catalogue entry — re-verified below):")
if novel:
    for a, b, m, terms in sorted(novel):
        print(f"    p({a}n+{b}) ≡ 0 (mod {m})   [{terms} terms]")
else:
    print("    (none)")
print()

print("---- RE-VERIFY ?NOVEL? (independent coin-DP recompute + 2 hand-checks) ----")
if reverify_lines:
    for a, b, m, terms, ok_all, hc in reverify_lines:
        hcs = " ".join(f"p({x})={v}→{v}%{m}={r}" for x, v, r in hc)
        print(f"  p({a}n+{b})≡0 mod{m}: ∀n(DP)={ok_all} | handchecks: {hcs}")
else:
    print("  (no ?NOVEL? candidates — every hit is classical or tautological)")
print()

print("---- NEGATIVE CONTROLS (must FAIL — proves search discriminates) ----")
for desc, a, b, m, holds, fail_n in neg:
    print(f"  {desc:<20} ? {holds}  (expect False; first counterexample n={fail_n}, "
          f"p({fail_n}) mod {m} = {P[fail_n] % m if fail_n is not None else 'n/a'})")
print(f"NEG_CONTROLS_ALL_FAIL_AS_EXPECTED={controls_ok}")
print()

print("=== SUMMARY ===")
print(f"GATES_PASSED={sum(1 for _,ok in gates if ok)}/{len(gates)}")
print(f"RAMANUJAN_REDISCOVERED={len(ramanujan)}")
print(f"KNOWN_EXTENSIONS={len(extension)}")
print(f"TAUTOLOGY_SUBPROGRESSION={len(superset)}")
print(f"NOVEL_CANDIDATES={len(novel)}")
print(f"NOVEL_CONFIRMED={len(confirmed_novel)}")
print(f"ALL_GATES_PASS={all_gates_ok}")
print(f"NEG_CONTROLS_OK={controls_ok}")
print(f"DEPLETED={'YES' if len(confirmed_novel)==0 else 'NO'}")
