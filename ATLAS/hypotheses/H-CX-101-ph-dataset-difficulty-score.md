# H-CX-101: PH Difficulty Score — Predicting Dataset Difficulty via Epoch 1 H0_total

> Epoch 1 H0_total is a universal indicator of dataset difficulty.
> Larger H0 = classes well-separated = easier; smaller H0 = overlapping = harder.

## Background

- MNIST H0≈4.2, Fashion H0≈2.3, CIFAR H0≈2.1
- MNIST acc=98% > Fashion 89% > CIFAR 54%
- H0 and final accuracy share the same ordering

## Predictions

1. Correlation between epoch 1 H0_total and final accuracy r > 0.9
2. H0_total can predict difficulty before training on new datasets too
3. H0_total / n_classes = normalized difficulty score

## Verification Status

- [ ] cross-dataset H0 vs accuracy (n=3 done, needs n>=6)
- [ ] normalized score
- [ ] baseline comparison (epoch-1 accuracy, epoch-1 loss)
- [ ] multi-architecture robustness
- [ ] permutation test

## Review Notes (2026-03-26)

**Status downgraded: ✅ SUPPORTED → 🟨 WEAK**

Critical issues:
1. **n=3 datasets is insufficient** — any 3-item monotonic ordering gives Spearman r=1.0. Probability of random monotonic order = 2/6 = 33%, so p=0.33 (NOT significant)
2. **Reporting "r > 0.9" with n=3 is misleading** — r=1.0 trivially for perfect monotonic order
3. **No baseline comparison** — epoch-1 accuracy or epoch-1 loss likely predict same ordering with zero PH computation cost
4. **MNIST/Fashion/CIFAR have universally known difficulty** — any reasonable model feature reproduces this order
5. **Document is 22 lines** — below 40-line minimum quality standard
6. **Both verification checkboxes unchecked**

To upgrade: test on SVHN, STL-10, KMNIST, EMNIST, Tiny ImageNet (minimum 6-8 datasets for meaningful p<0.05)
