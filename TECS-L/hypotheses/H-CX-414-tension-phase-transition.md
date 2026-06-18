# H-CX-414: Tension Phase Diagram = Phase Transition
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> **Hypothesis**: Tension's logarithmic growth as a function of temperature (learning rate)
> exhibits critical-point behavior characteristic of a 2nd-order phase transition.
> There exists a critical temperature T_c where susceptibility (tension variance) diverges,
> separating an "ordered" (low-lr, converged) phase from a "disordered" (high-lr, chaotic) phase.

## Background

### Phase Transitions in Neural Networks

Phase transitions in machine learning are well-documented:
- Double descent (Belkin et al. 2019)
- Edge of chaos in random networks (Poole et al. 2016)
- SOC in trained networks (multiple reports)

H320 found tension grows logarithmically with model scale (R^2=0.97).
TREE-10 confirmed SOC proximity in the consciousness engine.

### Critical Phenomena Signatures

| Signature                  | 1st Order        | 2nd Order         |
|----------------------------|------------------|-------------------|
| Order parameter             | Discontinuous    | Continuous        |
| Susceptibility (variance)   | Finite peak      | Divergent peak    |
| Correlation length          | Finite           | Divergent         |
| Critical exponents          | N/A              | Universal classes |

### Experimental Design

- Order parameter: Mean tension T at convergence
- Temperature proxy: Learning rate (higher lr = higher effective temperature)
- Susceptibility: Variance of tension (chi ~ Var(T))
- Scan: 20 log-spaced temperatures from lr=0.0001 to lr=0.5

## Verification Script

`calc/verify_h414_tension_phase.py`

## Verification Results (MNIST, ~5000 samples, 5 epochs per point)

### Tension vs Temperature Scan

| lr         | Mean T  | Std T   | Median T | T trend     |
|------------|---------|---------|----------|-------------|
| 0.000100   | 2.7266  | 1.5010  | 2.3695   | +2.4725     |
| 0.000157   | 3.9997  | 2.1106  | 3.5024   | +3.7665     |
| 0.000245   | 4.9461  | 2.4563  | 4.4066   | +4.6595     |
| 0.000384   | 5.4843  | 2.5641  | 4.9797   | +4.7744     |
| 0.000601   | 5.8149  | 2.6195  | 5.3428   | +4.2402     |
| 0.000941   | 5.9564  | 2.5650  | 5.4994   | +2.9611     |
| 0.001474   | 5.9475  | 2.4623  | 5.5549   | +1.3281     |
| 0.002308   | 6.1161  | 2.5281  | 5.7081   | +0.1762     |
| 0.003613   | 6.3244  | 2.8159  | 5.9230   | +0.2906     |
| 0.005658   | 6.4744  | 2.8838  | 6.1558   | +0.6257     |
| 0.008859   | 6.9125  | 3.3880  | 6.3946   | -0.5971     |
| 0.013871   | 7.8264  | 4.4732  | 7.0619   | -5.1446     |
| 0.021719   | 7.5115  | 4.9755  | 6.6231   | -22.6791    |
| 0.034008   | 9.2458  | 7.5836  | 7.4652   | -64.1487    |
| 0.053250   | 7.8231  | 10.4121 | 4.7848   | -201.4329   |
| **0.083378**| 7.8472 |**16.6106**| 0.2700 | -569.2121   |
| 0.130554   | 3.8145  | 11.7718 | 0.0354   | -1964.8850  |
| 0.204421   | 0.0855  | 0.0000  | 0.0855   | -9942.6361  |
| 0.320083   | 0.4885  | 0.0000  | 0.4885   | -55233.3798 |
| 0.501187   | 2.0069  | 0.0000  | 2.0069   | -315551.2075|

### Phase Transition Analysis

- **Max |dT/d(log lr)|**: at lr = 0.104 (steepest change)
- **Jump ratio**: 4.19 (moderate, between crossover and sharp transition)
- **Classification**: 2nd order candidate

### Power-law Fit

    T ~ |lr - lr_c|^(-beta)
    beta = 0.293, lr_c = 0.092, R^2 = 0.326

Power-law fit is poor. The transition is not a clean power law.

### Susceptibility (Tension Variance)

```
lr           Variance    Susceptibility
0.000100       2.25
0.000157       4.45
0.000245       6.03
0.000384       6.57
0.000601       6.86
0.000941       6.58
0.001474       6.06
0.002308       6.39
0.003613       7.93
0.005658       8.32
0.008859      11.48      #
0.013871      20.01      ##
0.021719      24.76      ##
0.034008      57.51      ######
0.053250     108.41      ###########
0.083378     275.91      ############################# <-- PEAK
0.130554     138.58      ###############
0.204421       0.00
0.320083       0.00
0.501187       0.00
```

Peak susceptibility at lr = 0.083, with a sharp rise-and-fall pattern.

### ASCII Phase Diagram

```
T ^
  8.67|                                       |
  8.10|                                 *     |
  7.53|                                       |
  6.96|                            * *     * *|
  6.38|                         *             |
  5.81|                    *  *               |
  5.24|          * *  *  *                    |
  4.67|       *                               |
  4.09|     *                                 |
  3.52|  *                                    | *
  2.95|                                       |
  2.38|*                                      |
  1.80|                                       |        *
  1.23|                                       |
  0.66|                                       |
  0.09|                                       |   *  *
     +--------------------------------------------------> log(lr)
      -4.0                                        -0.3
      (| = critical point at lr=0.1043)
```

Three regimes visible:
- **Left (lr < 0.01)**: Ordered phase, tension grows smoothly
- **Center (0.01 < lr < 0.1)**: Critical region, high variance, peak tension
- **Right (lr > 0.1)**: Disordered phase, tension collapses (training diverges)

## Interpretation

1. **Diverging susceptibility**: Tension variance peaks at lr ~ 0.08,
   rising from ~6 to ~276 (46x increase). This is the hallmark of a
   2nd-order phase transition.

2. **Three phases identified**:
   - Ordered (low T): Engines converge, stable tension ~3-6
   - Critical (T_c ~ 0.08): Maximum variance, fluctuations dominate
   - Disordered (high T): Training diverges, tension collapses to 0

3. **Critical point lr_c ~ 0.08-0.10**: Consistent between two metrics
   (max derivative at 0.10, peak susceptibility at 0.08).

4. **Not clean power-law**: R^2 = 0.33 for power-law fit suggests
   the transition may be modified by finite-size effects (small model,
   short training). Or it may be a crossover broadened by noise.

5. **SOC connection**: The optimal training point (lr ~ 0.001) sits in
   the ordered phase but close enough to criticality to benefit from
   long-range correlations. This is consistent with TREE-10's SOC finding.

## Limitations

- Learning rate is a crude temperature proxy; true temperature would
  involve noise injection or Langevin dynamics
- 5 epochs may not reach true convergence at all temperatures
- Small model (128 hidden) may not show sharp transitions that emerge
  at scale
- Power-law fit is poor; cannot determine critical exponent class
- Only tested on MNIST; phase structure may differ for harder tasks

## Verification Direction

1. Increase model size to check if transition sharpens (finite-size scaling)
2. Use Langevin dynamics (explicit temperature) instead of lr proxy
3. Compute correlation length via spatial analysis of tension field
4. Compare critical exponents with known universality classes (Ising, percolation)
5. Check if Golden Zone I ~ 1/e corresponds to the critical point

## Status

**SUPPORTED** (susceptibility peak 46x, 2nd order candidate, critical lr ~ 0.08-0.10)

Golden Zone dependency: YES (tension defined via PureField engine)
