# Hypothesis 297: Mitosis Ensemble Diversity = Anomaly Detection Sensitivity

> **When split children learn independently, they form different "normal models". This diversity creates "cross-validation" for anomalies. Does anomaly detection AUROC increase monotonically as the number of splits increases (2→4→8 children)?**

## Background

```
  H296 experiments:
    Internal tension (single engine): AUROC = 0.156 (almost useless)
    Inter tension (2 children):       AUROC = 0.805

  Why this difference?
    Internal tension: engine_a and engine_g learn simultaneously on same data
      → Agree on same patterns → Agree on anomalies → Cannot distinguish
    Inter tension: child_a and child_b learn independently on different mini-batches
      → Different "normal profiles" → Different reactions to anomalies → Can distinguish

  Random Forest analogy:
    Single tree < Random forest (diversity increases accuracy)
    Single engine < Mitosis ensemble (diversity increases anomaly detection)
```

## Core Questions

```
  Q1: Does AUROC increase as split count N increases?
      N=1 (single): AUROC ≈ 0.16
      N=2 (split): AUROC ≈ 0.81
      N=4 (double split): AUROC = ?
      N=8 (triple split): AUROC = ?

  Q2: Where does the increase saturate?
      Proportional to log(N)? sqrt(N)? Linear?

  Q3: How to "ensemble" inter tensions?
      mean(pairwise T_ij)?
      max(pairwise T_ij)?
      variance(outputs)?

  Q4: Is independent learning period important?
      1 epoch vs 5 epochs vs 10 epochs → AUROC change?
```

## Experimental Design

```
  Data: Breast Cancer (sklearn), digit anomaly (MNIST)

  Phase 1: Train parent (normal only)
  Phase 2: N-way split
    N=1: parent only
    N=2: parent → child_a, child_b
    N=4: parent → 2 → 4 (double split)
    N=8: parent → 2 → 4 → 8 (triple split)
  Phase 3: Train each child independently on different mini-batches (K epochs)
  Phase 4: Test
    T_inter = mean of pairwise |child_i(x) - child_j(x)|²
    Calculate AUROC

  Parameters:
    K = {1, 5, 10} epochs
    split_scale = 0.01
    N = {1, 2, 4, 8, 16}
```

## Mathematical Prediction

```
  Diversity theory (Krogh & Vedelsby, 1995):
    Ensemble error = Average individual error - Diversity
    Diversity = (1/N) Σ (f_i - f̄)²

  Anomaly detection mapping:
    "Normal consensus" = Low diversity → Low anomaly score
    "Anomaly disagreement" = High diversity → High anomaly score

  AUROC ∝ (Diversity_anomaly - Diversity_normal) / σ
  As N increases, diversity estimation becomes more stable → AUROC ↑

  Prediction: AUROC(N) ≈ AUROC_max × (1 - e^(-αN))
  → Exponential saturation, α depends on data/architecture
```

## ASCII Prediction Graph

```
  AUROC
  1.0 |                              ★──────── max
      |                    ★
      |              ★
  0.8 |         ★
      |
      |
      |
      |
  0.2 |   ★
      |
  0.0 └───┬───┬───┬───┬───┬──
      N=1  2   4   8  16  32
```

## Related Hypotheses

```
  287: Tension = Anomaly score (AUROC=1.0)
  296: Inter-split tension >> Internal tension
  270: Diversity = Information
  271: Mitosis ≈ Design
  267: Collective phase transition (diversity critical point)
```

## Experimental Results (2026-03-24)

```
  N-way split (Breast Cancer, 3 trials each):

  N     AUROC mean    std
  ─────  ──────────  ──────
  1      0.080       (internal tension only)
  2      0.820       ← Best!
  4      0.803
  8      0.778
  16     0.726

  Exponential saturation fit: AUROC = 0.80 - 5.21 × e^(-2.0N)
  R² = 0.951

  Surprising finding:
    N=2 is best! Slight decrease for N>2
    → Different from expectation (monotonic increase)
    → Over-differentiation as N increases?
    → Or: Dividing same data into smaller pieces → Insufficient learning?
```

### ASCII Graph

```
  AUROC
  0.9 |
      |
  0.8 |    *     *     *
      |                        *
  0.7 |
      |
  0.5 |
      |
  0.2 |
  0.1 |  *
      └──┬──┬──┬──┬──┬──
        1  2  4  8  16
```

### Revised Interpretation

```
  Original prediction: AUROC ∝ 1-e^(-αN) (monotonic increase)
  Actual: N=2 optimal, decreases for N>2
  → "Optimal diversity" concept: Too much diversity is harmful
  → Connects to hypothesis 267 (diversity phase transition): Performance drops beyond critical point
  → N=2 = Minimal and optimal split count
```

## Status: 🟧 Modified (N=2 optimal, N>2 decreases = optimal diversity)