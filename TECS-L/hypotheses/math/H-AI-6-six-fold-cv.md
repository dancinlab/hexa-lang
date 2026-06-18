# H-AI-6: Why 6-fold CV is Optimal Among k-fold

> **Hypothesis**: In k-fold cross-validation, k=6 is the optimal point for bias-variance tradeoff, related to σφ=nτ balance.

## Background
- Practice: k=5 or k=10 is conventional. k=6 is rare.
- Theory: As k increases, bias decreases but variance increases; opposite for small k
- σφ/(kτ)=1 at k=6: "Arithmetic balance of data partitioning"
- Hastie, Tibshirani, Friedman (ESL): No single optimal k exists; depends on data/model

## Verification Results (2026-03-24)

### Experimental Setup
- 1000 samples, 20 features, LogisticRegression
- k = 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20
- 100 iterations (different random seeds)
- 3 datasets: easy / medium / hard

### Easy Dataset (n_informative=15, flip_y=0.01)

|  k | Mean Acc   | Std Acc    | Variance     | MSE x1e4  |
|----|-----------|-----------|-------------|----------|
|  2 | 0.936070  | 0.032321  | 0.00104463  | 10.6303  |
|  3 | 0.938960  | 0.032482  | 0.00105510  | 10.5706  |
|  4 | 0.939110  | 0.031975  | 0.00102242  | **10.2398** |
|  5 | 0.939940  | 0.032214  | 0.00103772  | 10.3789  |
|  6 | 0.939750  | 0.032507  | 0.00105668  | 10.5705  |
|  7 | 0.939859  | 0.032479  | 0.00105492  | 10.5517  |
|  8 | 0.940010  | 0.032499  | 0.00105621  | 10.5633  |
|  9 | 0.939707  | 0.032910  | 0.00108309  | 10.8351  |
| 10 | 0.940070  | 0.032403  | 0.00104993  | 10.5001  |
| 15 | 0.940179  | 0.032742  | 0.00107201  | 10.7204  |
| 20 | 0.940360  | 0.032365  | 0.00104749  | 10.4749  |

**Winner: k=4** (both variance and MSE)

### Medium Dataset (n_informative=10, flip_y=0.05)

|  k | Mean Acc   | Std Acc    | Variance     | MSE x1e4  |
|----|-----------|-----------|-------------|----------|
|  2 | 0.804790  | 0.058821  | 0.00345993  | 34.8728  |
|  3 | 0.807792  | 0.057223  | 0.00327453  | 32.7949  |
|  4 | 0.809630  | 0.058020  | 0.00336633  | 33.6649  |
|  5 | 0.809930  | 0.057554  | 0.00331247  | 33.1247  |
|  6 | 0.809618  | 0.056690  | 0.00321380  | **32.1396** |
|  7 | 0.810309  | 0.057805  | 0.00334140  | 33.4149  |
|  8 | 0.809980  | 0.057936  | 0.00335658  | 33.5658  |
|  9 | 0.810280  | 0.057124  | 0.00326316  | 32.6323  |
| 10 | 0.810200  | 0.057102  | 0.00326064  | 32.6067  |
| 15 | 0.810496  | 0.057646  | 0.00332300  | 33.2323  |
| 20 | 0.810020  | 0.057932  | 0.00335606  | 33.5606  |

**Winner: k=6** (both variance and MSE)

### Hard Dataset (n_informative=5, flip_y=0.15)

|  k | Mean Acc   | Std Acc    | Variance     | MSE x1e4  |
|----|-----------|-----------|-------------|----------|
|  2 | 0.703430  | 0.066704  | 0.00444937  | 44.9097  |
|  3 | 0.706469  | 0.065910  | 0.00434411  | **43.5575** |
|  4 | 0.707660  | 0.066622  | 0.00443848  | 44.4341  |
|  5 | 0.708300  | 0.067266  | 0.00452467  | 45.2717  |
|  6 | 0.708943  | 0.066224  | 0.00438556  | 43.8644  |
|  7 | 0.708621  | 0.067107  | 0.00450331  | 45.0489  |
|  8 | 0.708730  | 0.067128  | 0.00450616  | 45.0748  |
|  9 | 0.709129  | 0.067428  | 0.00454653  | 45.4710  |
| 10 | 0.709290  | 0.067317  | 0.00453157  | 45.3191  |
| 15 | 0.709489  | 0.067826  | 0.00460031  | 46.0046  |
| 20 | 0.709880  | 0.067300  | 0.00452931  | 45.2931  |

**Winner: k=3** (both variance and MSE)

### Summary: k=6 rank across datasets

| Dataset | Best k (var) | Best k (MSE) | k=6 rank (var) | k=6 rank (MSE) |
|---------|-------------|-------------|----------------|----------------|
| easy    | k=4         | k=4         | 9/11           | 7/11           |
| medium  | k=6         | k=6         | **1/11**       | **1/11**       |
| hard    | k=3         | k=3         | 2/11           | 2/11           |

**k=6 average rank by variance: 4.0 / 11**
**k=6 average rank by MSE: 3.3 / 11**

### Variance by k: ASCII chart (medium dataset, where k=6 won)

```
  k= 2: ######################################## 3.46e-03
  k= 3: ##################################### 3.27e-03
  k= 4: ###################################### 3.37e-03
  k= 5: ###################################### 3.31e-03
  k= 6: ##################################### 3.21e-03  <-- BEST
  k= 7: ###################################### 3.34e-03
  k= 8: ###################################### 3.36e-03
  k= 9: ##################################### 3.26e-03
  k=10: ##################################### 3.26e-03
  k=15: ###################################### 3.32e-03
  k=20: ###################################### 3.36e-03
```

### Statistical tests: k=6 vs k=5 and k=10

| Dataset | k=6 vs k=5 (t, p)     | k=6 vs k=10 (t, p)     | Significant? |
|---------|----------------------|------------------------|-------------|
| easy    | t=-0.63, p=0.529     | t=-1.27, p=0.207       | No           |
| medium  | t=-0.72, p=0.472     | t=-1.29, p=0.201       | No           |
| hard    | t=+1.01, p=0.316     | t=-0.51, p=0.609       | No           |

**No statistically significant difference between k=6 and k=5 or k=10 in any dataset.**

## Interpretation

1. k=6 won in 1/3 datasets (medium), but k=4 won in easy, k=3 won in hard
2. All k in the k=5~10 range have no statistically significant difference (p > 0.2)
3. Which k is "optimal" depends on dataset difficulty and characteristics
4. Theoretically, no single optimal k exists (Hastie et al.)

## Limitations

- Only LogisticRegression tested (trees, SVM etc. not tested)
- Only synthetic data used (real datasets not tested)
- Fixed 1000 samples (optimal k may vary with sample size)

## Conclusion

> **Hypothesis refuted: k=6 is not special.**
> Any k in the k=5~10 range yields no statistically significant difference.
> k=6's win in medium difficulty is coincidental, unrelated to perfect number 6's structural properties.

## Grade: White Circle (coincidence, no structural basis)
## Difficulty: Low | Impact: None