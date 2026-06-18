# H-CX-68: Precognition Conservation Law — Magnitude Precognition + Direction Precognition ≈ Constant
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


> Per-class mag_AUC + dir_AUC ≈ const (conservation).
> Classes weak in magnitude precognition are compensated by direction precognition, and vice versa.
> Precognition version of G×I = D×P conservation law (H172).

## Background

- Per-class data from unified precognition:
  - MNIST class 1: mag_AUC=0.331, dir_AUC=0.969 (sum=1.30)
  - MNIST class 7: mag_AUC=0.861, dir_AUC=0.885 (sum=1.75)
- H172: G×I = D×P (conservation law)

**Core Connection**: Magnitude and direction of tension "distribute precognition energy".
When one channel is weak, the other compensates → total precognition energy conserved?

## Predictions

1. Variance of per-class mag_AUC + dir_AUC is smaller than variance of mag_AUC or dir_AUC alone
2. Correlation between mag_AUC and dir_AUC is negative (trade-off)
3. Coefficient of variation (CV) of sum < individual CV
4. Product (mag_AUC × dir_AUC) may also be conserved

## Verification Method

```
1. Collect per-class (mag_AUC, dir_AUC) from unified precognition experiments
2. Calculate variance/CV of sum and product
3. Corr(mag_AUC, dir_AUC) — negative indicates trade-off
4. Repeat across 3 datasets
```

## Related Hypotheses

- H172 (G×I=D×P conservation law), H-CX-58, H-CX-59
- H341 (output = magnitude × direction)

## Limitations

- Statistical power weak with only 10 classes
- May be simple ceiling effect rather than conservation

## Verification Status

- [x] Sum/product variance comparison
- [x] Trade-off correlation

## Verification Results

**Verdict: REJECTED**

### Trade-off Correlation: Corr(mag_AUC, dir_AUC)

| Dataset | r     | Trade-off? |
|---------|-------|------------|
| MNIST   | -0.07 | Weak YES   |
| Fashion | 0.58  | NO (positive corr) |
| CIFAR   | 0.22  | NO (positive corr) |

```
  Corr(mag, dir)
  0.6 |     ##  Fashion (0.58)
  0.5 |     ##
  0.4 |     ##
  0.3 |     ##
  0.2 |     ##      ##  CIFAR (0.22)
  0.1 |     ##      ##
  0.0 |--+--+-------+-------> datasets
 -0.1 |  ##  MNIST (-0.07)
       MNI  FAS    CIF
```

Prediction 2 (negative correlation = trade-off) failed. Only MNIST shows weak negative correlation, others show positive correlation.

### Sum Conservation: CV(sum) vs CV(mag)

| Dataset | CV_sum  | CV_mag  | CV_sum < CV_mag? |
|---------|---------|---------|------------------|
| MNIST   | --      | --      | NO               |
| Fashion | --      | --      | NO               |
| CIFAR   | 0.062   | 0.081   | YES              |

Only CIFAR shows sum CV smaller than individual -- holds for 1/3 datasets only.

### Product Conservation

Product (mag_AUC x dir_AUC) conservation failed in all 3 datasets.

### Rejection Reasons

1. Trade-off (Prediction 2): Weak support in only 1 out of 3
2. Sum conservation (Prediction 3): Holds in only 1 out of 3
3. Product conservation (Prediction 4): All failed
4. No consistent conservation law exists
5. Precognition version of G x I = D x P conservation does not hold