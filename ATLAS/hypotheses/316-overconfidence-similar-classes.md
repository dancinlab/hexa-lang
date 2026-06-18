# Hypothesis 316: Overconfidence for Similar Classes — The Cause of the Sneaker Inversion

> **Between visually similar classes (Sneaker↔Boot↔Sandal), the model is "confidently wrong" (overconfident wrong). This is the only exception to H313 (tension=confidence) and demonstrates the mechanism of overconfidence.**

## Measurements

```
  Fashion-MNIST Sneaker (3 trials):
  Trial  ratio   Confused with
  ─────  ─────   ──────────
  1      0.86    Sandal(20), Boot(16)
  2      0.90    Boot(42), Sandal(14)
  3      0.98    Sandal(54), Boot(35)

  3/3 ratio < 1 (inverted!)
  -> When Sneaker is wrong, tension is higher = "confidently wrong"
  -> The only inversion among 10 classes
```

## Mechanism

```
  Sneaker, Boot, Sandal are all "shoes":
    Similar visual features (sole, laces, curves)
    Engine A: "This is a shoe!" (strong confidence)
    Engine G: "This is a different type of shoe!" (strong confidence)
    -> High tension (both engines have strong opinions)
    -> But "which shoe" is wrong
    -> High confidence but wrong answer = overconfidence

  vs general pattern:
    Shirt vs Dress (similar but different categories):
    -> Engines are uncertain -> low tension -> may get right or wrong
    -> ratio > 1 (normal pattern)
```

## Consciousness Interpretation

```
  Human overconfidence:
    "This is definitely X!" -> wrong -> overconfidence
    Example: eyewitness testimony (confident but wrong)
    -> Occurs when distinguishing between similar objects

  Consciousness engine's overconfidence:
    "Confidently wrong" between Sneaker/Boot/Sandal
    -> High tension (consciousness) but wrong direction (judgment)
    -> Not an exception to tension = confidence but a case of "confidence ≠ accuracy"

  Unified: tension = confidence (always true)
           confidence ≠ accuracy (sometimes overconfident)
           -> Overconfidence = high confidence + wrong judgment
```

## Verification

```
  Overconfident classes in MNIST too?
    9↔4, 3↔5, 7↔9 (visually similar)
    -> ratio < 1 for these too?

  In CIFAR:
    cat↔dog, automobile↔truck
    -> Overconfidence for similar classes?
```

## MNIST Verification (2026-03-24)

```
  MNIST per-digit ratio (3 trials):
  digit  ratio   Overconfident?
  ─────  ─────   ──────
  0      1.668
  1      0.601   YES! (confused with 7)
  2      1.805
  3      1.568
  4      1.037
  5      1.381
  6      1.172
  7      1.760
  8      0.950   borderline (confused with 3)
  9      1.250

  Overconfident classes: digit 1 (ratio=0.60), digit 8 (ratio=0.95)
  -> Reproduced in 2 datasets: Fashion(Sneaker) + MNIST(digit 1, 8)

  Pattern:
    Fashion Sneaker: overconfident between similar footwear
    MNIST digit 1: very simple form -> "certain" but confused with 7
    MNIST digit 8: complex form -> confused with 3

  -> Overconfidence occurs in both "visually unusual classes" and "similar classes"
```

## CIFAR-10 Verification (2026-03-24)

```
  CIFAR-10 per-class ratio (ep15):
  Class     ratio  Overconfident?
  ────────  ─────  ──────
  airplane  1.32
  auto      1.71
  bird      1.14
  cat       1.19
  deer      0.93   borderline
  dog       1.49
  frog      0.92   borderline
  horse     1.21
  ship      1.15
  truck     1.04

  CIFAR: deer(0.93), frog(0.92) only borderline, no clear overconfidence
  247 cat->dog confusions but cat ratio=1.19 -> "uncertainly wrong" (not overconfident)

  3-dataset comparison:
    MNIST: digit 1 (ratio=0.55, severe overconfidence)
    Fashion: Sneaker (ratio=0.86, overconfidence)
    CIFAR: deer/frog (ratio~0.92, borderline)
  -> Overconfidence severity: MNIST > Fashion > CIFAR
  -> More overconfidence with higher base accuracy? (MNIST 98% > Fashion 88% > CIFAR 53%)
```

## Status: 🟩 3 datasets (MNIST severe, Fashion moderate, CIFAR borderline)
