# H-CX-450: Confusion Topology is Computable from Raw Data (No Training)
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


**Status**: SUPPORTED (Fashion r=-0.81, MNIST merge r=-0.85, all top-5 3/5)
**Golden Zone Dependency**: None
**Related**: H-CX-449 (arch invariance), H-CX-91 (k-NN=NN), H-CX-66 (PH merge=confusion)

> **Hypothesis**: Raw pixel-space class centroid distances predict trained model
> confusion topology without any training. Classes closer in pixel space are
> more confused after training.

## Background

H-CX-449 showed confusion topology is architecture-invariant (r>0.95 MLP+CNN).
H-CX-91 showed even k-NN confusion matches neural networks (r=0.94).
If confusion is truly data-driven, the raw data geometry should already encode it.

## Experiment

For each dataset: compute class centroids in raw pixel space, then compare
pairwise distances with trained model confusion counts.

## Results

### Cross-dataset summary

| Dataset | Raw~Confusion r | PH merge~Confusion r | Top-5 overlap | Centroid dist corr |
|---------|----------------|---------------------|---------------|-------------------|
| MNIST   | -0.429         | **-0.849**          | **3/5**       | 0.513             |
| Fashion | **-0.807**     | -0.633              | **3/5**       | **0.800**         |
| CIFAR   | -0.564         | 0.150               | **3/5**       | 0.531             |

### Fashion-MNIST detail (strongest result)

```
  Rank | Pair              | Raw Dist | Confusion | Notes
  -----+-------------------+----------+-----------+------------------
     1 | Pullover-Coat     |  0.0304  |    204    | closest = 2nd most confused
     2 | Coat-Shirt        |  0.0401  |    112    | close = confused
     3 | Pullover-Shirt    |  0.0577  |    154    | close = confused
     4 | Tshirt-Shirt      |  0.1219  |    215    | MOST confused (1st)
     5 | Trouser-Dress     |  0.1225  |     25    | close but NOT confused (counter)
```

### MNIST detail (PH merge strongest)

```
  PH merge order:          Confusion top-5:
  1. 4-9 (d=0.10)          1. 2-7 (17)
  2. 5-8 (d=0.13)          2. 4-9 (13)  <<<< MATCH
  3. 7-9 (d=0.15)          3. 7-9 (12)  <<<< MATCH
  4. 3-5 (d=0.16)          4. 3-8 (11)
  5. 3-8 (d=0.19)          5. 3-5 (9)   <<<< MATCH

  3/5 overlap, PH merge order Spearman r=-0.85 (p=0.004)
```

### ASCII: Raw distance vs Confusion (Fashion-MNIST)

```
  Raw Distance  0.0   0.1   0.2   0.3   0.4   0.5
                |     |     |     |     |     |
  Pullvr-Coat   ██  ............................ 204 confused
  Coat-Shirt    ███ ............................ 112 confused
  Pullvr-Shirt  █████ .......................... 154 confused
  Tshirt-Shirt  ████████████ ................... 215 MOST confused
  Trouser-Dress ████████████ ...................  25 (exception)
  Sandal-Snkr   ███████████████ ................  38
  ...
  Trouser-Boot  ████████████████████████████████   0 (far = no confusion)

  Trend: closer in pixel space = more confused (r = -0.81)
```

## Interpretation

**Confusion topology is largely encoded in raw data geometry.**

Key findings:
1. **Top-5 overlap = 3/5 universally**: Regardless of dataset complexity, 60% of the most confused pairs are predictable from raw pixel distances alone
2. **Fashion-MNIST shows strongest signal** (r=-0.81): Clothing categories have meaningful pixel-level similarity
3. **MNIST PH merge is predictive** (r=-0.85): The dendrogram structure of digit centroids predicts confusion order
4. **CIFAR is weaker** (r=-0.56): 3D natural images have less pixel-level structure relevant to confusion

This means: **training doesn't CREATE confusion structure — it REVEALS structure already present in the data.** The model learns to distinguish classes that are inherently similar, and this similarity is visible even in raw pixel space.

## Significance

Combined with:
- H-CX-449: Architecture invariance (r>0.95)
- H-CX-91: k-NN = NN confusion (r=0.94)
- H-CX-66: PH merge = confusion (r=-0.97)

We now have the full chain: **Raw data geometry → PH topology → Confusion structure → Architecture invariant**

This supports Paper P-002 (Universal Confusion Topology) with a new claim:
confusion topology is a geometric property of the dataset, computable without training.

## Limitations

- Pixel-level centroids are simplistic (PCA/UMAP centroids might be stronger)
- CIFAR is weak because pixel distance != semantic distance for 3D images
- Top-5 overlap (3/5) is better than random (~1/5) but not perfect
- Tshirt-Shirt anomaly: most confused but rank 4 in raw distance (non-monotone)
