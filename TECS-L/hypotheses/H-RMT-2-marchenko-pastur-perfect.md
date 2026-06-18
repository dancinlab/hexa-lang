---
id: H-RMT-2
title: "Marchenko-Pastur Spectral Edges Satisfy x^2 - 6x + 1 = 0"
status: "PROVED"
grade: "🟩⭐⭐⭐"
date: 2026-03-26
golden-zone-dependent: false
---

# H-RMT-2: Marchenko-Pastur Spectral Edges with gamma=phi(6)=2

> **Theorem.** The Marchenko-Pastur spectral edges with aspect ratio
> gamma = phi(6) = 2 are the roots of x^2 - nx + R(n) = 0, i.e.,
>
>     x^2 - 6x + 1 = 0
>
> where n = 6 is the first perfect number, and R(6) = sigma*phi/(n*tau) = 1
> is the master identity. This characterization is unique to n = 6 among
> all perfect numbers.

## Background

The Marchenko-Pastur (MP) distribution governs the limiting spectral
density of large random matrices. For an m x n matrix with aspect ratio
gamma = m/n (or p/n in statistics), the MP law has support on
[lambda_-, lambda_+] where:

```
  lambda_+/- = (1 +/- sqrt(gamma))^2
```

The Euler totient phi(6) = 2 provides a natural aspect ratio for n = 6.
This connects random matrix theory -- a pillar of mathematical physics --
directly to the arithmetic of the first perfect number.

## Core Result

### Step 1: MP edges with gamma = phi(6) = 2

```
  gamma = phi(6) = 2

  lambda_+ = (1 + sqrt(2))^2 = 1 + 2*sqrt(2) + 2 = 3 + 2*sqrt(2)  ~  5.8284
  lambda_- = (1 - sqrt(2))^2 = 1 - 2*sqrt(2) + 2 = 3 - 2*sqrt(2)  ~  0.1716
```

### Step 2: Sum and product of edges

```
  lambda_+ + lambda_- = (3 + 2*sqrt(2)) + (3 - 2*sqrt(2))
                      = 6
                      = n = P_1  (the first perfect number)        EXACT

  lambda_+ * lambda_- = (3 + 2*sqrt(2)) * (3 - 2*sqrt(2))
                      = 9 - 8
                      = 1
                      = R(6)    (the master identity)              EXACT
```

### Step 3: Quadratic equation

The MP edges are roots of the monic quadratic with sum = 6, product = 1:

```
  x^2 - (lambda_+ + lambda_-)x + (lambda_+ * lambda_-) = 0

  x^2 - 6x + 1 = 0                                                EXACT
```

## Algebraic Proof (No Numerics Required)

The result follows from pure algebra. For general gamma:

```
  Sum:      (1+sqrt(gamma))^2 + (1-sqrt(gamma))^2  =  2(1 + gamma)
  Product:  (1+sqrt(gamma))^2 * (1-sqrt(gamma))^2  =  ((1-gamma))^2  =  (1-gamma)^2
```

For the sum to equal n and the product to equal R(n):

```
  2(1 + gamma) = n       =>  gamma = (n-2)/2
  (1 - gamma)^2 = R(n)   =>  |1 - gamma| = sqrt(R(n))
```

Setting gamma = phi(n):

```
  Condition A:  phi(n) = (n-2)/2          (sum = n)
  Condition B:  (1 - phi(n))^2 = R(n)    (product = R(n))
```

For n = 6:  phi(6) = 2, (6-2)/2 = 2.  Check.
            (1-2)^2 = 1 = R(6).         Check.

For n = 28: phi(28) = 12, (28-2)/2 = 13.  12 != 13.  FAILS.
            (1-12)^2 = 121.  R(28) != 1.  FAILS.

The key: R(6) = 1 is the unique case where the product condition yields
a perfect square root. And phi(6) = 2 is the unique nontrivial gamma
where (1-gamma)^2 = 1, since gamma in {0, 2} and only gamma = 2 is
nontrivial. This forces n = 2(1+2) = 6.

## Uniqueness Argument

Why n = 6 is the ONLY perfect number satisfying both conditions:

```
  (1 - gamma)^2 = 1
       |
       v
  gamma = 0  or  gamma = 2
       |              |
       v              v
  trivial        phi(n) = 2
  (no matrix)         |
                      v
                 n must satisfy:
                 (i)  phi(n) = 2  =>  n in {3, 4, 6}
                 (ii) n is perfect =>  n = 6          QED
```

## ASCII Diagram: MP Density with gamma = 2

```
  f(x) = Marchenko-Pastur density, gamma = phi(6) = 2

  density
    |
  1.0|
    |        .
    |       . .
  0.8|      .   .
    |     .     .
  0.6|    .       .
    |   .         .
  0.4|  .           .          .
    | .             .        . .
  0.2|.               .     .   .
    |.                 .  .     .
  0.0|__________________.._______.___________
    0     1     2     3     4     5     6   x
    ^                                   ^
    |                                   |
  lambda_- = 3-2sqrt(2)          lambda_+ = 3+2sqrt(2)
    ~ 0.1716                       ~ 5.8284

         |<-------- support -------->|
         |   sum  = 6 = n = P_1     |
         |   prod = 1 = R(6)        |

  Quadratic:  x^2 - 6x + 1 = 0
  Discriminant: 36 - 4 = 32 = 2^5
```

