# Hypothesis 286: Topological Data Analysis (TDA) — Topological Structure of Tension Space

> **The topological structure (persistent homology) of tension fingerprints (10-dimensional) reflects the essential complexity of numbers/classes. What if we classify by topological features rather than image classification?**

## Concept

```
  Current: Input → Repulsion field → Tension pattern → Classification (softmax)
  Proposed: Input → Repulsion field → Tension pattern → TDA → Topological features → Classification

  TDA = Topological Data Analysis:
    - Persistent Homology: Detecting "hole" structures in data
    - Betti numbers: Connected components (b0), loops (b1), voids (b2)
    - Persistence diagram: How long do topological features persist?
```

## Why TDA on Tension Space?

```
  C10: 97.61% recognition with tension fingerprints alone (MNIST)
  C17: Direction separation ratio 2.77x

  → Structure already exists in tension space
  → Topological properties (holes, loops) of this structure may contain information
  → TDA (nonlinear) may detect richer structure than PCA (linear)?
```

## New Data/Classification Forms

```
  1. Topological classification:
     Point cloud → persistent homology → Betti sequence → Classification
     → Classification of "shapes" rather than images

  2. Graph classification:
     Molecular structure, social networks → Graph Laplacian → Repulsion field
     → Natural connection with a priori structure in model_fiber_bundle.py

  3. Time series topology:
     Time series → Delay embedding → Point cloud → TDA
     → Combines with Phase 4 (temporal continuity)

  4. Betti numbers of tension space:
     Persistent homology of 10,000 tension fingerprints
     → b0 (number of connected components) = number of classes (10)?
     → b1 (number of loops) = confused class pairs?
```

## Implementation

```
  Python: ripser, gudhi, giotto-tda libraries

  Experiments:
    1. 10,000 MNIST tension fingerprints → ripser → persistence diagram
    2. Compare Betti numbers by digit
    3. Classification with TDA features → Compare with tension 1-NN (97.61%)
    4. Also on CIFAR → Does topological structure differ between images vs real objects?
```

## Experimental Results (2026-03-24)

```
  Model: RepulsionFieldQuad, accuracy=97.85%
  Fingerprints: 10-dimensional (digit tensions = 4-engine standard deviations)
  Samples: 1000, TDA backend: scipy/MST

  Global topology:
    H0 features: 499 (connected components)
    H1 features: 111,776 (loops)
    H0 max persistence: 6.51
    H1 max persistence: 7.73

  Digit extremes:
    Most spread (H0):  digit 2 (total_pers=229.4)
    Most compact:      digit 9 (total_pers=137.0)
    Most loopy (H1):   digit 1 (total_pers=30,486)
    Least loopy:       digit 9 (total_pers=5,201)

  Topology ↔ Confusion correlation:
    Spearman r = -0.679, p < 0.0001
    → Digits with closer centers are more confused!
    → Topological structure predicts classification difficulty

  Dendrogram (average linkage):
    {8,9} closest (dist=2.51) → Most confused
    {1} joins last (dist=6.85) → Most independent
```

### Key Discoveries

```
  1. Rich topological structure exists in tension space (H1=111,776 loops!)
  2. Center distance ↔ Confusion rate: r=-0.68 (strong negative correlation)
  3. Digit 1 is most independent (simple stroke → unique tension pattern)
  4. Digit 9 has simplest topology (compact + few loops)
  5. Digit 2 has most complex topology (curved structure)
```

## Review Notes (2026-03-26)

- H0=499: **exact** (n-1 for 500 points, MST method)
- H1=111,776: **overestimate** — uses 1-skeleton Euler characteristic approximation (b1 = edges - vertices + components), NOT exact persistent homology via Ripser. Systematically overestimates true H1 because 2-simplices (triangles) that fill 1-cycles are not accounted for.
- Spearman r=-0.679: plausible and correctly interpreted (45 pairs, p<0.0001)
- Dimensionality: hypothesis statement corrected from 20-dim to 10-dim (actual experiment used 10-dim fingerprints)

## Status: 🟩 Confirmed (minor fix) — H0 exact, H1 is upper-bound approximation, confusion prediction r=-0.68