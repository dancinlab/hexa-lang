# Hypothesis 372: MI-FP Correlation N-Scaling — Is 0.705 a Structural Constant

> **The MI efficiency=FP correlation=0.705 coincidence in H-CX-25 was observed only at N=10(Fashion). As N increases (N=100, N=1000), does this value converge, or is it coincidental? If the 1.7% error with ln(2)=0.693 converges to 0 as N→∞, it's a structural constant.**

## Background/Context

```
  H-CX-25 Core:
    C39: MI efficiency = 0.705 (MNIST, N=10 classes)
    H318: r(tension, knn_acc) = 0.705 (Fashion, N=10 classes)
    Match: 0.705 = 0.705 (0.0% error)

  Problem:
    N=10 → Pearson r's SE = 1/√8 = 0.35
    95% CI: [0.0, 1.4] → Very uncertain!
    → Verification with larger N essential
```

## Predictions

```
  Hypothesis A (Structural): 0.705 ≈ ln(2) = 0.693
    MI efficiency → ln(2) converges as N→∞
    Reason: Landauer principle — thermodynamic limit of 1bit information processing
    Prediction: MI efficiency ∈ [0.68, 0.72] at N=100

  Hypothesis B (Coincidental): 0.705 is coincidental at N=10
    Value changes with different N
    Prediction: MI efficiency ∉ [0.68, 0.72] at N=100
```

## N-Scaling Prediction (ASCII)

```
  MI efficiency / r(T,knn)
  0.80 |
  0.75 |
  0.71 |  * N=10        ? N=26
  0.693|  ─────── ln(2) ──────── ? ──── ? ──── Converge?
  0.65 |
  0.60 |
  0.55 |
       +--+--------+--------+--------+-->
          10       26      100      1000   N(classes)
```

## Experiment Design

```
  Systematically increase N and measure both metrics simultaneously:

  | Dataset         | N    | MI eff | r(T,knn) | Notes |
  |-----------------|------|--------|----------|-------|
  | MNIST           | 10   | 0.705  | ?        | Existing |
  | Fashion-MNIST   | 10   | ?      | 0.705    | Existing |
  | EMNIST-Letters  | 26   | ?      | ?        | New |
  | EMNIST-Balanced | 47   | ?      | ?        | New |
  | CIFAR-100       | 100  | ?      | ?        | Key |
  | ImageNet subset | 1000 | ?      | ?        | Ideal |

  For each N:
    1. Train RepulsionField 2-pole
    2. MI efficiency = (MI_field - MI_best_pole) / (MI_max - MI_best_pole)
    3. r(tension, knn_acc) per-class correlation
    4. Compare both values + error with ln(2)
```

## Success/Failure Criteria

```
  Success (Structural constant):
    MI efficiency ∈ [0.68, 0.72] at N=100
    AND r(T,knn) ∈ [0.68, 0.72]
    AND difference between two values < 5%

  Partial Success:
    Only one converges → Independent mechanisms

  Failure (Coincidental):
    Both values outside [0.68, 0.72] at N=100
    → Downgrade H-CX-25 to ⬛
```

## Related Hypotheses

- H-CX-25: MI efficiency=FP correlation=0.705 (original, 🟨)
- H-CX-2: MI≈ln(2)=1bit (Landauer, 🟧★ p=0.0003)
- H318: FP sufficiency r=+0.71 (🟩)
- C39: MI efficiency 70.5% (🟦)

## Limitations

```
  - EMNIST, CIFAR-100 have different domains from MNIST
  - N↑ → learning difficulty↑ → tension patterns may change
  - MI efficiency definition itself may depend on N
```

## Verification Direction

```
  Stage 1: EMNIST-Letters (N=26) — Most accessible
  Stage 2: CIFAR-100 (N=100) — Key verification
  Stage 3: N vs MI efficiency graph → Judge convergence
  Stage 4: If converges → Attempt theoretical derivation (Why ln(2)?)
```

## Status: 🟨 Unverified