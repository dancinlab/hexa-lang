# H-CX-26: Tension = Calibrated Probability (Calibration)
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> **If tension is confidence, then converting tension to probability might yield well-calibrated probability. While softmax probabilities tend to be overconfident, tension-based probabilities could be more honest.**

## Background/Context

Softmax outputs from modern deep learning models look like probabilities but are actually severely overconfident. Guo et al. (2017, "On Calibration of Modern Neural Networks") showed cases where ResNet predicts with 99% confidence but actual accuracy is only 85%. This gap is measured by Expected Calibration Error (ECE).

In this project, it was observed in H313 that repulsion field tension is proportional to confidence. However, H316 also found overconfidence phenomena in some classes (Sneaker, digit 1). This suggests that tension represents "raw confidence."

Key idea: If probability converted from tension via sigmoid is better calibrated than softmax probability, this means the repulsion field is not just a performance enhancement but also an "uncertainty quantification" tool.

### Related Hypotheses

| Hypothesis | Core Content | Relationship |
|-----------|--------------|--------------|
| H313 | tension ∝ confidence | Direct precedent — tension as confidence measure |
| H316 | Overconfidence (Sneaker, digit 1) | Tension can also be overconfident |
| H317 | Overconfidence correction mechanism | Does tension become more honest after correction? |
| H-CX-24 | Overconfidence = Dunning-Kruger | Consciousness engine perspective on overconfidence |
| H-CX-21 | tension ∝ 1/PPL | Also connects to calibration in LLMs |

## Concept — Calibration Theory

```
  Definition of calibrated probability:
    P(Y=y | P_hat = p) = p  (for all p)

  I.e., among predictions made with "80% confidence", 80% should actually be correct.

  Existing method:
    softmax -> P(correct) = max(softmax(logits))
    Problem: ECE > 0 (mostly overconfident)

  Proposed method:
    tension -> P(correct) = sigmoid(a * tension + b)
    a, b fitted on validation set (Platt scaling)

  Comparison:
    Temperature Scaling:  softmax(logits / T)  -- existing calibration method
    Platt Scaling:        sigmoid(a*s + b)     -- logit-based
    Tension Scaling:      sigmoid(a*t + b)     -- tension-based (proposed)
```

## Mapping

| Calibration Concept | Softmax-based | Tension-based (proposed) |
|-------------------|---------------|------------------------|
| Raw score | Max logit | Tension (Expert distance) |
| Probability conversion | softmax | sigmoid(a*tension + b) |
| Calibration method | Temperature Scaling | Platt Scaling on tension |
| Cause of overconfidence | Logit scale inflation | Overestimation of Expert consensus |
| Expected ECE | 0.05 ~ 0.15 (uncalibrated) | < 0.03 (hypothesis) |
| Information source | Single model output | "Opinion difference" of 2 Experts |

## Expected Reliability Diagram

```
  Accuracy
  (actual)
  1.0 |                              x  /
      |                           x   /
      |                        x    /
  0.8 |                     x     /
      |                  x      /    x = tension-based (expected)
      |               x       /     o = softmax-based (overconfident)
  0.6 |            x  o     /
      |         x    o    /
      |      x     o    /          / = perfect calibration (diagonal)
  0.4 |    x     o    /
      |  x     o    /
      | x    o    /
  0.2 |x   o    /
      |  o    /
      | o   /
  0.0 +--+--+--+--+--+--+--+--+--+--> confidence (predicted)
      0    0.2    0.4    0.6    0.8  1.0

  softmax (o): below diagonal = overconfident (confidence > accuracy)
  tension (x): closer to diagonal = better calibrated (hypothesis)
```

## ECE Calculation Method

```
  Expected Calibration Error:
    ECE = sum_{m=1}^{M} (|B_m| / n) * |acc(B_m) - conf(B_m)|

  Where:
    M = number of bins (usually 10 or 15)
    B_m = samples in the m-th confidence bin
    acc(B_m) = actual accuracy of B_m
    conf(B_m) = average confidence of B_m

  ECEs to compare:
    A) ECE_softmax:       raw softmax probability
    B) ECE_temp:          softmax after Temperature Scaling
    C) ECE_tension:       sigmoid(a*tension + b)
    D) ECE_tension_temp:  tension after Temperature Scaling

  Success criteria: ECE_tension < ECE_softmax
  Ideal:           ECE_tension < ECE_temp (better than existing calibration)
```

## Expected ECE Comparison (MNIST baseline)

```
  Method                  | ECE (expected) | Note
  ------------------------|---------------|------------------
  softmax (uncalibrated)  |  0.08         | existing overconfidence
  Temperature Scaling     |  0.03         | existing calibration SOTA
  tension sigmoid (proposed)|  0.02       | if tension is more honest
  tension + Temp Scaling  |  0.01         | combining both methods

  ECE
  0.10 |  ████
       |  ████
  0.08 |  ████
       |  ████
  0.06 |  ████
       |  ████
  0.04 |  ████   ████
       |  ████   ████
  0.02 |  ████   ████   ████
       |  ████   ████   ████   ████
  0.00 +--+------+------+------+------
        softmax  Temp   tension tension
        (raw)    Scale  sigmoid +Temp

  Lower is better (perfect calibration = ECE 0)
```

