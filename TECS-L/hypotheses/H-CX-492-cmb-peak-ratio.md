# H-CX-492: CMB Acoustic Peak Ratio l2/l1 = sopfr/phi

> The ratio of second to first CMB acoustic peak multipole moments
> l2/l1 ~ 537.5/220 = 2.443 is approximated by sopfr(6)/phi(6)
> = 5/2 = 2.5, with 2.33% error.

## Background

The Cosmic Microwave Background (CMB) angular power spectrum shows acoustic
peaks at specific multipole moments l. The first peak at l1 ~ 220 and second
at l2 ~ 537 encode information about cosmological parameters (baryon density,
curvature, dark energy). Their ratio reflects the harmonic structure of
primordial sound waves modified by baryon loading.

Golden Zone dependency: INDEPENDENT (cosmological observation).

## Formula

```
  Observation (Planck 2018):
    l1 = 220.0     (first acoustic peak)
    l2 = 537.5     (second acoustic peak)
    l2/l1 = 2.443

  Prediction:
    sopfr(6)/phi(6) = 5/2 = 2.500

  Error:
    |2.500 - 2.443| / 2.443 = 2.33%

  Theoretical context:
    Pure harmonic (no baryons): l2/l1 = 2 (exact second harmonic)
    With baryons: ratio increases above 2
    Observed: 2.443 (baryon loading shifts peaks)
```

## Competing Simple Ratios

```
  Expression      Value    Error vs 2.443   Notes
  --------------- -------- --------------- -------------------------
  sopfr/phi = 5/2 2.5000   2.33%           THIS hypothesis
  12/5            2.4000   1.77%           sigma/sopfr (BETTER)
  17/7            2.4286   0.60%           ad-hoc (MUCH BETTER)
  22/9            2.4444   0.05%           ad-hoc (EXCELLENT)
  sqrt(6)         2.4495   0.26%           cleaner (BETTER)
  7/3             2.3333   4.50%           M3/3 (worse)
  tau/phi + 1     3.0000   22.8%           (bad)

  sqrt(6) = 2.4495 matches at 0.26%, much better than 5/2.
  22/9 matches at 0.05%, nearly exact.
  Our 5/2 is NOT the best simple expression.
```

## Why This Fails

```
  Issue 1: 2.33% error is poor
    For a ratio of small integers (5/2), hitting within 2.33%
    of ANY number near 2.5 is unremarkable.

  Issue 2: No physical motivation
    WHY should sopfr (sum of prime factors) relate to acoustic peaks?
    WHY phi (Euler totient) in the denominator?
    There is no chain of reasoning connecting these.

  Issue 3: Better alternatives exist
    sigma/sopfr = 12/5 = 2.4 matches better (1.77%)
    sqrt(6) = 2.449 matches much better (0.26%)
    If we allow two-digit fractions, 22/9 = 2.444 is nearly exact

  Issue 4: The ratio is parameter-dependent
    l2/l1 depends on Omega_b (baryon density) and other parameters
    In a different universe with slightly different Omega_b,
    the ratio would be different. This is NOT a mathematical constant.
```

## n=28 Generalization

```
  sopfr(28)/phi(28) = 11/12 = 0.9167

  vs observed ratio 2.443:
    Error = |0.917 - 2.443| / 2.443 = 62.5%

  CATASTROPHIC FAIL.
  The formula gives a value less than 1, which is unphysical
  (would mean l2 < l1, reversing peak order).
```

## Texas Sharpshooter Test

```
  Search space:
    Ratios a/b where a,b in {sigma,tau,phi,sopfr,n,M3,R}
    ~7 * 6 = 42 ordered pairs (excluding a=b)
    Remove duplicates/trivials: ~30 distinct ratios

  Target: match 2.443 within 2.33% in range [0.1, 12]
    Width: 2.443 * 0.0233 = 0.057
    Range: ~12
    P(single trial): 0.057/12 = 0.0047

  P(any of 30): 1-(1-0.0047)^30 = 0.132

  p-value: 0.35 (with penalty for choosing favorable framing)
  NOT significant.
```

## ASCII Visualization

```
  CMB peak ratio and simple fractions:

  Ratio
  2.60 |
  2.55 |
  2.50 |====X sopfr/phi=5/2                      (2.33% off)
  2.45 |        X sqrt(6)                         (0.26% off)
  2.44 |         X 22/9                           (0.05% off)
  2.443|          * OBSERVED (Planck 2018)
  2.43 |           X 17/7                         (0.60% off)
  2.40 |              X sigma/sopfr=12/5          (1.77% off)
  2.35 |
  2.33 |                  X 7/3                   (4.50% off)
  2.30 |
       +--------+--------+--------+--------->
       5/2 is the WORST of the simple matches

  Harmonic structure:
  Pure harmonic:  l2/l1 = 2.000 (no baryons)
  Observed:       l2/l1 = 2.443 (with baryons)
  Our prediction: l2/l1 = 2.500 (overshoots)

  The shift from 2 to 2.44 is due to baryon loading physics,
  not number theory.
```

## Honesty Assessment

```
  Strengths:
    - Simple expression (5/2)
    - Within 3% of observed value

  Weaknesses:
    - 2.33% error is poor (many better expressions exist)
    - No physical motivation for sopfr or phi
    - l2/l1 is NOT a fundamental constant (parameter-dependent)
    - n=28 fails catastrophically (62% error)
    - p = 0.35 (far from significant)
    - sqrt(6) = 2.449 would be a cleaner claim with better precision

  This is the weakest hypothesis in this batch.
  The ratio 2.443 is well-explained by standard LCDM cosmology
  and requires no number-theoretic explanation.
```

## Grade

```
  Arithmetic: CORRECT (5/2 = 2.5, error 2.33%)
  Texas p-value: 0.35 (>> 0.05, not significant)
  Ad-hoc: HIGH (no motivation for sopfr/phi)
  n=28: CATASTROPHIC FAIL (62% error)
  Competing expressions: MANY BETTER OPTIONS

  GRADE: ⚪ (arithmetically correct but Texas p > 0.05, coincidence)

  Not recommended for any further development.
  The CMB peak ratio is a derived cosmological parameter,
  not a fundamental constant, and is fully explained by
  baryon acoustic oscillation physics.
```

## Related

- H-CX-491: Baryon-to-photon ratio (similar cosmological fitting, also ⚪)
- H-CX-487: Fine structure constant (better precision, 🟧)
- Planck 2018 results (arXiv:1807.06209) for authoritative CMB parameters
