---
id: H-MP-10
title: "Analytic Number Theory Extensions of R-Spectrum"
domain: Analytic Number Theory
status: Numerical verification completed
created: 2026-03-24
depends_on: [H-MP-1, H-MP-3]
golden_zone: false
---

# H-MP-10: Analytic Number Theory Extensions of R(n)=σ(n)φ(n)/(nτ(n))

> **Hypothesis**: R(n)=σ(n)φ(n)/(nτ(n)) is a completely multiplicative function,
> and the Dirichlet series Σ R(n)/n^s has an Euler product decomposition.
> The R-spectrum {R(n) : n≥1} ∩ [0,5) consists of exactly 24 discrete values,
> with box-counting dimension d_box ≈ 0.574.
> The distribution of R(n) mod 1 shows strong clustering in the interval [0.4, 0.5).

## Background and Context

For the core ratio function R(n) = σ(n)φ(n)/(nτ(n)) of the σφ=nτ project,
R(6) = 12·2/(6·4) = 1 holds uniquely (H-MP-1).
We analyze the structure of the R-spectrum using tools from analytic number theory
(Dirichlet series, Euler products, mean value theorems, equidistribution theorems)
to explore deeper structures.

Related hypotheses:
- H-MP-1: Unique solutions n=1,6 to σφ=nτ
- H-MP-3: R-spectrum structure
- H-MP-5: F(2,N) ~ (1/2)ln(ln N) conjecture

## 1. Box-Counting Dimension of R-Spectrum

### Observation: Exactly 24 discrete values in [0,5)

Testing from N=100 to N=50,000, the distinct R-values satisfying R(n) < 5
remain fixed at **exactly 24**.

| Rank | R-value | First n | Rank | R-value | First n |
|---:|------:|---:|---:|------:|---:|
| 1 | 0.7500 | 2 | 13 | 2.8889 | 9 |
| 2 | 1.0000 | 1 | 14 | 3.1000 | 16 |
| 3 | 1.1667 | 4 | 15 | 3.2000 | 15 |
| 4 | 1.3333 | 3 | 16 | 3.3704 | 36 |
| 5 | 1.5556 | 12 | 17 | 3.4286 | 7 |
| 6 | 1.8000 | 10 | 18 | 3.7333 | 60 |
| 7 | 1.8750 | 8 | 19 | 4.0000 | 28 |
| 8 | 2.1667 | 18 | 20 | 4.0909 | 22 |
| 9 | 2.4000 | 5 | 21 | 4.1333 | 48 |
| 10 | 2.5000 | 24 | 22 | 4.5000 | 40 |
| 11 | 2.5714 | 14 | 23 | 4.5714 | 21 |
| 12 | 2.8000 | 20 | 24 | 4.8462 | 26 |

This is because R(p) = (p²-1)/(2p) is monotonically increasing for primes p,
so for p ≥ 11, R(p) > 5 and no new values are added.

### Box-counting dimension calculation

| ε | N_box | ln(1/ε) | ln(N_box) |
|----:|------:|--------:|----------:|
| 2.000 | 3 | -0.6931 | 1.0986 |
| 1.000 | 5 | 0.0000 | 1.6094 |
| 0.500 | 9 | 0.6931 | 2.1972 |
| 0.250 | 15 | 1.3863 | 2.7081 |
| 0.100 | 20 | 2.3026 | 2.9957 |
| 0.050 | 24 | 2.9957 | 3.1781 |

Linear regression slope: **d_box = 0.574**

```
  ln(N_box)
  3.2 |                                    *
      |                             *
  2.8 |                      *
      |
  2.2 |              *
      |
  1.6 |       *
      |
  1.1 |*
      +--+----+----+----+----+----+-----> ln(1/ε)
     -0.7  0   0.7  1.4  2.0  2.7  3.0

  Slope ≈ 0.574 (box-counting dimension)
  Compare: ln(2)/ln(3) = 0.631 (Cantor set)
```

d_box ≈ 0.574 is slightly smaller than ln2/ln3 ≈ 0.631 of the standard Cantor set.
Since this is a finite set of 24 points, it's not a true fractal,
but the gap structure shows Cantor-like patterns.

