# H-CX-91: k-NN Confusion Prediction — Reproducing Confusion Structure with Raw Data Without Neural Networks

> k-NN classifier's confusion matrix has the same confusion structure
> as neural networks (PureField, Dense). Confusion = pure data geometry.

## Background

- H-CX-88: PF vs Dense confusion r=0.96 (architecture invariant)
- H-CX-89: MNIST raw→confusion r=-0.90
- Extreme verification: Even in learning-free k-NN?

## Predictions

1. k-NN confusion vs PureField confusion Spearman r > 0.8
2. k-NN top-5 confusion pairs = PureField top-5 overlap > 3/5
3. Consistent across k=1,3,5,10

## Verification Status

- [ ] k-NN confusion matrix
- [ ] Cross-architecture comparison