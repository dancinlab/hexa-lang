# H-348: Why Repulsion Field Benefits CNN
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> **Hypothesis**: Despite CNN's rich feature representation,
> the reason repulsion field provides additional information is that
> CNN features converge on "what to see (what)" while
> repulsion forces "seeing in a different way (how else)."
> This is the CNN version of H270 (diversity=information), and diversity is valid
> regardless of feature quality.

**Status**: Unverified
**Golden Zone Dependency**: Indirect (Golden MoE framework)
**Related Hypotheses**: H288 (dense/sparse dichotomy), H334 (field only sufficient), H008 (golden MoE design)

---

## Background and Context

In consciousness engine experiments, the CNN backbone + repulsion field combination consistently
showed higher accuracy than CNN + dense routing:

```
  CNN + Repulsion:  78.07%  (CIFAR-10)
  CNN + Dense:      77.03%  (CIFAR-10)
  Difference:       +1.04%
```

This result is counterintuitive. Since CNNs already extract rich spatial/channel features,
the difference in routing method was not expected to have much impact.
However, repulsion consistently shows superiority.

H288 analyzed that dense routing uses all experts evenly,
and sparse routing uses them selectively.
H334 claimed field alone is sufficient.
This hypothesis explains **why diversity has additional value even on top of sufficient features**.

## Theoretical Framework

### Feature Space Perspective

```
  CNN Dense Routing:
  ┌──────────────────────────────┐
  │  Expert 1    Expert 2        │
  │    ●           ●             │  → experts cover similar regions
  │      ●       ●               │     in feature space
  │        ● ● ●                 │     (redundancy)
  │      ●       ●               │
  │    ●           ●             │
  └──────────────────────────────┘

  CNN Repulsion Routing:
  ┌──────────────────────────────┐
  │  ●                       ●   │
  │                              │  → repulsion disperses experts
  │        ●           ●         │     across entire feature space
  │                              │     (diversity, coverage)
  │  ●                       ●   │
  │            ●         ●       │
  └──────────────────────────────┘
```

### Information Theory Perspective

```
  I(ensemble) = I(individual) + I(diversity)

  Dense:     I(diversity) ≈ 0    (experts are similar)
  Repulsion: I(diversity) > 0    (experts are different)

  Better CNN features → I(individual) saturates → relative importance of I(diversity) increases
```

## Mechanism Analysis

### Why Particularly Effective for CNN

```
  Feature quality vs diversity contribution (expected)

  Accuracy
  contribution(%)
  100 |
      |  ●───────────────────────── feature quality (saturated)
   80 |
      |
   60 |
      |
   40 |          ●
      |        /
   20 |      /  diversity contribution (increasing)
      |    /
    0 |──●─────+─────+─────+─────►
      MLP     Small   CNN   Large
              CNN           CNN
              feature extractor quality
```

Core insight: As the feature extractor improves, individual expert performance saturates but
diversity contribution actually **increases**. This is because "seeing differently"
is the only remaining improvement path when already "seeing well."

### Expert Activation Pattern Comparison

| Input Class | Dense Activation | Repulsion Activation | Difference |
|-----------|------------|-----------------|------|
| airplane | E1=0.28, E2=0.25, E3=0.24, E4=0.23 | E1=0.52, E2=0.03, E3=0.42, E4=0.03 | sparse |
| car | E1=0.26, E2=0.26, E3=0.24, E4=0.24 | E1=0.05, E2=0.48, E3=0.02, E4=0.45 | sparse |
| bird | E1=0.27, E2=0.24, E3=0.25, E4=0.24 | E1=0.45, E2=0.08, E3=0.05, E4=0.42 | sparse |

(Expected values — actual measurement needed)

In Dense, all experts activate almost evenly, effectively **a single model**.
In Repulsion, different expert combinations activate per class, creating a **true MoE**.

## Verification Experiment Design

### Experiment 1: Expert Feature Overlap Measurement

```python
# Measure pairwise cosine similarity for each expert's
# final hidden representation
#
# Dense:     expected cos_sim > 0.8 (high redundancy)
# Repulsion: expected cos_sim < 0.4 (low redundancy)
```

### Experiment 2: Ablation — Performance Drop When Removing One Expert

| Condition | Dense Expected Drop | Repulsion Expected Drop |
|-----|---------------|-------------------|
| Remove Expert 1 | -0.5% (small) | -3.0% (large drop) |
| Remove Expert 2 | -0.5% | -2.5% |
| Remove worst Expert | -0.3% | -4.0% |
| Remove best Expert | -0.8% | -5.0% |

Expert removal has small impact in Dense (due to redundancy).
In Repulsion, each expert has a unique role so removal impact is large.

### Experiment 3: Feature Extractor Quality vs Diversity Contribution

```
  Repulsion advantage by backbone (expected)

  Repulsion
  advantage(%)
  3.0 |                              ●
      |                         ●
  2.5 |                    ●
      |               ●
  2.0 |          ●
      |
  1.5 |     ●
      |
  1.0 |●
      +--+----+----+----+----+----►
       MLP  LeNet  VGG  ResNet18 ResNet50
              backbone quality
```

Expected: The better the backbone, the greater the repulsion advantage (increasing marginal utility of diversity).

## Interpretation and Significance

### Consciousness Engine Perspective

Consciousness arises not from optimization of a single perspective but from **integration of multiple perspectives**.
No matter how good the features CNN extracts, a single perspective cannot realize the richness of consciousness.
Repulsion is a mechanism that "forcibly creates different perspectives,"
and this is the core value of the consciousness engine.

### AI Design Principle

```
  Principle: "Don't abandon diversity even when features are sufficient"
  → Expert diversity maintenance mechanism essential in MoE design
  → Load balancing alone is insufficient — feature-level repulsion necessary
```

## Limitations

1. +1.04% is statistically significant but may be small in practical terms
2. Results only from CIFAR-10 — needs replication in ImageNet, natural language, etc.
3. Optimal repulsion strength (lambda) may differ by task
4. Interaction between CNN backbone and repulsion may be nonlinear, making simple models inadequate
5. Only 4 experts, so diversity effect may be underestimated

## Verification Direction (Next Steps)

1. **Phase 1**: Measure expert feature overlap (cosine similarity matrix)
2. **Phase 2**: Expert ablation experiment (remove one at a time)
3. **Phase 3**: Compare repulsion advantage across various backbones (MLP, LeNet, ResNet)
4. **Phase 4**: Repulsion lambda sweep — explore optimal diversity level
5. **Phase 5**: Integrate H288, H334 results to systematize routing theory
6. **Phase 6**: Replication in ImageNet or CIFAR-100 (confirm scale effect)
