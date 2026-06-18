# H-TOP-426: Kissing Number in Dim 8 = sigma(6)*tau(6)*sopfr(6) = 240

> **Hypothesis**: The kissing number in 8 dimensions (E8 lattice) equals sigma(6)*tau(6)*sopfr(6) = 240.

## Background

Kissing number k(d) = max non-overlapping unit spheres touching a central one in d-dim.

Known exact values and n=6 expressions:
- k(1) = 2 = phi(6)
- k(2) = 6 = n
- k(3) = 12 = sigma(6)
- k(4) = 24 = sigma(6)*phi(6)
- k(8) = 240 = sigma(6)*tau(6)*sopfr(6)
- k(24) = 196560

## Formula

```
k(8) = sigma(6) * tau(6) * sopfr(6) = 12 * 4 * 5 = 240
```

## Verification Data

| Dim | k(d) | n=6 expression | Value |
|-----|------|----------------|-------|
| 1 | 2 | phi(6) | 2 |
| 2 | 6 | n | 6 |
| 3 | 12 | sigma(6) | 12 |
| 4 | 24 | sigma*phi | 24 |
| 8 | 240 | sigma*tau*sopfr | 240 |
| 24 | 196560 | 24*8190 | 196560 |

## ASCII Graph

```
  log10(k)
  5.3 |                                          * k(24)=196560
      |
      |
      |
  2.4 |                * k(8)=240
  1.4 |       * k(4)=24
  1.1 |    * k(3)=12
  0.8 |  * k(2)=6
  0.3 | * k(1)=2
      +--+--+--+--+--+--+--+--+--+--+--+--+--+
      1  2  3  4  5  6  7  8  ...         24
```

## E8 Properties in n=6

- E8 rank = 8 = sigma(6)-tau(6)
- E8 roots = 240 = sigma*tau*sopfr
- E8 Coxeter h = 30 = sopfr(6)*6
- E8 dim = 248 = 240+8

## Limitations

- 240 factorizes many ways (2^4*3*5)
- Post-hoc expression selection
- k(5),k(6),k(7) unknown; pattern has gaps
- k(24) doesn't factor cleanly in n=6 terms alone

## Grade: 🟧 (observational, progressive pattern suggestive but post-hoc)
