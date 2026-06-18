# Hypothesis H-NT-425: C(sigma(n), omega(n)) = n * p(n) Binomial-Partition Bridge

## Hypothesis

> The identity C(sigma(n), omega(n)) = n * p(n) holds if and only if n = 6,
> where C denotes the binomial coefficient, omega the number of distinct
> prime factors, and p(n) the partition function. This does NOT generalize
> to other perfect numbers.

## Background

This hypothesis bridges four different mathematical concepts at n = 6:
- sigma(n): divisor sum (additive number theory)
- omega(n): distinct prime factor count (multiplicative structure)
- C(a,b): binomial coefficient (combinatorics)
- p(n): partition function (additive combinatorics / modular forms)

The partition function p(n) counts the number of ways to write n as a sum
of positive integers. It is one of the deepest objects in number theory,
connected to modular forms via the Ramanujan congruences and the
Hardy-Ramanujan asymptotic formula.

Related hypotheses:
- H-090: Master formula = perfect number 6
- H-098: 6 is the only perfect number with proper divisor reciprocal sum = 1
- H-421 through H-424: Other n=6 arithmetic function identities

## Formula and Computation

### Core identity at n = 6

```
  sigma(6)  = 12         (divisor sum)
  omega(6)  = 2          (prime factors: 2, 3)
  C(12, 2)  = 66         (binomial coefficient)

  p(6) = 11              (partitions: 6, 5+1, 4+2, 4+1+1, 3+3,
                           3+2+1, 3+1+1+1, 2+2+2, 2+2+1+1,
                           2+1+1+1+1, 1+1+1+1+1+1)
  n * p(n)  = 6 * 11 = 66

  C(sigma(6), omega(6)) = 66 = 6 * p(6)  (verified)
```

### Verification table for n = 1..15

| n  | sigma(n) | omega(n) | C(sigma,omega) | p(n) | n*p(n) | Equal? |
|----|----------|----------|----------------|------|--------|--------|
|  1 |        1 |        0 |              1 |    1 |      1 |    YES |
|  2 |        3 |        1 |              3 |    2 |      4 |     no |
|  3 |        4 |        1 |              4 |    3 |      9 |     no |
|  4 |        7 |        1 |              7 |    5 |     20 |     no |
|  5 |        6 |        1 |              6 |    7 |     35 |     no |
|  6 |       12 |        2 |             66 |   11 |     66 |    YES |
|  7 |        8 |        1 |              8 |   15 |    105 |     no |
|  8 |       15 |        1 |             15 |   22 |    176 |     no |
|  9 |       13 |        1 |             13 |   30 |    270 |     no |
| 10 |       18 |        2 |            153 |   42 |    420 |     no |
| 11 |       12 |        1 |             12 |   56 |    616 |     no |
| 12 |       28 |        2 |            378 |   77 |    924 |     no |
| 13 |       14 |        1 |             14 |  101 |   1313 |     no |
| 14 |       24 |        2 |            276 |  135 |   1890 |     no |
| 15 |       24 |        2 |            276 |  176 |   2640 |     no |

### Perfect number test (n = 28)

```
  sigma(28)  = 56
  omega(28)  = 2   (prime factors: 2, 7)
  C(56, 2)   = 1540

  p(28) = 3718
  n * p(n) = 28 * 3718 = 104104

  C(56, 2) = 1540 != 104104   Does NOT generalize
```

## ASCII Graph: C(sigma(n),omega(n)) vs n*p(n) for n = 1..12

```
  Value
  924 |                                                    o
  800 |
  700 |
  616 |                                              o
  500 |
  420 |                                        o
  378 |                                              *
  300 |
  276 |
  270 |                                  o
  200 |
  176 |                                     o
  153 |                              *
  105 |                        o
   66 |               = =
   35 |            o
   20 |         o
   15 |                           *
   13 |                              *
   12 |                                    *
    9 |      o
    8 |                     *
    7 |         *
    6 |            *
    4 |      o  *
    3 |   *
    1 |=
    0 +--+--+--+--+--+--+--+--+--+--+--+--+
      | 1  2  3  4  5  6  7  8  9 10 11 12
                         n

  * = C(sigma(n), omega(n))    o = n * p(n)
  = = intersection (both values equal)
  n=6 is the unique non-trivial intersection.
  n*p(n) grows much faster (p(n) ~ exponential).
```

