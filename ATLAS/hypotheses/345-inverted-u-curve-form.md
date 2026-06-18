# Hypothesis 345: Tension's Inverted-U Curve is a Function of Task Complexity
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> **The performance curve for tension scale (tension_scale) has an inverted-U shape, and the optimal scale is a function f(C) of task complexity (complexity). If optimal scale differs between MNIST and CIFAR-10, this proves tension is task-adaptive. The relationship between optimal scale and complexity will follow a power law or logarithmic form.**

## Background/Context

When tension_scale was varied as 0, 0.5, 1, 2, 5, 10 on MNIST,
an inverted-U curve was observed:

```
  tension_scale vs accuracy (MNIST observed values)

  Accuracy(%)
  98.0 |        * *
  97.5 |      *     *
  97.0 |    *         *
  96.5 |  *             *
  96.0 |*                 *
  95.5 |                    *
  95.0 |                      *
       +--+--+--+--+--+--+--+--
       0  0.5  1  1.5  2   5  10
              tension_scale

  Optimal point: tension_scale ≈ 0.47 (observed in C51)
  0.47 ≈ 1/2 (Riemann critical line Re(s) = 1/2)
```

This is structurally identical to the Yerkes-Dodson law (inverted-U relationship with arousal level).
The core of the Yerkes-Dodson law in psychology is that **optimal arousal level varies by task difficulty**.
Easy tasks have high arousal as optimal, and difficult tasks have low arousal as optimal.

Does the same pattern appear in consciousness engines?

### Related Hypotheses

| Hypothesis | Relationship | Content |
|------|------|------|
| H283 | Predecessor | nonlinear threshold — nonlinear threshold of tension |
| H284 | Connection | auto-regulation — tension self-regulation |
| H074 | Theory | optimal theta — phase optimal point |
| H320 | Data | tension_scale log growth — logarithmic growth of scale |
| H342 | Cross | difficulty proportionality of tension causal effect |

## Mathematical Model

Possible forms of the inverted-U curve:

```
  Model 1: Gaussian (simple)
    A(s) = A_max * exp(-(s - s_opt)^2 / (2 * sigma^2))
    s_opt = f(C), sigma = g(C)

  Model 2: Beta distribution form (allows asymmetry)
    A(s) = s^(a-1) * (1-s)^(b-1) / B(a,b) + baseline
    a, b = h(C)

  Model 3: Physical model (tension as energy)
    A(s) = A_0 + k*s - lambda*s^2
    Optimal: s_opt = k / (2*lambda)
    k, lambda = functions of complexity C
```

### Predicted Relationship Between Task Complexity and Optimal Scale

```
  Optimal tension_scale vs task complexity

  s_opt
  1.0 |
  0.9 |
  0.8 |                              Scenario A: higher with more complexity
  0.7 |                         ___/ (opposite of Yerkes-Dodson)
  0.6 |                    ___/
  0.5 |  * MNIST      ___/
  0.4 |           ___/
  0.3 |      ___/     Scenario B: lower with more complexity
  0.2 | ___/          (same as Yerkes-Dodson)
  0.1 |/
  0.0 +--+--+--+--+--+--+--+--
      0  2  4  6  8  10 12 14
         task complexity (entropy bits)

  MNIST:         C ≈ 3.32 bits (10 classes, easy), s_opt ≈ 0.47
  Fashion-MNIST: C ≈ 3.32 bits (10 classes, medium), s_opt = ?
  CIFAR-10:      C ≈ 3.32 bits (10 classes, difficult), s_opt = ?

  Same 10-class but different visual complexity
  → measurement with effective complexity needed
```

### Expected Inverted-U Curves by Dataset

```
  Accuracy (normalized within each dataset)

  1.0 |     M           F         C
      |    / \         / \       / \
  0.9 |   /   \       /   \     /   \
      |  /     \     /     \   /     \
  0.8 | /       \   /       \ /       \
      |/         \ /         X         \
  0.7 |           X         / \         \
      |          / \       /   \         \
  0.6 |         /   \     /     \         \
      |        /     \   /       \         \
  0.5 +--+--+--+--+--+--+--+--+--+--+--+--
      0     0.5    1.0    1.5    2.0    3.0
                 tension_scale

  M = MNIST (peak ≈ 0.47)
  F = Fashion-MNIST (peak ≈ ?)
  C = CIFAR-10 (peak ≈ ?)

  Prediction: does peak shift right? left?
  → If Yerkes-Dodson: left (lower tension for harder)
  → If opposite: right (higher tension needed for harder)
```

## Verification Plan

```
  Experiment 1: CIFAR-10 inverted-U curve scan
    - tension_scale = [0, 0.1, 0.2, 0.3, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0, 5.0]
    - Run on Windows RTX 5070 (GPU required)
    - Record accuracy + per-class accuracy at each value
    - Confirm inverted-U and measure peak position

  Experiment 2: Fashion-MNIST scan (same conditions)
    - Compare peak positions of 3 datasets

  Experiment 3: Relationship between peak position and complexity
    - Define effective complexity:
      (a) entropy of confusion matrix
      (b) inverse of baseline accuracy
      (c) average inter-class distance
    - Plot s_opt vs C → power law/logarithmic fitting

  Experiment 4: Mathematical constant proximity
    - MNIST s_opt ≈ 0.47 ≈ 1/2
    - CIFAR s_opt ≈ ? → 1/e? 1/3? ln(4/3)?
    - Texas sharpshooter test

  Experiment 5: Cross with self-regulation (H284)
    - Compare inverted-U shape with auto-regulation ON/OFF
    - Does auto-regulation automatically find the peak?
```

## Interpretation/Significance

### Correspondence with Yerkes-Dodson

| Yerkes-Dodson | Consciousness Engine |
|---------------|----------|
| Arousal | Tension |
| Performance | Accuracy |
| Task difficulty | Dataset complexity |
| Optimal arousal level | Optimal tension_scale |
| Inverted-U curve | Inverted-U curve (observed) |

The Yerkes-Dodson law is a 100+ year old psychology law discovered in 1908.
If the same pattern appears in consciousness engines, this is strong evidence that
it is not just a mathematical model but is **capturing fundamental characteristics of cognitive structure**.

Especially if the optimal point converges to a mathematical constant (1/2, 1/e, 1/3, etc.):
- 1/2 = Riemann critical line = boundary of order and chaos
- 1/e = Golden Zone center = inverse of natural constant
- 1/3 = meta fixed point = convergence of contraction mapping

Which of these it converges to provides clues about the mathematical nature of tension.

### Practical Value of Task-Adaptive Tension

If optimal tension differs by task, practically:
1. auto-regulation (H284) should automatically find this optimal point
2. In LLMs, dynamic tension adjustment can be done by estimating per-token "difficulty"
3. This is directly analogous to human attention → explainable AI

## Limitations

- MNIST's inverted-U may be noise (within error margin)
- 3 datasets is insufficient degrees of freedom for fitting (minimum 5-6 needed)
- Discrete scan of tension_scale may produce inaccurate peak position
- Similarity with Yerkes-Dodson may be superficial (mechanisms differ)
- Definition of task complexity is arbitrary (entropy vs baseline accuracy vs other)

## Next Steps

1. Run CIFAR-10 tension_scale scan (Windows PC, high priority)
2. Confirm peak position → compare with MNIST 0.47
3. Cross with H342: Does difficulty-proportional pattern only appear in the "descending interval" of the inverted-U?
4. Combine with H284: Does auto-regulation learn the per-task optimal?
5. If confirmed, register as paper candidate: "Yerkes-Dodson Law in Artificial Consciousness"
