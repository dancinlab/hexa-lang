# H-CX-99: PH Optimal Checkpoint — Epoch with Minimum H0_gap is Optimal Model

> The model at the epoch with minimum H0_gap (where train/test PH are most similar)
> achieves the highest test accuracy. "Topological balance" = optimal generalization.

## Background

- H-CX-95: H0_gap and gen_gap r=0.998
- gap_detector: H0_gap monotonically increases → minimum is near epoch 1

## Predictions

1. test_acc at min(H0_gap) epoch = highest or near highest
2. H0_gap-based checkpoint selection performs equal to or better than val_loss-based
3. Consistent across multiple seeds

## Verification Status

- [ ] Min H0_gap epoch vs best test_acc epoch