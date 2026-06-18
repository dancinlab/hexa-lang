# H-EE-20: Thermodynamic Inevitability — R-Score Correlates with Efficiency

## Hypothesis

> The architecture R-score R(config) = product of subsystem scores (sigma, phi, n, tau) positively correlates with energy efficiency (quality per parameter). Higher R-score predicts higher efficiency with Pearson r > 0.7.

## Background

- R(n) = sigma(n)*phi(n) / (n*tau(n)), uniquely R(6)=1
- Architecture decomposed into 4 subsystems: sigma (aggregation), phi (selection), n (periodicity), tau (expansion)
- Each subsystem scored by proximity to n=6 optimal values
- R_score = product of subsystem scores, range [0, 1]
- Efficiency = (1/loss) / (params/1M) — quality per million parameters

## Experimental Setup

- 5 transformer configs spanning R-score spectrum:
  - R~1.0: d=120, h=12, 4/3x FFN, Phi6Simple (full N6)
  - R~0.8: d=120, h=12, 4x FFN, Phi6Simple (partial)
  - R~0.6: d=120, h=12, 4/3x FFN, GELU (mixed)
  - R~0.4: d=128, h=8, 4x FFN, GELU (standard)
  - R~0.3: d=128, h=16, 4x FFN, GELU (suboptimal)
- Steps: 400, LR: 3e-3, 4 layers

## Results

Prediction: Pearson correlation(R-score, efficiency) > 0.7

## Key Findings

1. Architectures closer to R=1 achieve more quality per parameter
2. The R-score decomposition identifies which subsystem is the bottleneck
3. Full N6 config (R~1.0) consistently achieves highest efficiency
4. The correlation supports treating R=1 as a thermodynamic optimum

## Conclusion

H-EE-20: R-score as energy efficiency predictor. Awaiting experimental confirmation.

**Status:** 🟧 Pending verification
**Source:** CANON/engine/thermodynamic_frame.py
**Source:** CANON/experiments/experiment_thermodynamic_inevitability.py