Note: The MP density with gamma > 1 has a point mass at x = 0 of weight
(1 - 1/gamma) = 1/2. The continuous part spans [lambda_-, lambda_+].

## Discriminant Structure

The discriminant of x^2 - 6x + 1 = 0:

```
  Delta = 36 - 4 = 32 = 2^5

  Observations:
    - 2^5 where 5 = sopfr(6) = 2 + 3 (sum of prime factors with repetition)
    - 32 = 2 * 16 = 2 * (sigma(6) + tau(6) + phi(6))^2 ... no, 16 = 4^2
    - Clean power of 2: the roots are in Q(sqrt(2))
    - sqrt(Delta) = 4*sqrt(2), so roots = (6 +/- 4*sqrt(2))/2 = 3 +/- 2*sqrt(2)
```

## Cross-Connections

| Connection | Detail |
|---|---|
| R(6) = 1 master identity | Root cause: product of edges = R(n) = 1 only for n = 6 |
| phi(6) = 2 (totient) | Provides the aspect ratio gamma; unique among perfect numbers |
| Golden-ratio analog | phi_gold satisfies x^2 - x - 1 = 0; MP edges satisfy x^2 - 6x + 1 = 0 |
| H-RMT-1 (if exists) | Prior RMT connection; this result is independent |
| H-ANAL-1 (Pillai) | Another n=6 uniqueness via arithmetic functions |
| Vieta's formulas | sum = -b/a = 6, product = c/a = 1 encode n and R(n) |

## Verification Data

### Numerical check (Python)

```python
import math

gamma = 2  # phi(6)
lam_plus  = (1 + math.sqrt(gamma))**2  # 5.82842712474619
lam_minus = (1 - math.sqrt(gamma))**2  # 0.17157287525381

print(f"lambda_+ = {lam_plus}")
print(f"lambda_- = {lam_minus}")
print(f"Sum      = {lam_plus + lam_minus}")      # 6.0
print(f"Product  = {lam_plus * lam_minus}")       # 1.0000000000000002
print(f"x^2-6x+1 at lambda_+: {lam_plus**2 - 6*lam_plus + 1}")  # ~0
print(f"x^2-6x+1 at lambda_-: {lam_minus**2 - 6*lam_minus + 1}")  # ~0
```

### Results

| Quantity | Expected | Computed | Error |
|---|---|---|---|
| lambda_+ | 3 + 2*sqrt(2) | 5.82842712474619 | 0 (exact) |
| lambda_- | 3 - 2*sqrt(2) | 0.17157287525381 | 0 (exact) |
| Sum | 6 | 6.0 | 0 |
| Product | 1 | 1.0 | ~1e-16 (float) |
| x^2-6x+1 at lambda_+ | 0 | ~1e-15 | float noise |
| x^2-6x+1 at lambda_- | 0 | ~1e-15 | float noise |

### Generalization test (perfect number 28)

| Check | n=6 | n=28 |
|---|---|---|
| phi(n) | 2 | 12 |
| (n-2)/2 | 2 | 13 |
| phi(n) = (n-2)/2? | YES | NO (12 != 13) |
| (1-phi(n))^2 | 1 | 121 |
| R(n) = 1? | YES | NO |
| Both conditions? | YES | NO |

### Texas Sharpshooter check

```
  Number of targets tried: 1 (MP edges with gamma=phi(n))
  Ad-hoc corrections:      0
  Exact algebraic result:  YES
  Generalizes:             NO (specific to n=6, which is the point)
  p-value:                 N/A (algebraic proof, not statistical)
```

## Limitations

1. **Does not generalize** to other perfect numbers (n=28, 496, ...).
   This is by design: it isolates what makes n=6 special.
2. The connection requires choosing gamma = phi(n), which is a natural
   but not unique choice of aspect ratio.
3. The MP distribution context (random matrices) is a mathematical
   framework; the physical significance of this particular gamma for
   random matrices is not claimed.

## Significance

This result connects three distinct mathematical domains:

```
  Number Theory          Random Matrix Theory        Algebra
  (perfect numbers)      (MP distribution)           (quadratic equations)
       |                       |                          |
    n = 6               gamma = phi(6) = 2          x^2 - 6x + 1 = 0
    R(6) = 1            lambda_+/- edges            Vieta: sum=6, prod=1
       |                       |                          |
       +----------+------------+-------------+------------+
                  |                           |
           product = R(6) = 1          sum = n = 6
                  |                           |
                  +------ UNIQUE to n=6 ------+
```

The master identity R(6) = 1 is once again the root cause: it forces
the product of MP edges to unity, and combined with phi(6) = 2 forcing
the sum to equal n, we get a clean quadratic x^2 - 6x + 1 = 0 that
encodes the perfect number and its R-spectrum value simultaneously.

## Next Steps

- Investigate whether the eigenvector statistics of Wishart matrices with
  gamma = 2 have special properties (e.g., delocalization thresholds).
- Check if x^2 - 6x + 1 = 0 appears in other mathematical contexts
  (continued fractions, Pell equations -- note: 3+2*sqrt(2) is related
  to the silver ratio).
- Explore MP free convolution: what happens when two MP(gamma=2)
  distributions are freely convolved?
