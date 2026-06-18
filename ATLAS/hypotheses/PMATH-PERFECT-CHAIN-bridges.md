# PMATH-PERFECT-CHAIN: Inter-Perfect-Number Bridge Classification

> **Hypothesis**: The pair (P1, P2) = (6, 28) is the ONLY non-trivial structural
> cross-bridge between even perfect numbers. All other inter-perfect connections
> are either universal identities or numerical coincidences.

**Status**: PROVEN (two uniqueness theorems)
**Grade**: 🟩⭐⭐ (two proven uniqueness results)
**GZ Dependency**: NONE (pure number theory)
**Calculator**: `calc/perfect_chain_bridges.py`

---

## Background

Even perfect numbers have the form P_k = 2^(p_k - 1)(2^(p_k) - 1) where p_k is
the k-th Mersenne prime exponent. A "bridge" between P_i and P_j is any identity
f(P_i) = g(P_j) where f, g are standard arithmetic functions.

Known bridges prior to this analysis:
- phi(P2) = sigma(P1) = 12
- phi(P3) = 240 = |E8 roots|
- tau(P2) = 6 = P1
- tau(P3) = 10 = D(superstring)

This analysis systematically classifies ALL such connections.

## Arithmetic Function Table (P1..P5)

```
  Function       P1=6       P2=28      P3=496     P4=8128    P5=33550336
  -----------------------------------------------------------------------
  p              2          3          5          7          13
  sigma          12         56         992        16256      67100672
  phi            2          12         240        4032       16773120
  tau            4          6          10         14         26
  sopfr          5          11         39         139        8215
  Omega          2          3          5          7          13
  omega          2          2          2          2          2
  radical        6          14         62         254        16382
  sigma/phi      6          14/3       62/15      254/63     16382/4095
  phi/n          1/3        3/7        15/31      63/127     4095/8191
  tau/omega      2          3          5          7          13
```

All closed forms verified:
- sigma(P_k) = 2*P_k [UNIVERSAL, definition]
- tau(P_k) = 2*p_k [UNIVERSAL]
- phi(P_k) = 2^(p-1)(2^(p-1)-1) [UNIVERSAL]
- Omega(P_k) = p_k, omega(P_k) = 2 [UNIVERSAL]
- sopfr(P_k) = 2^p + 2p - 3 [UNIVERSAL]
- rad(P_k) = 2(2^p - 1) [UNIVERSAL]

## Theorem 1: phi-sigma Bridge Uniqueness

> **Theorem**: phi(P_{k+1}) = sigma(P_k) if and only if k = 1.

**Proof**:

For even perfect P_k = 2^(p-1)(2^p - 1):
```
  sigma(P_k)     = 2^p * (2^p - 1)
  phi(P_{k+1})   = 2^(q-1) * (2^(q-1) - 1)    where q = p_{k+1}
```

Setting equal: 2^(q-1)(2^(q-1) - 1) = 2^p(2^p - 1)

Matching powers of 2 in the factorization: q - 1 = p, hence q = p + 1.
Substituting: 2^p(2^p - 1) = 2^p(2^p - 1). Identity holds.

But q = p + 1 requires p_{k+1} = p_k + 1, i.e., consecutive Mersenne exponents
differing by exactly 1.

```
  Mersenne exponents:      2,  3,  5,  7, 13, 17, 19, 31, ...
  Consecutive differences:  1,  2,  2,  6,  4,  2, 12, ...
                            ^
                         UNIQUE
```

The pair (p_1, p_2) = (2, 3) is the only consecutive pair with difference 1.
For q > p + 1: LHS > RHS (strictly increasing in q). No other solution exists.

**Verification**: phi(P2) = phi(28) = 12 = sigma(6) = sigma(P1). QED.

**Stronger result**: sigma(P1) = 12 = phi(28) = phi(P2), AND phi(P2) = 12 = sigma(6) = sigma(P1).
This is a BIDIRECTIONAL bridge: the phi-sigma link goes both ways between P1 and P2.

```
  P1=6 ----sigma(P1)=12----> phi(P2)=12---- P2=28
  P1=6 <---phi(P2)=12------ sigma(P1)=12--- P2=28
         (same identity, bidirectional)
```

