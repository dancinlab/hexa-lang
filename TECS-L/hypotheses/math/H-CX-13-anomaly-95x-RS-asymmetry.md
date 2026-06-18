# H-CX-13: Anomaly Detection 95x tension ↔ R-S 2051x Asymmetry

> **Hypothesis**: The "95x tension vs normal" in consciousness engine anomaly detection is a miniature version of R-S asymmetry (2051x).

## Background
- Consciousness Engine Experiment 10: Anomaly detection AUROC=1.0, 95x tension vs normal
- R-S asymmetry: R<5=24 values(sparse), S<5=49218 values(dense) → 2051x difference
- H-CX-12: R gaps provide "natural margin" for anomaly detection

## Core Correspondence

```
  Mathematics                    Consciousness Engine
  ────────────────────         ────────────────────
  R(n)=1 (n=6, balance point)    Normal data (tension≈0)
  R(n)≥7/6 (n≠6, imbalance)      Anomalous data (tension 95x)

  R-S asymmetry 2051x            Normal/anomalous separation ratio 95x
  → Different ratios but same structure:
    "Balance point is isolated" + "Imbalance is majority"

  R gap [3/4→1→7/6]:             tension gap [0→threshold→95x]:
  "Natural margin"               "Natural decision boundary"
```

## Quantitative Connection Attempt

```
  R gap size: |R-1|_min = 1/6 ≈ 0.167 (at n=4)
  Anomaly detection normalization: 95x / (95x+1x) ≈ 0.990 → "normal=1%"

  "Normal ratio" in R: #{R≤1}/{R≤5} = 2/24 ≈ 8.3%
  Both have "normal is minority" structure

  ASCII:
  R spectrum:    ·|···     ←gap→    ████████████████████
                3/4  1              7/6        →∞

  Tension dist:  ████      ←gap→    ·
                normal(low)         anomalous(95x)
```

## Verification Directions
1. [ ] Is the "gap" in consciousness engine tension distribution structurally identical to R gap?
2. [ ] Compare tension ratios with R-S asymmetry across various datasets
3. [ ] Performance when using R gap size (0.167) as anomaly detection threshold
4. [ ] Measure R-S asymmetry in expert activation patterns in Golden MoE

## Difficulty: Extreme | Impact: ★★★★★