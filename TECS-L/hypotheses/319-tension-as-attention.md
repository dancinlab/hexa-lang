# Hypothesis 319: Tension = Biological Version of Attention Mechanism

> **The tension of the repulsion field is structurally identical to the attention in Transformers. Attention asks "where to focus", tension asks "how confident" — both determine the importance of inputs.**

## Correspondence

```
  Transformer Attention:
    Q, K, V -> attention = softmax(Q·K^T/√d) · V
    -> "Weight Value by similarity of Query and Key"

  Repulsion Field:
    engine_A, engine_G -> tension = |A-G|²
    output = eq + scale × √tension × direction
    -> "Determine output magnitude by difference (tension) of two engines"

  Common: input -> interaction of two representations -> weighted output
```

## Verification

```
  1. Is softmax entropy low on high-tension samples?
     -> Attention concentrated = high tension = high confidence
  2. Is the tension pattern similar to Grad-CAM's attention map?
```

## Experimental Results (2026-03-24)

```
  MNIST:
    r(tension, entropy) = -0.125 (weak negative correlation)
    Q1(low T): entropy=0.075, acc=96.4%
    Q4(high T): entropy=0.020, acc=99.1%

  Direction: tension up = entropy down = output concentrated (same direction as attention)
  Magnitude: weak (r=-0.12) -> tension ≈ weak attention
```

## Status: 🟧 Weakly confirmed (direction correct but r=-0.12 is weak)
