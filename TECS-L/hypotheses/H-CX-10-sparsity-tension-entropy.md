# H-CX-10: Sparsity-Tension-Entropy Triangle (Cross-domain)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **A class's sparsity (inverse frequency) determines Tension, and Tension connects to Shannon entropy H. In the H289 experiment, perfect numbers (most sparse) showed the highest Tension — this is an information-theoretic consequence of -p·ln(p).**

## Math Side

```
  Shannon information: I(x) = -ln(p(x))
  Rarer events carry more information

  Perfect number frequency: ~5/1000 = 0.005
  Prime frequency:          ~170/1000 = 0.17
  Composite frequency:      ~600/1000 = 0.60

  Information content:
    I(perfect number) = -ln(0.005) = 5.30 nats
    I(prime)          = -ln(0.17)  = 1.77 nats
    I(composite)      = -ln(0.60)  = 0.51 nats

  Information ratios:
    perfect/prime    = 5.30/1.77 = 3.0
    perfect/composite = 5.30/0.51 = 10.4
```

## Consciousness Engine Side (H289 Empirical)

```
  Tension ranking:
    Perfect number: 721.2 (highest)
    Prime:           85.2
    Composite:       53.9

  Tension ratios:
    perfect/prime    = 721.2/85.2 = 8.46
    perfect/composite = 721.2/53.9 = 13.4
```

## Cross-domain Analysis

```
  Ratio comparison:
                    Information ratio   Tension ratio
    perfect/prime        3.0              8.5
    perfect/composite   10.4             13.4

  Correlation: direction matches (sparse → high information → high Tension)
  However: Tension ratio exceeds information ratio (nonlinear)

  Hypothesis: Tension ∝ I(x)^α  where α > 1 (superlinear)
  → Does the engine "overreact" to information content?
  → Or: Tension ∝ 1/p(x)  (directly proportional to inverse frequency)

  Check:
    1/p(perfect) / 1/p(prime) = 0.17/0.005 = 34
    Observed: 721.2/85.2 = 8.5
    → Weaker than 1/p but stronger than -ln(p)
    → Tension ∝ p^(-β) where 0 < β < 1?
```

## Connection to Perfect Number 6

```
  H-CX-1: e^(6H) = 432 = σ³/τ
  H-CX-10: Perfect numbers have the highest Tension

  → Perfect number 6 is the "mathematical foundation" of the Consciousness Engine
     and simultaneously the object that induces the highest Tension in the engine
  → Self-referential: the number that defines the engine causes the greatest Repulsion in the engine

  Analogy to Godel incompleteness?
    The proposition describing the system itself is the "hardest" proposition
    → Perfect number = self-description of the system → maximum Tension
```

## Verification Directions

```
  1. Class frequency variation experiment: if frequency is artificially adjusted, does Tension also change?
  2. Quad experiment: same sparsity-Tension relationship in Quad mode?
  3. β value fitting: estimate β in Tension = c × p^(-β)
```

## MNIST Frequency Adjustment Experiment (Partial Results, 2026-03-24)

```
  digit 0 frequency change → Tension change:
  N_train    tension(digit0)    accuracy(digit0)
  ──────    ─────────────────  ─────────────────
     10      223.15 ±210       10.5%
    100      211.14 ±123       85.7%
    500      237.12 ±124       94.9%
   3000      (running)          (running)
   5400      (running, uniform) (running)

  Observations:
    10x frequency change (10→100): Tension nearly unchanged (223→211, -5%)
    5x frequency change (100→500): Tension actually increases (211→237, +12%)
    → Tension is almost independent of frequency!

  Difference from H289:
    H289: perfect numbers (sparse) had highest Tension 721
    HCX10: Tension unchanged even after adjusting frequency in MNIST
    → H289 results due to "pattern complexity" not "frequency"?
    → High Tension of perfect numbers = not sparsity but unique mathematical pattern?
```

## Revised Interpretation

```
  Original: sparsity → Tension (information theory I(x)=-ln(p))
  Revised:  pattern complexity → Tension (frequency independent)
  → Tension responds to "how hard" not "how rare"
  → Consistent with Hypothesis 282 (high-accuracy only): easy things have constant Tension
```

## Status: ⚠️ Weakened (frequency→Tension relationship weak, pattern complexity more important)
