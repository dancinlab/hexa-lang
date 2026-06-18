# Hypothesis 293: Universality of Tension Anomaly Detection — AUROC > 0.9 on All Dense Data?

> **Is anomaly detection AUROC=1.0 only on synthetic data, or is it maintained on real data? If repulsion field tension is a universal anomaly score, comparison with existing anomaly detection techniques (Isolation Forest, Autoencoder) is necessary.**

## Verification Targets

```
  Synthetic data: AUROC=1.0 (confirmed, Hypothesis 287)
  Real data candidates:
    1. Credit card fraud (Kaggle creditcard) → Real anomaly detection benchmark
    2. Network intrusion (KDD Cup 99) → Cybersecurity
    3. Medical anomalies (breast cancer outlier) → Healthcare
    4. Manufacturing sensors (SWAT/SWaT) → Industrial

  Comparison techniques:
    Isolation Forest
    Autoencoder reconstruction error
    One-Class SVM
    → Is tension better than these?
```

## Experimental Results (2026-03-24)

```
  Dataset               IForest   OC-SVM   Tension   Recon     Combined
  ─────────────────────  ───────   ──────   ───────   ─────     ────────
  Breast Cancer          0.9736    0.9401   0.9469    0.9631    0.9596
  Digits (normal=0)      0.9914    0.9949   0.9607    0.9946    0.9782
  Gaussian Outliers      1.0000    1.0000   1.0000    1.0000    1.0000
```

### Analysis

```
  Tension standalone AUROC:
    Breast Cancer:    0.947 (IForest 0.974, -2.7%)
    Digits:           0.961 (OC-SVM 0.995, -3.4%)
    Gaussian:         1.000 (tied)

  Average AUROC:
    IForest:   0.988
    OC-SVM:    0.978
    Tension:   0.969 (-1.9% from best)
    Recon:     0.986
    Combined:  0.979

  Conclusion: Tension approaches but doesn't surpass specialized anomaly detection techniques
    → Synthetic: AUROC=1.0 (perfect)
    → Real: AUROC 0.95~1.0 (competitive but not best)
    → Tension achieves 0.95+ AUROC as a "byproduct" = remarkable achievement
    → Slightly inferior to dedicated techniques (IForest)
```

### ASCII Graph

```
  AUROC (Breast Cancer):
    IForest  |################################################| 0.974
    OC-SVM   |###############################################.| 0.940
    Tension  |###############################################.| 0.947
    Recon    |################################################| 0.963
    Combined |###############################################.| 0.960

  Gaussian:
    All      |##################################################| 1.000
```

## Status: 🟧 Partially Confirmed (AUROC > 0.9 confirmed, but slightly inferior to specialized techniques)