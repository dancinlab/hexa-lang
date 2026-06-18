# Hypothesis 305: Contrastive Learning + Mitosis = Best Anomaly Detection
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **After training with contrastive learning to "pull normals together", then applying mitosis, a tighter normal cluster is formed than with reconstruction (MSE), achieving anomaly detection AUROC > 0.85.**

## Rationale

```
  Reconstruction(MSE) + inter-tension: AUROC = 0.80 (H302)
  Classification(CE) + inter-tension:  AUROC = 0.59 (H302)

  Advantages of contrastive learning:
    - Trains representations to be close among normal samples
    - Anomalies naturally drift away
    - Learns "semantic" distance rather than reconstruction

  Contrastive + mitosis:
    child_a: forms normal cluster A via contrastive learning
    child_b: forms normal cluster B via contrastive learning
    Anomaly: moves away from both cluster A and B
    -> Inter-tension becomes more discriminative
```

## Experimental Design

```
  SimCLR-style contrastive learning:
    - Normal data augmentation (noise, dropout)
    - Augmentations of the same original are pulled together
    - Different originals are pushed apart
    - NT-Xent loss

  Comparison:
    1. MSE + inter-tension (H302 baseline: 0.80)
    2. Contrastive learning + inter-tension
    3. Contrastive learning + internal tension
    4. Triplet loss + inter-tension
```

## Prediction

```
  Contrastive+inter > reconstruction+inter > classification+inter
  AUROC:         0.85+            0.80              0.59

  Reason: contrastive learning defines "boundary of normal" more clearly
```

## Experimental Results (2026-03-24)

```
  Breast Cancer, 5 trials, N=2 mitosis:

  Learning objective               AUROC mean   std
  ───────────────────   ──────────   ─────
  A) MSE + Inter         0.791        0.018  <- Best!
  B) NT-Xent + Inter     0.648        0.019
  C) Triplet + Inter     0.767        0.033

  Conclusion: Contrastive < Reconstruction! H305 refuted.
  MSE is the most suitable learning objective for mitosis anomaly detection.

  Why contrastive learning performs worse:
    NT-Xent: pulls normals together -> all normals converge to one point
    -> child_a and child_b converge to the same point -> inter-tension ≈ 0
    -> Cannot distinguish anomaly from normal

    MSE: reconstructs input -> each child learns different reconstruction patterns
    -> Different reconstruction on anomaly -> high inter-tension
```

## Status: ⬛ Refuted (MSE > CL > Triplet, contrastive learning unsuitable for mitosis)
