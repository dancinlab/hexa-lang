# H-SEDI-10: R-filter on Tension Vectors Detects Anomalies
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


**Status**: REFUTED
**Golden Zone Dependency**: Indirect (ratio targets include 1/e, ln(4/3))
**Experiment**: `experiments/experiment_h_sedi_10_tension_rfilter.py`

## Hypothesis

> Applying SEDI's ratio detection to per-class tension vectors from a trained
> PureField model reveals structured patterns matching known constants
> (sigma/tau=3, phi/tau=0.5, 1/e, golden ratio, ln(4/3)). These ratios
> would appear more frequently than in random permutations.

## Background

SEDI's ratio scanner looks for sigma/tau, phi/tau patterns in data streams.
If the PureField engine's tension structure reflects the mathematical constants
of the TECS-L framework, then tension ratios between classes should cluster
around these constants more than chance would predict.

## Method

1. Train PureFieldEngine on MNIST for 5 epochs
2. Extract per-class mean tensions from test set (10 classes)
3. Consecutive ratio scan: compute t[i]/t[i+1] for sorted tensions
4. Pairwise ratio scan: compute t[i]/t[j] for all 90 pairs
5. Random baseline: shuffle tensions 1000 times, recompute consecutive ratios
6. Compare real hit counts vs random baseline

## Results

### Per-Class Tension Statistics

| Class | Mean     | Std      |   N  |
|-------|----------|----------|------|
|     0 |  94.1114 |  51.8935 |  980 |
|     1 |  39.9143 |  13.4454 | 1135 |
|     2 |  91.3351 |  48.7145 | 1032 |
|     3 | 119.3483 |  60.7061 | 1010 |
|     4 |  57.0219 |  25.9475 |  982 |
|     5 | 100.3372 |  56.0002 |  892 |
|     6 |  77.0485 |  37.9950 |  958 |
|     7 |  98.0123 |  49.0898 | 1028 |
|     8 |  38.1664 |  15.2236 |  974 |
|     9 |  62.0373 |  26.8620 | 1009 |

### Consecutive Ratio Scan (sorted class means, 5% tolerance)

| Target     | Value  | Hits |
|------------|--------|------|
| sigma/tau  | 3.0000 |    0 |
| phi/tau    | 0.5000 |    0 |
| sigma_inv  | 2.0000 |    0 |
| 1/e        | 0.3679 |    0 |
| golden     | 1.6180 |    0 |
| ln(4/3)    | 0.2877 |    0 |

### Pairwise Ratio Scan (all 90 pairs)

| Target     | Value  | Hits | Rate |
|------------|--------|------|------|
| sigma/tau  | 3.0000 |    2 | 2.2% |
| phi/tau    | 0.5000 |    4 | 4.4% |
| sigma_inv  | 2.0000 |    4 | 4.4% |
| 1/e        | 0.3679 |    1 | 1.1% |
| golden     | 1.6180 |    7 | 7.8% |
| ln(4/3)    | 0.2877 |    0 | 0.0% |

### Random Baseline (1000 shuffles, consecutive only)

| Target     | Real | Random(avg) | Ratio   |
|------------|------|-------------|---------|
| sigma/tau  |    0 |        0.41 |    0.0x |
| phi/tau    |    0 |        0.76 |    0.0x |
| sigma_inv  |    0 |        0.76 |    0.0x |
| 1/e        |    0 |        0.20 |    0.0x |
| golden     |    0 |        1.40 |    0.0x |
| ln(4/3)    |    0 |        0.00 |    1.0x |

### ASCII Visualization: Per-Class Mean Tension
```
Tension
 119 |            ##  class 3
 100 |         ## ##  class 5
  98 |      ## ## ##  class 7
  94 |   ## ## ## ##  class 0
  91 |   ## ## ## ##  class 2
  77 |   ## ## ## ##  class 6
  62 |## ## ## ## ##  class 9
  57 |## ## ## ## ##  class 4
  40 |## ## ## ## ##  class 1
  38 |## ## ## ## ##  class 8
     +--+--+--+--+--+--+--+--+--+--
      8  1  4  9  6  2  0  7  5  3  (sorted)
```

## Interpretation

- Zero consecutive ratio hits: no TECS-L constants appear in sorted tension ratios
- Pairwise scan finds some hits (golden ratio 7.8%), but this is expected by chance
  with 90 pairs and 5% tolerance windows
- The random baseline actually produces MORE consecutive hits than the real data
- Per-class tensions reflect task difficulty, not mathematical constants
- Classes 1 and 8 (lowest tension) are visually simplest digits
- Class 3 (highest tension) is the most confusable digit

## Limitations

- Only 10 classes means only 9 consecutive ratios (very few samples)
- 5% tolerance may be too tight or too loose
- Tension values are strongly influenced by class difficulty, not architecture
- A different model or task might produce different ratio distributions

## Verdict

The hypothesis is clearly refuted. Per-class tension ratios do not encode
TECS-L mathematical constants. Tensions reflect task difficulty (which digits
are hard to classify), not underlying mathematical structure. The pairwise
hits are consistent with chance given the number of comparisons and tolerance.
