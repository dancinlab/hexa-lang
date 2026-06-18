# H-CX-92: dendrogram depth = learning difficulty

> Classes that merge late (deep) in PH dendrogram = high accuracy.
> Classes that merge early (shallow) = low accuracy.
> Merge depth predicts per-class accuracy.

## Background

- H-CX-85: dendrogram = semantic hierarchy (89% purity)
- H-CX-66: early merge = high confusion

## Predictions

1. Positive correlation between per-class "first merge distance" and class accuracy r > 0.5
2. Latest merging classes = highest accuracy
3. Negative correlation between dendrogram cluster size and average accuracy within cluster

## Verification Status

- [ ] first_merge_dist vs class_accuracy