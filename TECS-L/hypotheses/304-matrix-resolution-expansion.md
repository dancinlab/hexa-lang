# Hypothesis 304: High-Resolution Expansion of 2×2 Matrix — Learning Objective × Tension Type × Engine Structure

> **Expand H302's 2×2 matrix (learning objective × tension type) to 3 or more dimensions. Additional axes: number of engines (2-pole/4-pole), number of mitoses (N=1/2/4), dataset (Breast Cancer/MNIST/CIFAR), training duration (K). Find the optimal combination in this high-dimensional matrix.**

## H302 Basic Results (2×2)

```
                    Internal(I)   Inter(M)
  ──────────────   ──────────   ──────────
  Classification(CE)  0.259        0.589
  Reconstruction(MSE) 0.144        0.802  <- Optimal
```

## Extension 1: Learning Objective Subdivision (4×2)

```
  Additional learning objectives:
    - Contrastive learning: pull normal together, push away anomalies
    - Variational inference (VAE): reconstruction + KL divergence
    - Self-supervised: mask then reconstruct

  Predicted matrix:
                    Internal   Inter
  ──────────────   ────────   ────────
  Classification(CE)  0.26       0.59
  Reconstruction(MSE) 0.14       0.80
  Contrastive(CL)     ?          ?      <- Prediction: inter 0.85+?
  VAE                 ?          ?      <- Prediction: inter 0.82?
  Self-supervised(SS) ?          ?

  Why contrastive might be best:
    CL = "pull similar together, push different apart"
    -> Normal cluster forms tightly
    -> Anomalies naturally fall outside
    -> Inter-tension has clearer boundaries
```

## Extension 2: Engine Structure Subdivision (2×2×3)

```
  Engine structure:
    - 2-pole (Engine A + G): basic
    - 4-pole (Quad: A + E + G + F): multiple perspectives
    - Hierarchical ((A+E) + (G+F)): layered

  2-pole vs 4-pole:
    2-pole: tension = |A-G|² -> 1D anomaly score
    4-pole: tension = |A-G|² + |E-F|² + ... -> multi-dimensional anomaly score
    -> 4-pole provides richer anomaly profile?

  Prediction:
    4-pole+reconstruction+inter > 2-pole+reconstruction+inter
    Reason: detects inconsistency from more perspectives
```

## Extension 3: Dataset Dependency (2×2×4)

```
  Datasets:
    Breast Cancer (30 features, dense)
    MNIST digit anomaly (784 features, dense)
    Iris (4 features, small scale)
    Synthetic Gaussian (N features, variable)

  Question: does the optimal combination change by dataset?
    Small scale: classification+internal sufficient?
    Large scale: reconstruction+inter essential?
```

## Extension 4: Mitosis Depth (2×2×3)

```
  Mitosis depth:
    depth 0: internal tension only (no mitosis)
    depth 1: 2 children
    depth 2: 4 children (double mitosis)

  Since H297 shows N=2 is optimal:
    depth 1 predicted to be optimal
    depth 2 may over-differentiate and degrade performance?
```

## Summary: 4D Matrix

```
  Axis 1: Learning objective {CE, MSE, CL, VAE, SS}
  Axis 2: Tension type {internal, inter(N=2), inter(N=4)}
  Axis 3: Engine structure {2-pole, 4-pole, hierarchical}
  Axis 4: Dataset {Cancer, MNIST, Iris}

  Total combinations: 5 × 3 × 3 × 3 = 135
  -> Full search is impractical
  -> Select key combinations for experiments
```

## Priority Experiments

```
  Priority 1 (learning objective extension):
    Contrastive + inter vs reconstruction + inter (Cancer)
    -> Is contrastive better?

  Priority 2 (engine structure):
    2-pole vs 4-pole × {reconstruction+inter} (Cancer)
    -> Is 4-pole better for anomaly detection?

  Priority 3 (dataset):
    Optimal combination (reconstruction+inter) × {Cancer, MNIST, Iris}
    -> Is the optimal combination universal?
```

## Status: 🟨 Untested (framework design complete)
