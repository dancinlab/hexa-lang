---
id: H-MP-12
title: "R-map Dynamical Systems: Bifurcation, Lyapunov Spectrum, Symbolic Dynamics"
domain: Dynamical Systems
status: exploring
created: 2026-03-24
depends_on: [H-MP-01, H-MP-03]
golden_zone_dependent: false
tags: [sigma-phi, dynamical-systems, bifurcation, lyapunov, symbolic-dynamics]
---

# H-MP-12: R-map Dynamical Systems — Bifurcation, Lyapunov Spectrum, Symbolic Dynamics

> **Hypothesis**: The R(n) = σ(n)φ(n)/(nτ(n)) map and T(n) = nR(n) = σ(n)φ(n)/τ(n) map have
> non-trivial dynamical structure. n=6 is the unique stable fixed point, and
> in the parameterized T_α(n) = σ(n)^α · φ(n)^(1-α) / τ(n), bifurcation
> phenomena appear according to α.

## Background

In the σφ = nτ project, the ratio R(n) = σ(n)φ(n)/(nτ(n)) is a key indicator.
R(6) = 1 (fixed point property of perfect numbers) is known, and in R-chains (repeated application)
all chains are observed to converge in the R < n direction.

This hypothesis analyzes R and T as **discrete dynamical systems**.
Through ODE continuous interpolation, bifurcation parameters, Lyapunov exponents, and symbolic dynamics,
we explore the dynamic behavior of number-theoretic structures.

Related hypotheses:
- H-MP-01: σφ = nτ identity (basic structure)
- H-MP-03: R-chain convergence (starting point of dynamical behavior)

## 1. Orbit Structure of T(n) Map

Defining the T(n) = σ(n)φ(n)/τ(n) map as the integer map T_int(n) = round(T(n)),
we can trace orbits of the discrete dynamical system n → T_int(n).

### Fixed Points

| n | σ(n) | φ(n) | τ(n) | T(n) | T_int(n) | Fixed point? |
|---|------|------|------|------|----------|---------|
| 2 | 3 | 1 | 2 | 1.50 | 2 | YES (rounded) |
| 6 | 12 | 2 | 4 | 6.00 | 6 | YES (exact) |
| 28 | 56 | 12 | 6 | 112 | 112 | NO |

**In the range n = 2..10000, T_int has only two fixed points: n=2 and n=6.**
n=2 is a quasi-fixed point by rounding (T(2)=1.5→2), and n=6 is an exact fixed point (T(6)=6.0).

### Periodic Orbits

Full search result for n = 2..200: **No periodic orbits**. All orbits of T_int either diverge monotonically
or reach fixed points (n=2, n=6). No period-doubling phenomena observed.

### Representative Orbits

```
  n=3:  3 → 4 → 5 → 12 → 19 → 180 → 1456 → 99994 → ...  (divergent)
  n=6:  6 → 6  (fixed point)
  n=9:  9 → 26 → 126 → 936 → 32760 → ...  (divergent)
  n=28: 28 → 112 → 1190 → 62208 → ...  (divergent)
```

## 2. Escape Velocity (Chain Length)

Define the minimal k such that T^k(n) > 10000 starting from n as "escape time".

### Escape Time Distribution (n=2..100)

```
  steps | count | histogram
  ------+-------+--------------------------------------------------
  fixed |     2 | ##                                   (n=2, 6)
      2 |    48 | ################################################
      3 |    33 | #################################
      4 |    10 | ##########
      5 |     4 | ####                                 (n=5,7,8,10)
      6 |     1 | #                                    (n=4)
      7 |     1 | #                                    (n=3)
```

Most n exceed 10000 in just 2-3 steps. Only small primes (n=3,4,5) have
longer chains. Since R(n) > 1 holds for all n except n=2,
T(n) > n, and orbits **diverge exponentially**.

## 3. Symbolic Dynamics

Assign symbols according to the sign of R(n):
- U (Up): R(n) > 1
- D (Down): R(n) < 1
- F (Fixed): R(n) = 1

### Symbol Sequence (n=2..100)

```
  n=2-51:  D U U U F U U U U U U U U U U U U U U U U U U U U
           U U U U U U U U U U U U U U U U U U U U U U U U U
  n=52-100: U U U U U U U U U U U U U U U U U U U U U U U U U
            U U U U U U U U U U U U U U U U U U U U U U U U U

  Statistics (n=2..100):
    U (R>1):  97 (98.0%)
    D (R<1):   1 ( 1.0%)  — only n=2
    F (R=1):   1 ( 1.0%)  — only n=6

  Even for n=2..1000, R(n)<1 only for n=2!
```

**Key discovery**: The integer with R(n) < 1 is unique: n=2 (confirmed for n=2..1000).
This means σ(n)φ(n) < nτ(n) holds only for n=2.
R(2) = 3·1/(2·2) = 3/4.

## 4. Lyapunov Spectrum

### Single Exponent Λ(n) = ln(R(n))

R(n)=1 (n=6) with Λ=0 means **neutral stability**.
R(n)<1 (n=2) with Λ<0 means **contraction**.
R(n)>1 (all others) with Λ>0 means **expansion**.

```
  Lyapunov exponent Λ(n) = ln(R(n))    (* = special)
  ─────────────────────────────────────────────────
  n   R(n)       Λ(n)
  ─────────────────────────────────────────────────
  2   0.7500    -0.2877  *  Unique negative
  3   1.3333     0.2877     = -Λ(2) = ln(4/3)!
  4   1.1667     0.1542
  5   2.4000     0.8755
  6   1.0000     0.0000  *  Fixed point (Λ=0)
  7   3.4286     1.2321
  8   1.8750     0.6286
  ...
  28  4.0000     1.3863
  ...
  41  20.4878    3.0198
  47  23.4894    3.1565
```

