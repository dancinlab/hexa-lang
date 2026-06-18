# H-SEDI-1: Koide Angle delta = phi(6) tau(6)^2 / sigma(6)^2 = 2/9

**Grade: 🟩 Exact arithmetic identity**
**Golden Zone dependency: None (pure number theory)**
**Cross-domain: SEDI particle physics x TECS-L n=6 arithmetic**

## Hypothesis

> The combination phi(6) tau(6)^2 / sigma(6)^2 yields the exact fraction 2/9,
> which is labeled the "Koide angle" in the SEDI framework. This is an exact
> arithmetic identity from the divisor functions of the first perfect number.

## Background

The Koide formula Q = (m_e + m_mu + m_tau) / (sqrt(m_e) + sqrt(m_mu) + sqrt(m_tau))^2
yields Q = 0.666661, remarkably close to 2/3. The SEDI project defines a parameter
delta = phi(6) tau(6)^2 / sigma(6)^2 and calls it the "Koide angle."

Related hypotheses: H-090 (master formula = perfect number 6), H-092 (zeta Euler product).

## Derivation

```
  phi(6) = 2     (Euler totient: gcd(k,6)=1 for k=1,5)
  tau(6) = 4     (divisor count: 1,2,3,6)
  sigma(6) = 12  (divisor sum: 1+2+3+6)

  delta = phi * tau^2 / sigma^2
        = 2 * 16 / 144
        = 32 / 144
        = 2/9                   EXACT
```

## Verification

### Arithmetic check

```
  2 * 4^2 = 2 * 16 = 32
  12^2 = 144
  32/144 = 2/9             Confirmed exact (Fraction arithmetic)
```

### Physical connection check

The standard Koide parametrization uses:
```
  sqrt(m_i) = A(1 + sqrt(2) cos(theta_0 + 2*pi*i/3))    for i = 0,1,2
```

Computing theta_0 from physical lepton masses:

```
  m_e   = 0.511 MeV
  m_mu  = 105.658 MeV
  m_tau = 1776.86 MeV

  A = (sqrt(m_e) + sqrt(m_mu) + sqrt(m_tau)) / 3

  theta_0 = 2.3166 rad = 132.73 degrees
  theta_0 / pi = 0.7374

  2/9 = 0.2222

  theta_0 vs 2/9: NO MATCH (different by factor ~10)
```

### Connection diagram

```
  phi(6)=2  tau(6)=4  sigma(6)=12
     |         |          |
     v         v          v
   phi * tau^2 / sigma^2
     = 2 * 16 / 144
     = 2/9
     |
     v
   "Koide angle"  <--- label only, no derivation of Q=2/3
     |                    |
     ?                    v
   Physical         Q = 2/3 (geometric identity,
   Koide angle      holds for ANY theta_0)
   theta_0 = 2.317
```

### Q = 2/3 independence

The Koide ratio Q = 2/3 is a geometric identity: for ANY masses parametrized as
sqrt(m_i) = A(1 + sqrt(2) cos(theta + 2pi*i/3)), Q = 2/3 exactly regardless of
the angle theta. Therefore delta = 2/9 does NOT independently predict Q = 2/3.

## Generalization test

For perfect number 28:
```
  phi(28) = 12, tau(28) = 6, sigma(28) = 56
  delta_28 = 12 * 36 / 3136 = 432/3136 = 27/196
  27/196 = 0.1378  (not a clean fraction)
```

Does NOT generalize to P_2 = 28. The 2/9 result is specific to n = 6.

## Limitations

- The label "Koide angle" is misleading: 2/9 is numerically close to the actual
  Koide parametrization angle only by coincidence (0.222 vs 2.317 rad).
- No mechanism connects delta = 2/9 to the physical Koide formula.
- Q = 2/3 follows from parametrization geometry, not from delta.

## Verdict

The arithmetic identity phi(6)*tau(6)^2/sigma(6)^2 = 2/9 is exact and proven.
However, its claimed connection to Koide physics lacks a derivation mechanism.
As a pure n=6 arithmetic fact, it is 🟩. As a physics prediction, it is unverified.

## Next steps

1. Search for a mechanism connecting delta = 2/9 to lepton mass ratios
2. Check if 2/9 appears in other particle physics contexts
3. Test whether delta enters any Lagrangian parameter naturally
