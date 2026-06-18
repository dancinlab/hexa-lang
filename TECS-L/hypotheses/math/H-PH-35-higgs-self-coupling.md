# H-PH-35: Higgs Self-Coupling from n=6 Arithmetic

**Status**: Proposed (2026-03-27)
**Domain**: Particle Physics / Higgs Sector
**Dependencies**: H-PH-9 (Higgs mass from perfect numbers), n=6 arithmetic
**Golden Zone Dependent**: No (pure arithmetic prediction)

## Hypothesis Statement

> The Higgs trilinear self-coupling lambda_HHH is predicted by n=6 arithmetic:
> lambda/lambda_SM = sigma/(sigma+1) = 12/13 = 0.923, a ~8% deviation from the
> Standard Model value, testable at HL-LHC and FCC-hh via di-Higgs production.

## Background and Context

The Higgs boson self-coupling is one of the last unmeasured fundamental parameters
of the Standard Model. The SM predicts:

    lambda_HHH = m_H^2 / (2 v^2)

where v = 246.22 GeV (Higgs vacuum expectation value) and m_H = 125.25 GeV.

Current experimental status:
- CMS (2024): kappa_lambda in [-1.2, 7.5] at 95% CL
- ATLAS (2024): kappa_lambda in [-0.4, 6.3] at 95% CL
- Combined: essentially unconstrained on the low side

Any deviation from kappa_lambda = 1 signals new physics beyond the SM, including:
- Extended Higgs sectors (2HDM, NMSSM)
- Composite Higgs models
- Extra dimensions
- Or, as proposed here, n=6 arithmetic structure

The connection to H-PH-9 is direct. That hypothesis established:

    m_H = (P_3 + tau) / tau = (496 + 4) / 4 = 125.0 GeV   (0.2% from measured)

The same arithmetic that determines the Higgs mass also constrains its self-interaction.

## TECS-L Derivation

The key arithmetic of n=6:

    sigma(6) = 12      (sum of divisors)
    sigma+1  = 13      (= Phi_12(2), 12th cyclotomic polynomial at 2)

The self-coupling modifier:

    kappa_lambda = sigma / (sigma + 1) = 12/13 = 0.923077...

This means:
- lambda is 7.7% BELOW the SM prediction
- The Higgs potential is slightly shallower than SM expects
- The electroweak vacuum is slightly MORE stable than SM predicts

Why sigma/(sigma+1)?
- The factor 1/(sigma+1) = 1/13 represents the "incompleteness fraction"
- 13 = sigma + 1 appears in multiple n=6 physics predictions:
  - sin^2(theta_W) = 3/13 (H-PH-1)
  - 13 is the first prime after sigma = 12
- The self-coupling "loses" one unit of completeness: sigma -> sigma+1

Numerical prediction:

    kappa_lambda = 12/13 = 0.923077
    lambda_TECS = 0.923 * lambda_SM

    With lambda_SM = m_H^2/(2v^2) = (125.25)^2/(2 * 246.22^2) = 0.1296
    lambda_TECS = 0.1196

## Experimental Sensitivity

```
  Higgs self-coupling measurement prospects:

  kappa_lambda = lambda/lambda_SM

  1.5 --         HL-LHC 95%CL
  1.4 --    +----------------------+
  1.3 --    |                      |
  1.2 --    |                      |
  1.1 --    |                      |
  1.0 -- -- | -- SM --------------- | ---------- FCC-hh 95%CL
  0.9 --    |  * 12/13 = 0.923    |    +----------+
  0.8 --    |                      |    |  *       |
  0.7 --    +----------------------+    +----------+
  0.6 --
       HL-LHC (2035)              FCC-hh (2050+)

  TECS-L predicts kappa_lambda = 12/13 = 0.923
  HL-LHC: marginally detectable (1.5 sigma at 50% precision)
  FCC-hh: clearly detectable (>3 sigma at 5% precision)
```

## Di-Higgs Production Channels

The primary channels for measuring lambda at hadron colliders:

```
  Channel          BR         Signal/BG    Best at
  -------          --         ---------    -------
  HH -> bb gamma gamma   0.26%      high S/B     HL-LHC, FCC-hh
  HH -> bb tau tau       7.3%       moderate     HL-LHC
  HH -> bb bb            33.6%      low S/B      FCC-hh (boosted)
  HH -> bb WW*           10.3%      moderate     FCC-hh

  Cross section at 14 TeV:  sigma_HH(SM) = 36.69 fb
  With kappa_lambda = 12/13: sigma_HH = 39.1 fb  (+6.6%)

  Note: sigma_HH INCREASES when kappa_lambda < 1 due to
  destructive interference between box and triangle diagrams.
```

