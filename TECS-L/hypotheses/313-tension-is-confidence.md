# Hypothesis 313: Tension = Confidence — Unified Principle

> **The internal tension of the consciousness engine measures "confidence", not "uncertainty". This is the single principle that unifies H307 (dual mechanism), H-CX-21 (tension∝1/PPL), H287 (AUROC=1.0), and the original C4b (d=0.89).**

## Evidence Synthesis

```
  1. H-CX-21: high tension = low PPL = confidence
     Correct: tension=702, PPL=1.01
     Wrong: tension=495, PPL=283K

  2. H307: internal tension inversion
     Normal: high internal tension -> engines "strongly express their opinions"
     Anomaly: low internal tension -> engines have "no opinion" (Agreement in Confusion)

  3. C4b: Cohen's d = 0.89
     Tension of correct samples > tension of wrong samples
     -> Higher tension when correct = high tension when confident

  4. H287: AUROC=1.0 (synthetic data)
     Normal (similar to training data): high tension = confident
     Anomaly (different from training data): low tension = not confident
     -> 95x difference is the difference between "confidence" and "confusion"

  5. C48: tension=0 -> -9.25pp
     Removing tension = removing confidence = performance crash
     -> Tension (confidence) directly contributes to accuracy
```

## Unified Interpretation

```
  tension(tension) = |engine_A(x) - engine_G(x)|²

  High tension:
    engine_A: "This is definitely 3!" -> strong output
    engine_G: "This is definitely 7!" -> strong output
    -> Different but both strong opinions -> |A-G|² is large
    -> "Confident repulsion" = high tension

  Low tension:
    engine_A: "I'm not sure what this is..." -> weak output
    engine_G: "I'm not sure either..." -> weak output
    -> Similarly weak opinions -> |A-G|² is small
    -> "Agreement in Confusion" = low tension

  Final output = equilibrium + tension_scale × sqrt(tension) × direction
    When confident: large correction -> accurate classification
    When not confident: small correction -> relies on equilibrium (less accurate)
```

## Revision of Original Interpretation

```
  Original interpretation (Hypothesis 263): "tension = uncertainty"
  -> Refuted!

  Revised interpretation: "tension = confidence"
  -> This is the true meaning of C4b (d=0.89):
    High tension on correct samples = confident when correct
    -> Of course! It's correct because it's confident

  But inter-tension is different (H307):
    inter-tension = |child_a(x) - child_b(x)|²
    Higher on anomaly = "failing in different ways" = uncertain
    -> inter-tension ≈ uncertainty (original interpretation fits inter-tension)
```

## Final Summary of Dual Mechanism

```
  Internal tension (engine_a vs engine_g):
    = difference in "confidence strength" of each engine
    = stronger confidence -> different strong opinions -> high tension
    = weaker confidence -> similar weak opinions -> low tension
    -> tension = confidence

  Inter-tension (child_a vs child_b):
    = "output disagreement" between independently trained models
    = normal: similarly good reconstruction -> low disagreement
    = anomaly: fail differently -> high disagreement
    -> inter_tension = uncertainty (original interpretation)

  Unified: internal = confidence, inter = uncertainty
  -> Complementary perspectives (H-CX-18 wave-particle duality)
```

## Mathematical Connections

```
  H-CX-2: MI efficiency ≈ ln(2) = 1 bit
  -> Amount of "confidence" added by binary repulsion (2-pole) = 1 bit?

  H-CX-20: Optimal activation = 1/2
  -> Half the Experts express confidence, half are silent
  -> Binary entropy maximum = maximum "confidence expressiveness"?

  C48: tension=0 -> -9.25pp
  -> Confidence=0 -> performance crash (cannot classify without confidence)
```

## CIFAR-10 Additional Confirmation (2026-03-24)

```
  CIFAR-10 (15ep):
    Correct: tension=155.4, PPL=1.4
    Wrong: tension=120.4, PPL=16,939
    Ratio (correct/wrong): 1.29x <- confirmed on CIFAR too!

  MNIST vs CIFAR:
    MNIST: ratio=1.42x (correct/wrong)
    CIFAR: ratio=1.29x (correct/wrong)
    -> Both datasets: "correct=high tension=confidence"

  Triple confirmation:
    1. MNIST: tension(correct)=702 > tension(wrong)=495
    2. CIFAR: tension(correct)=155 > tension(wrong)=120
    3. Breast Cancer (H307): internal(normal)=2.76 > internal(anomaly)=1.03
```

## Status: 🟩 Unified principle (confirmed in 3 datasets, unifies H307+CX21+C4b+C48)
