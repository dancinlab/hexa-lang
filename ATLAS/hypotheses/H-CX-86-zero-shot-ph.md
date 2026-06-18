# H-CX-86: Zero-shot PH — Semantic hierarchy emerges from random initialization alone

> The PH merge order of randomly initialized models before training already contains confusion structure.
> H-CX-82 showed epoch 1 perfect prediction → What about epoch 0 (untrained)?
> Confusion structure = Intrinsic property of data distribution, independent of training.

## Background

- H-CX-82: CIFAR ep1 r=-0.95, P@5=1.0
- H-CX-85: dendrogram = semantic hierarchy (CIFAR 89%)
- Epoch 1 = trained once. Epoch 0 = completely random.

## Predictions

1. Epoch 0 (random) PH merge also correlates with final confusion |r| > 0.5
2. Same merge order across 3 different random initializations (seed invariant)
3. Confusion structure inherent in data distribution → Model architecture independent

## Verification Status

- [ ] Epoch 0 PH vs epoch 15 confusion
- [ ] 3 seeds repetition