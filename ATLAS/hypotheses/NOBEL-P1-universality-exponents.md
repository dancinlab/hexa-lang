# H-NOBEL-1 Prediction: Universality Class Exponents as n=6 Arithmetic
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


> **Hypothesis**: All critical exponents across universality classes decompose
> into arithmetic expressions built from number-theoretic functions of n=6
> (sigma=12, tau=4, phi=2, sopfr=5, n=6).

## Background

SLE_6 showed that all 7 percolation exponents decompose into n=6 arithmetic.
The Criticality Theorem predicts this works for ALL universality classes.
This document tests that prediction against 45 exponents from 11 universality
classes, using strict n=6 atoms and depth-2 expressions, with a proper
statistical control.

## Method

**Atoms**: {1, phi=2, tau=4, sopfr=5, n=6, sigma=12}
(These are the number-theoretic functions of 6: Euler totient, divisor count,
sum of prime factors, the number itself, and sum of divisors.)

**Expressions**:
- Depth 0: single atom (7 values)
- Depth 1: atom op atom, ops = {+, -, *, /} (53 values)
- Depth 2: (d1 op atom) or (d1 op d1) (1,974 values)

**Tolerance**:
- Exact classes: exact fraction match required
- Numerical (3D) classes: 1% relative error allowed

## Master Table: All 45 Exponents

### Exact Classes (24 exponents)

| Class | Exponent | Value | n=6 Expression | Status |
|-------|----------|-------|----------------|--------|
| Ising 2D | alpha | 0 | `0` | EXACT |
| Ising 2D | beta | 1/8 | `(1/phi)/tau` | EXACT |
| Ising 2D | gamma | 7/4 | `phi-(1/tau)` | EXACT |
| Ising 2D | delta | 15 | `(1+phi)*sopfr` | EXACT |
| Ising 2D | nu | 1 | `1` | EXACT |
| Ising 2D | eta | 1/4 | `1/tau` | EXACT |
| Mean Field | alpha | 0 | `0` | EXACT |
| Mean Field | beta | 1/2 | `1/phi` | EXACT |
| Mean Field | gamma | 1 | `1` | EXACT |
| Mean Field | delta | 3 | `1+phi` | EXACT |
| Mean Field | nu | 1/2 | `1/phi` | EXACT |
| Mean Field | eta | 0 | `0` | EXACT |
| Percolation 2D | nu | 4/3 | `tau/(1+phi)` | EXACT |
| Percolation 2D | beta | 5/36 | `(sopfr/n)/n` | EXACT |
| Percolation 2D | gamma | 43/18 | --- | **MISS** |
| Percolation 2D | eta | 5/24 | `sopfr/(phi*sigma)` | EXACT |
| SAW 2D | nu | 3/4 | `(1+phi)/tau` | EXACT |
| SAW 2D | gamma | 43/32 | --- | **MISS** |
| KPZ | alpha | 1/2 | `1/phi` | EXACT |
| KPZ | beta | 1/3 | `phi/n` | EXACT |
| KPZ | z | 3/2 | `n/tau` | EXACT |
| Tricritical Ising | beta | 1/24 | `(1/phi)/sigma` | EXACT |
| Tricritical Ising | gamma | 7/6 | `(1+n)/n` | EXACT |
| Tricritical Ising | nu | 5/9 | `sopfr/(tau+sopfr)` | EXACT |

**Exact hit rate: 22/24 (91.7%)**

Both failures have numerator 43 (a prime unreachable from {1,2,4,5,6,12} in 2 ops).

### Numerical Classes (21 exponents)

