# Hypothesis 373: Causal Effect Difficulty Gradient — Intermediate Point Verification with Fashion

> **If tension's causal effect (accuracy drop at tension=0) is monotonically proportional to task difficulty, Fashion-MNIST between MNIST(-9.25pp) and CIFAR(-0.53pp) should show intermediate values(-2~-6pp). If confirmed, H278(tension∝base_accuracy) upgrades to 🟩.**

## Background/Context

```
  C48 Causal Experiment Results:
    MNIST: tension=0 → -9.25pp (large effect!)
    CIFAR: tension=0 → -0.53pp (almost no effect!)

  tension_scale comparison:
    MNIST: 0.4683 (high tension)
    CIFAR: 0.0389 (low tension, 12x difference)

  Base accuracy:
    MNIST: ~98% (easy)
    CIFAR: ~53% (difficult)

  H278 prediction: tension causal effect ∝ base accuracy
  → Tension more important for easy tasks?
  → Counterintuitive! (H342 predicts "more dependence on difficult")
```

## Key Questions

```
  Two competing hypotheses:

  H278: Causal effect ∝ base accuracy (easier → higher tension dependence↑)
    MNIST(98%) > Fashion(~90%) > CIFAR(53%)
    Prediction: Fashion at -2~-6pp

  H342: Causal effect ∝ difficulty (harder → higher tension dependence↑)
    Opposite direction prediction → CIFAR should be largest
    but actual measurement shows CIFAR is smallest!

  → Fashion as discriminating experiment:
    If H278 correct: Fashion -2~-6pp (intermediate)
    If H342 correct: Fashion < MNIST (should be smaller)
```

## Predictions (ASCII)

```
  Causal Effect (drop at tension=0, pp)
  10 |  * MNIST (-9.25pp)
   8 |
   6 |          ★ Fashion (predicted: -3~-6pp)
   4 |
   2 |
   1 |                              * CIFAR (-0.53pp)
   0 +--+-----------+-----------+-->
       98%         ~90%        53%    Base Accuracy

  If H278 correct: monotonic decrease (base_accuracy↑ → causal_effect↑)
  If H342 correct: non-monotonic (what pattern?)
```

## Experimental Design

```
  Data: Fashion-MNIST (10 classes, ~90% base accuracy)
  Model: RepulsionField 2-pole (same architecture as MNIST/CIFAR)

  1. Normal training 30ep → measure base accuracy
  2. tension=0 intervention → measure accuracy change
  3. per-class analysis: which classes are most affected?
  4. Record tension_scale → compare with MNIST/CIFAR

  Additional data (if possible):
    EMNIST-Letters (~85%?) → 4th data point
    SVHN (~90%?) → same difficulty different domain
```

## Success/Failure Criteria

```
  H278 confirmation: Fashion causal effect ∈ [-2pp, -6pp]
    AND tension_scale ∈ [0.04, 0.47] (between CIFAR~MNIST)
    → H278 🟩 upgrade

  H278 refutation: Fashion causal effect < -1pp
    → Non-linear relationship, new model needed

  Exception: Fashion causal effect > -6pp (larger than MNIST)
    → Non-monotonic relationship, very interesting result
```

## Related Hypotheses

- H278: tension∝base_accuracy (🟨, only 2 points)
- H342: causal+difficulty proportional (🟨)
- C48: tension=0 causal experiment (⚠️ CIFAR not reproduced)
- H282: high-accuracy exclusive (🟨)
- H283: non-linear threshold (⚠️ inverted)

## Limitations

```
  - Fashion is 28x28 like MNIST → possible architecture bias
  - 3 points (MNIST, Fashion, CIFAR) insufficient to determine function form
  - Effects beyond base accuracy (data structure, class similarity)
```

## Verification Direction

```
  Stage 1: Fashion-MNIST causal experiment (core)
  Stage 2: Add EMNIST/SVHN → 4-5 point fitting
  Stage 3: per-class difficulty vs causal effect correlation (10 points each)
  Stage 4: Theoretical model: effect = f(base_acc, tension_scale)
```

## Status: 🟨 Unverified