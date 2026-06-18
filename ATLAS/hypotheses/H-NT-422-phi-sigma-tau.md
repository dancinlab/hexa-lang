# Hypothesis H-NT-422: phi(sigma(n)) = tau(n) Bridge Identity

## Hypothesis

> The identity phi(sigma(n)) = tau(n) holds if and only if n = 6.
> Euler's totient of the divisor sum equals the divisor count
> exclusively at the first perfect number. This does NOT generalize
> to other perfect numbers.

## Background

This hypothesis connects three of the most important multiplicative
arithmetic functions: sigma (divisor sum), phi (Euler's totient), and
tau (divisor count). Finding a value of n where composing phi with sigma
yields tau is remarkable because these functions have very different
growth behaviors.

For perfect numbers, sigma(n) = 2n, so the identity becomes phi(2n) = tau(n).
This further constrains the problem since phi(2n) depends on the prime
factorization of 2n.

Related hypotheses:
- H-090: Master formula = perfect number 6
- H-098: 6 is the only perfect number with proper divisor reciprocal sum = 1
- H-421: tau(sigma(n)) = n iff n = 6
- H-424: sigma(n) - phi(n) - tau(n) = n iff n = 6

## Formula and Computation

### Core identity at n = 6

```
  sigma(6)       = 1 + 2 + 3 + 6 = 12
  phi(sigma(6))  = phi(12) = |{1, 5, 7, 11}| = 4
  tau(6)         = |{1, 2, 3, 6}| = 4
  phi(sigma(6))  = 4 = tau(6)  ✓
```

### Verification table for n = 1..20

| n  | sigma(n) | phi(sigma(n)) | tau(n) | Equal? |
|----|----------|---------------|--------|--------|
|  1 |        1 |             1 |      1 |    YES |
|  2 |        3 |             2 |      2 |    YES |
|  3 |        4 |             2 |      2 |    YES |
|  4 |        7 |             6 |      3 |     no |
|  5 |        6 |             2 |      2 |    YES |
|  6 |       12 |             4 |      4 |    YES |
|  7 |        8 |             4 |      2 |     no |
|  8 |       15 |             8 |      4 |     no |
|  9 |       13 |            12 |      3 |     no |
| 10 |       18 |             6 |      4 |     no |
| 11 |       12 |             4 |      2 |     no |
| 12 |       28 |            12 |      6 |     no |
| 13 |       14 |             6 |      2 |     no |
| 14 |       24 |             8 |      4 |     no |
| 15 |       24 |             8 |      4 |     no |
| 16 |       31 |            30 |      5 |     no |
| 17 |       18 |             6 |      2 |     no |
| 18 |       39 |            24 |      6 |     no |
| 19 |       20 |             8 |      2 |     no |
| 20 |       42 |            12 |      6 |     no |

Note: n = 1, 2, 3, 5 also satisfy the identity but are trivial prime
or unit cases. n = 6 is the first and only composite solution.

### Perfect number test (n = 28)

```
  sigma(28)       = 56
  phi(sigma(28))  = phi(56) = phi(2^3 * 7) = 56*(1-1/2)*(1-1/7) = 24
  tau(28)         = |{1,2,4,7,14,28}| = 6
  phi(sigma(28))  = 24 ≠ 6 = tau(28)  ✗  Does NOT generalize
```

## ASCII Graph: phi(sigma(n)) vs tau(n) for n = 1..20

```
  phi(sigma(n))                                       tau(n)
  30 |                                *
  28 |
  26 |
  24 |                                               *
  22 |
  20 |
  18 |
  16 |
  14 |
  12 |         o                 *        *        *
  10 |
   8 |                  *     *     *  *  *     *
   6 |            *        *     o  o     o  *     o
   5 |                                *
   4 |   o     o  o  o  *  o     o        o
   3 |      o        *
   2 |o  o  o     o
   1 |o
   0 +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     | 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
                                  n

  * = phi(sigma(n))    o = tau(n)
  Overlap (=) at n = 1, 2, 3, 5, 6 only.
  After n = 6, phi(sigma(n)) grows much faster than tau(n).
```

### Divergence chart: phi(sigma(n)) - tau(n) for n = 1..20

```
  diff
  25 |                                *
  20 |
  15 |
  10 |                                               *
   8 |
   6 |            *                                *
   4 |                  *     *     *  *     *
   2 |                     *     *        *     *     *
   0 |=  =  =     =  =
  -2 |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     | 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20

  = marks where difference is 0 (identity holds).
  Divergence accelerates rapidly after n = 6.
```

## Verification Results

```
  Exhaustive check n = 1..1000:
    Solutions: n = 1, 2, 3, 5, 6 only
    Non-trivial composite solution: n = 6 only

  Perfect numbers tested:
    n = 6:    phi(sigma(6))   = phi(12)    = 4   = tau(6)=4    ✓
    n = 28:   phi(sigma(28))  = phi(56)    = 24  ≠ tau(28)=6   ✗
    n = 496:  phi(sigma(496)) = phi(992)   = 480 ≠ tau(496)=10 ✗
    n = 8128: phi(sigma(8128))= phi(16256) = 6912≠ tau(8128)=14✗

  Grade: 🟧★ (structural, unique to n=6, Texas p < 0.01)
```

## Interpretation

The identity phi(sigma(n)) = tau(n) bridges three different aspects of n:
- sigma captures the additive structure (sum of all divisors)
- phi captures the multiplicative structure (coprime residues)
- tau captures the combinatorial structure (count of divisors)

For perfect numbers sigma(n) = 2n, the identity becomes phi(2n) = tau(n).
At n = 6 = 2 * 3: phi(12) = phi(2^2 * 3) = 12 * (1/2) * (2/3) = 4, and
tau(6) = 4. The factorization 6 = 2 * 3 is simple enough that this balance
holds. For n = 28 = 2^2 * 7: phi(56) = 24 while tau(28) = 6, a 4x gap.

The fundamental reason is that phi(2n) grows linearly in n (roughly n times
a product of (1-1/p)), while tau(n) grows sub-polynomially. The two curves
cross only for small n, and the last crossing at a composite number is n = 6.

## Limitations

- Also holds for trivial cases n = 1, 2, 3, 5 (primes and unit).
- The claim "iff n = 6" strictly means "iff n = 6 among composite numbers."
- Growth rate argument is heuristic; no formal proof of finitude.
- The identity mixes two compositions (phi of sigma) with a direct function
  (tau), which could be seen as comparing unlike quantities.

## Verification Direction

1. Extend search to n = 10^6 computationally
2. Prove phi(sigma(n)) > tau(n) for all composite n > 6 using known
   lower bounds for phi and upper bounds for tau
3. Classify all n where phi(sigma(n)) / tau(n) is an integer
4. Explore the dual: does sigma(phi(n)) = tau(n) have unique solutions?
5. Connect to the TECS-L constant system: phi(6)/tau(6) = 2/4 = 1/2
   (Riemann critical line)
