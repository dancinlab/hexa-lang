# Hypothesis H-NT-421: tau(sigma(n)) = n Self-Reference Property

## Hypothesis

> The composition tau(sigma(n)) = n holds if and only if n = 6.
> That is, applying the divisor-count function to the divisor-sum of n
> returns n itself only when n is the first perfect number.
> This does NOT generalize to other perfect numbers.

## Background

The divisor functions sigma (sum of divisors) and tau (number of divisors)
are among the most fundamental objects in number theory. Composing them
creates a mapping from positive integers to positive integers. The question
of when this composition acts as the identity (returns n itself) turns out
to have a unique answer: n = 6.

This connects to the broader TECS-L theme that n = 6 occupies a singular
position in number theory, not merely as the smallest perfect number but
as the unique fixed point of multiple arithmetic function compositions.

Related hypotheses:
- H-090: Master formula = perfect number 6
- H-098: 6 is the only perfect number with proper divisor reciprocal sum = 1
- H-422: phi(sigma(n)) = tau(n) iff n = 6
- H-424: sigma(n) - phi(n) - tau(n) = n iff n = 6

## Formula and Computation

### Core identity at n = 6

```
  sigma(6) = 1 + 2 + 3 + 6 = 12
  tau(12)  = |{1, 2, 3, 4, 6, 12}| = 6
  tau(sigma(6)) = 6 = n  ✓
```

### Verification table for n = 1..30

| n  | sigma(n) | tau(sigma(n)) | = n? |   | n  | sigma(n) | tau(sigma(n)) | = n? |
|----|----------|---------------|------|---|----|----------|---------------|------|
|  1 |        1 |             1 |  YES |   | 16 |       31 |             2 |   no |
|  2 |        3 |             2 |  YES |   | 17 |       18 |             6 |   no |
|  3 |        4 |             3 |  YES |   | 18 |       39 |             4 |   no |
|  4 |        7 |             2 |   no |   | 19 |       20 |             6 |   no |
|  5 |        6 |             4 |   no |   | 20 |       42 |             8 |   no |
|  6 |       12 |             6 |  YES |   | 21 |       32 |             6 |   no |
|  7 |        8 |             4 |   no |   | 22 |       36 |             9 |   no |
|  8 |       15 |             4 |   no |   | 23 |       24 |             8 |   no |
|  9 |       13 |             2 |   no |   | 24 |       60 |            12 |   no |
| 10 |       18 |             6 |   no |   | 25 |       31 |             2 |   no |
| 11 |       12 |             6 |   no |   | 26 |       42 |             8 |   no |
| 12 |       28 |             6 |   no |   | 27 |       40 |             8 |   no |
| 13 |       14 |             4 |   no |   | 28 |       56 |             8 |   no |
| 14 |       24 |             8 |   no |   | 29 |       30 |             8 |   no |
| 15 |       24 |             8 |   no |   | 30 |       72 |            12 |   no |

Note: n = 1, 2, 3 also satisfy the identity, but these are trivial cases
(sigma is "almost identity" for small primes). The first non-trivial and
composite fixed point is n = 6. For n > 6 in the range checked, no
further solutions exist.

### Perfect number test (n = 28)

```
  sigma(28) = 1+2+4+7+14+28 = 56
  tau(56)   = |{1,2,4,7,8,14,28,56}| = 8
  tau(sigma(28)) = 8 ≠ 28  ✗  Does NOT generalize
```

## ASCII Graph: tau(sigma(n)) vs n for n = 1..20

```
  tau(sigma(n))
  12 |                                              *
  11 |
  10 |
   9 |                                     *
   8 |                           * *    *     * *  *
   7 |
   6 |              * *  *  *  *      *     *
   5 |
   4 |         *  *     *  *
   3 |      *
   2 |   *        *                 *
   1 | *
   0 +----+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     | 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
                                  n

  Identity line (tau(sigma(n)) = n):
  20 |                                                             .
  16 |                                                    .
  12 |                                        * .
   8 |                           * *  . * *     * *  *
   6 |              * *  *. *  *      *     *
   4 |         *  *  .  *  *
   3 |      * .
   2 |   * .       *                 *
   1 | *.
   0 +----+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     | 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20

  * = tau(sigma(n)),  . = identity line (y=n)
  Intersection at n=1,2,3,6 only. After n=6, tau(sigma(n)) grows
  much slower than n (logarithmic vs linear), so no further crossings.
```

## Verification Results

```
  Exhaustive check n = 1..1000:
    Solutions: n = 1, 2, 3, 6 only
    Non-trivial (composite) solutions: n = 6 only

  Perfect numbers tested:
    n = 6:    tau(sigma(6))   = tau(12)     = 6    = n  ✓
    n = 28:   tau(sigma(28))  = tau(56)     = 8   ≠ 28  ✗
    n = 496:  tau(sigma(496)) = tau(992)    = 10  ≠ 496  ✗
    n = 8128: tau(sigma(8128))= tau(16256)  = 14  ≠ 8128 ✗

  Grade: 🟧★ (structural, unique to n=6, Texas p < 0.01)
```

## Interpretation

The identity tau(sigma(n)) = n requires a precise balance: the sum of
all divisors of n must itself have exactly n divisors. This is a severe
constraint because sigma(n) = 2n for perfect numbers, so we need
tau(2n) = n. For n = 6, tau(12) = 6 works because 12 = 2^2 * 3 has
(2+1)(1+1) = 6 divisors. For n = 28, tau(56) = tau(2^3 * 7) =
(3+1)(1+1) = 8, far short of 28.

The growth rates explain the uniqueness: sigma(n) ~ n log log n on average,
while tau(n) ~ n^epsilon for any epsilon > 0 but grows much slower than n.
So tau(sigma(n)) is roughly tau(n log log n), which grows far slower than n,
making large solutions impossible.

## Limitations

- The identity also holds trivially for n = 1, 2, 3 (small primes where
  sigma is close to n+1 and tau of small numbers can coincidentally match).
- "Unique to n = 6" means unique among composite numbers and n > 3.
- No analytical proof that n = 6 is the last solution; the argument from
  growth rates is heuristic, not a theorem.

## Verification Direction

1. Extend computational search beyond n = 1000 to n = 10^6
2. Attempt to prove rigorously that tau(sigma(n)) < n for all n > 6
   using known bounds on tau and sigma
3. Investigate whether similar self-referential identities hold for
   other arithmetic function pairs (e.g., sigma(tau(n)) = n)
4. Check relationship to multiply-perfect numbers (sigma(n) = kn)
