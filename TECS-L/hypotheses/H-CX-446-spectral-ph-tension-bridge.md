# H-CX-446: Spectral Gap <-> PH H0 <-> Tension Gap — Trinity Bridge
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


**Status**: NOT SUPPORTED (MNIST-only, fails on Fashion/CIFAR)
**Golden Zone Dependency**: None
**Related**: H-CX-445 (spectral gap=tension gap, r=0.97), H-CX-66 (PH merge=confusion, r=-0.97)

> **Hypothesis**: The spectral gap of weight matrices, PH H0 total lifetime of class centroids,
> and tension gap across classes are all pairwise strongly correlated (|r| > 0.8) during training,
> forming a "trinity bridge" connecting linear algebra, topology, and learning theory.

## Background

Two S-tier discoveries exist independently:
- **H-CX-445**: Spectral gap (lambda_1 - lambda_2) correlates with tension gap (r=0.9712, p<0.001)
- **H-CX-66**: PH merge order correlates with confusion pairs (r=-0.97, p<0.001)

Neither has been connected to the other. If spectral gap also predicts PH structure,
we have a triangle connecting three mathematical domains:

```
                Spectral Gap
               (Linear Algebra)
                /            \
          r_1 /              \ r_2
             /                \
     PH H0 -------- r_3 ------- Tension Gap
   (Topology)              (Learning Theory)
```

## Prediction

All three pairwise Spearman correlations satisfy |r| > 0.8 with p < 0.01.

## Experiment

- Model: PureFieldEngine (784-128-10) on MNIST
- Epochs: 0-15
- At each epoch, measure:
  1. Spectral gap: mean SVD gap across all weight matrices
  2. PH H0: total lifetime from class centroid cosine distances (single-linkage)
  3. Tension gap: max(class_tension) - min(class_tension)
- Compute pairwise Pearson + Spearman correlations

## Results

### Epoch-by-epoch measurements (MNIST, PureFieldEngine)

| Epoch | Accuracy | Spectral Gap | PH H0  | Tension Gap |
|-------|----------|-------------|--------|-------------|
| 0     | 7.4%     | 0.0175      | 0.8235 | 0.0751      |
| 1     | 95.1%    | 0.1037      | 5.0104 | 11.6352     |
| 2     | 96.6%    | 0.1087      | 4.9987 | 16.5210     |
| 3     | 97.5%    | 0.0801      | 4.9273 | 18.1674     |
| 5     | 97.9%    | 0.0790      | 4.7760 | 30.0233     |
| 10    | 98.2%    | 0.0856      | 4.3326 | 61.6128     |
| 15    | 98.2%    | 0.0591      | 4.1183 | 97.6445     |

### Correlation matrix

| Pair                       | Pearson r | p-value  | Spearman r | p-value  |
|----------------------------|-----------|----------|------------|----------|
| Spectral Gap <-> PH H0    | **0.868** | 1.3e-05  | 0.591      | 1.6e-02  |
| Spectral Gap <-> Tension   | -0.050    | 8.5e-01  | -0.271     | 3.1e-01  |
| PH H0 <-> Tension Gap     | 0.118     | 6.6e-01  | -0.627     | 9.4e-03  |

### ASCII visualization

```
  Ep |     Spectral Gap     |       PH H0          |    Tension Gap
  ---+----------------------+----------------------+--------------------
   0 |                      |                      |
   1 | ##################   | ##################   | ##
   5 | ############         | ################     | #####
  10 | #############        | ###############      | ###########
  15 | ########             | ##############       | #################
```

### Per-class tension (epoch 15)

```
  Digit 3: ██████████████████████████████ 151.89  (hardest)
  Digit 2: █████████████████████████      130.27
  Digit 5: █████████████████████████      126.61
  Digit 7: ██████████████████████         116.32
  Digit 0: ██████████████████              93.65
  Digit 9: ████████████████                83.36
  Digit 6: ████████████████                82.66
  Digit 4: ███████████████                 80.28
  Digit 1: ████████████                    60.99
  Digit 8: ██████████                      54.25  (easiest)
```

## Interpretation

**Trinity bridge NOT confirmed.** Full 3-way connection fails.

However, a **partial bridge** emerges:
- **SG <-> H0 (Pearson 0.87)**: Strong linear link between weight spectral structure and topological structure
- SG has no monotone relationship with tension gap (r=-0.05)
- H0 and tension gap weakly anti-correlated (Spearman -0.63)

The reason: Spectral gap and PH H0 both **peak early then decay**, while tension gap **monotonically increases**. The spectral-topological link is real but operates on a different timescale than the tension dynamics.

Key insight: **Weight geometry (spectral) determines representation topology (PH), but tension measures something different — the magnitude of class separation, not its structure.**

## Limitations

- MNIST only (needs Fashion-MNIST, CIFAR replication)
- Spectral gap uses mean across all layers (per-layer analysis may reveal more)
- PureFieldEngine specific (needs dense MLP comparison)
- Tension gap is magnitude, not structure — different metric needed for structural comparison
- N=16 epochs may be too few to separate early dynamics from convergence behavior

## Cross-Dataset Verification (H-CX-446b)

| Dataset | Pearson r | p-value  | Verdict |
|---------|-----------|----------|---------|
| MNIST   | 0.719     | 1.7e-03  | Moderate |
| Fashion | 0.027     | 9.2e-01  | NONE |
| CIFAR   | 0.230     | 3.9e-01  | NONE |

**Universal bridge: NO.** The SG-H0 correlation is MNIST-specific and does not generalize.
Per-layer analysis also shows no consistent pattern across datasets.
