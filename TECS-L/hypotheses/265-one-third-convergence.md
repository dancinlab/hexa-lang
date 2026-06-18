# Hypothesis 265: 1/3 Convergence Law [Refuted — Initial Value Bias]

> ~~The learned tension_scale of repulsion fields converges to 1/3.~~ **Refuted: Starting from different initial values leads to different convergence. init-final correlation 0.998. 1/3 was initial value bias.**

## Background/Context

1/3 appears repeatedly throughout the project:

```
  Contraction mapping f(x) = 0.7x + 0.1 → Fixed point x* = 1/3
  Meta router contraction coefficient: 0.7 → Convergence target 1/3
  Repulsion field tension_scale initial value: 1/3
  Repulsion field tension_scale learned value: 0.34 (classification, MNIST)
  Generative engine tension_scale learned value: 0.34 (VAE, MNIST)
  Fiber curvature curvature_scale learned value: 1.58 (diverged!)
  Perfect number 6: 1/2 + 1/3 + 1/6 = 1 (1/3 is the middle term)
```

Related hypotheses: 263(Tension Integration), 264(Design Principles), 172(Conservation Laws)

## Convergence Data

| Model | Initial Value | Learned Value | Difference from 1/3 | Dataset |
|---|---|---|---|---|
| RepulsionFieldEngine | 1/3 | 0.34 | +0.007 | MNIST |
| RepulsionFieldQuad | 1/3 | 0.34 | +0.007 | MNIST |
| RepulsionFieldVAE (generative) | 1/3 | 0.34 | +0.003 | MNIST |
| **FiberBundleEngine** | **1/3** | **1.58** | **+1.25** | **MNIST** |

```
  Classification models: 1/3 → 0.34 (fine-tuning, stays near 1/3)
  Generative model: 1/3 → 0.34 (same)
  Fiber:    1/3 → 1.58 (4.7x increase, diverged)

  Why is fiber different?
```

## Hypothesis: 1/3 is the Optimal Coupling Constant for Base Space

```
  Repulsion field:  output = equilibrium + scale × tension × direction

  If scale too large → tension dominates output → unstable
  If scale too small → tension information lost → just averaging
  scale = 1/3 → optimal balance point

  From contraction mapping perspective:
    f(w) = a×w + (1-a)×target, a=0.7
    Fixed point = target/(1-a+a) = 0.1/(1-0.7) = 1/3
    → Balance between contraction and target achieved at 1/3
```

## Meaning of Fiber Divergence

```
  In fiber bundle:
    base output = equilibrium + curvature_scale × fiber_info

  fiber_info is information from a different dimension than base.
  To inject this information into base requires larger scale.

  Interpretation 1: Higher dimensional info is not a "small signal"
    → Must inject strongly to affect base
    → 1/3 insufficient, needs 1.58

  Interpretation 2: Different dimensions require different optimal coupling constants
    → Same dimension coupling: 1/3
    → Cross-dimension coupling: ~5/3 ≈ 1.58?
    → 5/3 = 1 + 2/3 = 1 + 2×(1/3) — variation of 1/3?

  Interpretation 3: Initial value bias
    → Starting from 1/3, classification stays nearby
    → Fiber has different structure, escapes initial value
    → Need experiments with different initial values
```

## Verification Directions

```
  1. Start tension_scale from 0.1, 0.5, 1.0 etc.
     → Does it still converge near 1/3?
  2. Start fiber curvature_scale from 1.0, 2.0
     → Does it converge to 1.58, or other values?
  3. Check tension_scale learned values on CIFAR
     → Same 1/3 as MNIST?
  4. Explore information-theoretic meaning of 1/3
     → Maximum entropy contribution in 3-state system?
  5. Does 5/3 ≈ 1.58 appear in other contexts?
```

## Limitations

```
  1. Only confirmed on MNIST. Need reproduction on other datasets.
  2. Initial value was 1/3, cannot exclude initial value bias.
  3. May vary with hyperparameters like learning rate, epochs.
  4. No mathematical proof for "why 1/3".
```

## Subsequent Discovery: 1/3 via Different Path (C41)

```
  Hypothesis 265 refuted: tension_scale ≈ 1/3 was initial value bias
  But C41 discovered: (T_wrong / T_correct)² ≈ 1/3 (Texas p=0.033)

  Scale(C1-C3): 1/3 → ❌ (initial value bias)
  Ratio(C41):    1/3 → 🟧 (measured, different path)

  Interpretation: Wrong answer's tension energy is exactly 1/3 of correct
  Energy loss: 1 - 1/3 = 2/3 = 1 - 1/3 = P≠NP gap ratio from CLAUDE.md

  1/3 appears not from initial values but from ratios.
  The spirit of Hypothesis 265 may live on — in a different form.
```