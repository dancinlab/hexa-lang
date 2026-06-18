# Hypothesis 277: Feature Quality Threshold — The Boundary Where Architecture Becomes Important
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> **When feature extraction quality is below the threshold, weight structure (architecture) determines performance; above the threshold, data determines performance. {1/2,1/3,1/6} being optimal in MLP and worst in CNN shows this.**

## Background/Context

```
  MLP (weak features):
    Meta fixed {1/2,1/3,1/6}: 53.52% (1st place)
    Uniform {1/4,1/4,1/4,1/4}: lower
    → Weight structure determines performance

  CNN (strong features):
    Meta fixed {1/2,1/3,1/6}: 77.39% (5th place, worst)
    Learned weights: {0.34, 0.35, 0.31} (converge to uniform)
    → Weight structure irrelevant, features determine
```

Related hypotheses: 273(Euclidean triangle, partially refuted), 264(Design principle S3)

## Core Argument

```
  Define feature quality Q:
    Q = (backbone standalone accuracy) / (theoretical maximum)
    MLP: Q = 53%/100% = 0.53 (low)
    CNN: Q = 77%/100% = 0.77 (high)

  Threshold Q* exists:
    Q < Q*: Weight asymmetry advantageous (diversity compensates for insufficient features)
    Q > Q*: Weight uniformity advantageous (if features good, don't interfere)

  Estimate: Q* ∈ (0.53, 0.77) — threshold somewhere in this interval
```

## Connection with Hypothesis 270

```
  Hypothesis 270: Diversity = Information

  Q < Q* (weak features):
    → Lack of feature diversity
    → Weight asymmetry adds artificial diversity
    → Information increase → performance improvement

  Q > Q* (strong features):
    → Features already sufficiently diverse
    → Additional asymmetry = unnecessary constraints = performance drop
    → Uniform = no constraints = optimal
```

## Verification Direction

```
  1. Continuously adjust Q by varying CNN backbone size
     - 1-layer CNN (Q ≈ 0.6?)
     - 2-layer CNN (Q ≈ 0.7?)
     - 3-layer CNN (Q ≈ 0.77)
     → Compare {1/2,1/3,1/6} vs uniform at each Q
     → Identify threshold Q*

  2. Vary MLP hidden_dim
     - hidden=16 (low Q)
     - hidden=64 (medium Q)
     - hidden=256 (high Q)
     → Same threshold pattern?

  3. Confirm on other datasets (Fashion-MNIST, SVHN)

  4. Theoretical prediction: Q* = 1/√3 ≈ 0.577? (connection with C7, C41?)
```

## Limitations

```
  1. Observed with only two points MLP and CNN — cannot specify threshold location.
  2. Definition of Q is arbitrary (other definitions possible).
  3. MLP and CNN differ in many ways besides weight structure (unfair comparison).
  4. More observation than hypothesis — no theory for "why threshold exists".
```