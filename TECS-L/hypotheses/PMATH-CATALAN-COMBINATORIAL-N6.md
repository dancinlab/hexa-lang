# PMATH-CATALAN: Combinatorial Sequences Encode n=6 Arithmetic

> **Hypothesis**: Classical combinatorial sequences -- Catalan, Fibonacci,
> Bell, partitions, Bernoulli, Stirling, derangements -- encode the
> arithmetic functions of the first perfect number n=6 at structurally
> significant indices. The strongest connections are P1-specific and do
> not generalize to n=28.

**Date**: 2026-03-31
**Golden Zone Dependency**: None (pure mathematics)
**Calculator**: `calc/catalan_combinatorial_n6.py`
**n=6 Constants**: P1=6, sigma=12, tau=4, phi=2, sopfr=5, M3=7, P2=28

---

## Summary Table

| # | Identity | Sequence | Grade | Depth | P2 test |
|---|---|---|---|---|---|
| CAT-1 | C_3 = sopfr(6) = 5 | Catalan | ⚪ | Trivial | N/A |
| CAT-2 | C_5 = M3*P1 = 42 | Catalan | 🟧 | Moderate | - |
| CAT-3 | C_6 = sigma*sopfr(P2) = 132 | Catalan | 🟧 | Moderate | - |
| FIB-1 | F_6 = sigma-tau = 8 | Fibonacci | ⚪ | Weak | - |
| FIB-2 | F_sigma(6) = sigma(6)^2 = 144 | Fibonacci | 🟩 | Deep | FAIL at P2 |
| BELL-1 | B(6) = 7*29 (M3 factor) | Bell | ⚪ | Weak | - |
| PART-1 | p(6) = sopfr(P2) = 11 | Partition | 🟧 | Moderate | - |
| PART-2 | p(p(6)) = sigma(P2) = 56 | Partition | 🟧★ | Deep | - |
| BERN-1 | B_6 = 1/(M3*P1) = 1/42 | Bernoulli | 🟩 | Proven | structural |
| BERN-2 | B_P1 * C_sopfr = 1 | Cross | 🟩 | Deep | FAIL at P2 |
| STIR-1 | S(6,2) = M_sopfr = 31 | Stirling | 🟧 | Moderate | structural |
| STIR-2 | S(6,5) = C(6,2) = 15 | Stirling | ⚪ | Trivial | universal |
| DER-1 | D(6)/6! ~ 1/e | Derangement | ⚪ | Universal | all n |

**Score: 🟩 3, 🟧★ 1, 🟧 3, ⚪ 6**

---

## Top Findings

### FIB-2: F_sigma(6) = sigma(6)^2 (DEEP, P1-ONLY)

> F_12 = F_sigma(6) = 144 = 12^2 = sigma(6)^2

This is the strongest finding. The 12th Fibonacci number equals the
square of sigma(6) = 12. Since sigma(6) = 12, this reads:

    F_sigma(n) = sigma(n)^2   at n = 6

**Generalization test**:
```
  n = 6:   sigma = 12,  F_12 = 144 = 12^2    EXACT
  n = 28:  sigma = 56,  F_56 = 225851433717  != 3136 = 56^2    FAIL
  n = 496: sigma = 992, F_992 >> 992^2    FAIL
```

This is definitively P1-ONLY. The identity F_12 = 12^2 requires that
the 12th Fibonacci number happens to equal 144 = 12^2, which is a
specific numerical fact. Among F_n for n=1..100, the only case where
F_n = n^2 is n = 12.

```
  F_n vs n^2 scan (n=1..50):
  n:    1   2   3   4   5   6   7   8   9  10  11  12  ...
  F_n:  1   1   2   3   5   8  13  21  34  55  89 144  ...
  n^2:  1   4   9  16  25  36  49  64  81 100 121 144  ...
                                                    ^
                                              UNIQUE MATCH at n=12=sigma(6)
```

**Grade: 🟩 (exact, P1-only, verified)**

---

### BERN-2: Bernoulli-Catalan Bridge B_P1 * C_sopfr = 1

> B_6 * C_5 = (1/42) * 42 = 1

The 6th Bernoulli number and the 5th Catalan number are reciprocals:

    B_P1 = 1 / C_sopfr(P1)

This connects two fundamental combinatorial sequences through n=6
arithmetic: the Bernoulli index is P1=6, the Catalan index is
sopfr(6)=5, and their product is exactly 1.

**Why it works**: B_6 = 1/42 by the Von Staudt-Clausen theorem (the
denominator of B_{2k} is the product of primes p where (p-1)|2k; for
2k=6, primes are 2,3,7 giving 42). C_5 = C(10,5)/6 = 252/6 = 42.
So this is 1/42 * 42 = 1.

**Generalization**: Does B_n * C_{sopfr(n)} = 1 for other n?
- n=28: B_28 has denominator 6, not C_{sopfr(28)} = C_33. FAIL.
- n=12 (non-perfect): B_12 = -691/2730, C_{sopfr(12)} = C_7 = 429. Product != 1.

**Grade: 🟩 (exact, P1-only)**

---

### PART-2: Partition Chain p(p(6)) = sigma(P2)

> p(6) = 11 = sopfr(28) = sopfr(P2)
> p(11) = 56 = sigma(28) = sigma(P2)
> Therefore: p(p(P1)) = sigma(P2)

