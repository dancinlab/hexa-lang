# BRIDGE-003: n - 2 = tau(n) and the Uniqueness of n = 6
**n6 Grade: 🟩 EXACT** (auto-graded, 11 unique n=6 constants)


## Hypothesis

> The equation n - 2 = tau(n) (number of divisors) has a **unique solution: n = 6**.
> This provides an independent number-theoretic characterization of 6, separate from
> perfectness (sigma(n) = 2n), making n = 6 the intersection of at least two
> algebraically independent characterizations among all positive integers.

## Background

The number 6 is famously the smallest perfect number: sigma(6) = 12 = 2 * 6.
But perfectness is not unique to 6 -- the sequence continues 28, 496, 8128, ...

The equation n - 2 = tau(n) provides a **completely independent** characterization.
This connects to Cayley's formula T(K_n) = n^{n-2} for spanning trees of the
complete graph, because at n = 6 the exponent n - 2 equals tau(n), giving the
only complete graph where the spanning tree count is n^{tau(n)}.

Related hypotheses: H-090 (master formula = perfect number 6), H-098 (6 is unique
perfect number with proper divisor reciprocal sum = 1), H-067 (1/2 + 1/3 = 5/6).

## Proof of Uniqueness

**Theorem.** The equation n - 2 = tau(n) has exactly one solution in the positive
integers: n = 6.

**Proof.**

Step 1 (Analytic bound). For all n >= 1, tau(n) <= 2*sqrt(n). This is classical:
each divisor d <= sqrt(n) pairs with n/d >= sqrt(n), giving at most 2*sqrt(n)
divisors.

Step 2 (Reduction to finite check). If n - 2 = tau(n), then:

```
  n - 2  <=  2*sqrt(n)
  n - 2*sqrt(n) - 2  <=  0
```

Substituting x = sqrt(n):

```
  x^2 - 2x - 2  <=  0
  x  <=  1 + sqrt(3)  =  2.7320...
  n  <=  (1 + sqrt(3))^2  =  4 + 2*sqrt(3)  =  7.4641...
```

So n <= 7.

Step 3 (Exhaustive check).

```
  n | n-2 | tau(n) | Match
  --+-----+--------+------
  1 |  -1 |      1 |  no
  2 |   0 |      2 |  no
  3 |   1 |      2 |  no
  4 |   2 |      3 |  no
  5 |   3 |      2 |  no
  6 |   4 |      4 |  YES
  7 |   5 |      2 |  no
```

The only solution is n = 6. QED.

Computationally verified up to n = 10,000 with no other solutions.

## Cayley's Formula Consequence

Cayley's formula: T(K_n) = n^{n-2}, the number of labeled spanning trees of
the complete graph on n vertices.

At n = 6: since n - 2 = tau(6) = 4, we have:

```
  T(K_6) = 6^4 = 6^{tau(6)} = 1296
```

**K_6 is the only complete graph where T(K_n) = n^{tau(n)}.**

Verification table:

```
   n |    n^(n-2) |   n^tau(n) | Match
  ---+------------+------------+------
   2 |          1 |          4 |  no
   3 |          3 |          9 |  no
   4 |         16 |         64 |  no
   5 |        125 |         25 |  no
   6 |       1296 |       1296 |  YES
   7 |      16807 |         49 |  no
   8 |     262144 |       4096 |  no
   9 |    4782969 |        729 |  no
  10 |  100000000 |      10000 |  no
```

### Combinatorial interpretation

The divisor count tau(6) = 4 records the divisors {1, 2, 3, 6}. Cayley's
formula gives T(K_6) = 6^4. Each of the 4 positions in the Prufer sequence
of a spanning tree of K_6 takes one of 6 values. The coincidence n - 2 = tau(n)
means the Prufer sequence length equals the divisor count -- a collision between
the combinatorial structure (graph complexity) and the arithmetic structure
(divisibility) of the number 6.

## Genus of K_6 and the Appearance of 1/2

The Ringel-Youngs formula for the genus of the complete graph:

```
  gamma(K_n) = ceil((n-3)(n-4)/12)    for n >= 3
```

At n = 6:

```
  (6-3)(6-4)/12 = 3*2/12 = 6/12 = 1/2
  gamma(K_6) = ceil(1/2) = 1
```

So K_6 embeds on the torus (genus 1). The value 1/2 that appears before the
ceiling is the Golden Zone upper bound / Riemann critical line Re(s) = 1/2.

However, this 1/2 fractional part is NOT unique to n = 6. It recurs at
n = 9, 10, 13, 18, ... (all n with n mod 12 in {1, 6, 9, 10}). The
connection to 1/2 is suggestive but not a characterization.

## Independence from Perfectness

```
  n    | n-2  | tau(n) | n-2=tau? | sigma=2n?
  -----+------+--------+----------+----------
     6 |    4 |      4 |   YES    |   YES
    28 |   26 |      6 |   no     |   YES
   496 |  494 |     10 |   no     |   YES
  8128 | 8126 |     14 |   no     |   YES
```

- n - 2 = tau(n) does NOT follow from perfectness.
- Perfectness does NOT follow from n - 2 = tau(n).
- These are **algebraically independent** characterizations.
- n = 6 is the **unique intersection** of both properties.

## sigma(n)/n = phi(n): Another Equation Unique to n = 6

