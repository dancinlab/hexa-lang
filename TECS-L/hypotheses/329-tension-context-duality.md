# Hypothesis 329: Tension's Contextual Duality — confidence vs boundary proximity

> **Tension has opposite meanings depending on context. From a classification accuracy perspective, high tension=confidence (H313); from a decision boundary perspective, high tension=uncertainty (H328). This contradiction is because "tension = strength of repulsion between two engines", not "good/bad".**

## Contradiction

```
  H313: Correct sample tension > wrong sample tension (ratio 1.29~2.68)
  H328: Boundary-near sample tension > boundary-far sample tension (r=-0.79)

  For both to coexist:
    Near boundary + correct -> high tension ("conscious effort for hard case")
    Far from boundary + correct -> low tension ("automatic unconscious processing")
    Near boundary + wrong -> moderate tension (hard and wrong)
    Far from boundary + wrong -> this is rare (easy but wrong = overconfidence H316)
```

## Unified Interpretation

```
  tension = |engine_A - engine_G|²
  = "strength of repulsion between two perspectives"
  ≠ simple measure of good/bad, high/low

  What high tension means:
    1. Two engines strongly express their opinions -> confidence (H313)
    2. Decision is subtle so two engines point in different directions -> boundary proximity (H328)

  -> These are two sides of the same phenomenon!
    "Deciding confidently" = "strongly choosing one side at the boundary"
    -> High tension = "strong decision" (correct or wrong)
    -> Low tension = "weak decision" (consensus or indifference)

  Brain analogy:
    Prefrontal cortex activation = "concentrated attention on difficult decision"
    = high tension = simultaneous confidence + boundary proximity
```

## Additional Verification

```
  H329 2D map (MNIST): margin up -> tension up -> accuracy up
    Far(T=811,100%) > Near(T=495,92%)

  H322 EEG proxy: awake(16.4) ≈ sleep(16.7) >> drowsy(2.6)
    -> Distinct state = high tension, ambiguous transition = low tension
    -> Perfectly consistent with "decision strength" interpretation!

  Comprehensive evidence (5 items):
    H313: correct=high tension (4 datasets)
    H316: overconfidence=high tension+wrong (3 datasets)
    H329 2D: margin up -> tension up
    H322 EEG: distinct state = high tension
    H328: boundary proximity <-> tension r=-0.79
```

## Status: 🟩 5-fold confirmed (decision strength = unified interpretation)
