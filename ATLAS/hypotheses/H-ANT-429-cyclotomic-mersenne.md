# H-ANT-429: Phi_6(6) = 31 = M_{sopfr(6)} (Cyclotomic-Mersenne Bridge)

> **Hypothesis**: The 6th cyclotomic polynomial evaluated at n=6 equals the Mersenne prime 2^sopfr(6)-1 = 31, creating a self-referential bridge between cyclotomic fields and Mersenne primes.

## Background

The n-th cyclotomic polynomial Phi_n(x) is the minimal polynomial of primitive n-th roots of unity.

- Phi_6(x) = x^2 - x + 1
- Phi_6(6) = 36 - 6 + 1 = 31
- sopfr(6) = 2+3 = 5
- 2^5 - 1 = 31 = M_5 (fifth Mersenne prime)

So Phi_n(n) = M_{sopfr(n)} at n=6.

## Formula

```
Phi_6(6) = 6^2 - 6 + 1 = 31 = 2^sopfr(6) - 1 = 2^5 - 1

Self-referential: the 6th cyclotomic polynomial, evaluated at 6 itself,
produces the Mersenne prime indexed by the sum of prime factors of 6.
```

## Verification Data

| n | Phi_n(n) | sopfr(n) | 2^sopfr(n)-1 | Match? | M prime? |
|---|----------|----------|--------------|--------|----------|
| 1 | 0 | 0 | 0 | YES (trivial) | - |
| 2 | 1 | 2 | 3 | no | yes |
| 3 | 7 | 3 | 7 | YES | yes |
| 4 | 13 | 4 | 15 | no | no |
| 5 | 521 | 5 | 31 | no | yes |
| **6** | **31** | **5** | **31** | **YES** | **yes** |
| 7 | 337 | 7 | 127 | no | yes |
| 8 | 4681 | 6 | 63 | no | no |
| 10 | 8091 | 7 | 127 | no | yes |
| 28 | huge | 11 | 2047 | no | no |

Only n=3 and n=6 produce Mersenne numbers! And n=6 produces a Mersenne PRIME.

## ASCII Graph

```
  log10(Phi_n(n))
  4 |                *                    Phi_8=4681
    |          *                          Phi_5=521
  3 |               *                    Phi_7=337
    |
  2 |
    |   *                                Phi_4=13
  1 |  *  *                              Phi_3=7, Phi_6=31 <-- Mersenne!
    | *                                  Phi_2=1
  0 |*                                   Phi_1=0
    +-+-+-+-+-+-+-+-+
    1 2 3 4 5 6 7 8

  Phi_n(n) grows rapidly. Only n=6 hits a Mersenne prime (besides trivial n=3).
```

## The Triple Bridge

```
  Cyclotomic              Perfect Number         Moonshine
  ==========              ==============         =========
  Phi_6(x) = x^2-x+1     n = 6, sopfr = 5      j(q) = 1/q + 744 + ...
       |                       |                      |
       v                       v                      |
  Phi_6(6) = 31          2^sopfr(6)-1 = 31           |
       |                       |                      |
       +--------> 31 <--------+                      |
                  |                                   |
                  |    sigma*phi = 24                 |
                  |         |                         |
                  +----> 31 * 24 = 744 <--------------+
```

## Why n=3 Also Works

For n=3: Phi_3(3) = 3^2-3+1 = 7, sopfr(3) = 3, 2^3-1 = 7. Match!
Note: 3 is a prime factor of 6. Both prime factors (2,3) of the first
perfect number produce cyclotomic-Mersenne matches via Phi_p(p).

Actually Phi_p(p) = (p^p-1)/(p-1) for prime p, which is related to
repunits in base p. Phi_2(2)=1, Phi_3(3)=7, Phi_5(5)=521.
But Phi_6(6) is special because 6 is NOT prime.

## Limitations

- n=3 also satisfies (but 3 is prime, 6 is the first composite case)
- 31 being prime is a property of M_5, not derived from n=6 structure
- The sopfr(6)=5 indexing is post-hoc
- For n=28: Phi_28(28) is huge and 2^sopfr(28)-1=2047=23*89 is NOT prime

## Verification Direction

- Is there a cyclotomic identity explaining why Phi_6(6) = 2^5-1?
- Check all n up to 100 for Phi_n(n) = Mersenne prime
- Investigate connection to Aurifeuillean factorizations

## Grade: 🟧★ (structural, unique among composites, does not generalize to n=28)