| Class | Exponent | Target | n=6 Expression | Value | Error% |
|-------|----------|--------|----------------|-------|--------|
| Ising 3D | alpha | 0.1100 | `(n/sopfr)/(sopfr+n)` | 0.1091 | 0.826 |
| Ising 3D | beta | 0.3265 | --- | --- | **MISS** |
| Ising 3D | gamma | 1.2372 | `(phi/sopfr)+(sopfr/n)` | 1.2333 | 0.313 |
| Ising 3D | delta | 4.7890 | `sopfr-(1/sopfr)` | 4.8000 | 0.230 |
| Ising 3D | nu | 0.6301 | `(tau/sopfr)-(1/n)` | 0.6333 | 0.513 |
| Ising 3D | eta | 0.0364 | `(phi/sopfr)/(sopfr+n)` | 0.0364 | 0.100 |
| XY 3D | alpha | -0.0146 | --- | --- | **MISS** |
| XY 3D | beta | 0.3485 | `(sopfr*sopfr)/(n*sigma)` | 0.3472 | 0.367 |
| XY 3D | gamma | 1.3177 | `(sopfr+sigma)/(1+sigma)` | 1.3077 | 0.759 |
| XY 3D | nu | 0.6717 | `tau/n` | 0.6667 | 0.749 |
| XY 3D | eta | 0.0381 | `(sopfr/sigma)/(sopfr+n)` | 0.0379 | 0.581 |
| Heisenberg 3D | alpha | -0.1336 | `(1-sopfr)/(sopfr*n)` | -0.1333 | 0.200 |
| Heisenberg 3D | beta | 0.3689 | `(1/sopfr)+(1/n)` | 0.3667 | 0.605 |
| Heisenberg 3D | gamma | 1.3960 | `(1+n)/sopfr` | 1.4000 | 0.287 |
| Heisenberg 3D | nu | 0.7112 | `(sopfr+sigma)/(phi*sigma)` | 0.7083 | 0.403 |
| Heisenberg 3D | eta | 0.0375 | --- | --- | **MISS** |
| SAW 3D | nu | 0.5876 | `(phi*sopfr)/(sopfr+sigma)` | 0.5882 | 0.108 |
| SAW 3D | gamma | 1.1575 | `(sigma/sopfr)-(sopfr/tau)` | 1.1500 | 0.648 |
| Dir. Percolation | beta | 0.2760 | `sopfr/(n+sigma)` | 0.2778 | 0.644 |
| Dir. Percolation | nu_perp | 0.7333 | `(phi/sopfr)+(phi/n)` | 0.7333 | 0.005 |
| Dir. Percolation | nu_par | 1.0972 | `(1-sigma)/(phi-sigma)` | 1.1000 | 0.255 |

**Numerical hit rate: 18/21 (85.7%)**

### Summary by Universality Class

| Class | Hits | Total | Rate |
|-------|------|-------|------|
| Ising 2D | 6 | 6 | 100% |
| Mean Field | 6 | 6 | 100% |
| KPZ | 3 | 3 | 100% |
| Tricritical Ising | 3 | 3 | 100% |
| Directed Percolation | 3 | 3 | 100% |
| SAW 3D | 2 | 2 | 100% |
| Ising 3D | 5 | 6 | 83% |
| XY 3D | 4 | 5 | 80% |
| Heisenberg 3D | 4 | 5 | 80% |
| Percolation 2D | 3 | 4 | 75% |
| SAW 2D | 1 | 2 | 50% |
| **TOTAL** | **40** | **45** | **88.9%** |

## Failures (5 exponents)

| # | Exponent | Value | Why it fails |
|---|----------|-------|--------------|
| 1 | Perc2D gamma | 43/18 | Numerator 43 unreachable in 2 ops |
| 2 | SAW2D gamma | 43/32 | Numerator 43 unreachable in 2 ops |
| 3 | Ising3D beta | 0.3265 | No fraction in 1974 values within 1% |
| 4 | XY3D alpha | -0.0146 | Very small negative, sparse coverage |
| 5 | Heisenberg3D eta | 0.0375 | 3/80, denominator 80 unreachable |

## Error Distribution (40 matched exponents)

```
   EXACT | ########################################  22
  <0.01% | ##                                         1
   <0.1% | ##                                         1
   <0.5% | ###############                            8
   <1.0% | ###############                            8
```

## CONTROL TEST: Is n=6 Special?

Tested the same 45 exponents with atoms from n=4,5,6,7,8,10,12,28:

```
  n   sigma tau phi sopfr  Exprs  Exact   Numer   Total  Random
  --  ----- --- --- -----  -----  ------  ------  -----  ------
  4     7    3   2    4     1003   20/24   15/21   35/45  90.7%
  5     6    2   4    5      936   22/24   16/21   38/45  80.5%
  6*   12    4   2    5     1974   22/24   18/21   40/45  93.6%
  7     8    2   6    7     1382   22/24   17/21   39/45  89.0%
  8    15    4   4    6     2383   22/24   19/21   41/45  96.6%
 10    18    4   4    7     3038   22/24   19/21   41/45  98.1%
 12    28    6   4    7     4296   22/24   20/21   42/45  99.1%
 28*   56    6  12   11     7586   22/24   21/21   43/45  99.8%
```

`*` = perfect numbers

### Key observations from control test:

1. **Exact exponents**: All numbers n=5..28 achieve 22/24 (identical to n=6).
   The 2 misses (43/18, 43/32) fail for ALL of them because numerator 43
   is simply too large for depth-2 expressions from small atoms.

2. **Numerical exponents**: Performance scales with number of expressions.
   n=6 has 1974 expressions; n=8 has 2383 and scores higher (41/45).
   n=28 generates 7586 expressions and matches 43/45.

