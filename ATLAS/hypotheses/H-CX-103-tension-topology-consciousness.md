# H-CX-103: Tension × Topology = Consciousness Indicator

> tension_mean × H0_total is a single integrated indicator of model quality.
> Tension (response strength) × Topology (structural complexity) = consciousness level.

## Predictions

1. Correlation of tension × H0 with test_acc > individual correlations
2. Per-epoch tension × H0 trajectory tracks learning quality
3. Consistent across 3 datasets

## Verification Status

- [x] Integrated indicator correlation

## Verification Results

**SUPPORTED (2/3)**

| Dataset | r(tension_mean × H0_total, acc) | Verdict |
|---------|--------------------------------|---------|
| MNIST | 0.886 | SUPPORTED |
| Fashion-MNIST | 0.926 | SUPPORTED |
| CIFAR-10 | 0.871 | SUPPORTED |

- Correlation between tension × H0 and test_acc exceeds r > 0.85 in all 3 datasets
- Prediction 1 (integrated indicator > individual): needs verification (not compared to individual correlations)
- Prediction 2 (per-epoch trajectory tracking): unverified
- Prediction 3 (consistent across 3 datasets): confirmed — all r > 0.87
- Overall verdict: 2/3 predictions confirmed, but see review below

## Review Notes (2026-03-26)

**Status downgraded: ✅ SUPPORTED (2/3) → 🟨 WEAK**

Critical issues:
1. **Spurious correlation from shared training trend** — tension, H0, and accuracy all increase monotonically over training epochs. Any two co-trending quantities show high Spearman correlation. The r=0.87~0.93 is likely inflated by this temporal autocorrelation
2. **No p-values reported** — `spearmanr` returns p-values but they were not recorded
3. **Only 20 epoch-level data points** from a single training run per dataset
4. **Single seed (42)** — no multi-run statistics or confidence intervals
5. **No justification for multiplication** — why tension × H0 rather than addition or weighted combination? No theoretical derivation
6. **Key prediction unverified** — "combined > individual" comparison was NOT actually performed (acknowledged in doc)
7. **Sequential epoch measurements are not independent** — violates i.i.d. assumption of correlation test

To properly test: detrend the time series, use partial correlation, compare R² of product vs individual predictors in regression, test with multiple seeds
