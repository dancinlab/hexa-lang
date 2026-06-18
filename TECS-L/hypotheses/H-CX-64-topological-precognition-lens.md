# H-CX-64: Topological Precognition Lens — H0_total Decay Rate Predicts Precognition AUC

> The epoch-wise decay rate of H0_total_persistence (dH0/dep)
> predicts changes in precognition AUC. Models where PH simplifies rapidly = stronger precognition lens.

## Background

- H-CX-62 v2: H0_total and accuracy correlation r=-0.97 (Fashion)
- H-CX-58: tension_scale and AUC correlation r=0.982
- Intersection of both hypotheses: PH rate of change → precognition strength prediction

**Key Connection**: If tension_scale is the "lens magnification",
then H0_total's decay rate is "how fast the lens focuses".
Rapid topological simplification = rapid focusing = strong precognition.

## Predictions

1. Correlation between dH0/dep (decay rate) and final AUC r > 0.7
2. High precognition AUC in datasets where H0_total decreases rapidly
3. H0_total decay rate × tension_scale = composite precognition strength metric
4. Composite metric has higher predictive power for precognition AUC than single metrics

## Verification Method

```
1. Collect epoch-wise (H0_total, tension_scale, precog_AUC) from 3 datasets
2. dH0/dep = linear regression slope of H0_total vs epoch
3. Calculate Corr(dH0/dep, final_AUC)
4. Composite metric: dH0/dep × tension_scale vs AUC
```

## Related Hypotheses

- H-CX-62 (topological precognition), H-CX-58 (precognition lens)
- H320 (tension_scale log growth)

## Limitations

- Statistical significance of cross-dataset correlation is weak with only 3 datasets
- dH0/dep may not be linear

## Verification Status

- [x] dH0/dep vs AUC correlation
- [x] Composite metric verification

## Verification Results

**Verdict: PRELIMINARY (cross-dataset r=0.912, but n=3 p≈0.27 NOT significant)**

### dH0/dep (Linear Decay Rate)

| Dataset | dH0/dep | final AUC |
|---------|---------|-----------|
| MNIST   | -0.0358 | 0.953     |
| Fashion | -0.0358 | 0.871     |
| CIFAR   | -0.0338 | 0.612     |

### Cross-dataset Correlation

```
Cross-dataset |dH0/dep| vs final_AUC: r = 0.912
```

```
  AUC
  0.95 |  *  MNIST
       |
  0.87 |    *  Fashion
       |
       |
  0.61 |         *  CIFAR
       +--+----+----+------>
        0.034  0.035  0.036
              |dH0/dep|
```

### Epoch-level Correlation (Within Dataset)

| Dataset | corr(H0, AUC) | Interpretation |
|---------|---------------|----------------|
| MNIST   | 0.39          | Weak positive correlation |
| Fashion | -0.05         | No correlation |
| CIFAR   | -0.15         | Weak negative correlation |

Within epochs, the correlation between H0 and AUC is weak -- strong correlation only at cross-dataset level.

### Composite Metric: |dH0/dep| x ts_final

| Dataset | |dH0/dep| x ts_final |
|---------|----------------------|
| MNIST   | 0.070                |
| Fashion | 0.064                |
| CIFAR   | 0.041                |

```
  Composite Metric
  0.07 |  ##  MNIST
  0.06 |  ##  ##  Fashion
  0.05 |  ##  ##
  0.04 |  ##  ##  ##  CIFAR
  0.03 |  ##  ##  ##
       +--+---+---+-->
         MNI  FAS  CIF
```

The composite metric also aligns with AUC order (MNIST > Fashion > CIFAR).
However, with only 3 cross-dataset points, statistical significance is limited.

## Review Notes (2026-03-26)

**Status downgraded: ✅ SUPPORTED → 🟨 PRELIMINARY**

Critical issues:
1. **n=3 is insufficient**: Spearman r=0.912 with n=3 gives p≈0.27 — NOT significant at any conventional threshold
2. **2/3 dH0/dep values are identical** (-0.0358 for MNIST and Fashion) — the "correlation" is driven entirely by CIFAR being different
3. **Within-dataset correlations are weak/absent** (0.39, -0.05, -0.15) — undermines mechanistic claim
4. **No baseline comparison**: epoch-1 accuracy alone likely predicts the same ordering

To upgrade: test on 5-8 additional datasets (SVHN, EMNIST, KMNIST, STL-10, Tiny ImageNet)