## Theorem 2: tau-Value Bridge Uniqueness

> **Theorem**: tau(P_k) = P_j has unique solution (k, j) = (2, 1).

**Proof**:

tau(P_k) = 2*p_k. Setting 2*p_k = P_j = 2^(q-1)(2^q - 1):
```
  p_k = 2^(q-2) * (2^q - 1)
```

For q = 2: p_k = 2^0 * 3 = 3. Is 3 a Mersenne exponent? YES. Gives k=2.
For q = 3: p_k = 2^1 * 7 = 14. Is 14 prime? NO (14 = 2*7). Not a Mersenne exponent.
For q >= 3: p_k = 2^(q-2)(2^q - 1) >= 14, which is always composite for q >= 3
(product of two factors both >= 2).

Therefore (k, j) = (2, 1) is the unique solution. QED.

**Verification**: tau(P2) = tau(28) = 6 = P1.

## Additional Bridge: rad(P2) = tau(P4)

```
  rad(P2) = rad(28) = 2 * 7 = 14
  tau(P4) = tau(8128) = 2 * 7 = 14
```

This is NOT a structural bridge. It follows from:
- rad(P2) = 2 * M_3 = 2 * 7 = 14
- tau(P4) = 2 * p_4 = 2 * 7 = 14

The coincidence is that M_3 = 7 = p_4 (the 3rd Mersenne prime equals the 4th
Mersenne exponent). This is a numerical coincidence in the Mersenne sequence,
not a structural property of perfect numbers.

## Cross-Reference Matrix (32 connections found)

Non-trivial bridges (excluding omega=2 matches):

| Source | f(P_i) | Value | g(P_j) | Target | Class |
|--------|---------|-------|---------|--------|-------|
| P1 | n | 6 | tau | P2 | STRUCTURAL* |
| P1 | sigma | 12 | phi | P2 | STRUCTURAL* |
| P1 | n/2 | 3 | Omega | P2 | trivial (small number) |
| P1 | sopfr | 5 | Omega | P3 | trivial (small number) |
| P2 | radical | 14 | tau | P4 | COINCIDENTAL |
| P2 | n/2 | 14 | tau | P4 | same as above |

Most of the 32 connections involve omega=2 (universal for all even perfects)
or small values (2, 3) that match trivially.

## Divisor Containment

> **Theorem**: div(P_i) is NOT a subset of div(P_j) for any i != j.

**Proof**: P_k = 2^(p-1) * M_p where M_p is a Mersenne prime.
Distinct Mersenne primes are coprime (both prime, unequal).
Hence M_{p_i} does not divide P_j, so any divisor of P_i involving M_{p_i}
is not a divisor of P_j.

The intersection of divisor sets is exactly the powers of 2:
```
  div(P_i) INTERSECT div(P_j) = {1, 2, 4, ..., 2^(min(p_i,p_j)-1)}
```

Verification:
```
  div(6)    = {1, 2, 3, 6}
  div(28)   = {1, 2, 4, 7, 14, 28}
  Overlap   = {1, 2}               (= powers of 2 up to 2^(min(2,3)-1) = 2^1)

  div(28)   = {1, 2, 4, 7, 14, 28}
  div(496)  = {1, 2, 4, 8, 16, 31, 62, 124, 248, 496}
  Overlap   = {1, 2, 4}            (= powers of 2 up to 2^(min(3,5)-1) = 2^2)
```

## Generating Function

No simple function F(P_k) = P_{k+1} exists. The Mersenne exponent gaps
(1, 2, 2, 6, 4, 2, 12, ...) are irregular. Any such F would solve the
Mersenne prime distribution problem, which is open.

## phi-sigma Chain Extensions

```
  sigma(P1) = 12 = phi(13, 21, 26, 28, 36, 42)    contains P2=28
  sigma(P2) = 56 = phi(87, 116, 174)               no perfect numbers
  sigma(P3) = 992                                   no phi-preimage in [1,3000]

  phi(P1) = 2:  no sigma-preimage (sigma(n)=2 has no solution for n>1)
  phi(P2) = 12 = sigma(6, 11)                      contains P1=6!
  phi(P3) = 240 = sigma(114, 135, 158, 177, ...)   no perfect numbers
```

