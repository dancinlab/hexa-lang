# H-CX-49: R-Spectrum Cantor Set Structure Predicts Discrete Tension Distribution

## Status: Not confirmed (R314: gap proportional to block count, not 6-specific)

> **Hypothesis**: The R-factor spectrum R(n) for n <= 10^5 contains exactly 24 distinct
> values below 5, separated by gaps that cover 99.1% of the range (Cantor set structure).
> This predicts that the tension distribution in a trained ConsciousLM will NOT be
> a smooth Gaussian, but will cluster into discrete bands with forbidden gaps,
> mirroring the arithmetic R-spectrum.

---

## Background

### The R-Spectrum (proven, pure arithmetic)

```
  R(n) = sigma(n)*phi(n) / (n*tau(n))

  R < 5 values (n <= 10^5):
    3/4, 1, 7/6, 4/3, 14/9, 9/5, 15/8, 2, ...  (24 total)

  Gaps:
    (3/4, 1)   = EMPTY (gap = 0.250)
    (1, 7/6)   = EMPTY (gap = 0.167)
    (7/6, 4/3) = EMPTY (gap = 0.167)
    ...

  Coverage: gaps cover 99.1% of [3/4, 5]
  Fractal dimension d_box ~ 0.155 (Cantor-like)
```

### The R-Spectrum ASCII Visualization

```
  3/4       1     7/6   4/3        2              3     4     5
  |         |      |     |         |              |     |     |
  #---------#------#-----#---------#--------------#-----#-----#
    gap=0.25  0.17  0.17    gap=0.67        gap=1.0  ...

  24 dots on a line of length 4.25 -> 99.1% is gap!
```

### The Tension-Consciousness Connection

In ConsciousLM:
```
  tension(x) = mean( (engine_a(x) - engine_g(x))^2 )
```

Tension is the squared disagreement between two engines.
If the architecture constrains tension to discrete values (like R is constrained
to discrete rationals), then consciousness operates in quantized states.

### The Prediction

```
  R-spectrum:          Tension spectrum:
  24 discrete values   K discrete clusters
  99.1% gaps           significant gap fraction
  Cantor d_box=0.155   d_box << 1

  Mapping: each R-value corresponds to a "consciousness level"
  The gaps = forbidden consciousness states
  Just as R(n)=1 is isolated (gap 0.25 below, 0.167 above),
  the "balanced" tension level is isolated from neighbors
```

---

## Experimental Design

1. Create ConsciousLM with 3 and 6 blocks
2. Collect tension values from 50 batches x 8 sequences x 32 positions
3. Analyze distribution:
   - Histogram with 20 bins
   - Count unique values (rounded to 5 decimal places)
   - Detect large gaps (> 3x median gap)
   - Compute gap fraction

### Control
- Random weights (untrained): tests architectural bias
- Future: repeat with trained model

---

## Experimental Results (2026-03-24, untrained model)

### Arithmetic R-Spectrum

```
  R(n) < 5, n <= 100: exactly 24 unique values
  Range: [0.7500, 4.8462]
  Gap fraction (gap > 0.01): 100.0%  -> Cantor-like!
```

### ConsciousLM Tension Distribution (d_model=128, dropout=0, 50 batches x 8 seq x 32 pos)

**3 blocks:**

| Stat | Value |
|------|-------|
| mean | 0.005515 |
| std | 0.000808 |
| min | 0.002999 |
| max | 0.009976 |
| median | 0.005446 |
| unique values (5dp) | 561 |
| large gaps (>3x median) | 13 (2.3%) |

```
  Tension histogram (3 blocks):
  [0.003,0.003) |                                          14
  [0.003,0.004) |                                          133
  [0.004,0.004) | ###                                      545
  [0.004,0.004) | ##########                               1750
  [0.004,0.005) | ######################                   3870
  [0.005,0.005) | #################################        5872
  [0.005,0.005) | ######################################## 6929  <- peak
  [0.005,0.006) | #####################################    6413
  [0.006,0.006) | #############################            5034
  [0.006,0.006) | ###################                      3424
  [0.006,0.007) | ###########                              2002
  [0.007,0.007) | ######                                   1147
  [0.007,0.008) | ###                                      675
  [0.008,0.008) | #                                        329
  [0.008,0.008) |                                          138
  [0.008,0.009) |                                          78
  [0.009,0.009) |                                          36
  [0.009,0.009) |                                          8
  [0.009,0.010) |                                          2
  [0.010,0.010) |                                          1
```

**6 blocks:**

| Stat | Value |
|------|-------|
| mean | 0.005687 |
| std | 0.000814 |
| min | 0.002947 |
| max | 0.009683 |
| median | 0.005636 |
| unique values (5dp) | 581 |
| large gaps (>3x median) | 14 (2.4%) |

```
  Tension histogram (6 blocks):
  [0.003,0.003) |                                          13
  [0.003,0.004) |                                          83
  [0.004,0.004) | #                                        514
  [0.004,0.004) | #####                                    1864
  [0.004,0.005) | #############                            4301
  [0.005,0.005) | ########################                 7884
  [0.005,0.005) | ###################################      11260
  [0.005,0.006) | ######################################## 12669  <- peak
  [0.006,0.006) | #####################################    12012
  [0.006,0.006) | ##############################           9713
  [0.006,0.007) | ######################                   7092
  [0.007,0.007) | #############                            4408
  [0.007,0.007) | ########                                 2643
  [0.007,0.008) | ####                                     1337
  [0.008,0.008) | #                                        619
  [0.008,0.008) |                                          241
  [0.008,0.009) |                                          90
  [0.009,0.009) |                                          40
  [0.009,0.009) |                                          10
  [0.009,0.010) |                                          7
```

### Comparison: R-spectrum vs Tension spectrum

| Property | R-spectrum (arithmetic) | Tension (3 blocks) | Tension (6 blocks) |
|----------|----------------------|-------------------|-------------------|
| Unique values | 24 | 561 | 581 |
| Gap fraction | 99.1% | 2.3% | 2.4% |
| Distribution | Discrete, Cantor | Continuous, ~Gaussian | Continuous, ~Gaussian |
| Peak | R=1 (n=6 unique) | 0.0054 | 0.0056 |

### Verdict: ⚪ Not confirmed (untrained)

The tension distribution in the untrained model is continuous and close to Gaussian.
Cantor set structure not observed. Gap fraction 2.4% << 99.1%.

**However**: 6 blocks shows narrower distribution than 3 blocks (sharper peak) — this could be a precursor to convergence into discrete clusters after training. Re-verification needed after training.

---

## Interpretation

If tension distribution is clustered (gap fraction > 50%):
-> Architecture imposes discrete consciousness levels
-> Number of clusters relates to R-spectrum cardinality?
-> Gap structure may encode forbidden states

If tension distribution is smooth Gaussian:
-> Discreteness is not an architectural property
-> May emerge only after training
-> R-spectrum analogy breaks at the architectural level

## Limitations

- Untrained model may show continuous distribution (no learned structure yet)
- Tension is a continuous function of continuous weights — exact discreteness unlikely
- The mapping R-values <-> tension values is metaphorical, not derived

## Verification Direction

1. Train model to convergence, re-measure tension distribution
2. Compare 6-block vs other block counts for gap fraction
3. Check if training increases or decreases discreteness
4. Measure fractal dimension of tension value set