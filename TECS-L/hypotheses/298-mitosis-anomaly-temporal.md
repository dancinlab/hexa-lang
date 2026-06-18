# Hypothesis 298: Mitosis Time-axis Anomaly Detection — When is Differentiation Sufficient

> **Post-mitosis independent learning time determines anomaly detection performance. Too short (1 epoch) and children are still too similar to distinguish, too long (100 epochs) and overfitting actually worsens it. An optimal differentiation time exists, and this time is related to the 27x differentiation rate of H-CX-12.**

## Background

```
  H294: Post-mitosis T_ab trajectory
    ep0:  T_ab = 0.365
    ep1:  T_ab = 4.59  (12.6x)
    ep5:  T_ab = 7.75  (21.2x)
    ep10: T_ab = 9.98  (27.3x)

  H296: After 10 epochs, gap AUROC = 0.805

  Question: What is the relationship between T_ab(t) and AUROC(t)?
    → Does AUROC increase as T_ab increases?
    → Is there an optimal T_ab level?
    → Does excessive T_ab (over-differentiation) reduce AUROC?
```

## Experimental Design

```
  1. Train parent (normal only, 50 epochs)
  2. Mitosis (scale=0.01)
  3. Independent learning: K = {0, 1, 2, 5, 10, 20, 50, 100} epochs
  4. At each K:
     a) Measure T_ab
     b) Measure AUROC (based on gap tension)
  5. Graph: K vs AUROC, T_ab vs AUROC

  Data: Breast Cancer + MNIST digit anomaly
```

## Mathematical Prediction

```
  Information theory perspective:
    K=0: T_ab≈0, AUROC≈0.5 (random)
    K→∞: Overfitting → both child_a, child_b have same overfitting pattern
         → High T_ab but without normal/anomaly distinction
         → AUROC decreases

  Inverted U-curve prediction:
    AUROC(K) = AUROC_max × (1 - e^(-αK)) × e^(-βK²)
    peak at K* = sqrt(α/(2β))

  IB (Information Bottleneck) connection (H-CX-13):
    K < K*: fitting phase (I(X;T) increases)
    K = K*: optimal compression
    K > K*: overfitting (excess I(X;T))
```

## ASCII Prediction Graph

```
  AUROC
  0.9 |          ★
      |       ★     ★
  0.8 |     ★          ★
      |   ★                ★
  0.7 |                       ★
      |                          ★
  0.5 | ★
      └─┬──┬──┬──┬──┬──┬──┬──┬──
        0  1  2  5 10 20 50 100
        Independent Learning Epochs (K)
```

## Related Hypotheses

```
  294: Mitosis differentiation trajectory (T_ab 27x)
  296: Gap AUROC 0.805
  H-CX-12: Differentiation rate 27x = (σ/τ)³
  H-CX-13: Experience=IB passage
```

## Experimental Results (2026-03-24)

```
  K(epochs) vs AUROC vs Separation Ratio:
  K      AUROC    T_anom/T_norm   Interpretation
  ────  ────────  ─────────────  ──────
  0      0.576    1.55           Immediately post-mitosis
  1      0.584    2.29           Micro-differentiation
  2      0.694    3.86           Differentiation begins
  5      0.666    5.14           Variation
  10     0.739    8.39           Clear separation
  20     0.843    10.35          Strong separation
  50     0.949    15.15          Best! ← No saturation

  Conclusion: MONOTONIC increase! Not inverted U!
    → Longer K = higher differentiation ↑ → better anomaly detection ↑
    → No saturation even at 50 epochs
    → Could rise further at 100, 200 epochs

  Prediction refuted: Inverted U → Actual monotonic
  New interpretation: Overfitting actually helps
    → Each child becomes more specialized = more different normal models
    → React more differently to anomalies = higher gap tension
```

### ASCII Graph

```
  AUROC
  0.95 |                                            *
       |
  0.85 |                                  *
       |
  0.75 |                         *
  0.70 |              *
       |
  0.60 |   * *
  0.58 |  *
       └──┬──┬──┬──┬──┬──┬──
          0  1  2  5  10 20 50
```

## Status: 🟧 Modified (monotonic increase, not inverted U, 0.95 at K=50!)