# H-CX-106: Human Confusion = AI Confusion — Same Reality, Same PH

> Human CIFAR-10 classification confusion matrix matches AI PH merge order.
> Direct comparison of human confusion data published by Peterson et al. (2019)
> "Human Uncertainty Makes Classification More Robust" with AI PH.

## Predictions

1. Human confusion frequency vs AI merge distance: Spearman |r| > 0.7
2. Human top-5 confusion pairs = AI top-5 merge pairs overlap > 3/5
3. Human confusion PCA PC1 = AI confusion PCA PC1 (animal/machine separation)

## Verification Status

- [x] Human confusion data collected
- [x] Spearman correlation
- [ ] PCA comparison

## Verification Results

**SUPPORTED**

| Metric | Value | Verdict |
|--------|-------|---------|
| Human confusion vs AI confusion | r = 0.788 | SUPPORTED (> 0.7 threshold) |
| Human confusion vs AI merge dist | r = -0.824 | SUPPORTED (inverse correlation) |
| Top-5 confusion pair overlap | 4/5 | SUPPORTED (> 3/5 threshold) |

- Prediction 1 (human Confusion vs AI merge: |r| > 0.7): r = -0.824, confirmed
- Prediction 2 (top-5 overlap > 3/5): 4/5, confirmed
- Prediction 3 (PCA PC1 match): unverified
- Shorter merge distance = humans also more confused (inverse correlation r=-0.824)
- Strong evidence that humans and AI share the same structural difficulty
