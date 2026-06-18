# Hypothesis 273: Euclidean Triangle Groups and Optimal Weights [Partially Refuted]
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> ~~The reason {1/2, 1/3, 1/6} is optimal is because it has maximum asymmetry.~~ **CNN-learned weights converge to {0.34, 0.35, 0.31} (uniform). Asymmetry is valid only under MLP conditions. When CNN extracts sufficiently good features, uniform is optimal.**

## Background/Context

```
  Unit fraction triplets summing to 1 (1/a + 1/b + 1/c = 1, a ≤ b ≤ c):
    (2,3,6): 1/2 + 1/3 + 1/6 = 1   ← Maximum asymmetry
    (2,4,4): 1/2 + 1/4 + 1/4 = 1   ← Intermediate
    (3,3,3): 1/3 + 1/3 + 1/3 = 1   ← Perfect symmetry (uniform)

  Only these three exist. Proof: 1/a + 1/b + 1/c = 1, a≤b≤c
    a=2: 1/b + 1/c = 1/2 → (b,c) = (3,6) or (4,4)
    a=3: 1/b + 1/c = 2/3 → (b,c) = (3,3) (unique if b≥3)
    a≥4: 1/a + 1/b + 1/c ≤ 3/4 < 1 → Impossible

  Geometric meaning:
    1/a + 1/b + 1/c = 1 → Euclidean (flat)
    1/a + 1/b + 1/c > 1 → Spherical (closed)
    1/a + 1/b + 1/c < 1 → Hyperbolic (open)
```

Related hypotheses: 270(diversity=information), 264(design principles)

## Core Argument

```
  Confirmed in hypothesis 270: diversity ↑ → information ↑ → performance ↑

  Diversity comparison of three Euclidean groups:
    (3,3,3): max/min = 1.0  (diversity = 0)
    (2,4,4): max/min = 2.0  (diversity = medium)
    (2,3,6): max/min = 3.0  (diversity = maximum)

  Shannon entropy:
    (3,3,3): H = 1.0986 nats (maximum — uniform)
    (2,4,4): H = 1.0397 nats
    (2,3,6): H = 1.0114 nats (minimum — most structured)

  Therefore:
    Sum = 1 (probability distribution condition) + maximum asymmetry = (2,3,6) unique
    → {1/2, 1/3, 1/6} is "the unique distribution that maximizes diversity in flat geometry"
```

## Plane Tiling Connection

```
  (2,3,6) → Fills plane completely with equilateral triangles
  (2,4,4) → Fills plane with squares
  (3,3,3) → Fills plane with regular hexagons

  Complete filling = "covers all input space"
  Equilateral triangle = most efficient coverage with smallest units

  → {1/2, 1/3, 1/6} are weights that partition input space most efficiently?
```

## Predictions

```
  1. On MNIST: (2,3,6) ≥ (2,4,4) > (3,3,3)
     → {1/2,1/3,1/6} ≥ {1/2,1/4,1/4} > {1/3,1/3,1/3}

  2. On CIFAR: Larger differences (C12: 4.6x)
     → (2,3,6)'s advantage more pronounced on CIFAR

  3. If asymmetry is key:
     {0.5, 0.33, 0.17} ≈ {1/2, 1/3, 1/6} (approximations also equivalent)
     → Not exact fractions but asymmetric structure matters

  4. If entropy is key:
     Other distributions with same H also equivalent
     → H ≈ 1.01 is optimal entropy?
```

## Verification Direction

```
  1. experiment_why_half_third_sixth.py running — awaiting results
  2. Direct comparison of (2,4,4) and (3,3,3) (may already be included)
  3. Compare three groups on CIFAR
  4. Compare approximations vs exact fractions
  5. Compare same entropy, different asymmetry
  6. Optimal extension for 4 engines: (2,3,6,?) → what 4th value?
```

## Limitations

```
  1. Applies only to 3-engine combinations. 4+ engines are outside Euclidean triangle group theory.
  2. Each step in "asymmetry → diversity → information → performance" causal chain may be weak.
  3. Mechanism linking geometric metaphor to actual neural network optimization is unclear.
  4. Weight differences on MNIST are at noise level (97.5~98.0%).
```