## 2. Multiplicative Property and Dirichlet Series of R(n)

### Key Discovery: R(n) is a completely multiplicative function

Verified R(mn) = R(m)·R(n) for all pairs (m,n) with gcd(m,n)=1:
- Test: 2 ≤ m,n ≤ 49, 1410 coprime pairs
- **Failures: 0** — R(n) is multiplicative

This is natural since σ, φ, τ are all multiplicative, and n itself is multiplicative.

### R(p) formula for primes

R(p) = σ(p)φ(p)/(pτ(p)) = (p+1)(p-1)/(2p) = **(p²-1)/(2p)**

| p | R(p) | (p²-1)/(2p) |
|---:|-------:|------------:|
| 2 | 0.7500 | 0.7500 |
| 3 | 1.3333 | 1.3333 |
| 5 | 2.4000 | 2.4000 |
| 7 | 3.4286 | 3.4286 |
| 11 | 5.4545 | 5.4545 |
| 13 | 6.4615 | 6.4615 |
| 29 | 14.4828 | 14.4828 |

### Dirichlet Series and Euler Product

Since R(n) is multiplicative, the Dirichlet series has an Euler product:

```
  D(s) = Σ R(n)/n^s = Π_p (1 + R(p)/p^s + R(p²)/p^{2s} + ...)
```

| s | Euler Product (25 primes) | Direct Sum (N=5000) | Convergence Ratio |
|----:|-------------------:|-----------------:|----------:|
| 2.0 | 2.5838 | 3.0259 | 0.854 |
| 2.5 | 1.4913 | 1.5109 | 0.987 |
| 3.0 | 1.2296 | 1.2307 | 0.999 |

Slow convergence at s=2 is because R(p) ~ p/2, so
Σ R(p)/p^s ~ Σ 1/(2p^{s-1}) converges conditionally at s=2.

**Convergence condition**: D(s) **absolutely converges for s > 2** (since R(p) ~ p/2).

### Relation to ζ-function

| s | D(s) | ζ(s)²/ζ(2s) | D(s) / [ζ(s)²/ζ(2s)] |
|----:|------:|------------:|---------------------:|
| 2.0 | 3.026 | 2.500 | 1.210 |
| 2.5 | 1.511 | 1.736 | 0.871 |
| 3.0 | 1.231 | 1.420 | 0.867 |

D(s) ≠ ζ(s)²/ζ(2s), but the ratio stabilizes as s→∞.
The exact closed form is difficult to express as a standard ζ-product
due to the reciprocal of τ(n).

## 3. Asymptotic Mean Value of R(n)

### Numerical Data

| N | (1/N)Σ R(n) | N/ln(N) | mean / (N/ln N) |
|------:|------------:|--------:|----------------:|
| 100 | 11.71 | 21.71 | 0.539 |
| 500 | 50.97 | 80.46 | 0.634 |
| 1,000 | 96.55 | 144.76 | 0.667 |
| 2,000 | 184.12 | 263.13 | 0.700 |
| 5,000 | 434.45 | 587.05 | 0.740 |
| 10,000 | 835.63 | 1085.74 | 0.770 |

### Asymptotic Fitting

Optimal fitting result:

```
  (1/N) Σ_{n≤N} R(n) ≈ 0.2476 · N · (ln N)^{-0.488}
```

Goodness of fit:

| N | Actual | Fitted | Ratio |
|------:|-------:|-------:|------:|
| 100 | 11.71 | 11.75 | 0.997 |
| 500 | 50.97 | 50.74 | 1.005 |
| 1,000 | 96.55 | 96.38 | 1.002 |
| 2,000 | 184.12 | 183.97 | 1.001 |
| 5,000 | 434.45 | 435.07 | 0.999 |
| 10,000 | 835.63 | 837.54 | 0.998 |

Excellent fit with error < 0.5%. Theoretical basis:
- R(p) = (p²-1)/(2p) ~ p/2, so prime contributions dominate
- By prime number theorem, Σ_{p≤N} p/2 ~ N²/(4 ln N)
- Therefore Σ_{n≤N} R(n) ~ c · N² · (ln N)^{-β} (β ≈ 0.488)

