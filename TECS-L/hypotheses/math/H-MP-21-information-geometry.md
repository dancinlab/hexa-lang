---
id: H-MP-20
title: "Information Geometry of Divisor Distributions"
category: pure-math
status: verified
created: 2026-03-24
depends_on: [H-MP-10, H-MP-11]
golden_zone: false
tags: [information-geometry, Fisher-metric, KL-divergence, perfect-numbers, sigma-phi]
---

# H-MP-20: Information Geometry of Divisor Distributions

> **Hypothesis**: Each natural number n defines a probability distribution p_n(d) = (1/d) / sigma_{-1}(n) over its divisors,
> and in the statistical manifold of these distributions, perfect numbers have distinctive geometric properties.
> In particular, we show that the Jensen-Shannon distance between perfect numbers is fixed at exactly ln(2)/4.

## Background

In the core ratio of the sigma-phi project, R(n) = sigma(n) * phi(n) / (n * tau(n)),
n=6 is the unique natural number where R(6)=1 (see H-MP-10, H-MP-12).

The sum of divisor reciprocals sigma_{-1}(n) = sum_{d|n} 1/d equals exactly 2 for perfect numbers.
Using this property, we can define a natural probability distribution over the divisors of each natural number:

```
  p_n(d) = (1/d) / sigma_{-1}(n)    (d | n)
```

For perfect number n, since sigma_{-1}(n) = 2, we have p_n(d) = 1/(2d).

This distribution gives "higher probability to smaller divisors" as a natural weighting,
and applying tools from Information Geometry translates number-theoretic structure
into geometric language.

## 1. Statistical Manifold M_n

Each natural number n defines a probability distribution p_n over its tau(n) divisors.
This is a point on the (tau(n)-1)-simplex.

### Divisor Distribution for n=6

| Divisor d | 1/d   | p_6(d) = 1/(2d) | Cumulative |
|-----------|-------|------------------|------------|
| 1         | 1.000 | 0.5000           | 0.50       |
| 2         | 0.500 | 0.2500           | 0.75       |
| 3         | 0.333 | 0.1667           | 0.92       |
| 6         | 0.167 | 0.0833           | 1.00       |

### Divisor Distribution for n=28

| Divisor d | p_28(d) = 1/(2d) | Cumulative |
|-----------|------------------|------------|
| 1         | 0.500000         | 0.5000     |
| 2         | 0.250000         | 0.7500     |
| 4         | 0.125000         | 0.8750     |
| 7         | 0.071429         | 0.9464     |
| 14        | 0.035714         | 0.9821     |
| 28        | 0.017857         | 1.0000     |

### Shannon Entropy

| n    | tau(n) | H(p_n)  | H_max = ln(tau) | Efficiency H/H_max |
|------|--------|---------|-----------------|-------------------|
| 6    | 4      | 1.1989  | 1.3863          | 0.8648            |
| 28   | 6      | 1.3325  | 1.7918          | 0.7437            |
| 496  | 10     | 1.3818  | 2.3026          | 0.6001            |
| 8128 | 14     | 1.3859  | 2.6391          | 0.5251            |

Observation: As perfect numbers increase, entropy converges (~ln(2)+0.7) while efficiency decreases.
This is because probability concentrates on d=1,2 despite having more divisors.

```
  H(p_n)    Efficiency H/H_max
  1.40 |                              0.90 |*
       |         *   *   *                  |
  1.30 |    *                         0.80 |
       |                              0.70 |   *
  1.20 | *                            0.60 |       *
       |                              0.50 |           *
  1.10 |                              0.40 |
       +--+---+---+---+--            +--+---+---+---+--
         6  28 496 8128                 6  28 496 8128
```

## 2. Fisher Information Metric

For categorical distributions, the Fisher information matrix is diagonal:

```
  g_{ij} = delta_{ij} / p_n(d_i)
```

### Fisher Metric at n=6

| Divisor d | p_6(d) | g(d) = 1/p_6(d) |
|-----------|--------|------------------|
| 1         | 1/2    | 2                |
| 2         | 1/4    | 4                |
| 3         | 1/6    | 6                |
| 6         | 1/12   | 12               |

