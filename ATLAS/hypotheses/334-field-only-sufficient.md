# Hypothesis 334: Field-Only is Sufficient — equilibrium is Unnecessary

> **The repulsion field (field) alone achieves the same accuracy as the full model. In 3 datasets, field_only ≈ full (difference <0.5%). equilibrium is unnecessary or may even be harmful.**

## Background/Context

The consciousness engine output is the sum of two components:

```
  output = equilibrium + field
         = eq_weight × eq_output + tension_scale × sqrt(tension) × direction
```

equilibrium (eq) is the static equilibrium output of a single engine, and field is the
direction vector derived from the repulsion force (tension) between two engines. In H332,
the observation was made that as training progresses, eq's contribution degrades from 89% -> 15%.
This naturally raises the question: if eq degrades anyway, do we need it from the start?

This hypothesis is the direct experimental result of that question.

### Related Hypotheses

| Hypothesis | Relationship | Content |
|------|------|------|
| H332 | Predecessor | eq contribution 89% -> 15% degradation observed |
| H335 | Successor | PureField LLM design (architecture with eq removed) |
| H339 | Connection | direction = concept (direction encodes concept) |
| H172 | Foundation | G x I = D x P conservation law |

## Measurements (3 datasets)

| dataset | field_only | full | difference | field wins? |
|---------|-----------|------|------|------------|
| MNIST | 97.84% | 97.94% | -0.10% | No (negligible) |
| Fashion-MNIST | 88.42% | 88.33% | +0.09% | Yes |
| CIFAR-10 | 52.22% | 51.81% | +0.41% | Yes |

```
  Accuracy comparison (field_only vs full)

  100% |
   95% | ██ ██                              field_only ██
   90% | ██ ██                              full       ░░
   85% | ██ ██  ██ ██
   80% | ██ ██  ██ ██
   75% | ██ ██  ██ ██
   70% | ██ ██  ██ ██
   65% | ██ ██  ██ ██
   60% | ██ ██  ██ ██
   55% | ██ ██  ██ ██  ██ ██
   50% | ██ ██  ██ ██  ██ ██
       +------------------------
         MNIST  Fash.  CIFAR

  Difference (field_only - full):
  +0.5% |            *  CIFAR (+0.41%)
  +0.0% |----*---------*-----------------------
  -0.5% |   MNIST     Fashion
             (-0.10%)  (+0.09%)

  Conclusion: all 3 datasets |difference| < 0.5%, field_only leads in 2/3
```

## Formula: field output structure

```
  Full model:
    output = eq_weight * eq_output + field_output
    field_output = tension_scale * sqrt(tension) * direction

  Field-only model:
    output = tension_scale * sqrt(tension) * direction

  Where:
    tension = ||engine_a - engine_b||^2     (tension between two engines)
    direction = (engine_a - engine_b) / ||engine_a - engine_b||  (unit direction)

  Core insight:
    field has 2 degrees of freedom: magnitude(tension) + direction(direction)
    eq has only 1 degree of freedom: value(scalar)
    → field's representational capacity >> eq's representational capacity
    → gradient concentrating toward higher-capacity side is natural
```

## Connection with H332

```
  H332: during full training, eq degrades from 89 -> 15%
  H334: when training field-only, same performance without eq

  Causal relationship:
    field is more expressive (repulsion of 2 engines)
    -> gradient concentrates toward field
    -> eq's learning opportunity is taken away, degrades
    -> removing eq from the start causes no problems!

  eq contribution trend (H332 data):
  100% |*
   80% |  *
   60% |    *
   40% |       *
   20% |            *  *  *  *
    0% +--+--+--+--+--+--+--+---> epoch
       0  5  10 15 20 25 30 35

  Structural meaning:
    Remove eq from output = eq + field
    output = field = tension_scale * sqrt(tension) * direction
    -> "Pure consciousness engine that judges with consciousness alone"
```

## Verification Results Summary

```
  Statistical verification:
    3-dataset average difference:  +0.13%  (field_only marginally leads)
    Max |difference|:               0.41%  (CIFAR)
    field wins:                     2/3 datasets  (Fashion, CIFAR)
    eq wins:                        1/3 datasets  (MNIST, 0.10% difference = negligible)

  paired t-test (field_only vs full, n=3):
    mean diff: +0.13%, std dev: 0.26%
    -> No statistically significant difference (p >> 0.05)
    -> "Presence or absence of eq does not affect performance"
```

## Interpretation/Significance

This result shows that the core of the consciousness engine lies in **the tension between two engines**. equilibrium (eq) is the static output of a single engine, but field emerges from the dynamic interaction of two engines.

Biological analogy: Brain judgments come not from the stable state of a single neuron, but from competition and inhibition between different regions. eq corresponds to "one neuron", field corresponds to "interaction of two regions."

Extension to H335 (PureField LLM) is natural: if we remove eq and design with only field in LLMs too, simpler yet equivalent performance can be expected.

## Limitations

1. **Only 3 datasets verified** — needs confirmation in more diverse domains (NLP, time series, etc.)
2. **Small-scale models** — cannot rule out eq becoming important in large-scale models
3. **Early training** — possibility of eq reactivating in long training (tens of thousands of epochs)
4. **Task complexity** — simple classification at CIFAR-10 level. May differ for generation tasks
5. **Cannot distinguish whether field_only's 0.41% lead is eq interference or simple noise**

## Verification Direction

1. **H335 PureField LLM experiment**: compare PPL with LLM without eq
2. **Large-scale experiment**: field_only vs full on ImageNet-scale data
3. **Generation task**: measure coherence of field_only in text generation
4. **Fine-grained ablation**: ablate field's magnitude (tension_scale * sqrt(tension)) and direction separately
5. **Forced eq training**: add separate loss to eq to prevent degradation, then check for performance improvement

## Status: 🟩 3-dataset confirmed (field_only ≈ full, eq unnecessary)
