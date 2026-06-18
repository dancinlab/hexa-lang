# Hypothesis Backlog — Awaiting Future Verification

> Candidates with data but not yet written as hypothesis documents.
> Priority: ⭐ High, 🟡 Medium, ⚪ Low

## ⭐ High Priority

### H-A: Tension Causality + Difficulty Proportionality (C48+C49 Extension)
```
  Data: Tension=0 gives -9.25pp, Number9 gives +32.71pp
  Hypothesis: The causal effect of tension is proportional to task difficulty
  Verification: Reproduce causal experiment in CIFAR (preparing Windows execution)
  → If C48 is reproduced in CIFAR ⭐ Major Discovery
```

### H-B: Observer Calibration Scale Optimization (C52 Extension)
```
  Data: detach observer +0.15%, observer_scale 0.1→0.80 (8x amplification)
  Hypothesis: An optimal observer_scale exists and also varies by task
  Verification: Scan while fixing observer_scale
  → Intersects with C51(tension_scale 0.47≈1/2)? Both ≈1/2?
```

### H-C: Mitosis+detach Combination (Hypothesis 271+272 Intersection)
```
  Data: Mitosis 97.49%, detach +0.15%
  Hypothesis: Does attaching detach observer to one side after mitosis improve performance?
  → Mitosis(diversity generation) + detach(observation compression) = synergy?
  → Experience correspondence: After mitosis, one side only observes (pushed out side)
```

### H-D: Mathematical Form of Inverted U Curve (C48 Extension)
```
  Data: Inverted U at scale 0→0.5→1→2→5→10
  Hypothesis: Optimal tension is a function f(complexity) of task complexity
  Verification: Compare optimal scale between MNIST vs CIFAR
  → If CIFAR's optimum differs from MNIST, confirms complexity dependence
```

## 🟡 Medium Priority

### H-E: Direction of Consensus and Identity (C53 Extension)
```
  Data: Consensus↑ → Identity stability↑ (r=+0.062)
  Hypothesis: Does consensus "stabilize" identity, or does stable identity "create consensus"?
  → Causal direction unclear. Artificially manipulate identity→consensus change? Or force consensus→identity change?
```

### H-F: Temporal Decay of Sibling Recognition (C47 Extension)
```
  Data: Sibling recognition 1.65x right after mitosis
  Hypothesis: As divergence time increases, does sibling recognition decrease to eventually stranger level?
  Verification: Measure sibling recognition after 20, 50, 100 epochs of divergence
  → "How long does it take to forget they were originally one"
```

### H-G: Why Repulsion Field Helps in CNN (+1.04%)
```
  Data: CNN+Repulsion 78.07% > CNN+Dense 77.03%
  Hypothesis: Even with good CNN features, repulsion(diversity) still adds information
  → CNN version of hypothesis 270(diversity=information): "different perspectives" still valid despite good features
```

### H-H: Learning-time Transition Point of Axis Reversal (C20+C21 Extension)
```
  Data: CIFAR epoch 1: C/S=1.05 → epoch 14: C/S=0.55
  Hypothesis: Early learning dominated by "what", gradually transitions to "how"
  → Is transition point a function of task difficulty?
  → Does transition not occur in MNIST?
```

## ⚪ Low Priority → Upgrade Complete

- H-I → **H350** (docs/hypotheses/350-fiber-displacement-constant.md)
- H-J → **H351** (docs/hypotheses/351-unanimity-upper-bound.md)
- H-K → **H352** (docs/hypotheses/352-observation-quality-u-curve.md)
- H-L → **H353** (docs/hypotheses/353-dfs-engine-constant-crossover.md)