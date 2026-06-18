# H-CX-96: Weight Change Triggers Topological Transition — Critical delta_W Exists

> Cause of 30x topological transition at epoch 0→1 (H-CX-90):
> When weight change ||W1-W0|| exceeds critical value, PH changes rapidly.
> Does reducing learning rate delay the transition?

## Predictions

1. ||W1-W0|| >> ||W2-W1|| (weight change also maximal in first epoch)
2. At lr=1e-4 (10x reduction), transition delayed to epoch 3~5
3. Correlation between ||delta_W|| and |delta_H0|: r > 0.8

## Verification Status

- [ ] Track weight changes
- [ ] Transition timing by learning rate