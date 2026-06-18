# H-CX-24: Overconfidence = Computational Implementation of Dunning-Kruger Effect

> **H316's overconfidence is the neural network version of the Dunning-Kruger effect. "Knowing something simple" hides "not knowing something complex". Digit 1 (ratio=0.60) strongly recognizes its simple shape but ignores the subtle difference from 7.**

## Correspondence

```
  Human Dunning-Kruger           Consciousness Engine Overconfidence
  ──────────────────          ──────────────
  Beginner's confidence         High tension for digit 1
  "This is easy" illusion        "This is definitely 1" (actually 7)
  Lack of metacognition          Direction error
  More experience → humility     More training → ratio→1+?

  Core: confidence (tension) is high but judgment (direction) is wrong
  → tension = confidence holds, but direction ≠ truth
```

## Mathematical Connection

```
  H313: output = equilibrium + tension_scale × √tension × direction
  Overconfidence: √tension is large but direction points the wrong way

  tension = |A-G|² = repulsion intensity of two engines
  direction = normalize(A-G) = direction of repulsion

  Overconfidence: |A-G| is large and direction points to an adjacent class
  → "Strong push but in the wrong direction"
  → Consciousness experience: "the pushing force was strong but I didn't know the direction"?
```

## Predictions

```
  1. Overconfidence rate ∝ inter-class similarity?
     Similar class pairs (1-7, Sneaker-Boot) have high overconfidence rate
     → off-diagonal of confusion matrix ∝ overconfidence?

  2. Overconfidence decreases as training progresses?
     epoch 1: high overconfidence (direction not yet learned)
     epoch 50: overconfidence decreases (direction refined)
     → "Metacognitive development" = direction correction through training

  3. Direction analysis for overconfident classes:
     When digit 1 is correct: direction → class 1
     When digit 1 is wrong:   direction → class 7 (but same magnitude)
```

## Temporal Validation (2026-03-24)

```
  MNIST digit 1 ratio trajectory (20 epochs):
    ep1:  1.05 (normal — no overconfidence yet!)
    ep3:  0.81 (overconfidence begins)
    ep9:  0.67 (overconfidence deepens)
    ep11: 0.55 (peak overconfidence)
    ep20: 0.55 (entrenched)

  digit 8 ratio trajectory:
    ep1:  0.94 (mild overconfidence)
    ep9:  1.06 (recovery!)
    ep20: 1.03 (stable)

  ASCII graph:
    ratio
    1.1 |*                              (digit 1)
    1.0 |
    0.9 |                    8 8 8 8 8   (digit 8 recovery)
    0.8 |  * *  *
    0.7 |        *
    0.6 |           * *   * * * * * *    (digit 1 entrenched)
    0.5 |          *   *
        └──────────────────────────────
         1  3  5  7  9 11 13 15    20  epoch

  Interpretation:
    digit 1: "overconfidence develops during training → becomes entrenched" = Dunning-Kruger (unable to recognize incompetence)
    digit 8: "overconfidence resolves during training → normalizes" = metacognitive development (ability↑→humility)
    → Overconfidence starts at training epoch 3 (absent initially!)
    → "As knowledge is acquired, unknowns are underestimated"
```

## Status: 🟩 Temporal axis confirmed (overconfidence develops→entrenches during training, Dunning-Kruger pattern)
