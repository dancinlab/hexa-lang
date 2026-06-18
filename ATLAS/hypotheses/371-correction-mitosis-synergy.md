# Hypothesis 371: Calibration+Mitosis Synergy — Overconfidence Calibration Without Forgetting
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> **Combining H317(overconfidence calibration) and H312(mitosis=forgetting prevention) enables overconfidence calibration without forgetting. Specifically: child_a=freeze(memory storage), child_b=confusion pair focused learning(calibration), router=tension-based delegation → overall maintained + ratio→1.0.**

## Background/Context

Two hypotheses showed strong results independently but have complementary weaknesses:

```
  H317 (Overconfidence Calibration):
    1+7 focus → ratio 0.53→1.06 (calibration success!)
    Cost: overall 98→87% (catastrophic forgetting)

  H312 (Mitosis=Forgetting Prevention):
    child_a=freeze, child_b=train
    Normal 43%(forgetting!) vs Mitosis 99%(preserved!)
    Cost: Calibration impossible (child_a remains overconfident)

  Combined Hypothesis:
    Mitosis + Calibration = Resolve overconfidence without forgetting?
```

## Predictions

```
  Combined System:
    1. Phase 1: General learning 10ep → parent (overconfident state)
    2. Mitosis: child_a = parent(freeze), child_b = parent(trainable)
    3. Phase 2: 1+7 focused learning on child_b 10ep
    4. Router: Input → delegate to child_a or child_b based on tension
       - digit 1,7 related → child_b (calibrated expert)
       - Others → child_a (memory keeper)

  Predicted Results:
    d1_ratio ≈ 1.0 (overconfidence resolved, child_b handles)
    overall ≥ 97% (no forgetting, child_a handles)
    vs Existing:
      1+7 focus only: ratio=1.06, overall=87% (forgetting!)
      Mitosis only: ratio=0.57, overall=98% (not calibrated)
```

## Performance Comparison Predictions (ASCII)

```
  overall(%)
  100 |  * child_a(freeze)      ★ Combined(predicted)
   98 |  *                      ★
   96 |
   94 |
   92 |
   90 |
   88 |
   86 |                    * 1+7focus(forgetting!)
   84 |
      +--+--------+--------+--------+-->
         Base     Mitosis  1+7only Combined
                  only

  d1_ratio (1.0=normal, <1=overconfident)
  1.1 |                    * 1+7    ★ Combined(predicted)
  1.0 |  ──────────────────────────────── Normal line
  0.9 |
  0.8 |
  0.7 |
  0.6 |
  0.5 |  * Base    * Mitosis only
      +--+--------+--------+--------+-->
         Base     Mitosis  1+7only Combined
                  only
```

## Experiment Design

```
  1. Data: MNIST (digit 1 overconfidence confirmed)
  2. Model: RepulsionField 2-pole
  3. Steps:
     a) General learning 10ep → parent
     b) Confirm overconfidence: measure digit 1 ratio
     c) Mitosis: child_a(freeze) + child_b(copy)
     d) 1+7 focused learning on child_b 10ep
     e) Router implementation: tension-based (T>threshold → child_b)
     f) Ensemble evaluation: overall + per-digit + d1_ratio
  4. Control groups:
     - Base (no calibration)
     - 1+7 focus only (H317)
     - Mitosis only (H312)
     - Combined (this hypothesis)
  5. Success criteria: overall ≥ 97% AND d1_ratio ∈ [0.9, 1.1]
```

## Related Hypotheses

- H317: Overconfidence Calibration (calibration success, forgetting occurs)
- H312: Mitosis=Forgetting Prevention (forgetting prevented, calibration impossible)
- H316: Overconfidence 3-set Reproduction (MNIST, Fashion, CIFAR)
- H-CX-24: Dunning-Kruger Timeline (overconfidence emergence→fixation)
- H314: Confidence Rejection→Accuracy↑ (improvement just from rejection)

## Limitations

```
  - MNIST digit 1 overconfidence is a relatively simple case
  - Results may vary depending on router design
  - Overconfidence patterns may differ in Fashion/CIFAR (see H316)
  - Effects of increasing child count (N>2) unknown
```

## Verification Direction

```
  Stage 1: Basic verification with MNIST digit 1
  Stage 2: Reproduction with Fashion-MNIST (shirt/coat overconfidence)
  Stage 3: Generalization to CIFAR (boundary classes)
  Stage 4: Compare router strategies (tension, softmax, oracle)
```

## Status: 🟨 Unverified