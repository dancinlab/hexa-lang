# H-SEDI-2: Fermion Mass Tower from {sigma, tau, phi}
**n6 Grade: 🟩 EXACT** (auto-graded, 12 unique n=6 constants)


**Grade: ⚪ Overfitted (11 choices for 6 outputs)**
**Golden Zone dependency: None (pure arithmetic)**
**Cross-domain: SEDI particle physics x TECS-L n=6 arithmetic**

## Hypothesis

> The six quark masses can be expressed as combinations of sigma(6)=12, tau(6)=4,
> phi(6)=2, tau(28)=6, and tau(496)=10, using six distinct formulas.
> Average error is 2.2% across all predictions.

## Background

The SEDI framework claims that divisor functions of perfect numbers 6, 28, 496
encode the quark mass spectrum. This is a strong claim requiring careful audit
of parameter freedom.

Related: H-090 (master formula = perfect number 6), H-067 (constant relationships).

## Predictions vs Observations

```
  Constants: s=sigma(6)=12, t=tau(6)=4, p=phi(6)=2, t2=tau(28)=6, t3=tau(496)=10

  Quark     Formula              Calculation           Pred MeV   Obs MeV   Error%  Sigma
  ------    --------             -----------           --------   -------   ------  -----
  top       s^3(s^2-st+t)       1728*(144-48+4)       172800     172760    0.02%    0.1
  bottom    p^s = 2^12          4096                   4096       4180      2.01%    2.8
  charm     (s*t3+t*p)*t3       (120+8)*10             1280       1270      0.79%    0.5
  strange   s*t*p               12*4*2                 96         93.4      2.78%    0.3
  down      t+p/t2              4+1/3                  4.333      4.67      7.21%    0.7
  up        p+p/s               2+1/6                  2.167      2.16      0.31%    0.0
```

### ASCII: Prediction vs Observation (log scale)

```
  log10(mass/MeV)
  6 |                                              T*
  5 |                                           (top)
  4 |
  3 |                       B*      (bottom)
  2 |              C*               (charm)
  1 |     S*                        (strange)
  0 | DU                            (down, up)
    +---+---+---+---+---+---+---+---+---+---+
    u   d   s       c       b               t

    * = prediction, letter = observation
    Spacing ~ log scale. Predictions track observations well.
```

## Free Parameter Analysis

```
  INPUT CONSTANTS (5):
    sigma(6)  = 12   |
    tau(6)    = 4    |-- from P1 = 6
    phi(6)    = 2    |
    tau(28)   = 6    --- from P2 = 28
    tau(496)  = 10   --- from P3 = 496

  FORMULA SELECTIONS (6):
    top:     s^3(s^2 - s*t + t)     3 terms, specific polynomial
    bottom:  p^s                     exponentiation choice
    charm:   (s*t3 + t*p) * t3      specific grouping
    strange: s*t*p                   simple product
    down:    t + p/t2               sum + fraction, uses P2
    up:      p + p/s                sum + fraction

  TOTAL CHOICES: 5 constants + 6 formula shapes = 11 degrees of freedom
  TOTAL OUTPUTS: 6 quark masses
  RATIO: 11/6 = 1.83  (> 1 means overfitted)
```

## Texas Sharpshooter Test

Monte Carlo with 50,000 random sets of 5 integers (2-15), same formula templates:

```
  Trials:  50,000
  Hits (5+ of 6 within 10%): 15
  Raw p-value: 0.0003

  BUT: The 6 formula templates were CHOSEN to fit the data.
  With ~100 possible 2-3 variable expressions per mass slot,
  effective formula trials ~ 100^6 = 10^12.
  Even with just 10 alternatives per slot: 10^6 = 1,000,000 trials.
  Bonferroni-corrected p-value: 0.0003 * 1,000,000 >> 1

  Verdict: NOT significant after Bonferroni correction for formula selection.
```

## Reachability Analysis

```
  From {2, 4, 6, 10, 12} with at most 2 arithmetic operations:
  Reachable integers in [1, 200000]: 238
  Hit rate: 0.1%

  The target 172800 IS reachable (12^3 * 100 = 172800), so the top quark
  formula is genuinely constrained. But lighter quarks (96, 1280, 4096)
  are also easily reachable from small integers.
```

## Generalization Test

For perfect number 28: sigma(28)=56, tau(28)=6, phi(28)=12
```
  "top" formula: 56^3 * (56^2 - 56*6 + 6) = 175616 * 2802 = 492,175,632 MeV
  This is ~3 million times too large. Does NOT generalize.
```

## Limitations

1. Formula selection freedom is the fatal flaw: 6 different formulas for 6 masses
2. No principle explains WHY top uses a cubic polynomial but bottom uses exponentiation
3. The formulas do not generalize to P2=28
4. Light quark masses (u, d) have large experimental uncertainties (~20%), making
   "matching" easy
5. down quark prediction is 7.2% off -- the worst of the set

## Verdict

The numerical matches are visually impressive (avg ~2.2% error) but the 11 degrees
of freedom for 6 outputs make this overfitted. No formula selection principle is
provided. The Texas Sharpshooter test, after Bonferroni correction for formula
choice, yields p >> 0.05. Grade: ⚪ (arithmetically possible but not structurally
significant).

## Next Steps

1. Find a SINGLE formula that predicts multiple masses (reduce formula freedom)
2. Make a BLIND prediction (predict a mass before measurement)
3. Derive formulas from a Lagrangian rather than fitting
