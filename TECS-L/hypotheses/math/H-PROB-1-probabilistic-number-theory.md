# H-PROB-1: Probabilistic Number Theory and Perfect Number 6

## Hypothesis

> The ratio R(n) = sigma(n)*phi(n) / (n*tau(n)) equals exactly 1 for
> only two values: n=1 (trivial) and n=6. Among all n > 1 up to 10^5,
> n=6 is the unique solution to R(n) = 1. Combined with the Erdos-Kac
> anomaly (Z = 1.86 sigma for omega(6)), perfect number 6 is a
> probabilistic outlier in multiple independent arithmetic measures.

**Status**: Verified (green) -- computed up to N=100,000
**Golden Zone dependence**: None (pure number theory)

## Background

Probabilistic number theory treats arithmetic functions as random
variables over integers. Key results:

- **Erdos-Kac theorem**: omega(n) (number of distinct prime factors)
  is approximately normal with mean ln(ln(n)) and std sqrt(ln(ln(n))).
- **Distribution of multiplicative functions**: ratios like sigma(n)/n,
  phi(n)/n, tau(n)/log(n) have known limiting distributions.

We define R(n) = sigma(n)*phi(n) / (n*tau(n)) and ask: how rare is
R(n) = 1, and what does it mean probabilistically?

## Verified Results

### 1. Erdos-Kac Analysis of omega(6)

| n | omega(n) | ln(ln(n)) | sqrt(ln(ln(n))) | Z-score |
|---|----------|-----------|-----------------|---------|
| 6 | 2 | 0.583 | 0.764 | **1.855** |
| 28 | 2 | 1.204 | 1.098 | 0.726 |
| 496 | 2 | 1.826 | 1.351 | 0.129 |
| 8128 | 2 | 2.198 | 1.483 | -0.133 |

n=6 is 1.86 sigma above the Erdos-Kac mean -- moderately anomalous.
It has "too many" prime factors for its size. Note that all even perfect
numbers have omega = number of distinct primes in 2^(p-1)(2^p-1), which
is exactly 2 when 2^p-1 is prime. As perfect numbers grow, their
Z-score drops toward 0 and eventually becomes negative (they become
"normal" then "under-factored").

```
  Erdos-Kac Z-scores for perfect numbers:

  Z
  2 |
    |  *  6
  1 |     .  .  .
    |        *  28
  0 |---.---.--*-496-.---.---.---.---.---.---.---.---.---
    |              *  8128
 -1 |
    +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--> ln(n)
       1  2  3  4  5  6  7  8  9
```

### 2. Distribution of R(n) = sigma*phi/(n*tau)

Computed for n = 1 to 100,000:

| Statistic | Value |
|-----------|-------|
| Mean | 7470.6 |
| Median | 4364.1 |
| Std | 8712.5 |
| Skewness | 2.29 |
| Min | 0.750 (n=4) |
| R(6) | **1.000** |
| Percentile of R=1 | 0.00% (bottom) |

Values with R(n) = 1 exactly: **{1, 6}** only.

The distribution is extremely right-skewed. Nearly all R(n) values
are much larger than 1:

```
  Histogram of R(n), n=1..100000 (log-scale count):

  R range       Count    Bar
  [0.0, 1.0)        1    |
  [1.0, 2.0)        5    |*
  [2.0, 5.0)       15    |**
  [5.0, 10)         9    |*
  [10, 50)         36    |****
  [50, 100)        20    |***
  [100, 500)       98    |*********
  [500, 1000)      76    |*******
  [1000, 5000)  29979    |################################
  [5000, 10k)   31847    |##################################  <-- peak
  [10k, 50k)    36284    |#####################################
  [50k+)         1628    |*

  R(6) = 1.0 is in the extreme left tail.
  Only 6 values out of 100,000 have R < 2.
```

### 3. R-values for Perfect Numbers

| Perfect n | sigma | phi | tau | R = sigma*phi/(n*tau) |
|-----------|-------|-----|-----|-----------------------|
| 6 | 12 | 2 | 4 | **1.000** |
| 28 | 56 | 12 | 6 | 4.000 |
| 496 | 992 | 240 | 10 | 48.000 |
| 8128 | 16256 | 4032 | 14 | 576.000 |

The R-values of perfect numbers grow rapidly. Only n=6 achieves R=1.

General formula for even perfect number n = 2^(p-1)(2^p - 1):

```
  sigma(n) = 2n = 2^p * (2^p - 1)
  phi(n)   = 2^(p-2) * (2^p - 2) = 2^(p-2) * 2 * (2^(p-1) - 1)
           = 2^(p-1) * (2^(p-1) - 1)
  tau(n)   = p * 2 = 2p

  R(n) = sigma * phi / (n * tau)
       = [2n] * [2^(p-1)(2^(p-1)-1)] / [n * 2p]
       = 2^(p-1) * (2^(p-1) - 1) / p

  R(6):    p=2: 2^1 * (2^1 - 1) / 2 = 2*1/2 = 1
  R(28):   p=3: 2^2 * (2^2 - 1) / 3 = 4*3/3 = 4
  R(496):  p=5: 2^4 * (2^4 - 1) / 5 = 16*15/5 = 48
  R(8128): p=7: 2^6 * (2^6 - 1) / 7 = 64*63/7 = 576
```