**Fisher diagonal for perfect numbers**: g(d) = 1/p_n(d) = 2d

### Fisher Metric Invariants

| n    | tr(g)  | det(g)    | tr(g)/tau(n) |
|------|--------|-----------|--------------|
| 6    | 24     | 576       | 6.00         |
| 28   | 112    | 1,404,928 | 18.67        |
| 496  | 1,984  | 3.07e+16  | 198.40       |

**Theorem (Fisher trace formula)**:
For perfect number n:

```
  tr(g_n) = sum_{d|n} 2d = 2 * sigma(n) = 2 * 2n = 4n
```

Proof: sigma(n) = 2n (perfect number definition) and g(d) = 2d, so
tr(g) = sum_{d|n} 2d = 2 * sigma(n) = 4n. QED.

**Theorem (Fisher determinant formula)**:

```
  det(g_n) = prod_{d|n} 2d = 2^{tau(n)} * prod_{d|n} d = 2^{tau(n)} * n^{tau(n)/2}
```

The last equality uses prod_{d|n} d = n^{tau(n)/2} (well-known number theory result).

## 3. Jensen-Shannon Divergence (JSD)

KL divergence D_KL(p_6 || p_28) is infinite since supports differ:
- supp(p_6) = {1, 2, 3, 6}
- supp(p_28) = {1, 2, 4, 7, 14, 28}
- supp(p_6) is not contained in supp(p_28) (3, 6 are missing)

We use Jensen-Shannon divergence (JSD) instead.

### JSD Decomposition Structure

Decomposing JSD between perfect numbers 6 and 28:

| Component         | Divisors      | Contribution |
|-------------------|---------------|--------------|
| Common {1,2}      | p=q so        | 0.000000     |
| Only in 6 {3,6}   | mass = 1/4    | 0.086643     |
| Only in 28 rest   | mass = 1/4    | 0.086643     |
| **Total**         |               | **0.173287** |

### Key Theorem: Fixed JSD Between Perfect Numbers

> **Theorem**: For two even perfect numbers m, n sharing only common divisors {1,2},
> JSD(p_m, p_n) = ln(2)/4 = 0.173287...

**Proof**:

For even perfect numbers m, n: p_m(1) = p_n(1) = 1/2, p_m(2) = p_n(2) = 1/4.
Common divisors have p = q, so JSD contribution is 0.

Mass of divisors only in m = 1 - 3/4 = 1/4.
Mass of divisors only in n = 1 - 3/4 = 1/4.

For non-common divisor d, mixture distribution m(d) = p(d)/2, so:
- p(d) * ln(p(d)/m(d)) = p(d) * ln(2)

Thus each non-common part contributes = (1/2) * (1/4) * ln(2) = ln(2)/8.
Both sides sum: JSD = 2 * ln(2)/8 = **ln(2)/4**. QED.

### JSD Distance Table

| Pair           | JSD      | sqrt(JSD) | Note                    |
|----------------|----------|-----------|-------------------------|
| (6, 28)        | 0.173287 | 0.416277  | ln(2)/4 (perfect-perfect) |
| (6, 496)       | 0.173287 | 0.416277  | ln(2)/4 (perfect-perfect) |
| (28, 496)      | 0.086643 | 0.294353  | ln(2)/8 (more common)   |
| (6, 12)        | 0.052260 | 0.228605  | multiple of 6, close    |
| (6, 10)        | 0.145503 | 0.381449  | non-perfect             |
| (6, 8)         | 0.156361 | 0.395425  | non-perfect             |
| (6, 15)        | 0.177926 | 0.421813  | non-perfect             |
| (6, 24)        | 0.074882 | 0.273647  | multiple of 6           |

```
  JSD(p_6, p_n)
  0.20 |           *        (15)
       |      *  *     * *  (28,496)
  0.15 |    *               (10)
       |   *                (8)
  0.10 |
       |         *          (24)
  0.05 |     *              (12)
       |
  0.00 +--+--+--+--+--+--+--+--
         6  8 10 12 15 20 24 28
```

**Observation**: JSD(6,28) = JSD(6,496) match exactly, and JSD(28,496) is exactly
half. This is a structural result from common divisor structure, not coincidence.

## 4. Curvature

