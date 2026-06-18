# H-NT-435: (sigma-phi)/(tau-omega) = sopfr — Proved for All Semiprimes

> **Hypothesis**: The ratio (sigma(n)-phi(n))/(tau(n)-omega(n)) equals sopfr(n) for all squarefree semiprimes n=pq.

## Background

For n=6: (12-2)/(4-2) = 10/2 = 5 = sopfr(6).
For n=28: (56-12)/(6-2) = 44/4 = 11 = sopfr(28). Also works!

## Proof

```
For n = pq (distinct primes p < q):
  sigma(pq) = (1+p)(1+q) = 1 + p + q + pq
  phi(pq) = (p-1)(q-1) = pq - p - q + 1
  tau(pq) = 4
  omega(pq) = 2
  sopfr(pq) = p + q

  sigma - phi = (1+p+q+pq) - (pq-p-q+1) = 2p + 2q = 2(p+q)
  tau - omega = 4 - 2 = 2

  Ratio = 2(p+q) / 2 = p + q = sopfr(pq).  QED.
```

## Verification

| n | p,q | sigma-phi | tau-omega | ratio | sopfr | Match? |
|---|-----|-----------|-----------|-------|-------|--------|
| 6 | 2,3 | 10 | 2 | 5 | 5 | YES |
| 10 | 2,5 | 14 | 2 | 7 | 7 | YES |
| 14 | 2,7 | 18 | 2 | 9 | 9 | YES |
| 15 | 3,5 | 16 | 2 | 8 | 8 | YES |
| 21 | 3,7 | 20 | 2 | 10 | 10 | YES |
| 22 | 2,11 | 26 | 2 | 13 | 13 | YES |
| 28 | 2^2*7 | 44 | 4 | 11 | 11 | YES* |
| 12 | 2^2*3 | 24 | 4 | 6 | 7 | NO |

*n=28=4*7 is not squarefree but still works because tau-omega=4 and sigma-phi=44.

## Non-semiprime Cases

- n=12=2^2*3: ratio=24/4=6, sopfr=7. FAILS (non-squarefree).
- n=30=2*3*5: tau=8, omega=3, tau-omega=5. sigma-phi=72-8=64. 64/5=12.8, sopfr=10. FAILS (3 primes).
- n=p^2: tau-omega=2. sigma-phi=(1+p+p^2)-(p^2-p)=1+2p. (1+2p)/2 non-integer. FAILS.

## Interpretation

This identity reveals that for semiprimes, the "spread" between sigma and phi, normalized by the "spread" between tau and omega, exactly recovers the sum of prime factors. It's a natural decomposition formula.

## Grade: 🟩 (proved for all squarefree semiprimes, generalizes beyond n=6)
