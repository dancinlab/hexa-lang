# Hypothesis 306: Is the 4-Pole Repulsion Field a Better Anomaly Detector than 2-Pole?
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **The inter-tension of 4-pole (Quad: A,E,G,F) provides a richer anomaly profile than 2-pole (A,G). The 4-pole measures inconsistency from 4 perspectives, so it can detect not only single-axis anomalies but also multi-dimensional anomalies.**

## Concept

```
  2-pole: tension = |A(x) - G(x)|² -> 1D anomaly score
  4-pole: tension = [|A-E|, |A-G|, |A-F|, |E-G|, |E-F|, |G-F|] -> 6D anomaly profile

  2-pole anomaly detection:
    If anomaly fools both A and G -> detection fails
    Only 1 "perspective" available

  4-pole anomaly detection:
    Anomaly must fool all 4 engines -> detection failure probability decreases
    6 "perspectives" -> more robust

  Mitosis combination:
    4-pole parent -> mitosis -> 4-pole child_a, 4-pole child_b
    Inter-tension: |child_a(x) - child_b(x)|² (10-dimensional)
    + internal 6D tension of each child
    -> Total 10+6+6 = 22-dimensional anomaly profile!
```

## Experimental Design

```
  Data: Breast Cancer (sklearn)

  Model A: 2-pole (engine_a + engine_g, hidden=64)
  Model B: 4-pole (A + E + G + F, hidden=32 each, similar total parameters)

  Each model:
    1. Reconstruction (MSE) training (normal only)
    2. Mitosis (N=2)
    3. Independent training (30 epochs)
    4. AUROC measurement: internal + inter + combined

  Comparison:
    2-pole internal vs 4-pole internal
    2-pole inter vs 4-pole inter
    2-pole combined vs 4-pole combined
```

## Prediction

```
  4-pole > 2-pole (for all tension types)
  Especially 4-pole combined (22D) >> 2-pole combined (3D)
  -> 4-pole better detects "multi-dimensional anomalies"
```

## H-CX-4 Connection

```
  H-CX-4: σ,τ,φ,σ₋₁ -> 4 functions = 4 engines
  -> Is 4-pole the "mathematically complete" set of perspectives?
  -> Are the 4 divisor functions of perfect number 6 the optimal anomaly detection perspectives?
```

## Status: 🟨 Untested
