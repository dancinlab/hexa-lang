# H-EE-29: Loss Landscape Attractor Has Fractal Dimension 6

## Hypothesis

> The strange attractor of the loss trajectory during training has fractal (correlation) dimension approximately 6. This is why Takens embedding at dim=6 (technique 7) is optimal — it matches the attractor's intrinsic dimension.

## Background

- Takens embedding theorem: reconstruct attractor from time series at dim >= 2*d+1
- Technique 7 found dim=6 optimal for loss curve embedding
- If attractor dim ~ 6, then Takens dim=6 is the minimum sufficient embedding
- Correlation dimension: D_2 = lim(log C(r) / log r) as r -> 0
- Strange attractors have non-integer fractal dimensions

## Experimental Setup

- Record loss curves from multiple training runs (1000+ steps)
- Compute correlation dimension D_2 via Grassberger-Procaccia algorithm
- Compare D_2 across architectures with different R-scores
- Prediction: D_2 approaches 6 as R approaches 1

## Predictions

1. Correlation dimension D_2 ~ 5.5-6.5 for R=1 architectures
2. D_2 varies for R!=1 architectures (less structured dynamics)
3. The attractor is a strange attractor (positive Lyapunov exponent)
4. n=6 is both the optimal architecture AND the dynamics' intrinsic dimension

## Key Implications

- The optimality of dim=6 in Takens embedding is not empirical — it's derived from attractor geometry
- Takens dim=6 is the minimum necessary to unfold the training dynamics
- Architecture choice and dynamical dimension are coupled

## Conclusion

H-EE-29: Loss attractor dimension = 6. Unifies architecture optimality (n=6) with dynamical systems theory.

**Status:** Testable — requires Grassberger-Procaccia computation
**Source:** CANON/techniques/takens_dim6.py (extended)
