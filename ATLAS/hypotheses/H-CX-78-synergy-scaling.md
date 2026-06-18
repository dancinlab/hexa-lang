# H-CX-78: Golden Zone Synergy Scaling — Synergy Optimal Point Convergence with Difficulty Calibration

> In H-CX-67, only CIFAR deviates from the Golden Zone. When normalizing
> tension by dataset difficulty (baseline accuracy), the synergy optimal point converges to 1/e for all datasets.

## Background

- H-CX-67: MNIST Q3(0.340), Fashion Q3(0.341) ≈ 1/e, CIFAR Q5(0.644) inconsistent
- CIFAR baseline acc 54% << MNIST 98%, Fashion 89%

## Predictions

1. When normalizing tension by accuracy (tension / accuracy), synergy peak positions converge
2. Synergy magnitude proportional to 1-accuracy (harder tasks have larger absolute synergy)
3. Normalized optimal point within 1/e ± 0.05 for all 3 datasets

## Verification Method

```
1. Reuse (tension, accuracy, synergy) data per quintile from H-CX-67 experiment
2. Normalization: tension_norm = tension / (max_tension × baseline_acc)
3. Recalculate synergy peak position in normalized quintiles
```

## Related Hypotheses

- H-CX-67, Golden Zone constant system

## Limitations

- Normalization method is arbitrary (risk of post-hoc fitting)

## Verification Status

- [ ] Synergy peak after normalization
- [ ] Confirm convergence across 3 datasets