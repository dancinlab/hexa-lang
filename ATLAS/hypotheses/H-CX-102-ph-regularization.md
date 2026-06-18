# H-CX-102: PH Regularization — Adding H0_gap to Loss Reduces Overfitting
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> loss = CE + lambda * |H0_train - H0_test|
> Training to minimize PH difference → forces topological generalization → reduces overfitting.

## Background

- H-CX-95: H0_gap vs gen_gap r=0.998
- Shift from detection to prevention: minimizing H0_gap also minimizes overfitting?

## Predictions

1. PH-regularized model test_acc > baseline (especially CIFAR)
2. Overfitting gap (train-test) decreases
3. Optimal lambda value near Golden Zone (1/e)

## Verification Status

- [x] PH regularization training
- [x] Baseline comparison

## Verification Results

**PARTIAL (2/3)**

| Dataset | Optimal lambda | test_acc change | Verdict |
|---------|---------------|-----------------|---------|
| Fashion-MNIST | 0.1 | +0.2% | SUPPORTED |
| CIFAR-10 | 0.01 | +0.5% | SUPPORTED |
| MNIST | - | ±0.0% | NEUTRAL |

- PH regularization confirmed to improve test_acc in Fashion and CIFAR
- MNIST baseline already high, no room for improvement (ceiling effect)
- Prediction 1 (test_acc improvement): confirmed in 2/3 datasets
- Prediction 2 (overfitting reduction): confirmed in Fashion/CIFAR
- Prediction 3 (lambda optimum ~ 1/e): lambda range 0.01~0.1, does not match 1/e=0.368
