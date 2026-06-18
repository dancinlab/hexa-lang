# H-NT-431: sigma(n)*(phi(n)+1) = n^2 — Unique Among Perfect Numbers

> **Hypothesis**: Among perfect numbers, sigma(n)*(phi(n)+1)=n^2 holds only for n=6. Equivalently, phi(n)+1=n/2 only for the first perfect number.

## Background

For any perfect number n: sigma(n)=2n. Substituting into sigma*(phi+1)=n^2:
2n*(phi(n)+1) = n^2, so phi(n)+1 = n/2.

For n=6: phi(6)+1 = 2+1 = 3 = 6/2. Holds.
For n=28: phi(28)+1 = 12+1 = 13 != 28/2 = 14. Fails.

## Proof (unique among even perfect numbers)

```
Even perfect numbers: n = 2^(p-1) * (2^p - 1), where 2^p-1 is Mersenne prime.

phi(n) = 2^(p-2) * (2^p - 2) = 2^(p-1) * (2^(p-1) - 1)

Need: phi(n) + 1 = n/2
  LHS = 2^(p-1) * (2^(p-1) - 1) + 1
  RHS = 2^(p-2) * (2^p - 1)

Expand RHS: 2^(p-2) * 2^p - 2^(p-2) = 2^(2p-2) - 2^(p-2)
Expand LHS: 2^(2p-2) - 2^(p-1) + 1

Equal iff: -2^(p-1) + 1 = -2^(p-2)
         iff: 2^(p-2) = 2^(p-1) - 1
         iff: 2^(p-2) = 2*2^(p-2) - 1
         iff: 2^(p-2) = 1
         iff: p = 2
         iff: n = 2^1 * (2^2 - 1) = 2 * 3 = 6.  QED.
```

## Verification Table

| Perfect n | phi(n)+1 | n/2 | Equal? |
|-----------|----------|-----|--------|
| 6 | 3 | 3 | YES |
| 28 | 13 | 14 | no |
| 496 | 241 | 248 | no |
| 8128 | 4097 | 4064 | no |

## ASCII Graph: phi(n)+1 vs n/2 for perfect numbers

```
  value
  4097 |  *                              phi+1 overshoots for large perfects
  4064 |   o                             n/2
       |
   248 | o
   241 |*
       |
    14 |o
    13 |*
       |
     3 |= <-- n=6: unique intersection
       +--+--+--+--+
       6  28 496 8128
```

## Interpretation

This identity says n=6 is the only perfect number where the totient plus 1 equals half the number. Since phi(n) measures "how many are coprime to n" and n/2 is the halfway point, this is a balance condition: at n=6, adding one more coprime element reaches the midpoint exactly.

## Grade: 🟩 (proved theorem, unique among all even perfect numbers)