**Note**: Λ(2) = -ln(4/3) ≈ -0.2877 and Λ(3) = +ln(4/3) ≈ +0.2877.
Exactly opposite sign! |Λ(2)| = Λ(3) = ln(4/3) = Golden Zone width.

### Chain-Average Lyapunov Exponent

```
  n  |  avg Λ along T-chain
  ---+--------------------------------------------------
   2 | <<                                          -0.29
   3 |  ##################                          2.38
   6 |                                               0.00
   7 |  ############################                 3.64
  28 |  ############################                 3.69
  37 |  ############################################ 6.62
  41 |  #####################################        5.35
  47 |  ######################################       5.40
```

For primes p, average Λ is large (R(p) = (p+1)(p-1)/2p ≈ p/2, exponential growth).

## 5. Bifurcation Analysis

### Parameterization: T_α(n) = σ(n)^α · φ(n)^(1-α) / τ(n)

Find α* solving the fixed point condition T_α(n) = n:
(σ/φ)^α = nτ/φ → **α* = ln(nτ/φ) / ln(σ/φ)**

### Critical α* Values

| n | σ | φ | τ | α* | Note |
|---|---|---|---|----|----|
| 2 | 3 | 1 | 2 | 1.2619 | |
| 3 | 4 | 2 | 2 | 1.5850 | |
| 6 | 12 | 2 | 4 | **1.3869** | Perfect number |
| 12 | 28 | 4 | 6 | 1.4854 | |
| 28 | 56 | 12 | 6 | **1.7132** | Perfect number |
| Prime p | p+1 | p-1 | 2 | ~ln(p)/ln(2) → ∞ | Diverges as p increases |

### α* Distribution (n=2..50)

```
  α*   | count | histogram
  -----+-------+----------------------------------
  1.2  |     1 | #
  1.4  |     3 | ###
  1.6  |    13 | #############        ← Mode
  1.8  |    10 | ##########
  2.0  |     3 | ###
  2.2  |     4 | ####
  2.6  |     1 | #
  3.0  |     2 | ##
```

**α* for primes diverges**: If p is prime, then σ(p)=p+1, φ(p)=p-1, so
α*(p) = ln(p) / ln((p+1)/(p-1)) ≈ p·ln(p)/2 → ∞.
That is, primes cannot be fixed by T_α for any α.

### T_α Values at n=6

| α | T_α(6) | T_α(6)/6 | Behavior |
|---|--------|----------|------|
| 0.0 | 0.50 | 0.083 | Strong contraction |
| 0.3 | 0.86 | 0.143 | Contraction |
| 0.5 | 1.22 | 0.204 | Weak expansion |
| 0.7 | 1.75 | 0.292 | Expansion |
| 1.0 | 3.00 | 0.500 | σ/τ |
| **1.387** | **6.00** | **1.000** | **Fixed point** |

At α = ln(12)/ln(6) ≈ 1.3869, exactly T_α(6) = 6.
This value is ln(12)/ln(6) = ln(2·6)/ln(6) = 1 + ln(2)/ln(6).

## 6. ODE Continuous Interpolation

Extending dx/dt = σ(x)/x - τ(x) to continuous variable x,
fixed points satisfy σ(x)/x = τ(x).

At integer points:
- x=6: σ(6)/6 = 12/6 = 2, τ(6) = 4. σ/x ≠ τ, so not an ODE fixed point.
- ODE fixed points depend on the specific interpolation method and generally
  do not coincide with fixed points of the number-theoretic T map.

This ODE approach has limitations since continuous interpolation of σ, τ is not natural.
Analysis as a number-theoretic dynamical system is more appropriate.

## Interpretation

1. **Uniqueness of n=6**: The exact fixed point of T_int map is unique: n=6.
   n=2 is a quasi-fixed point by rounding. Confirmed for n=2..10000.

2. **Universal divergence**: All orbits except n=2, 6 diverge monotonically.
   No periodic orbits, no period-doubling. Not chaos but **monotonic expansion**.

3. **Symmetry of Λ(2) and Λ(3)**: |Λ(2)| = Λ(3) = ln(4/3) = Golden Zone width.
   This reflects the arithmetic fact R(2)·R(3) = (3/4)·(4/3) = 1, but
   the exact coincidence with the Golden Zone width is noteworthy.

4. **Instability of primes**: Since α* diverges at primes p, primes cannot
   be fixed points in any member of the T_α family (for finite α).

5. **Rarity of R < 1**: n=2 uniquely has R(n) < 1. This suggests σ(n)φ(n) ≥ nτ(n)
   always holds for n ≥ 3 (proof needed).

## Limitations

- ODE continuous interpolation is formal since there's no natural continuous extension of σ, τ.
- T_int map depends on round(); using floor or ceil gives different results.
- α* analysis is individual values for each n, not a global bifurcation structure.
- Observation that n=2 is the unique R < 1 is confirmed only up to 1000. Proof incomplete.

## Verification Directions

1. **Prove σ(n)φ(n) ≥ nτ(n) for n ≥ 3**: If true, uniqueness of n=2 is confirmed.
   Try proving inequality by classifying into primes/prime powers/composites.

2. **Pattern in α*(perfect numbers)**: Explore regularity in α* values for perfect numbers 6, 28, 496.
   α*(6) = ln(12)/ln(6), α*(28) = ln(14)/ln(14/3). General formula?

3. **Floor-based T map**: Define T_floor(n) = floor(σφ/τ) instead of round.
   Do fixed points/periodic orbits change?

4. **Generalize R(2)·R(3) = 1**: Are there more (n,m) pairs with R(n)·R(m) = 1?

5. **Asymptotic behavior of Λ(n)**: For primes Λ(p) ≈ ln(p/2). Pattern for composites?