3. **Random baseline**: With 1974 expressions (n=6), a random number in
   [-0.2, 5.0] has a 93.6% chance of matching within 1%. The observed
   85.7% numerical hit rate is BELOW the random baseline.

4. **Statistical significance**: Binomial test for numerical exponents
   gives p = 0.96, Z = -1.5. **NOT significant.** n=6 performs no better
   than chance for approximate matching.

## Denominator Structure (the genuinely interesting finding)

All 21 non-zero exact exponents across all universality classes have
denominators that are **3-smooth** (only prime factors 2 and 3):

```
  Exponent        Value    Denominator    Factorization
  --------        -----    -----------    -------------
  Ising2D beta    1/8      8              2^3
  Ising2D gamma   7/4      4              2^2
  Ising2D eta     1/4      4              2^2
  MF beta         1/2      2              2^1
  MF nu           1/2      2              2^1
  KPZ beta        1/3      3              3^1
  KPZ alpha       1/2      2              2^1
  KPZ z           3/2      2              2^1
  Perc2D beta     5/36     36             2^2 * 3^2
  Perc2D gamma    43/18    18             2^1 * 3^2
  Perc2D nu       4/3      3              3^1
  Perc2D eta      5/24     24             2^3 * 3^1
  SAW2D nu        3/4      4              2^2
  SAW2D gamma     43/32    32             2^5
  Tri beta        1/24     24             2^3 * 3^1
  Tri gamma       7/6      6              2^1 * 3^1
  Tri nu          5/9      9              3^2
```

**3-smooth numbers up to 36**: {1, 2, 3, 4, 6, 8, 9, 12, 16, 18, 24, 27, 32, 36}
That is 14/36 = 38.9% of possible denominators.

**Null hypothesis**: If denominators were random in [1..36], the probability
that ALL 21 are 3-smooth = 0.389^21 = 2.4 x 10^-9.

**However**: This is EXPECTED from conformal field theory. CFT exponents
come from the Kac table h_{r,s} = ((m+1)r - ms)^2 - 1) / (4m(m+1)),
where m is a small integer. The denominators are products of m and m+1,
which for the minimal models are products of 2 and 3. The 3-smooth
pattern is a consequence of CFT structure, not n=6 arithmetic per se.

The "6" appearing in the CFT central charge formula c = 1 - 6/(m(m+1))
is genuinely related to the Virasoro algebra, not to the perfect number 6.

## Verdict

### Does H-NOBEL-1 survive?

**Partially. The claim requires significant weakening.**

| Claim | Status | Evidence |
|-------|--------|----------|
| Exact 2D exponents decompose into n=6 | MOSTLY TRUE (22/24) | But n=5,7,8 do equally well |
| Numerical 3D exponents decompose | STATISTICALLY INSIGNIFICANT | Below random baseline |
| n=6 is SPECIAL for this decomposition | **REFUTED** | n=8, n=10, n=12 all do better |
| Denominators are 3-smooth | TRUE (p < 10^-9) | But explained by CFT, not n=6 |

### What is true:

1. All exact 2D critical exponents have denominators built from primes
   {2, 3}, which are the prime factors of 6. This is genuine structure,
   but it comes from conformal field theory, not from n=6 being perfect.

2. The approximate matching for 3D exponents is a consequence of having
   ~2000 rational numbers to fit against -- any set of 6 atoms with
   comparable spread would do similarly.

3. The two exact failures (numerator 43) are real and irreducible at
   depth 2. Depth 3 would likely match them, but then the random
   baseline would approach 100%.

### Honest assessment: The hypothesis is NOT confirmed.

The 88.9% hit rate looks impressive but is entirely explained by the
density of rational expressions available at depth 2. The control test
with n=8 atoms (which has nothing to do with perfect numbers) scores
91%. n=6 is not special here.

The denominator structure IS real but is a known consequence of the
Virasoro algebra and conformal field theory. Claiming it as evidence
for n=6 would be circular: the 6 in CFT has a different origin than
the perfect number 6.

## Scripts

- `/Users/ghost/Dev/TECS-L/scripts/nobel_p1_universality_v2.py` -- strict search
- `/Users/ghost/Dev/TECS-L/scripts/nobel_p1_control.py` -- control test vs other n

## Grade

**Assessment: Not graded (prediction test)**

The prediction that ALL universality class exponents decompose into n=6
arithmetic is not statistically supported when properly controlled. The
approximate matches are curve-fitting artifacts. The exact denominator
structure is real but has a known explanation independent of n=6.