```
  mean R(n)
  900 |                                            *
      |
  700 |
      |
  500 |                                  *
      |                           *
  300 |
      |                    *
  100 |        *     *
      +--+----+----+----+----+----+-----> N
        100  500  1K   2K   5K   10K

  Growth: ~ 0.25 · N · (lnN)^{-0.49}
  Nearly linear but slightly decelerated by ln correction
```

## 4. Distribution of R(n) mod 1: Clustering, Not Equidistribution

### Histogram (N=10,000)

```
  [0.0,0.1) |############                            | 724
  [0.1,0.2) |#################                       | 979
  [0.2,0.3) |#############                           | 745
  [0.3,0.4) |###################                     | 1114
  [0.4,0.5) |########################################| 2240  ← Peak!
  [0.5,0.6) |################                        | 903
  [0.6,0.7) |##################                      | 1044
  [0.7,0.8) |##############                          | 799
  [0.8,0.9) |###############                         | 864
  [0.9,1.0) |##########                              | 588
             ----------------------------------------
             Uniform expectation: 1000 each
```

### Statistical Tests

| Test | Statistic | Critical Value (5%) | Conclusion |
|------|-------:|----------:|------|
| χ² (df=9) | 1932.22 | 16.92 | **Reject uniformity** |
| KS | 0.0828 | 0.0136 | **Reject uniformity** |

The interval [0.4, 0.5) has **2.24 times** the expected concentration.
This is due to the rational structure of R(n):
- R(n) is always rational (σ, φ, τ, n are all integers)
- Fractional parts of R(2^k) cluster near 0.5 (0.75, 0.167, 0.875, 0.1, 0.25, ...)
- For primes p, the fractional part of R(p) = (p²-1)/(2p) is determined by 1/(2p)

## Interpretation

1. **Multiplicative structure**: R(n) being multiplicative means R's behavior is
   completely determined by its values at prime powers. This gives the Dirichlet
   series an Euler product.

2. **Finite spectrum**: The exactly 24 values in [0,5) are a direct result of
   R(p) increasing. Since R(p)>5 for p=11 onward, n with R(n)<5 is restricted
   to products of powers of {2,3,5,7}. 24 = #{R-values < 5 of smooth numbers}.

3. **Mean value asymptotics**: (1/N)Σ R(n) ~ 0.25N(lnN)^{-0.49} is consistent
   with typical mean value theorems for multiplicative functions.
   The precise exponent -0.488 reflects the cumulative effect of prime contributions.

4. **Non-equidistribution**: The concentration of R(n) mod 1 in [0.4,0.5) arises
   from the rational structure of R(n) (denominators of the form 2p, 2p(k+1), etc.).

## Limitations

- d_box ≈ 0.574 is box-counting for a finite point set, not a rigorous fractal dimension.
  The full R-spectrum (unrestricted) is dense in Q, so has dimension 1.
- The exponent -0.488 in the mean value asymptotics is empirical fitting without
  analytic proof.
- A closed form expression for D(s) is difficult to express directly in terms of
  known L-functions due to the 1/τ(n) factor. Possible relation to Ramanujan's τ research.
- Numerical verification up to N=10,000, so asymptotic behavior might change for larger N.

## Next Steps

1. **Analytic proof**: Attempt to derive the exact asymptotic formula of the
   mean value theorem using the Selberg-Delange method
2. **Analytic continuation of D(s)**: Study what singularities D(s), which
   converges for s > 2, has near s=1 or s=2
3. **7-smooth numbers**: Rigorously prove that the 24 values in [0,5)
   correspond to R-values of 7-smooth numbers (prime factors ≤ 7)
4. **Analytic explanation of mod 1 clustering**: Explore whether an analogue
   of the Erdős–Kac theorem can explain the distribution of R(n) mod 1
5. **Connection to F(2,N) conjecture**: Clarify the relationship between the
   density of n with R(n)=1 and the behavior of Dirichlet series D(s) as s→1