# H-349: Axis Reversal Transition Point During Training
**n6 Grade: 🟩 EXACT** (auto-graded, 15 unique n=6 constants)


> **Hypothesis**: In early training, the "what" axis dominates with C/S > 1, but
> as training progresses, it transitions to the "how" axis, reversing to C/S < 1.
> This transition epoch is a function of task difficulty,
> and for easy tasks (MNIST), the transition doesn't occur or occurs very quickly.

**Status**: Unverified
**Golden Zone Dependency**: Indirect (consciousness engine framework)
**Related Hypotheses**: H339 (direction=concept), H281 (temporal causation), H129 (phase transition)

---

## Background and Context

In CIFAR-10 experiments, inversion of the content/style ratio (C/S ratio) was observed during training:

```
  CIFAR-10 observed data:
    Epoch  1:  C/S = 1.05  (content dominant)
    Epoch  7:  C/S = 0.82  (in transition)
    Epoch 14:  C/S = 0.55  (style dominant)
```

This suggests that in early training the model first grasps "what is there" (content/what),
and after sufficiently grasping that, transitions to "how to express it" (style/how).

H339 claimed that axis direction encodes concept,
H281 observed temporal causation structure.
Combined with H129's phase transition theory,
C/S inversion may be a **learning phase transition**.

## Theoretical Model

### Two-Phase Learning Theory

```
  Phase 1: Content Learning (what)
  ─────────────────────────────────
  - Grasp semantic content of input
  - Form class boundaries
  - C/S > 1 (content axis explains more variance)
  - Gradient concentrates in content direction

  Phase 2: Style Refinement (how)
  ─────────────────────────────────
  - Learn variations within same class
  - Optimize expression method
  - C/S < 1 (style axis explains more variance)
  - Gradient distributes in style direction
```

### Transition Point Model

```
  C/S(t) = C_0 * exp(-alpha * t) + S_inf * (1 - exp(-beta * t))

  Transition epoch T* = (1/(alpha-beta)) * ln(alpha*C_0 / (beta*S_inf))

  Where:
    C_0    = initial content contribution (>1)
    S_inf  = final style contribution
    alpha  = content decrease rate
    beta   = style increase rate
    T*     = transition point where C/S = 1
```

## Expected Transition Curves

### CIFAR-10 (Observed + Predicted)

```
  C/S Ratio
  1.20 |
       |●
  1.10 |  ●
       |    ●
  1.00 |------●------------------------------------------  C/S = 1 (transition line)
       |        ●
  0.90 |          ●
       |            ●
  0.80 |              ●●
       |                  ●●
  0.70 |                      ●●●
       |                           ●●●●
  0.60 |                                ●●●●●
       |                                      ●●●●●●●●●
  0.50 |
       +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--►
       1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
                              epoch

  Transition point T* ≈ epoch 4-5 (CIFAR-10)
```

### MNIST Prediction (Unobserved)

```
  C/S Ratio
  1.20 |
       |●
  1.10 |●
       |●
  1.00 |--●----------------------------------------------  C/S = 1
       |   ●●●
  0.90 |       ●●●●●●
       |              ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
  0.80 |
       +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--►
       1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
                              epoch

  Expected: T* ≈ epoch 1-2 (very fast, task is easy)
  Or: transition may not occur at all (content alone sufficient)
```

## Transition Point Predictions by Difficulty

| Task | Difficulty | Expected T* | Final C/S | Basis |
|-----|--------|---------|----------|------|
| MNIST | Very easy | 1-2 epochs or none | 0.85-0.95 | Simple forms, content solved immediately |
| Fashion-MNIST | Easy | 2-3 epochs | 0.75-0.85 | Some similar-shape classes |
| CIFAR-10 | Medium | 4-5 epochs (observed) | 0.55 (observed) | Natural images, diverse variations |
| CIFAR-100 | Difficult | 8-12 epochs | 0.40-0.50 | Fine-grained classification needed |
| ImageNet | Very difficult | 20-30 epochs | 0.30-0.40 | 1000 classes, extreme diversity |

