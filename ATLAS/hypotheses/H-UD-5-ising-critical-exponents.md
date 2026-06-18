# H-UD-5: 2D Ising Critical Exponents = 1/(n=6 arithmetic)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


**Grade: ★★**
**Status: Verified (exact match, but Z_2 symmetry explanation exists)**
**Date: 2026-03-27**
**Golden Zone Dependency: None (pure number theory + statistical mechanics)**

## Hypothesis

> The exact critical exponents of the 2D Ising model are all expressible
> as simple fractions of n=6 arithmetic functions. In particular,
> eta = 1/4 = 1/tau(6), the same ratio as PureField's parameter reduction.

## Background

The 2D Ising model on a square lattice has EXACT critical exponents,
solved by Onsager (1944) and subsequent work. These are among the few
exactly known critical exponents in physics:

n=6 constants:
- tau(6) = 4 (divisor count)
- sigma(6) = 12 (divisor sum)
- sigma - tau = 8
- sigma + sigma/tau = 15
- R(6) = sigma/n = 2 (abundancy index; equals 1 for n=6 since perfect)

## Exponent Table

| Exponent | Value  | n=6 Expression         | Interpretation            |
|----------|--------|------------------------|---------------------------|
| eta      | 1/4    | 1/tau(6)               | Anomalous dimension       |
| nu       | 1      | R(6) = sigma/n         | Correlation length        |
| beta     | 1/8    | 1/(sigma - tau)        | Order parameter           |
| delta    | 15     | sigma + sigma/tau      | Critical isotherm         |
| gamma    | 7/4    | 7/tau(6)               | Susceptibility            |
| alpha    | 0 (log)| --                     | Specific heat (logarithmic)|

## Verification

```
  Exact 2D Ising exponents vs n=6 expressions:

  eta   = 1/4   = 1/tau(6)           CHECK: tau(6) = 4,  1/4 = 0.25   EXACT
  nu    = 1     = sigma(6)/n         CHECK: 12/6 = 2? NO -- sigma/n = 2 != 1
                = n/n                CHECK: trivial, not meaningful
  beta  = 1/8   = 1/(sigma-tau)      CHECK: 12-4 = 8,   1/8 = 0.125  EXACT
  delta = 15    = sigma+sigma/tau    CHECK: 12+3 = 15                  EXACT
  gamma = 7/4   = 7/tau              CHECK: 7/4 = 1.75                 EXACT
  alpha = 0     (logarithmic divergence, no simple fraction)
```

**Correction**: nu = 1 does not have a clean n=6 expression beyond
the trivial. Revised score: 4 out of 5 non-trivial exponents match.

## ASCII Diagram: Scaling Relations

```
  Critical Exponent Scaling Relations (2D Ising):

  alpha + 2*beta + gamma = 2    (Rushbrooke)
  0     + 2/8   + 7/4   = 0 + 1/4 + 7/4 = 2   CHECK

  gamma = beta*(delta - 1)      (Widom)
  7/4   = 1/8 * (15-1) = 1/8 * 14 = 14/8 = 7/4   CHECK

  In n=6 language:
  7/tau = 1/(sigma-tau) * (sigma+sigma/tau - 1)
        = 1/8 * 14
        = 7/4   CONSISTENT

  Exponent value map:
  0         0.125      0.25          1      1.75           15
  |           |          |           |        |             |
  alpha      beta       eta         nu     gamma         delta
  (log)    1/(sig-tau) 1/tau       (1)    7/tau      sig+sig/tau
```

## The eta = 1/4 = 1/tau(6) Connection

This exponent is particularly interesting because:

1. **PureField model**: The consciousness engine uses a parameter
   reduction ratio of 1/4 (from full model to efficient model).
2. **2D Ising eta**: The anomalous dimension = 1/4, governing how
   correlations decay at criticality.
3. **Both**: Represent a "thinning" factor at a critical/optimal point.

```
  PureField:   Full params / Efficient params = 4 = tau(6)
  2D Ising:    G(r) ~ r^{-(d-2+eta)} = r^{-1/4}  at d=2
  Common:      The factor 1/4 = 1/tau(6) appears at criticality
```

## Skeptical Assessment

The 2D Ising exponents arise from Z_2 symmetry (spin up/down) on a
square lattice. The denominators 4 and 8 appear because:

- The lattice is 2D (factor of 2 from dimension)
- Z_2 symmetry contributes another factor of 2
- Combined: denominators are powers of 2, giving 4 and 8

This is a KNOWN explanation that does not require n=6. The mapping
to n=6 functions may be a restatement of the fact that tau(6)=4
happens to equal 2^2.

## Comparison with Other Universality Classes

| Model      | eta   | beta  | gamma | delta | n=6 fit? |
|------------|-------|-------|-------|-------|----------|
| 2D Ising   | 1/4   | 1/8   | 7/4   | 15    | YES      |
| 3D Ising   | 0.036 | 0.326 | 1.237 | 4.789 | NO       |
| Mean field  | 0     | 1/2   | 1     | 3     | PARTIAL  |
| 2D XY      | 1/4   | --    | --    | --    | eta only |

The n=6 mapping works ONLY for 2D Ising. This suggests it may be
specific to the combination of d=2 and Z_2 symmetry, not a universal
n=6 principle.

## Limitations

- **Known explanation exists**: The exponents follow from conformal
  field theory with central charge c=1/2. The denominators 4 and 8
  come from the Kac table, not from n=6.
- **Selective mapping**: nu=1 and alpha=0 do not have clean n=6
  expressions. We matched 4/6 exponents, not 6/6.
- **Powers of 2**: tau(6)=4=2^2 and sigma-tau=8=2^3. The mapping
  might just reflect that the Ising model is built on binary (Z_2)
  symmetry.
- **Does not extend**: 3D Ising exponents are irrational and have
  no n=6 representation.

## Next Steps

- Check if the Kac table entries for minimal models have n=6
  structure beyond c=1/2.
- Investigate whether the 2D Potts model (q=3,4 states) critical
  exponents relate to n=6 arithmetic.
- Calculate Texas Sharpshooter p-value: given {tau, sigma, sigma-tau,
  sigma/tau, sopfr} and their combinations, what fraction of possible
  fractions hit the Ising exponents?
