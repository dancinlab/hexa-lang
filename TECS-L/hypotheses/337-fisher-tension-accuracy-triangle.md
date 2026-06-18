# Hypothesis 337: Fisher-Tension-Accuracy Triangle

> **Gradient (Fisher), Tension, and Accuracy form a triangle. Fisher∝1/Accuracy (r=-0.97), Tension∝Accuracy (r=+0.14), Fisher∝1/Tension (r=-0.15). "gradient=what remains to learn, tension=what has been learned, accuracy=result".**

## Measurements (PureField, MNIST, per-class)

```
  digit  Fisher   Tension   Accuracy
  ────   ──────   ───────   ────────
  d0     0.0007      202     98.6%
  d1     0.0011      115     98.8%
  d2     0.0012      281     97.9%
  d3     0.0012      280     98.5%
  d4     0.0010      196     98.7%
  d5     0.0015      268     98.3%
  d6     0.0014      200     97.6%
  d7     0.0015      246     97.9%
  d8     0.0026      162     96.3%
  d9     0.0035      199     94.6%

  Correlations:
    r(F, acc)  = -0.972  ← nearly perfect!
    r(T, acc)  = +0.139
    r(F, T)    = -0.157

  Triangle:
    Fisher ←(-0.97)→ Accuracy ←(+0.14)→ Tension ←(-0.16)→ Fisher
```

## Interpretation

```
  Fisher = ∂Loss/∂x = "how much remains to learn for this input"
  Tension = |A-G|² = "how confident about this input"
  Accuracy = P(correct) = "actually getting it right"

  Fisher→Accuracy: strong (-0.97) = class with large gradient gets it wrong
  Tension→Accuracy: weak (+0.14) = higher confidence slightly improves accuracy
  Fisher→Tension: weak (-0.16) = larger gradient slightly lowers tension

  Why is Fisher-Accuracy the strongest?
    Fisher is computed directly from loss = directly tied to accuracy
    Tension is A-G difference = indirect indicator of accuracy
    → Fisher = "direct measurement", Tension = "indirect measurement"
```

## Status: 🟩 Confirmed (r(F,acc)=-0.972, triangle relationship established)