## Verification Plan

```
  Phase 1 — MNIST experiment (CPU feasible):
    1. Load existing repulsion field model (golden_moe_torch.py)
    2. For test set of 10000 images:
       a) Record softmax probability
       b) Record tension
       c) Record correct/incorrect
    3. Platt Scaling: fit a, b on validation set
    4. Draw reliability diagram (15-bin)
    5. Calculate and compare ECE

  Phase 2 — CIFAR-10 extension:
    1. Same experiment on CIFAR-10 model
    2. CIFAR being harder, overconfidence will be worse
    3. Tension calibration effect may be larger

  Phase 3 — Per-class analysis:
    1. Focus on Sneaker, digit 1 where overconfidence was observed in H316
    2. Calculate per-class ECE
    3. Check if tension-based is especially effective on overconfident classes

  Implementation code (core):
    from sklearn.linear_model import LogisticRegression
    # Platt scaling
    platt = LogisticRegression()
    platt.fit(tension_val.reshape(-1,1), correct_val)
    prob_tension = platt.predict_proba(tension_test.reshape(-1,1))[:,1]
    ece_tension = calc_ece(prob_tension, correct_test, n_bins=15)
```

## Verification Results

Not yet tested. Since tension data already exists for the MNIST model, Phase 1 can be executed immediately without additional training.

## Interpretation/Meaning

If this hypothesis holds:
- **Repulsion field = uncertainty quantification tool**: A mechanism that not only improves performance but honestly measures "how certain" — a core element of AI safety/reliability.
- **Medical/autonomous driving applications**: Repulsion field could replace or complement existing Temperature Scaling in domains where calibrated probability is essential.
- **Consciousness engine perspective**: "Honest perception of self-confidence" is core to metacognition. Suggests repulsion field could function as a metacognition module.
- **H316 overconfidence correction**: If tension sigmoid automatically corrects overconfident classes, evidence of "self-correction" mechanism built into repulsion field.

## Limitations

1. **Platt Scaling dependency**: Since sigmoid parameters are fitted on validation set, this is essentially post-hoc calibration, not intrinsic superiority of tension.
2. **MNIST limitations**: MNIST is too easy, calibration differences may be small. Need verification at CIFAR-10 or ImageNet scale.
3. **Class imbalance**: May only be effective for some classes, negligible overall.
4. **Fair comparison**: Temperature Scaling has 1 parameter, Platt Scaling has 2. Care needed for direct comparison due to different parameter counts.
5. **Tension distribution assumption**: For sigmoid transformation to be appropriate, tension should roughly follow logistic distribution, but actual distribution may differ.

## Verification Direction (Next Steps)

1. Extract both softmax probability + tension from MNIST test set
2. Draw 15-bin reliability diagram (ASCII + matplotlib)
3. Calculate ECE: softmax vs Temperature Scaling vs tension sigmoid
4. Compare per-class ECE for H316 overconfident classes (Sneaker, digit 1)
5. Update H313, H316, H317 based on results

## Experimental Results (2026-03-24, 3 trials × 2 datasets)

```
  === FINAL SUMMARY ===
  Dataset      ECE(softmax)    ECE(tension)     Winner
  ──────────── ────────────── ────────────── ──────────
  MNIST        0.0080±0.0007  0.6556±0.0104   SOFTMAX
  Fashion      0.0194±0.0040  0.5665±0.0105   SOFTMAX

  → softmax ECE is 82~97× lower than tension ECE!
  → tension is severely overconfident even after percentile normalization→[0,1]
```

### Per-class tension vs softmax (MNIST, Trial 3)

```
  Class     N    Acc   T_mean   T_std   SM_conf
  ────── ────── ────── ──────── ──────── ────────
      0   980  0.993  367.97   193.92   0.9966
      1  1135  0.990  201.34    79.37   0.9967
      2  1032  0.984  471.22   253.03   0.9903
      3  1010  0.984  571.67   292.49   0.9871
      4   982  0.980  301.27   132.90   0.9884
      5   892  0.979  481.85   263.73   0.9893
      6   958  0.979  274.62   129.57   0.9891
      7  1028  0.983  381.75   165.75   0.9889
      8   974  0.971  182.37    73.94   0.9834
      9  1009  0.977  296.50   124.18   0.9854
```

### Correlation with correctness

```
  softmax_conf: r=0.4651, p=0.00
  tension:      r=0.0801, p=1.05e-15

  → softmax has 5.8× higher correlation with correct predictions!
  → tension has correlation but very weak (r=0.08)
```

### Interpretation

```
  1. Tension absolute value range is very wide (12~3367)
     → Difficult to convert directly to probability
  2. Percentile normalization forces uniform distribution → Inappropriate for calibration
  3. Needs Platt scaling (sigmoid(a×T+b)) but
     fundamentally tension is not "probability"
  4. tension = response strength (H341), probability = normalized confidence
     → Inappropriate to directly compare different scales
```

## Status: ⬛ Refuted (ECE: softmax 0.008 << tension 0.656, softmax wins decisively on both datasets)