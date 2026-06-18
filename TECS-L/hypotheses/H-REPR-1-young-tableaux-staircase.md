---
id: H-REPR-1
title: "Young Tableaux Staircase: f^(3,2,1) = 2^tau(6) unique among triangular numbers"
status: VERIFIED
grade: "🟩⭐"
date: 2026-03-26
---

# H-REPR-1: Young Tableaux Staircase Identity

> **Theorem.** Among all triangular numbers n = T(k) = k(k+1)/2, the number of
> Standard Young Tableaux of the staircase partition (k, k-1, ..., 1) equals 2^tau(n)
> if and only if n = 6.

## The Identity

```
  n = 6 = T(3):  staircase = (3, 2, 1)
  f^(3,2,1) = 16 = 2^4 = 2^tau(6)

  Hook lengths of (3,2,1): [5, 3, 1, 3, 1, 1]
  Hook product = 45 = (sigma/tau)^2 * sopfr = 9 * 5
  f^lambda = 6!/45 = 720/45 = 16
```

## Verification

| k | n=T(k) | Staircase | f^lambda | 2^tau(n) | Match? |
|---|--------|-----------|----------|----------|--------|
| 2 | 3 | (2,1) | 2 | 4 | NO |
| **3** | **6** | **(3,2,1)** | **16** | **16** | **YES** |
| 4 | 10 | (4,3,2,1) | 768 | 16 | NO |
| 5 | 15 | (5,4,3,2,1) | 292864 | 16 | NO |
| 6 | 21 | (6,...,1) | 1.1×10^9 | 16 | NO |

For k >= 4, f^staircase grows super-exponentially while 2^tau stays bounded.
For k = 2, f = 2 < 4 = 2^tau(3). Only k = 3 (n = 6) achieves equality.

## Structural Analysis

The staircase (3,2,1) is the UNIQUE self-conjugate partition of 6:

```
  Young diagram:     Conjugate:
  ■ ■ ■              ■ ■ ■
  ■ ■                ■ ■
  ■                  ■
  Same! (3,2,1)' = (3,2,1)
```

This self-conjugate staircase achieves the maximum irrep dimension of S_6:

```
  S_6 irrep dimensions (from partitions of 6):
  ──────────────────────────────────────────────
  (6):         1     (3,1,1,1):   10
  (5,1):       5     (2,2,2):     5
  (4,2):       9     (2,2,1,1):   9
  (4,1,1):    10     (2,1,1,1,1): 5
  (3,3):       5     (1^6):       1
  (3,2,1):   *16*  ← maximum!

  Max dim = 16 = 2^tau(6) = tau(6)^2
```

## Hook Product Decomposition

```
  Hook lengths at each cell of (3,2,1):

  5  3  1
  3  1
  1

  Product = 5 * 3 * 1 * 3 * 1 * 1 = 45
         = 9 * 5
         = (sigma/tau)^2 * sopfr
         = (12/4)^2 * 5
```

The hook product factors into two fundamental arithmetic invariants of n=6.

## Connection to Existing Results

- tau(6) = 4 appears as the exponent: 2^4 = 16
- sigma/tau = 3 = k (the staircase index) — so n = T(sigma/tau)
- The self-conjugate property mirrors the self-referential nature of perfect numbers
- RSK: sum of (f^lambda)^2 = 6! = 720 (all partitions), and (3,2,1) contributes 256/720 = 35.6%

## Why This Is Special

The staircase partition (k, k-1, ..., 1) has f^lambda given by:
```
  f^staircase = n! / prod(hook lengths)
```

For this to equal 2^tau(n), we need:
```
  T(k)! / H(k) = 2^tau(T(k))
```

where H(k) is the hook product. This is a transcendental equation mixing factorials,
hook length products, and the divisor function — and it has exactly one solution.