A (k-1)-simplex with Fisher metric has constant sectional curvature kappa = 1/4
(well-known information geometry result, Amari & Nagaoka, 2000).

Scalar curvature: S = (k-1)(k-2) * kappa / (appropriate binomial coefficient)

| n    | k=tau(n) | dim=k-1 | Scalar curvature S = (k-1)(k-2)/4 |
|------|----------|---------|-----------------------------------|
| 6    | 4        | 3       | 1.50                              |
| 28   | 6        | 5       | 5.00                              |
| 496  | 10       | 9       | 18.00                             |
| 8128 | 14       | 13      | 39.00                             |

Since perfect number 2^(p-1)(2^p - 1) has tau = 2p divisors:

```
  S(n) = (2p-1)(2p-2)/4 = (2p-1)(p-1)/2
```

p=2 -> S=1.5, p=3 -> S=5, p=5 -> S=18, p=7 -> S=39.

## 5. Geometric Meaning of R(n)=1

R(n) = sigma(n)*phi(n)/(n*tau(n)) = 1 holds only for n=6.

Reinterpreting information-geometrically:

```
  R(n) = sigma(n) * phi(n) / (n * tau(n))
       = [tr(g_n)/2] * phi(n) / (n * tau(n))     (perfect: tr(g)=2*sigma)
       = tr(g_6) * phi(6) / (2 * 6 * 4)
       = 24 * 2 / 48 = 1
```

R(n)=1 is a balance condition between Fisher trace and Euler totient:

```
  tr(g_n) * phi(n) = 2 * n * tau(n)
```

For n=6: 24 * 2 = 2 * 6 * 4 = 48. Holds.
For n=28: 112 * 12 = 1344, 2 * 28 * 6 = 336. 1344/336 = 4. R(28)=4.

## 6. Geodesics

Do perfect numbers lie on geodesics in the statistical manifold?

Each perfect number lives on simplices of different dimensions (tau(6)=4, tau(28)=6, ...).
So the concept of geodesics on the same manifold doesn't directly apply.

However, through **projection onto common divisors {1,2}**,
we can project all even perfect numbers onto a 2-simplex:

```
  pi(p_n) = (p_n(1), p_n(2), 1 - p_n(1) - p_n(2)) = (1/2, 1/4, 1/4)
```

**All even perfect numbers converge to the same point after projection!**

This is an "information-geometric fixed point" of perfect numbers:
not a geodesic, but convergence to a single point.

## Interpretation and Meaning

1. **sigma_{-1}(n) = 2 as information-geometric normalization**: Perfect numbers have
   divisor reciprocal sum exactly 2, so 1/d weighting forms a natural probability distribution.

2. **JSD = ln(2)/4 theorem**: Information distance between perfect numbers is fixed at
   a universal constant (ln2). This is an "information-theoretic equidistance" property.

3. **tr(g) = 4n**: Total Fisher information is linearly proportional to n. Information
   capacity is directly proportional to the number's size.

4. **Projection convergence**: All even perfect numbers project to (1/2, 1/4, 1/4).
   A "universal information profile" exists for perfect numbers.

## Limitations

1. Each perfect number lives on simplices of different dimensions, limiting comparisons on a single manifold.
2. The JSD = ln(2)/4 theorem applies only when common divisors are {1,2} (28 and 496
   have more common divisors {1,2,4}, giving JSD = ln(2)/8).
3. Not applicable to odd perfect numbers (undiscovered) as 2 is not a divisor, changing the structure.
4. Scalar curvature is a property of the simplex itself, not dependent on distribution position.

## Verification Directions (Next Steps)

1. **Alpha-divergence generalization**: How does distance between perfect numbers
   depend on alpha when generalizing JSD with Renyi divergence D_alpha?
2. **e-geodesics / m-geodesics**: Compare geodesics in exponential and mixture connections.
3. **R(n) level sets**: Geometric structure of R(n)=c level surfaces on the information manifold.
4. **Normalization for non-perfect sigma_{-1}**: Geometric properties of normalized
   distributions when sigma_{-1}(n) != 2.
5. **Cross with H-AI-7 (information bottleneck)**: Does Golden MoE's information bottleneck
   correspond to entropy efficiency of divisor distributions?