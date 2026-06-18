# H-CX-87: PH-guided curriculum — Learning confusion pairs first accelerates convergence

> Learning class pairs with short PH merge distance (high confusion) first
> accelerates overall accuracy convergence. "Hard things first" = topology-guided curriculum.

## Background

- H-CX-66: merge distance = confusion frequency (r=-0.97)
- H-CX-82: Confusion structure already determined at epoch 1
- Application: If we know confusion structure in advance, we can optimize learning order

## Predictions

1. Confusion pair oversampling → 1-3%p accuracy improvement at same epoch
2. Confusion pair weighted loss → 20-30% reduction in convergence epochs
3. Especially effective on CIFAR (difficult data)

## Verification Status

- [ ] Confusion pair weighted learning
- [ ] Convergence speed comparison