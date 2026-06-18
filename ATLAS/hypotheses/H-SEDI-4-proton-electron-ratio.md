# H-SEDI-4: Proton-Electron Mass Ratio m_p/m_e = sigma(6) * T(17) = 1836

**Grade: 🟧 Structurally interesting (Texas p ~ 0.017)**
**Golden Zone dependency: None (pure arithmetic)**
**Cross-domain: SEDI particle physics x TECS-L n=6 arithmetic**

## Hypothesis

> The proton-to-electron mass ratio m_p/m_e = 1836.15267 is approximated by
> sigma(6) * T(sigma(6) + sopfr(6)) = 12 * T(17) = 12 * 153 = 1836,
> where T(n) = n(n+1)/2 is the triangular number function.

## Background

m_p/m_e = 1836.15267 is one of the most precisely known dimensionless constants.
Any "explanation" must account for both the integer part 1836 and the fractional
part 0.15267.

The SEDI claim: 12 * 153 = 1836, where 153 = T(17) and 17 = sigma(6) + sopfr(6) = 12 + 5.

Related: H-090 (perfect number 6), TECS-L amplification at theta=pi = 17.

## Derivation

```
  sigma(6) = 12    (sum of divisors of 6)
  sopfr(6) = 5     (sum of prime factors with repetition: 2+3)

  17 = sigma(6) + sopfr(6) = 12 + 5

  T(17) = 17 * 18 / 2 = 153

  m_p/m_e (predicted) = sigma(6) * T(17) = 12 * 153 = 1836
  m_p/m_e (observed)  = 1836.15267
```

## Precision Analysis

```
  Predicted:    1836.00000
  Observed:     1836.15267 +/- 0.00004 (CODATA)
  Delta:        0.15267
  Error:        0.00832%
  Sigma away:   3817 (from CODATA precision)

  The integer part matches EXACTLY.
  The fractional part 0.15267 is not explained.
```

### Visual: error context

```
  Error comparison (log scale):
  |
  |  *  H-SEDI-4: 0.008% (m_p/m_e)
  |     *  H-SEDI-5: 0.026% (1/alpha)
  |           *  H-SEDI-3: 0.195% (sin^2 theta_W)
  |                                *  H-SEDI-2 avg: 2.2% (quarks)
  +--+----+----+----+----+----+----+----+
     0.01 0.03 0.1  0.3  1    3    10  (%)
```

## Why 17?

```
  17 connections to n=6:
  1. 17 = sigma(6) + sopfr(6) = 12 + 5        (from n=6 directly)
  2. 17 = Fermat prime F_2 = 2^(2^2) + 1      (number theory)
  3. 17 = amplification at theta=pi in TECS-L  (model constant)
  4. 153 = T(17) = 1^3 + 5^3 + 3^3            (narcissistic number)
  5. 153 = 9 * 17                               (9 = 3^2 = (sigma/tau)^2)
```

The sigma + sopfr = 17 connection (item 1) is the most natural from n=6.
However, choosing sopfr among {sigma, tau, phi, sopfr, omega, ...} is itself
a selection from ~5 basic arithmetic functions.

## Reachability Analysis

Products sigma(6) * f(k) for various sequences f and small k:

```
  Sequence    k      Product    Distance from 1836.15
  --------    -      -------    ---------------------
  T(k)        17     1836       0.15       <-- EXACT integer match
  k^2         12     1728       108.15     (far)
  k^2         13     2028       191.85     (far)
  T(k)        16     1632       204.15     (far)
  T(k)        18     2052       215.85     (far)

  Only T(17) hits. Next nearest is T(16)*12 = 1632, distance 204.
  The gap to next candidate is 200x larger than the error.
```

## Texas Sharpshooter Test

```
  Trial space: c * f(k) where
    c in {2, 4, 6, 8, 10, 12}     (6 values from n=6 arithmetic)
    f in {T, square, factorial}     (3 common sequences)
    k in {1, ..., 30}              (30 values)

  Total trials: 6 * 3 * 30 = 540
  Hits within 0.1% of 1836.15: 1

  p-value ~ 1/540 ~ 0.002
  Bonferroni (tested ~10 different constant targets): p ~ 0.02
  Grade: 🟧 (weak structural evidence, p < 0.05)
```

## Generalization

For P2 = 28: sigma(28) = 56, sopfr(28) = 2+2+7 = 11
```
  56 * T(56+11) = 56 * T(67) = 56 * 2278 = 127568
  No known physical constant near 127568.
```
Does NOT generalize to P2 = 28.

## The 0.15267 Remainder

```
  m_p/m_e - 1836 = 0.15267

  Can 0.15267 be expressed from n=6?
  - phi/sigma = 2/12 = 0.1667  (error 26%)
  - 1/tau^(tau-1) = 1/64 = 0.015625  (wrong order)
  - sopfr/sigma^2 = 5/144 = 0.03472  (no)
  - ln(4/3) - 1/8 = 0.2877 - 0.125 = 0.1627  (error 6.6%)

  No clean expression found for the remainder.
```

## Limitations

1. T() function choice is an additional free parameter
2. sopfr(6) = 5 is one of several available arithmetic functions
3. Fractional part 0.15267 unexplained
4. Does not generalize to P2 = 28
5. 3817 sigma from CODATA precision -- the integer approximation fails at
   high precision even though the percentage error is small

## Verdict

The integer match 12 * 153 = 1836 is striking and the reachability gap to the
next candidate is large (200x). The Texas p-value of ~0.02 after Bonferroni
is borderline significant. The 17 = sigma + sopfr connection adds coherence.
However, the T() function choice and unexplained 0.15267 remainder prevent
a higher grade. Grade: 🟧 (structurally interesting, not proven).

## Next Steps

1. Search for an expression for the remainder 0.15267 from n=6
2. Investigate whether 1836 = 12 * 153 has a QCD interpretation
3. Test: does 17 appear in lattice QCD mass ratio calculations?
4. Cross-check: does the amplification constant 17 in TECS-L have independent support?
