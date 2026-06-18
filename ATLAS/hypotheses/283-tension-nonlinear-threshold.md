# Hypothesis 283: Nonlinear Threshold of Tension Effect

> **The relationship between tension causal effect and baseline accuracy is nonlinear. There exists a sharp transition point between MNIST(-9.25pp) and CIFAR(-0.53pp), and this threshold is estimated to be around ~70%.**

## Measurements

```
  Baseline accuracy vs causal effect:
    98% → -9.25pp (huge)
    53% → -0.53pp (minimal)

  Linear prediction: 53% baseline → -9.25 * (53/98) ≈ -5.0pp
  Actual: -0.53pp → 1/10 of linear

  → Nonlinear! There's a "cliff" somewhere
  → Threshold estimate: Verify with CNN CIFAR 78% (C56 experiment)
```

## tension_scale is also nonlinear

```
  MNIST: 0.4683
  CIFAR: 0.0389
  Ratio: 0.083x (12x difference)
  Accuracy ratio: 0.54x (1.8x difference)

  → scale decrease(12x) >> accuracy decrease(1.8x)
  → Model voluntarily "turns off" when "tension doesn't help"
```

## Verification: 3rd point is key

```
  CNN CIFAR (78%):
    Prediction A (linear): -9.25 * (78/98) = -7.36pp
    Prediction B (nonlinear, threshold ~70%): -5~-8pp
    Prediction C (nonlinear, threshold ~80%): -1~-3pp

  → Determine transition point based on which CNN CIFAR causal effect matches
  → To be measured in Windows experiment_cnn_tension_d.py
```

## Status: 🟨 (2 points observed, 3rd point needed)