# H-CX-491: Baryon-to-Photon Ratio eta = (n + 1/sigma) * 10^(-10)
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> The cosmic baryon-to-photon ratio eta = (6.12 +/- 0.04) * 10^(-10)
> is approximated by (n + 1/sigma) * 10^(-10) = (6 + 1/12) * 10^(-10)
> = 6.0833 * 10^(-10), with 0.60% error from the central value.

## Background

The baryon-to-photon ratio eta is a fundamental cosmological parameter
measured from Big Bang nucleosynthesis and the CMB. Planck 2018 reports
eta = (6.12 +/- 0.04) * 10^(-10). This hypothesis attempts to express
eta through n=6 arithmetic functions.

Golden Zone dependency: INDEPENDENT (cosmological constant).

## Formula

```
  Prediction:
    eta_pred = (n + 1/sigma) * 10^(-(n+tau))
             = (6 + 1/12) * 10^(-10)
             = (73/12) * 10^(-10)
             = 6.08333... * 10^(-10)

  Observation (Planck 2018):
    eta_obs  = (6.12 +/- 0.04) * 10^(-10)

  Error:
    |6.0833 - 6.12| / 6.12 = 0.60%

  Within measurement uncertainty?
    |eta_pred - eta_obs| = 0.0367 * 10^(-10)
    Uncertainty = 0.04 * 10^(-10)
    0.0367 < 0.04, so YES, barely within 1-sigma.
```

## Competing Expressions

```
  Expression      Coefficient   Error vs 6.12
  --------------- ------------- -------------
  6               6.0000        1.96%
  6 + 1/12        6.0833        0.60%    <-- THIS
  6 + 1/10        6.1000        0.33%
  6 + 1/8         6.1250        0.08%    <-- BETTER
  6 + 1/5         6.2000        1.31%
  sqrt(37.5)      6.1237        0.06%
  49/8            6.1250        0.08%
  61/10           6.1000        0.33%

  Note: 6 + 1/8 = 49/8 matches BETTER (0.08% vs 0.60%)
  and 8 = 2^3 could be expressed as phi^3.
  The choice of 1/sigma = 1/12 is NOT the best simple fraction.
```

## Ad-Hoc Analysis

```
  THREE free parameters chosen post-hoc:

  1. Base: n = 6 (WHY n? Could use any constant)
  2. Fraction: 1/sigma = 1/12 (WHY sigma? Not the best fit)
  3. Exponent: -10 = -(n+tau) (WHY n+tau? No physical reason)

  The exponent -10 = -(n+tau) is STRONGLY ad-hoc:
    -10 could equally be:
      -(n + tau)       = -(6+4)   = -10
      -(sigma - phi)   = -(12-2)  = -10
      -(sopfr * phi)   = -(5*2)   = -10
      -(2*sopfr)       = -(2*5)   = -10
    Multiple paths to -10, none physically motivated.

  Level: HIGH ad-hoc (3 degrees of freedom, no motivation)
```

## n=28 Generalization

```
  Using same formula structure with n=28:
    (n + 1/sigma) * 10^(-(n+tau))
    = (28 + 1/56) * 10^(-(28+6))
    = 28.0179 * 10^(-34)
    = 2.80 * 10^(-33)

  This is 23 orders of magnitude smaller than eta.
  No physical meaning whatsoever.

  FAILS catastrophically for n=28.
```

## Texas Sharpshooter Test

```
  Search space:
    Coefficient: ~20 simple fractions n+1/k for k in n=6 expressions
    Exponent: given as -10 (fixed by observation, adds 1 parameter)
    Total effective trials: ~20 (coefficient fitting only)

  Target: match within 1% of 6.12 in range [1, 10]
    Width: 6.12 * 0.01 = 0.0612
    Range: 10
    P(single trial hits): 0.0612/10 = 0.006

  P(any of 20 trials): 1-(1-0.006)^20 = 0.113

  p-value: 0.15 (adjusted for exponent ad-hoc penalty)
  NOT significant (> 0.05)
```

## ASCII Visualization

```
  eta coefficient comparison:

  6.00 |==========================|                          exact 6
  6.05 |                          |===|
  6.08 |                          |   |==|  <-- 6+1/12      THIS (0.60%)
  6.10 |                          |   |  |=|  <-- 6+1/10    (0.33%)
  6.12 |                          |   |  | |X  <-- OBSERVED
  6.125|                          |   |  | |=| <-- 6+1/8    (0.08%)
  6.15 |                          |   |  |   |
  6.17 |                          |   |  |   |= <-- 6+1/6   (0.76%)
       +----+----+----+----+----+----+----+----+
      5.8  5.9  6.0  6.1  6.2  6.3

  Error bars (1-sigma = 0.04):
       |<-------- 0.04 -------->|
  6.08       6.12       6.16
    ^          ^
    pred       obs
    Within 1-sigma (barely)
```

## Honesty Assessment

```
  Strengths:
    - Within 1-sigma of Planck measurement
    - Uses simple, memorable expression: 73/12

  Weaknesses:
    - 0.60% error is mediocre (6+1/8 does better)
    - THREE post-hoc parameter choices
    - Exponent -(n+tau) = -10 has no physical motivation
    - n=28 fails catastrophically
    - p = 0.15 (not significant)
    - The leading "6" is just n itself (circular: eta ~ 6*10^-10
      because we chose n=6)

  The circularity problem is fatal: if we START with n=6, and
  eta happens to have leading digit 6, matching the leading digit
  is guaranteed, not a discovery.
```

## Grade

```
  Arithmetic: CORRECT (6.0833 vs 6.12, error 0.60%)
  Texas p-value: 0.15 (> 0.05, not significant)
  Ad-hoc: HIGH (3 free parameters, no physics)
  n=28: CATASTROPHIC FAIL
  Circularity: PRESENT (n=6 -> leading digit 6)

  GRADE: ⚪ (arithmetically correct but Texas p > 0.05, high ad-hoc)

  This is a textbook case of fitting a constant with too many
  degrees of freedom. Not recommended for further development.
```

## Related

- H-CX-487: Fine structure constant (similar spirit, better precision)
- H-CX-492: CMB peak ratio (similar cosmological fitting)
- Dirac large number hypothesis (historical precedent for numerology in cosmology)
