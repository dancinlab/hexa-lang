# H-CX-76: PH Precognition Classifier — Predicting Confusion Pairs with merge distance

> Using PH merge distance as a feature yields confusion pair prediction accuracy > 90%.
> Practical application of H-CX-66: Computing PH mid-training enables early prediction of final confusion pairs.

## Background

- H-CX-66: merge_dist vs confusion Spearman r=-0.97 (p<0.001)
- However, correlation ≠ prediction. Must measure actual classifier (threshold-based) accuracy.

## Predictions

1. Pairs with merge distance < median = confusion pairs (precision > 80%)
2. merge distance computed at epoch 5 can predict epoch 15 confusion pairs
3. Kendall tau between merge distance rank and confusion rank > 0.8

## Verification Method

```
1. Compute PH merge distance at epochs 5, 10, 15
2. Extract actual confusion matrix at epoch 15
3. Predict "top-K confusion pairs" using merge distance from each epoch
4. Calculate Precision@K, Recall@K
5. Compare epoch 5 predictions → epoch 15 actual (early prediction)
```

## Related Hypotheses

- H-CX-66 (Direction Topology Confusion)
- H-CX-62 (Topology Precognition)

## Limitations

- Among 45 pairs (10C2), actual confusion pairs are few → imbalanced classification
- Absolute values of merge distance vary by dataset

## Verification Status

- [ ] Precision@K measurement
- [ ] Early prediction accuracy