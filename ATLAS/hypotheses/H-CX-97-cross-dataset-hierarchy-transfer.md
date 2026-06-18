# H-CX-97: Cross-Dataset Hierarchy Transfer — Transfer of MNIST Shape Hierarchy to Fashion

> PH hierarchy learned from MNIST (round digits vs straight digits)
> transfers to Fashion as similar shape-based hierarchy (round clothes vs straight clothes).
> Meaning differs but shape geometry is preserved.

## Predictions

1. When Fashion inputs are fed to MNIST-trained model, PH structure is not semantic (not top/shoe separation)
2. Instead shape-based clustering occurs (round shapes group together)
3. Confusion PCA's explained variance ratio decreases during MNIST→Fashion transfer

## Verification Status

- [ ] cross-dataset PH
- [ ] shape vs meaning analysis