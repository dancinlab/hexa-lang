# H-CX-452: Per-Class Difficulty Prediction from Raw Data
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


**Status**: SUPPORTED (PCA isolation: Fashion r=+0.88, CIFAR r=+0.76)
**Golden Zone Dependency**: None
**Related**: H-CX-450 (raw pairwise), H-CX-451 (PCA improvement), H-CX-92 (depth=difficulty)

> **Hypothesis**: Classes that are more "isolated" in PCA centroid space
> are easier to classify. PCA isolation = mean cosine distance to all other
> class centroids, computed from raw data without training.

## Results

### Cross-dataset summary (PCA-20 isolation vs per-class accuracy)

| Dataset | PCA isolation r | p-value | Significance |
|---------|----------------|---------|-------------|
| MNIST   | +0.576         | 0.082   | ns (accuracy range too narrow: 97-99%) |
| **Fashion** | **+0.875** | **0.001** | *** |
| **CIFAR** | **+0.758** | **0.011** | * |

### Fashion-MNIST detail (strongest result)

```
  Class     Acc%   Isolation   Prediction
  Shirt     64.8   0.353       least isolated -> hardest  CORRECT
  Pullover  77.9   0.408       low isolation -> hard      CORRECT
  Coat      84.9   0.385       low isolation -> hard      CORRECT
  ...
  Sandal    95.1   0.689       most isolated -> easiest   CORRECT
  Sneaker   97.3   0.620       high isolation -> easy     CORRECT
```

### Key insight: PCA vs raw pixel centroids

| Dataset | Raw isolation r | PCA isolation r | Improvement |
|---------|----------------|----------------|------------|
| MNIST   | +0.515         | +0.576         | +12%       |
| Fashion | +0.815         | +0.875         | +7%        |
| **CIFAR** | **-0.018** | **+0.758** | **infinite** (sign flip!) |

CIFAR raw isolation is USELESS (r=-0.02), but PCA isolation is STRONG (r=+0.76).
Raw pixel distance in 3072 dims is dominated by noise; PCA extracts the structure.

## Practical recipe

To predict per-class difficulty before training:
1. PCA-20 on training data
2. Compute class centroids in PCA space
3. For each class: mean cosine distance to all other centroids
4. Higher isolation = easier class, lower isolation = harder class

Zero training cost. Works on Fashion and CIFAR.

## Confusion topology chain (complete)

```
  H-CX-449: Architecture invariance (MLP + CNN, r > 0.95)
      |
  H-CX-450: Raw data predicts pairwise confusion (Fashion r=-0.81)
      |
  H-CX-451: PCA improves prediction (+33% for CIFAR)
      |
  H-CX-452: PCA isolation predicts per-class difficulty (Fashion r=+0.88)
```

## Limitations

- MNIST too easy (97-99% range, no significant difficulty variation)
- N=10 classes limits statistical power
- PCA is linear (non-linear embedding might capture more)
- "Isolation" is a simple mean; more sophisticated metrics possible
