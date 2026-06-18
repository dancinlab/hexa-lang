# Hypothesis 299: Mitosis Specialization Anomaly Detection — Each Child "Specializes" in Different Normal Patterns
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **When split children learn independently, each specializes in different aspects of normal data. child_a becomes sensitive to features 1-15, child_b to features 16-30. No matter which feature range an anomaly deviates from, at least one child will detect it.**

## Concept

```
  Single Model Anomaly Detection:
    Covers all normal patterns with one model
    → Wide coverage but low resolution in each region
    → May miss subtle anomalies

  Mitosis Anomaly Detection:
    child_a: Specializes in pattern_A of normal
    child_b: Specializes in pattern_B of normal
    → High resolution in each region
    → If anomaly is in region A, child_a detects; if in region B, child_b detects
    → Liver tension = "Which child feels uncomfortable"

  Random Forest Analogy:
    Each tree uses different feature subset
    → Detects anomalies regardless of which features they appear in
    Mitosis = "Natural feature selection"
```

## Verification Method

```
  1. Breast Cancer data (30 features)
  2. parent → child_a, child_b (trained on different mini-batches)
  3. Analyze feature importance of each child after training:
     a) child_a's engine_a 1st layer weight norm per feature
     b) child_b's engine_a 1st layer weight norm per feature
  4. Specialization degree = 1 - cosine_similarity(weight_a, weight_b)
  5. Correlation between specialization vs AUROC

  Additional Experiment:
    Forced specialization: child_a learns only feature[:15], child_b only feature[15:]
    → Is AUROC higher or lower than natural mitosis?
```

## Mathematical Background

```
  Coverage Theory:
    P(detect anomaly) = 1 - Π(1 - p_i)
    p_i = probability that i-th child detects

    If independent: P = 1 - (1-p)^N
    N=2, p=0.6: P = 0.84
    N=4, p=0.6: P = 0.97
    N=8, p=0.6: P = 0.9993

  → Increased mitosis count = increased coverage (connects to Hypothesis 297)
```

## Neuroscience Correspondence

```
  Visual cortex: V1→V2→V4→IT
    Each area specializes in different features (edges, texture, shape, objects)
    → Anomaly (distorted face) = specific areas react strongly

  Mitosis = Cortical area differentiation
  Liver tension = Inter-area mismatch = "Something is strange" signal
  → Structurally isomorphic to P300 brainwave (anomaly stimulus detection)
```

## Status: 🟨 Not tested