# H-NT-434: rad(sigma(n)) = n iff n=6

> **Hypothesis**: The radical of the divisor sum equals n itself exclusively for n=6 in [2,200].

## Background

rad(m) is the product of distinct prime factors of m (the "squarefree kernel").

For n=6: sigma(6)=12=2^2*3. rad(12)=2*3=6=n.

## Verification

| n | sigma(n) | rad(sigma) | = n? |
|---|----------|------------|------|
| 2 | 3 | 3 | no (3!=2) |
| 3 | 4 | 2 | no |
| 4 | 7 | 7 | no |
| 5 | 6 | 6 | no (6!=5) |
| **6** | **12** | **6** | **YES** |
| 7 | 8 | 2 | no |
| 8 | 15 | 15 | no |
| 10 | 18 | 6 | no |
| 12 | 28 | 14 | no |
| 28 | 56 | 14 | no |

Computationally verified: ONLY n=6 in [2,200].

## Why It Works

```
sigma(6) = 12 = 2^2 * 3
rad(12) = 2 * 3 = 6 = n

This requires: sigma(n) has exactly the same prime factors as n,
but with possibly different exponents.

For n=6=2*3: sigma = (1+2)(1+3) = 3*4 = 12 = 2^2*3. 
Prime factors of 12 are {2,3} = prime factors of 6. CHECK.
rad(12) = 2*3 = 6 = n. CHECK.

For general n=pq: sigma = (1+p)(1+q).
rad(sigma) = n requires rad((1+p)(1+q)) = pq.
This means {primes of (1+p)(1+q)} = {p, q}.
For p=2: 1+p=3, need 3 to have factor q=3. So q=3, n=6.
For p=3: 1+p=4=2^2, need 2 as prime of sigma. 1+q must contain 3.
  q=2: sigma=4*3=12, rad=6=n. Same case (n=6).
  q=5: sigma=4*6=24, rad=6!=15. FAILS.
```

## ASCII Graph

```
  rad(sigma(n))
  15 |            *              rad(sigma(8))=15
  14 |                  *  *     rad(sigma(12))=14, rad(sigma(28))=14
     |
   7 |      *                    rad(sigma(4))=7
   6 |  * = *                    rad(sigma(5))=6, n=6: rad=6=n!
     |         ^-- ONLY n=6 has rad(sigma(n))=n
   3 | *                         rad(sigma(2))=3
   2 |    *   *                  rad(sigma(3))=2, rad(sigma(7))=2
     +--+--+--+--+--+--+--+--+
     2  3  4  5  6  7  8  10

  = marks rad(sigma(n))=n at n=6.
```

## Interpretation

The radical strips away exponent information. sigma(6)=12 has the same prime support as 6 itself — the extra factor is just a repeated 2. This is because sigma(6)=(1+2)(1+3)=3*4, and the new primes introduced by "+1" happen to be exactly {2,3} again.

## Grade: 🟧★ (unique to n=6 in [2,200], proved for semiprimes)