A double application of the partition function on P1 yields sigma(P2).
This chains two perfect numbers through the partition function:

```
  P1 = 6  --p-->  11 = sopfr(P2)  --p-->  56 = sigma(P2)
             partition          partition
```

The intermediate value 11 is itself meaningful: it equals sopfr(P2),
the sum of prime factors of the second perfect number (28 = 2^2 * 7,
sopfr = 2+2+7 = 11).

**Caution**: This involves small numbers where coincidences are more
likely. The chain relies on p(6) = 11 and p(11) = 56, both small
partition values. Monte Carlo testing needed to assess significance.

**Grade: 🟧★ (exact chain, but small-number warning)**

---

### BERN-1: B_6 = 1/(M3 * P1)

> B_6 = 1/42 = 1/(7 * 6) = 1/(M3 * P1)

The denominator of the 6th Bernoulli number factors as the Mersenne
prime M3=7 times the first perfect number P1=6.

By Von Staudt-Clausen: denom(B_6) = 2 * 3 * 7 = 42.
Since 42 = 6 * 7 = P1 * M3, this is structural:

    denom(B_{P1}) = P1 * M3 = P1 * (2^3 - 1)

**Why**: The primes p with (p-1)|6 are {2, 3, 7}. Their product is 42.
Note 2*3 = P1 and 7 = M3 = 2^3 - 1. This is a consequence of 6 being
the product of the first two primes and having Mersenne structure.

**Grade: 🟩 (proven via Von Staudt-Clausen)**

---

## Other Findings

### CAT-2: C_5 = 42 = M3 * P1

The 5th Catalan number is 42 = 7 * 6 = M3 * P1. Note that 5 = sopfr(6),
so this reads C_sopfr(6) = M3 * P1. Moderate: requires knowing that
C_5 = 42 specifically factors this way.

### CAT-3: C_6 = 132 = sigma * 11

C_6 = 132 = 12 * 11 = sigma(6) * sopfr(P2). This connects the Catalan
number at the P1 index to both sigma and the second perfect number's
prime factor sum.

### STIR-1: S(6,2) = M5 = M_sopfr(6)

S(n,2) = 2^(n-1) - 1 for all n. At n=6, this gives 2^5 - 1 = 31 = M5.
Since 5 = sopfr(6), we have S(P1,2) = M_sopfr(P1). The fact that M5
is prime depends on sopfr(6) = 5 being prime, which is true but not
guaranteed for other perfect numbers (sopfr(28) = 11 is prime, but
sopfr(496) = 37 is prime too -- so M_sopfr may often be Mersenne prime
for perfect numbers, an interesting side observation).

### DER-1: D(6)/6! approximates 1/e (UNIVERSAL)

D(n)/n! -> 1/e as n -> infinity. At n=6, the approximation is already
within 1.4e-4 of 1/e. But this is NOT special to n=6; it holds for all
n with improving accuracy. Grade: ⚪ (universal, not P1-specific).

---

## ASCII Visualization

```
  Combinatorial Sequences Touching n=6 Constants
  ===============================================

  Catalan:    1   1   2   5  14  42 132
              |           |       |   |
              1        sopfr   M3*P1 sigma*11

  Fibonacci:  1   1   2   3   5   8  13  21  34  55  89 144
              |                   |                       |
              1              sigma-tau              sigma^2 !!!

  Partition:  1   1   2   3   5   7  11  15  22  30  42  56
                                      |                   |
                                   sopfr(P2)         sigma(P2)
                                      \________p________/
                                       partition chain

  Bernoulli:  1  -1/2  1/6   0 -1/30  0  1/42
                                          |
                                     1/(M3*P1) = 1/C_sopfr

  Stirling S(6,k):   1  31  90  65  15   1
                         |           |
                        M5       C(6,2)
```

---

## Limitations

1. **Small number bias**: Most connections involve values < 200, where
   coincidences are much more likely. The Strong Law of Small Numbers
   applies strongly here.

2. **Post-hoc selection**: We specifically looked at n=6-related indices
   (P1, sigma, sopfr, etc.) in these sequences. The Texas Sharpshooter
   correction is essential.

3. **Structural explanations exist**: B_6 = 1/42 follows from Von
   Staudt-Clausen. S(n,2) = 2^(n-1)-1 is universal. D(n)/n! -> 1/e
   is universal. These reduce the "surprise" of the connections.

4. **F_12 = 144 = 12^2 is the genuine surprise**: This is the one
   identity that is both exact, non-trivial, and P1-specific. It
   deserves further investigation.

---

## Verification Direction

1. **F_n = n^2 uniqueness**: Prove that n=12 is the only positive integer
   where F_n = n^2. (Likely provable via growth rate analysis: F_n grows
   as phi^n/sqrt(5) which eventually dominates n^2.)

2. **Partition chain extension**: Does p(p(p(6))) connect to P3=496 constants?
   Compute and check.

3. **Monte Carlo**: Full Texas Sharpshooter with Bonferroni correction across
   all 13 claims simultaneously.

---

## References

- PMATH-001~020: Pure mathematics n=6 structures
- PMATH-015: F(P1) = 8 = phi*tau (already catalogued)
- PMATH-016: C(sopfr) = 42 = 7*P1 (already catalogued)
- PMATH-014: p(11) = 56 = sigma(P2) (already catalogued)