The systematic search found that sigma(n)/n = phi(n) is also uniquely
satisfied by n = 6 in [2, 1000]:

```
  At n = 6: sigma(6)/6 = 12/6 = 2 = phi(6)
```

This is equivalent to sigma(n) = n * phi(n), which at n = 6 gives
12 = 6 * 2 = 12. Verified unique up to n = 1000.

## Systematic Search: 68 Equations Unique to n = 6

A systematic search over 92 arithmetic terms (combinations of n, tau, sigma,
phi, omega, Omega, rad, and constants) checked 4,186 equation pairs for
solutions in [2, 200]. Found **68 equations with unique solution n = 6**.

Key non-trivial identities (excluding trivially constant matches):

```
  Equation                  | At n=6          | Meaning
  --------------------------+-----------------+----------------------------
  n - 2 = tau(n)            | 4 = 4           | Cayley exponent = divisors
  n = sigma(n)/phi(n)       | 6 = 12/2        | Abundance/totient balance
  sigma(n)/n = phi(n)       | 2 = 2           | Abundancy = totient
  sigma(n)/n = Omega(n)     | 2 = 2           | Abundancy = prime power count
  sigma(n)/n = n - tau(n)   | 2 = 2           | Abundancy = complement of tau
  n/2 = sigma(n)/tau(n)     | 3 = 3           | Half = mean divisor
  rad(n) = sigma(n) - n     | 6 = 6           | Radical = aliquot sum
  tau(n)^2 = sigma(n)+tau(n)| 16 = 16         | Divisor count squared
  tau(n) = phi(n)^2         | 4 = 4           | Divisors = totient squared
  tau(n) - 1 = sigma/tau    | 3 = 3           | Divisor count minus 1
  sigma(n) = rad(n)*omega(n)| 12 = 12         | Sum = radical * distinct factors
  sigma(n)*phi(n) = tau(n)! | 24 = 24         | Product = factorial of divisors
  phi(n)*omega(n)=phi+omega | 4 = 4           | Multiplicative = additive
```

## ASCII Visualization

How tau(n) compares to n - 2 (the decisive crossing):

```
  Value
   10 |
    9 |                        ###########
    8 |                  ########
    7 |              #######
    6 |          ######           *  (tau(12)=6)
    5 |      #####     *  (tau(8)=4, but n-2=6)
    4 |  ####  *   *   *   *
    3 |  ###*
    2 |  ##  *  *  *  *  *  *  *  *  *  *  *
    1 |  #
    0 +--+--+--+--+--+--+--+--+--+--+--+---> n
       2  3  4  5  6  7  8  9 10 11 12 13

  * = tau(n),  # = n-2
  They meet exactly once: at n=6 where both equal 4.
```

The line n - 2 grows linearly while tau(n) grows as O(n^epsilon) for any
epsilon > 0. After their single crossing at n = 6, they never meet again.

## Property Landscape of n = 6

```
  Property                    | Unique to 6? | Also holds for
  ----------------------------+--------------+------------------------
  n - 2 = tau(n)              |     YES      | (none)
  sigma(n)/n = phi(n)         |     YES      | (none, checked to 1000)
  n = sigma(n)/phi(n)         |     YES      | (none, checked to 200)
  rad(n) = sigma(n) - n       |     YES      | (none, checked to 200)
  sigma(n) = 2n (perfect)     |     no       | 28, 496, 8128, ...
  sigma_{-1}(n) = 2           |     no       | 28, 496, 8128, ...
  n = sigma(n) - n (perfect)  |     no       | 28, 496, 8128, ...
  n = 3! (factorial)          |     no       | 1, 2, 24, 120, ...
  n = T(3) (triangular)       |     no       | 1, 3, 10, 15, ...
```

## Limitations

1. The proof of n - 2 = tau(n) uniqueness is rigorous (analytic bound + finite
   check). Grade: pure mathematics, no Golden Zone dependency.

2. The systematic search is limited to [2, 200] for most equations. Some
   "unique to 6" identities might have larger solutions not yet found.
   sigma(n)/n = phi(n) was verified to n = 1000.

3. The Cayley formula interpretation is an observation, not a deep theorem.
   Whether there is a structural reason connecting graph complexity (Prufer
   sequences) to divisor structure remains open.

4. The genus 1/2 connection is NOT unique to n = 6 and should not be
   over-interpreted.

## Verification Direction

1. Prove sigma(n)/n = phi(n) has unique solution n = 6 analytically (not just
   computationally). This would give a second rigorous characterization.

2. Investigate whether any of the 68 unique equations are logically equivalent
   to each other, reducing the count to independent characterizations.

3. Explore the Cayley/Prufer interpretation further: is there a bijection
   between the 1296 spanning trees of K_6 and some divisor-related structure?

4. Check if the intersection {n-2=tau(n)} AND {sigma=2n} logically constrains
   n to be 6, or if these are fully independent conditions that happen to
   intersect only at 6.

## Grade

- **n - 2 = tau(n) uniqueness**: Pure mathematics (proven). No Golden Zone dependency.
- **Systematic search results**: Computational, verified to stated bounds.
- **Cayley connection**: Observation (exact, follows from proof).
- **Genus connection**: Suggestive only, not unique.

## Script

Verification: `verify/verify_n6_unique_equations.py`

```bash
PYTHONPATH=. python3 verify/verify_n6_unique_equations.py
```