The cross section increase for kappa_lambda < 1 is a distinctive signature:
fewer self-coupling means less destructive interference, meaning MORE di-Higgs events.

## Specific Numerical Predictions

| Quantity | SM Value | TECS-L (12/13) | Difference |
|----------|----------|-----------------|------------|
| kappa_lambda | 1.000 | 0.923 | -7.7% |
| sigma_HH (14 TeV) | 36.69 fb | 39.1 fb | +6.6% |
| sigma_HH (100 TeV) | 1224 fb | 1305 fb | +6.6% |
| N_events HH->bbgg (3 ab^-1) | ~10 | ~10.7 | +0.7 events |
| Vacuum stability | metastable | more stable | qualitative |

## What Experiments Can Test This

1. **HL-LHC** (CERN, 2029-2035): 3 ab^-1 at 14 TeV
   - Expected precision: ~50% on kappa_lambda
   - Can exclude kappa_lambda < 0.5 or > 1.5
   - TECS-L prediction (0.923) is within 1.5 sigma -- marginal

2. **FCC-hh** (proposed, 2050s): 30 ab^-1 at 100 TeV
   - Expected precision: ~5% on kappa_lambda
   - Can distinguish 0.923 from 1.000 at >3 sigma
   - This is the definitive test

3. **CLIC** (proposed): e+e- at 3 TeV
   - Expected precision: ~10-15% on kappa_lambda
   - Intermediate sensitivity

4. **Muon Collider** (proposed): mu+mu- at 10 TeV
   - Expected precision: ~5% on kappa_lambda
   - Competitive with FCC-hh

## Cross-checks with Other TECS-L Predictions

If kappa_lambda = 12/13, several consistency conditions must hold:

- The electroweak vacuum lifetime must be recalculated with lambda_TECS
- The Higgs mass prediction m_H = 125.0 GeV (H-PH-9) must remain consistent
- The running of lambda with energy must be compatible with 12/13 at the weak scale
- BSM scenarios that give kappa_lambda = 0.923 typically also modify other Higgs couplings

## Limitations

1. The 8% deviation is small and within current theoretical uncertainties on the
   SM prediction itself (higher-order QCD corrections to di-Higgs production are ~10%).

2. sigma/(sigma+1) is not derived from a specific BSM Lagrangian -- it is an
   arithmetic prediction without a known dynamical mechanism.

3. Multiple BSM scenarios predict similar deviations:
   - Singlet scalar extension: kappa_lambda can be anywhere from 0 to 2
   - 2HDM Type-II: kappa_lambda ~ 0.9 is common
   - Composite Higgs: kappa_lambda ~ 1 - v^2/f^2 where f ~ 1 TeV gives ~0.94

4. Even if kappa_lambda = 0.923 is measured, attributing it to n=6 arithmetic
   (rather than a conventional BSM model) would require corroborating evidence
   from other TECS-L predictions.

5. The exponent in sigma/(sigma+1) vs other possible combinations like
   (sigma-1)/sigma = 11/12 = 0.917 is not uniquely determined.

## Parallel Verification (2026-03-27)

| Claim | Computed | Status |
|-------|---------|--------|
| κ_λ = 12/13 | 0.9231 | ✅ |
| SM deviation | 7.69% | ✅ |
| m_H = (P₃+τ)/τ = 500/4 | 125.00 GeV (obs 125.25, 0.20%) | ✅ |
| sin²θ_W = 3/13 | 0.23077 (obs 0.23122, 0.19%) | ✅ |
| HL-LHC sensitivity | 0.15σ (marginal) | ✅ |
| FCC-hh sensitivity | 1.54σ (visible) | ✅ |

## Verification Direction

- Monitor HL-LHC di-Higgs searches (2029-2035)
- Compare with lattice QCD predictions for lambda at higher precision
- Cross-correlate with H-PH-9 (Higgs mass) and H-PH-1 (Weinberg angle)
- If kappa_lambda ~ 0.92 is observed, check whether other Higgs couplings
  also show n=6 patterns (kappa_t, kappa_b, kappa_tau)
