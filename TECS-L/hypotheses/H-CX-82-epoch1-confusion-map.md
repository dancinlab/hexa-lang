# H-CX-82: Epoch 1 PH = Final Confusion Map

> Epoch 1's PH merge order alone can predict final (epoch 15) confusion pairs.
> From H-CX-77: Fashion ep1 tau=0.944 → confusion structure already determined right after training starts.

## Background

- H-CX-66: merge vs confusion r=-0.97
- H-CX-77: merge order tau>0.88 at ep5, stable from Fashion ep1

## Predictions

1. Epoch 1 merge order vs epoch 15 confusion frequency Spearman |r| > 0.8
2. Epoch 1 P@3 > 0.6 (top-3 confusion pair prediction)
3. Confusion structure is determined by initialization alone (inherent in data distribution)

## Verification Status

- [ ] Epoch 1 merge vs epoch 15 confusion
- [ ] Random initialization 3 repetitions stability