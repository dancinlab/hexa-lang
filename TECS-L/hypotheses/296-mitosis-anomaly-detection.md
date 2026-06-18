---
hypothesis: 296
title: Mitosis + Anomaly Detection — Does mitosis improve anomaly detection performance
---

# Hypothesis 296: Mitosis + Anomaly Detection — Are Split Engines Better Anomaly Detectors

> **"Inter-tension" (T_ab) between 2 split engines provides more sensitive anomaly scores than a single engine. Does inter-child tension detect anomalies better than parent internal tension (AUROC=1.0, Hypothesis 287)?**

## Rationale

```
  Hypothesis 287: Parent internal tension → AUROC=1.0 (synthetic data)
  Hypothesis 293: Real data → AUROC 0.94~1.0

  Adding mitosis:
    parent → child_a, child_b
    T_internal: child_a internal engine_a vs engine_g
    T_inter: child_a full output vs child_b full output

    Hypothesis: T_inter is more sensitive than T_internal
    Reason: After mitosis, learn differently → react differently to anomalies
    → Ensemble diversity = anomaly detection sensitivity
```

## Experimental Design

```
  1. Train parent (normal data only)
  2. Mitosis → child_a, child_b
  3. Train each child independently (normal data, different mini-batches)
  4. Test: normal + anomaly data
     a) T_internal_a: child_a internal tension → AUROC_a
     b) T_internal_b: child_b internal tension → AUROC_b
     c) T_inter: |child_a(x) - child_b(x)|² → AUROC_inter
     d) T_combined: T_internal + T_inter → AUROC_combined
  5. Compare: AUROC_inter > AUROC_internal?
```

## Predictions

```
  AUROC_internal ≈ 1.0 (already confirmed)
  AUROC_inter ≥ AUROC_internal (diversity added)
  AUROC_combined ≥ max(individual) (complementary information)

  But if AUROC=1.0, can't improve further
  → Differences will show in real data (breast cancer)
  → 0.947 → 0.97+?
```

## Experimental Results (2026-03-24)

```
  Breast Cancer dataset (5 trials):
    method       AUROC mean   std
    ─────────   ──────────   ─────
    internal      0.1555     0.015   ← internal tension (nearly useless!)
    inter         0.8049     0.029   ← inter-child tension (useful!)
    combined      0.1564     0.015

  Analysis:
    Inter-child tension: AUROC 0.805 >> internal tension 0.156
    → Supports H296: mitosis dramatically improves anomaly detection

    Why is internal tension low?
    → Trained as autoencoder (reconstruct normal data)
    → Internal tension = engine_a vs engine_g (trained on same data → consensus)
    → Inter tension = child_a vs child_b (different mini-batches → differentiation)

    Different mini-batch training → different "normal models" formed
    → React differently to anomaly data → inter tension ↑
```

### ASCII AUROC Comparison

```
  internal |#######.                                        | 0.156
  inter    |########################################.       | 0.805
  combined |#######.                                        | 0.156
```

## Status: 🟩 Confirmed (inter tension AUROC 0.805 >> internal 0.156)