# H-CX-93: Confusion Eigenstructure — Eigenvectors of confusion matrix encode semantic axes

> PCA eigenvectors of confusion matrix encode semantic axes (animals vs machines, etc).
> First eigenvector = largest semantic split.

## Background

- H-CX-85: dendrogram is semantic hierarchy
- H-CX-88: architecture invariant
- Confusion matrix itself should have structure

## Predictions

1. PC1 of confusion matrix matches CIFAR animal/machine split
2. PC2 is CIFAR sub-classification (birds vs mammals, etc)
3. Fashion PC1 = upper/lower/footwear split

## Verification Status

- [ ] Confusion PCA
- [ ] Semantic axis alignment