## Relationship Between Transition Point and Accuracy

```
  Accuracy(%)
  100 |                                          ●────── MNIST
      |                                    ●──── F-MNIST
   90 |                              ●────────── observed  CIFAR-10
      |
   80 |         Phase 1         │  Phase 2
      |      (content/what)     │  (style/how)
   70 |                         │
      |    rapid accuracy rise  │  gradual accuracy rise
   60 |         ●               │
      |       /                 │
   50 |     /                   │
      |   /                     │
   40 | /                       │
      |/                        │
   30 +---+---+---+---+---+---+---+---+---+---►
      1   2   3   4   5   6   7   8   9   10
                   epoch
                          T* (transition point)
```

Hypothesis: **The point where accuracy growth rate drops sharply ≈ C/S transition point T***

## Verification Experiment Design

### Experiment 1: Multi-dataset C/S Tracking

```
  Measure C/S ratio every epoch for each dataset:
    - MNIST (28x28, 10 classes)
    - Fashion-MNIST (28x28, 10 classes)
    - CIFAR-10 (32x32, 10 classes)
    - CIFAR-100 (32x32, 100 classes)

  Measurement method:
    1. Apply PCA to expert hidden representations
    2. Classify top PCs as content/style (by class label correlation)
    3. Content PC variance / Style PC variance = C/S ratio
```

### Experiment 2: Artificially Controlling Difficulty

```
  Control difficulty by adding label noise to CIFAR-10:
    - noise 0%:   original (T* ≈ 4-5)
    - noise 10%:  slightly harder (T* ≈ 6-7 expected)
    - noise 20%:  medium hard (T* ≈ 8-10 expected)
    - noise 40%:  very hard (T* ≈ 12+ expected)

  → Is relationship between T* and noise rate linear or nonlinear?
```

### Experiment 3: Learning Rate Effect

| Learning Rate | Expected T* | Expected Final C/S | Basis |
|-------|---------|-------------|------|
| 0.001 | 8-10 | 0.50 | Slow learning, late transition |
| 0.01 | 4-5 | 0.55 | Default setting (observed) |
| 0.1 | 2-3 | 0.60 | Fast learning, early transition |

## Interpretation and Significance

### Cognitive Science Analogues

```
  Human learning:
    1. Category learning (what): "this is a dog, that is a cat"
    2. Detail learning (how): "this breed has these features"

  Child language development:
    1. Vocabulary explosion (what): word meaning acquisition
    2. Grammar development (how): refinement of expression

  → C/S transition is a universal learning strategy from "what" to "how"?
```

### Consciousness Engine Design Implications

If transition point T* can be detected:
- Apply content-centered learning rate in Phase 1
- Apply style-centered learning rate in Phase 2
- **Adaptive curriculum** becomes possible

### Connection with H129 Phase Transition

The phase transition predicted in H129 may be concretized as C/S inversion.
If discontinuous changes in expert activation patterns, gradient distribution, etc.
are observed at C/S = 1, it is a true phase transition.

## Limitations

1. C/S ratio definition is PCA-based, may miss nonlinear structures
2. Some tasks where content/style separation is not obvious (e.g., abstract reasoning)
3. Model fitting unstable with only 14-epoch observation data from CIFAR-10
4. May be sensitive to hyperparameters like learning rate, batch size, optimizer
5. If transition point is gradual rather than sharp, definition of T* itself becomes ambiguous

## Verification Direction (Next Steps)

1. **Phase 1**: Measure per-epoch C/S ratio for MNIST, Fashion-MNIST
2. **Phase 2**: Compare with CIFAR-10 results, quantify difficulty-T* relationship
3. **Phase 3**: Confirm artificial difficulty manipulation effect with label noise experiment
4. **Phase 4**: Analyze gradient distribution/expert activation patterns at T*
5. **Phase 5**: Integrate with H339, H281, H129 results → learning phase transition theory
6. **Phase 6**: Adaptive learning rate experiment — performance improvement with strategy change before/after T*?
