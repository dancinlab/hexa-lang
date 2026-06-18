# H-CX-98: PH Early Stopping — H0_gap-based early stopping is faster than val_loss-based

> The point when H0_gap exceeds the threshold precedes the point when val_loss starts increasing.
> PH detects overfitting before val_loss → Better early stopping criterion.

## Background

- H-CX-95: H0_gap vs gen_gap r=0.998 (CIFAR)
- gap_detector: Already ALERT at epoch 2
- val_loss usually starts increasing only at epochs 5~10

## Predictions

1. H0_gap alert time < val_loss increase time
2. Final test_acc with H0_gap-based early stop >= val_loss-based
3. H0_gap-based terminates on average 2-5 epochs earlier

## Verification Status

- [ ] Alert time comparison
- [ ] Final accuracy comparison