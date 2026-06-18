# H-SEDI-9: Entropy of Confusion Matrix Predicts Generalization
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


**Status**: PARTIAL
**Golden Zone Dependency**: None (pure information theory)
**Experiment**: `experiments/experiment_h_sedi_9_entropy_confusion.py`

## Hypothesis

> Shannon entropy of the confusion matrix decreases monotonically during
> training (as the model learns to separate classes), and its rate of decrease
> (dH/dt) correlates with final test accuracy across models with different
> random seeds.

## Background

SEDI uses normalized entropy to distinguish structured signals from noise.
A decreasing entropy indicates emerging structure. This hypothesis tests whether
the same principle applied to confusion matrices can predict which training
runs will generalize better -- analogous to detecting "structure" in learning.

## Method

1. Train 8 PureFieldEngine models on MNIST with different seeds for 10 epochs
2. After each epoch, compute confusion matrix on test set
3. Normalize CM to probability distribution, compute Shannon entropy
4. Track H(CM) over epochs, compute dH/dt (slope of entropy decrease)
5. Correlate dH/dt with final accuracy across all 8 models

## Results

### Per-Epoch Confusion Entropy (3 representative models)

| Epoch | H(s=42) | H(s=123) | H(s=456) |
|-------|---------|----------|----------|
|     1 |  2.5259 |   2.5430 |   2.5494 |
|     2 |  2.4888 |   2.4917 |   2.4792 |
|     3 |  2.4646 |   2.4568 |   2.4564 |
|     4 |  2.4590 |   2.4483 |   2.4510 |
|     5 |  2.4345 |   2.4447 |   2.4329 |
|     6 |  2.4373 |   2.4380 |   2.4431 |
|     7 |  2.4343 |   2.4312 |   2.4291 |
|     8 |  2.4320 |   2.4364 |   2.4170 |
|     9 |  2.4246 |   2.4148 |   2.4174 |
|    10 |  2.4244 |   2.4434 |   2.4137 |

### Entropy Decrease Rate vs Final Accuracy

| Seed | H(ep1) | H(ep10) | dH/dt    | FinalAcc |
|------|--------|---------|----------|----------|
|   42 | 2.5259 |  2.4244 | -0.00661 |  98.11%  |
|  123 | 2.5430 |  2.4434 | -0.00656 |  97.75%  |
|  456 | 2.5494 |  2.4137 | -0.00790 |  98.30%  |
|  789 | 2.5422 |  2.4207 | -0.00660 |  98.18%  |
| 1337 | 2.5296 |  2.4225 | -0.00640 |  98.13%  |
| 2024 | 2.5333 |  2.4185 | -0.00623 |  98.16%  |
| 3141 | 2.5206 |  2.4278 | -0.00590 |  98.04%  |
| 9999 | 2.5218 |  2.4244 | -0.00598 |  98.11%  |

### Key Metrics
```
  Correlation(dH/dt, final_acc) = -0.4027
  Fraction of epochs with H decreasing: 82%
```

### ASCII Visualization: Entropy Over Epochs (seed=42)
```
H(CM)
 2.53 |*
 2.49 | *
 2.46 |  *
 2.46 |   *
 2.43 |    *
 2.44 |     *
 2.43 |      *
 2.43 |       *
 2.42 |        *
 2.42 |         *
      +--+--+--+--+--+--+--+--+--+--
       1  2  3  4  5  6  7  8  9  10  Epoch
```

## Interpretation

- H(CM) does decrease during training (82% of epoch transitions are downward)
- The overall trend is clearly downward: 2.53 -> 2.42 (4.3% reduction)
- However, entropy is not strictly monotonic (small upward fluctuations exist)
- dH/dt correlation with final accuracy is r=-0.40 (moderate, not significant)
  - Negative correlation is correct direction: faster decrease = better accuracy
  - But magnitude (0.40) falls below the significance threshold of 0.50
- The narrow accuracy range (97.75% - 98.30%) limits correlation power

## Limitations

- All models converge to similar accuracy on MNIST (narrow range = weak signal)
- Only 8 data points for correlation (low statistical power)
- Need harder dataset where models diverge more in final accuracy
- Epoch-level granularity may miss sub-epoch transitions
- Non-monotonic fluctuations suggest CM entropy is noisy at high accuracy

## Next Steps

- Test on CIFAR-10 where model accuracy variance is larger
- Use per-batch confusion entropy for finer temporal resolution
- Test with varied hyperparameters (not just seed) to create larger accuracy spread
- Combine with H-SEDI-6 R-filter to detect entropy phase transitions
- Test if early-epoch dH/dt (first 3 epochs) predicts final accuracy better
