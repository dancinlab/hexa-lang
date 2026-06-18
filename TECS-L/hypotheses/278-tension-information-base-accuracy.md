# Hypothesis 278: Tension Information Content ∝ Base Accuracy — Tension Carries More Information on Easy Problems

> **The information content in tension (Cohen's d, separation ratio) depends on the model's base accuracy. At high accuracy (MNIST 97%+), tension strongly distinguishes wrong answers (d=0.81), but at low accuracy (CIFAR 53%), tension poorly distinguishes wrong answers (d=0.24).**

## Measured Data

```
  CIFAR Reproduction Experiment (experiment_cifar_reproduce.py):

  │ Constant │     MNIST    │    CIFAR     │ Ratio │
  ├──────────┼──────────────┼──────────────┼───────┤
  │ Accuracy │     98.15%   │     53.83%   │       │
  │ C4b      │  d = -0.81   │  d = -0.24   │ 0.30x │
  │ C10      │  1-NN 97.40% │  1-NN 31.55% │ 0.32x │
  │ C17      │  Sep. 2.79x  │  Sep. 1.22x  │ 0.44x │

  All constants weakened to 1/3~1/2 in CIFAR.
  Base accuracy: 98%→54% (0.55x)
```

## Interpretation

```
  MNIST (base 97%+):
    Mostly correct → Wrong answers are "special events"
    Tension provides sufficient signal to select wrong answers
    → d=0.81, separation 2.79x

  CIFAR (base 53%):
    Half wrong → Wrong answers are "routine"
    Tension struggles to distinguish wrong/correct (all noisy)
    → d=0.24, separation 1.22x

  Generalization:
    Tension information content = f(base accuracy)
    f(0.97) ≈ 0.81 (large effect)
    f(0.54) ≈ 0.24 (weak effect)
    f(0.10) ≈ 0? (if random, tension meaningless?)
```

## Connection to Hypothesis 274 (Consciousness=Error Correction)

```
  Hypothesis 274: Tension = Error correction mechanism
  Hypothesis 278: Many errors make correction difficult

  Combined: Consciousness (tension) is most effective when errors are rare
  → Mostly automatic correct, consciousness focuses on occasional errors
  → When half are wrong, consciousness is overwhelmed (cognitive overload)

  Brain correspondence:
    Easy tasks: Attention focuses on exceptions → high efficiency
    Hard tasks: Attention dispersed → low efficiency
    → Similar to Yerkes-Dodson law?
```

## CNN Connection (Hypothesis 277)

```
  MLP CIFAR: 53% → Tension information weak
  CNN CIFAR: 78% → Tension information predicted to be stronger
  → Need to remeasure C4b, C17 in CNN

  Prediction: CNN CIFAR's C4b d > MLP CIFAR's 0.24
  (CNN has higher base accuracy → tension more useful)
```

## Verification Directions

```
  1. Measure C4b, C17 in CNN CIFAR → What is d at 78% base accuracy?
  2. Intentionally lower MNIST accuracy (epoch 1, accuracy ~90%) and measure
  3. Function form of f(acc): Linear? Sigmoid? Threshold?
```

## Limitations

```
  1. Observed with only two points: MNIST and CIFAR.
  2. MNIST and CIFAR differ in many ways besides accuracy (input dimensions, task complexity).
  3. MLP-based, so feature extraction quality is mixed in.
```