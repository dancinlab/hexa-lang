# H-CX-100: PH Learning Rate Guide — Optimal LR Search via dH0/dep

> The per-epoch decrease rate of H0_total (dH0/dep) varies with learning rate.
> Optimal LR = LR where H0 decreases steadily without oscillation.
> LR too large → H0 oscillation, LR too small → H0 stagnation.

## Predictions

1. H0 decrease stability in LR sweep points to optimal LR
2. test_acc at H0-based optimal LR is equivalent to manual tuning
3. LR with minimum H0 coefficient of variation (CV) = optimal LR

## Verification Status

- [ ] LR sweep + H0 stability
- [ ] Optimal LR comparison
