# H-CROSS-426: j-Function Constant 744 = (2^sopfr(6)-1)*sigma(6)*phi(6)

> **Hypothesis**: The j-invariant constant term 744 decomposes as Mersenne(sopfr(6)) times sigma(6)*phi(6), bridging Moonshine to perfect number arithmetic.

## Background

The j-invariant: j(q) = 1/q + 744 + 196884q + ...

744 = 31 * 24 = (2^5-1) * (12*2)

## Formula

```
744 = (2^sopfr(6) - 1) * sigma(6) * phi(6)
    = (2^5 - 1) * 12 * 2
    = 31 * 24
```

## Decomposition

| Component | Value | Source |
|-----------|-------|--------|
| sopfr(6) | 5 | 2+3 |
| 2^5-1 | 31 | Mersenne prime M5 |
| sigma(6) | 12 | divisor sum |
| phi(6) | 2 | totient |
| sigma*phi | 24 | Leech dim, eta exp |
| 31*24 | 744 | j-invariant const |

## ASCII Diagram

```
  Moonshine              Perfect Number 6
  =========              =================
  j(q) = 1/q + 744      n = 6 = 2*3
         |               sopfr = 5
         v                  |
      31 * 24              2^5-1 = 31 (Mersenne!)
       |    |                     |
       |    +-- sigma*phi = 24    |
       |                          |
       +-- Mersenne from sopfr ---+

  Monster |M| divisible by 31
  Leech lattice dim = 24
```

## Generalization

- n=28: sopfr=11, 2^11-1=2047=23*89 (NOT prime). No clean factorization.
- n=496: sopfr=36, 2^36-1 composite. Fails.
- Specific to n=6.

## Interpretation

Bridges three peaks: perfect numbers, Mersenne primes, Monstrous Moonshine. The chain sopfr(6)=5 -> M5=31, combined with sigma*phi=24, produces the j-invariant constant.

## Limitations

- 744 has many factorizations; this one is post-hoc
- Connection is observational, not derived from modular form theory
- The "meaning" of 744 in moonshine is debated

## Grade: 🟧 (cross-domain, observational)