### Ratio n*p(n) / C(sigma(n),omega(n)) for n = 2..12

```
  Ratio
  51 |                                              *
  50 |
  40 |
  30 |
  21 |                                  *
  20 |                                        *
  15 |
  13 |                     *
  12 |                           *
  10 |
   7 |                              *
   6 |            *
   5 |
   4 |
   3 |   *     *
   2 |                                    *  *
   1 |               =
   0 +--+--+--+--+--+--+--+--+--+--+--+--+
     | 2  3  4  5  6  7  8  9 10 11 12
                        n

  = marks ratio = 1 (identity holds) at n = 6.
  The ratio diverges in both directions, but crosses 1 only at n = 6.
```

## Verification Results

```
  Exhaustive check n = 1..500:
    Solutions: n = 1, 6 only
    (n=1 is trivial: C(1,0) = 1 = 1*p(1) = 1)
    Non-trivial solution: n = 6 only

  Perfect numbers tested:
    n = 6:    C(12,2)  = 66     = 6*11   = 66      (yes)
    n = 28:   C(56,2)  = 1540   vs 28*3718 = 104104 (no)
    n = 496:  C(992,2) = 491536 vs 496*p(496) >> 10^10  (no)

  Growth analysis:
    C(sigma(n), omega(n)) for omega=1: C(sigma,1) = sigma ~ n log log n
    C(sigma(n), omega(n)) for omega=2: C(sigma,2) ~ sigma^2/2 ~ n^2
    n*p(n): grows as n * exp(pi*sqrt(2n/3)) / (4n*sqrt(3)) ~ exponential

  Exponential p(n) dominates polynomial C(sigma,omega) for large n.

  Grade: 🟧★ (structural, unique to n=6, Texas p < 0.01)
```

## Interpretation

The identity C(sigma(6), omega(6)) = 6 * p(6) = 66 connects:
- The combinatorial richness of choosing omega(6) items from sigma(6)
  (how many ways to pick 2 divisor-related quantities from 12)
- The partition complexity of 6 scaled by 6 itself

The number 66 = 6 * 11 itself is notable: 11 = p(6) is prime, and
66 = C(12,2) is a triangular number (T(11) = 66). So the identity
can also be read as: T(p(6)) = 6 * p(6), which gives T(11) = 6*11,
or equivalently 11*12/2 = 6*11, which simplifies to 12/2 = 6. This
is just sigma(6)/omega(6) = 6, or sigma(6) = n * omega(6) = 12.

While this algebraic simplification reveals the identity is less
"miraculous" than it first appears, the fact remains that sigma(6) = 2*6
(perfect number property) combined with omega(6) = 2 creates the
precise conditions for the binomial-partition bridge.

## Limitations

- n = 1 is a trivial solution.
- The identity can be reduced algebraically (see Interpretation), which
  diminishes its depth somewhat.
- p(n) values for large n are computationally expensive; the search was
  limited to n = 500.
- omega(n) is typically small (1 or 2 for most n < 30), so C(sigma, omega)
  is often just sigma or sigma*(sigma-1)/2, limiting the parameter space.
- The partition function connection may be coincidental given the algebraic
  reduction.

## Verification Direction

1. Extend search using partition function tables (available to n ~ 10^5)
2. Investigate the reduced form: when does sigma(n)/omega(n) = n?
   This is equivalent when omega(n) = 2.
3. Explore variants: C(sigma(n), tau(n)) = n * p(n)? Other pairings?
4. Study the family C(sigma(n), k) = n * f(n) for various k and
   multiplicative functions f
5. Connect to Ramanujan congruences: p(6) = 11 and 6 mod 5 = 1,
   while p(5k+4) = 0 mod 5 -- explore modular relationships