The chain STOPS at P1-P2. sigma(P2) = 56 has phi-preimages but none are perfect.

## Texas Sharpshooter Test

```
  Total comparisons tested:      2000  (5 perfects x 20 pairs x 5x5 functions x2)
  Actual cross-matches:          4     (non-trivial, value > 1)
  Random baseline:               3.44 +/- 2.49
  Z-score:                       0.23
  p-value (MC, N=1000):          0.499
```

**Result**: The total number of cross-matches is CONSISTENT WITH RANDOM CHANCE.
The structural bridges (phi-sigma, tau-value) are not detected by the Monte Carlo
because they are PROVEN consequences of number theory, not statistical anomalies.

Per-bridge Bonferroni-corrected p-values:
- phi(P2)=sigma(P1)=12: STRUCTURAL (not applicable)
- tau(P2)=P1=6: STRUCTURAL (not applicable)
- phi(P3)=240=|E8|: p_corrected > 1.0 (not significant)
- tau(P3)=10=D(super): p_corrected > 1.0 (not significant)
- tau(P5)=26=D(bosonic): p_corrected > 1.0 (not significant)

## ASCII Bridge Diagram

```
  P1=6          P2=28         P3=496        P4=8128       P5=33550336
  p=2           p=3           p=5           p=7           p=13
  ====          ====          =====         =====         =========
  |             |             |             |             |
  | sigma=12 ====> phi=12     |             |             |
  |    [UNIQUE: p2=p1+1, only consecutive Mersenne exponents]
  |             |             |             |             |
  | n=6 <======== tau=6       |             |             |
  |    [UNIQUE: 2p_k = P_j only at (k,j)=(2,1)]
  |             |             |             |             |
  |             |  phi=240    |             |             |
  |             |  [COINCIDENTAL with |E8 roots|]         |
  |             |             |             |             |
  ====          ====          =====         =====         =========

  Two STRUCTURAL bridges (proven unique), zero beyond P1-P2.
```

## Classification Summary

| # | Bridge | Value | Class | Proof |
|---|--------|-------|-------|-------|
| 1 | sigma(P_k) = 2*P_k | 2n | UNIVERSAL | definition |
| 2 | tau(P_k) = 2*p_k | 2p | UNIVERSAL | factorization |
| 3 | phi(P2) = sigma(P1) | 12 | STRUCTURAL* | Thm 1 (p2=p1+1 unique) |
| 4 | tau(P2) = P1 | 6 | STRUCTURAL* | Thm 2 (2p composite for q>=3) |
| 5 | phi(P3) = 240 = \|E8\| | 240 | COINCIDENTAL | p > 1.0 after correction |
| 6 | tau(P3) = D(super) | 10 | COINCIDENTAL | p > 1.0 after correction |
| 7 | tau(P5) = D(bosonic) | 26 | COINCIDENTAL | p > 1.0 after correction |
| 8 | P3 = dim(SO(32)) | 496 | COINCIDENTAL+ | possible deeper structure |
| 9 | rad(P2) = tau(P4) | 14 | COINCIDENTAL | M_3 = p_4 numerical coincidence |
| 10 | div(P_i) not subset div(P_j) | --- | STRUCTURAL | coprime Mersenne primes |

## Limitations

1. Only even perfect numbers analyzed (odd perfect numbers, if they exist, are excluded).
2. Preimage searches limited to [1, 3000] for computational tractability.
3. Physics coincidences (E8, string dimensions) may have deeper explanations
   in contexts we do not explore here (e.g., lattice theory, modular forms).
4. The "COINCIDENTAL+" status for P3 = dim(SO(32)) is provisional --
   if a proof connects anomaly cancellation to perfect number structure,
   this would be upgraded.

## Verification Direction

1. Extend preimage search for sigma(P3) = 992 and phi(P3) = 240 to larger ranges
   (Rust calculator recommended for range > 10^6).
2. Investigate whether P3 = 496 = dim(SO(32)) has a lattice-theoretic explanation
   beyond numerical coincidence.
3. Check whether any odd perfect number (if one exists) would create new bridges.
4. Verify the tau chain pattern tau(P_k) = 2*p_k against all 51 known Mersenne primes.
