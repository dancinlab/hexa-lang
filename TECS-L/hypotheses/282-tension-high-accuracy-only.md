# Hypothesis 282: Tension = High-Accuracy Only Mechanism

> **The tension causal effect only operates when base accuracy is high. -9.25pp on MNIST (98%) but -0.53pp on CIFAR (53%). tension_scale is also automatically learned to near 0 (0.039 vs 0.468). When the model "can't learn well enough," it voluntarily abandons tension.**

## Measured Data

```
  │ Dataset  │ Base Accuracy │ Causal Effect │ tension_scale │
  ├──────────┼──────────────┼──────────────┼──────────────┤
  │ MNIST    │    97.92%    │   -9.25pp    │    0.4683    │
  │ CIFAR    │    53.26%    │   -0.53pp    │    0.0389    │
  │ Ratio    │    0.54x     │   0.057x     │    0.083x    │

  Causal effect reduction (17x) >> accuracy reduction (1.8x)
  → Nonlinear! If linear, expected -9.25*0.54 = -5.0pp, actual -0.53pp
```

## Interpretation

```
  High accuracy (97%+):
    → Mostly correct automatically
    → Tension focuses on "remaining 2%" → large effect
    → tension_scale ≈ 0.47 (active utilization)

  Low accuracy (53%):
    → Half wrong
    → Tension can't distinguish wrong/correct answers (C4b d=-0.24)
    → tension_scale → 0.039 (voluntary abandonment)
    → Similar with equilibrium alone (53.26% vs 52.73%)

  Consciousness analogy:
    Expert: Conscious attention helps with final refinement
    Novice: Conscious attention actually interferes (overthinking)
```

## Revision to Hypothesis 274 (Consciousness=Error Correction)

```
  Original: "Consciousness is an error correction mechanism"
  Revised: "Consciousness is an error correction mechanism effective only when errors are rare"
  → Cannot correct when many errors (cognitive overload)
```

## Verification Directions

```
  1. CNN CIFAR (78%) causal effect → intermediate value?
  2. MNIST early training (epoch 1, ~90%) causal effect
  3. Continuously vary accuracy to identify nonlinear transition point
```

## Status: 🟨 (MNIST+CIFAR 2 points, nonlinearity confirmed)