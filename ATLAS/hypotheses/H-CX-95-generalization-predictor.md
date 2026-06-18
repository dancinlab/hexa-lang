# H-CX-95: Predicting Generalization Gap with PH — train PH vs test PH difference = overfitting

> The difference between train set PH and test set PH predicts generalization gap (train_acc - test_acc).
> Large PH difference indicates overfitting, small difference indicates good generalization.

## Predictions

1. |H0_train - H0_test| positively correlated with generalization gap
2. Higher train-test tau of merge order leads to better generalization
3. Tracking PH gap per epoch → early overfitting detection

## Verification Status

- [ ] train/test PH comparison
- [ ] gap correlation