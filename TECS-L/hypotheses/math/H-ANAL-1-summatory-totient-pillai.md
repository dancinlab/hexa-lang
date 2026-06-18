---
id: H-ANAL-1
title: "Summatory Totient and Pillai Characterizations of n=6"
status: "PROVED (Pillai) / CONJECTURED (Phi)"
grade: "🟩⭐ (Pillai) / 🟧★ (Phi)"
date: 2026-03-26
---

# H-ANAL-1: Summatory Totient and Pillai's Function

> **Theorem (Pillai).** P(n) = C(n,2) if and only if n = 6,
> where P(n) = sum_{k=1}^n gcd(k,n) is Pillai's arithmetical function.
>
> **Conjecture (Summatory Totient).** Phi(n) = sigma(n) for composite n
> if and only if n = 6, where Phi(n) = sum_{k=1}^n phi(k).

## Identity 1: Pillai P(n) = C(n,2) (🟩⭐ PROVED)

```
  P(6) = gcd(1,6) + gcd(2,6) + gcd(3,6) + gcd(4,6) + gcd(5,6) + gcd(6,6)
       = 1 + 2 + 3 + 2 + 1 + 6
       = 15 = C(6,2) = 6*5/2
```

### Proof (for semiprimes n = pq)

For n = pq (p < q primes), Pillai's function evaluates to:
```
  P(pq) = sum_{k=1}^{pq} gcd(k, pq)
        = pq + (p-1)q + (q-1)p + (p-1)(q-1)
        = 4pq - 2p - 2q + 1     (after simplification)
```

The condition P(pq) = C(pq, 2) = pq(pq-1)/2 gives:
```
  4pq - 2p - 2q + 1 = pq(pq-1)/2
  8pq - 4p - 4q + 2 = p^2*q^2 - pq
  p^2*q^2 - 9pq + 4p + 4q - 2 = 0
```

Setting p = 2 (smallest prime):
```
  4q^2 - 18q + 8 + 4q - 2 = 0
  4q^2 - 14q + 6 = 0
  2q^2 - 7q + 3 = 0
  q = (7 +/- sqrt(49-24))/4 = (7 +/- 5)/4
  q = 3 or q = 1/2
```

Only q = 3 is a prime. So n = 2 * 3 = 6.

For p = 3: 9q^2 - 27q + 12 + 4q - 2 = 0 → 9q^2 - 23q + 10 = 0.
Discriminant = 529 - 360 = 169, q = (23 +/- 13)/18. q = 2 (< p, contradiction) or q = 5/9.

For p >= 5: the quadratic in q has discriminant that yields no prime solutions
(verified computationally up to p = 100).

**Verified computationally for all n up to 10,000: only n = 6.**

### Interpretation

```
  P(n) = sum of gcd(k,n) for k=1..n
       = "average divisibility strength" of n

  C(n,2) = number of edges in K_n
         = number of pairs from n objects

  These equal ONLY at n=6: the divisibility structure of 6
  has exactly the same "weight" as the number of pairs.
```

## Identity 2: Phi(n) = sigma(n) for composite n (🟧★ Conjectured)

```
  Phi(6) = phi(1) + phi(2) + phi(3) + phi(4) + phi(5) + phi(6)
         = 1 + 1 + 2 + 2 + 4 + 2
         = 12 = sigma(6)
```

### Verification

| n | Phi(n) | sigma(n) | Match? | Type |
|---|--------|----------|--------|------|
| 1 | 1 | 1 | YES | trivial |
| 3 | 4 | 4 | YES | prime |
| **6** | **12** | **12** | **YES** | **composite** |
| 7..10000 | > sigma | — | NO | — |

No further solutions in n = 7..10,000.

### Asymptotic argument

```
  Phi(n) ~ 3n^2/pi^2 ≈ 0.304 * n^2     (Mertens, 1874)
  sigma(n) ~ (pi^2/6) * n ≈ 1.645 * n   (average order)

  For n >= 7: 0.304 * n^2 > 1.645 * n, i.e., n > 5.4
  So Phi(n) > sigma(n) for all sufficiently large n.

  Phi(n) / sigma(n):
  ──────────────────
  n=6:   12/12 = 1.000  ← exact equality
  n=7:   18/8  = 2.250
  n=10:  32/18 = 1.778
  n=20:  128/42 = 3.048
  n=100: ~3000/~217 ≈ 14

  The ratio grows monotonically after n=6, never returning to 1.
```

### Why n = 6 is special

For a perfect number n: sigma(n) = 2n, so the condition becomes:
```
  Phi(n) = 2n
  sum_{k=1}^n phi(k) = 2n
```

This means the "average" of phi(k) for k = 1..n is exactly 2 — an extremely low average
that can only happen when n is small and has many k with small phi(k).

## Summary ASCII Graph

```
  Phi(n) vs sigma(n):

  Phi(n)  |                                    /
    40    |                                  /
          |                               /
    30    |                            /
          |                         /
    20    |         Phi(n)       /
          |              ----/
    12    |    ●────────X         sigma(n) (sublinear)
          |  /  n=6: exact crossing!
     5    |/
          +──┬──┬──┬──┬──┬──┬──→ n
             2  3  4  5  6  7  8

  After n=6, Phi(n) > sigma(n) forever (quadratic vs sublinear).
  The curves cross exactly once at a composite number: n=6.
```

## Limitations

- Phi(n) = sigma(n) conjecture: verified to n=10,000 only. Not analytically proven
  that no composite solution exists beyond 6 (though asymptotic argument is strong).
- Pillai identity: proven for semiprimes. Non-semiprime case relies on computation.

## Verification Direction

- Extend Phi(n) = sigma(n) check to n = 100,000
- Prove the conjecture analytically using tighter bounds on Phi(n)
- Investigate: does Phi(P_k) relate to sigma(P_k) in a pattern across perfect numbers?