So R(n) = 2^(p-1)(2^(p-1) - 1) / p. This equals 1 only when:

```
  2^(p-1)(2^(p-1) - 1) = p
  p=2: 2*1 = 2  YES
  p=3: 4*3 = 12 != 3
  p=5: 16*15 = 240 != 5
```

For p >= 3, the LHS grows exponentially while RHS grows linearly.
**R = 1 is unique to p = 2, i.e., n = 6.**

This is now a **proof**, not just empirical observation.

### 4. tau(sigma(n))/n Distribution

| Statistic | Value |
|-----------|-------|
| Mean (n=1..10000) | 0.01358 |
| Median | 0.00701 |
| tau(sigma(6))/6 | tau(12)/6 = 6/6 = **1.000** |
| Percentile of 1.0 | 99.96% |

Numbers where tau(sigma(n))/n = 1 (for n <= 10000): {1, 2, 3, 6}.
After n=6, no further solutions up to 10,000.

### 5. Rarity Comparison

| Property | Count in [1,100000] | Density |
|----------|---------------------|---------|
| Perfect: sigma(n)=2n | 4 | 0.004% |
| R(n)=1 | 2 | 0.002% |
| Both perfect AND R=1 | 1 (n=6 only) | 0.001% |

If "perfect" and "R=1" were independent events:

```
  P(both) = P(perfect) * P(R=1) = 4/10^5 * 2/10^5 = 8 * 10^-10
  Actual P(both) = 1/10^5 = 10^-5
  Enrichment = 10^-5 / (8*10^-10) = 12,500x
```

The overlap is enriched 12,500-fold over independence. This is because
the R=1 condition for perfect numbers is algebraically constrained
(only p=2 works), not a random coincidence.

### 6. Hardy-Ramanujan Partition Check

| n | p(n) exact | HR approx | ratio |
|---|-----------|-----------|-------|
| 1 | 1 | 1.9 | 0.533 |
| 3 | 3 | 4.1 | 0.733 |
| **6** | **11** | **12.9** | **0.854** |
| 10 | 42 | 48.1 | 0.873 |
| 15 | 176 | 198.5 | 0.887 |
| 20 | 627 | 692.4 | 0.906 |

The Hardy-Ramanujan approximation at n=6 gives ratio 0.854. This is
unremarkable -- the approximation is designed for large n and converges
monotonically. No special property of p(6)=11 related to perfectness.

## Interpretation

1. **R(6)=1 is provably unique among perfect numbers**: The algebraic
   formula R = 2^(p-1)(2^(p-1)-1)/p = 1 has the unique solution p=2.
   This is a theorem, not an observation.

2. **R(6)=1 is empirically unique among ALL n > 1**: Up to 10^5, only
   n=1 and n=6 satisfy R=1. Since R(n) grows with n for most n (the
   median is ~4364), and exact cancellation requires very specific
   divisor structure, this is likely true for all n.

3. **Erdos-Kac anomaly is moderate**: Z=1.86 means ~3.2% of integers
   near 6 would have omega >= 2. Anomalous but not extreme. The anomaly
   decreases for larger perfect numbers.

4. **The enrichment of perfect + R=1 is explained algebraically**: The
   12,500x enrichment is not statistical magic but a consequence of the
   tight algebraic constraint on R for perfect numbers.

5. **n=6 is the "simplest" perfect number in multiple probabilistic
   senses**: lowest R, highest Erdos-Kac Z-score, smallest tau(sigma)/n
   equal to 1.

## Limitations

- R(n)=1 uniqueness for n>1 is verified up to 10^5, not proven for all n.
  A proof would require showing sigma(n)*phi(n) != n*tau(n) for all n > 6.
  This is likely provable but not trivial.
- The Erdos-Kac Z-score is computed using the asymptotic formula, which
  is imprecise for small n. The "1.86 sigma" should be interpreted loosely.
- Hardy-Ramanujan shows no special property for n=6. Included for
  completeness; negative result.
- The "enrichment" calculation assumes independence as null hypothesis,
  which is inappropriate given the algebraic relationship. It illustrates
  the correlation but should not be interpreted as a p-value.

## Next Steps

- Attempt proof that R(n) = 1 implies n in {1, 6} for all n.
  Strategy: for n > 6, show sigma(n)*phi(n) > n*tau(n) using known
  bounds on arithmetic functions.
- Investigate R(n) = k for integer k: which integers appear as R-values?
- Connect R(n) distribution to known results on sigma*phi vs n*tau
  in analytic number theory.
- Examine whether the R-growth formula for perfect numbers
  R = 2^(p-1)(2^(p-1)-1)/p has number-theoretic significance beyond
  this context.
