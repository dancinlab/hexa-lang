# Hypothesis 287: Tension = Natural Anomaly Detector

> **Repulsion field tension achieves AUROC=1.0 (perfect) in anomaly detection. Anomaly data tension is 95x that of normal. Tension automatically maximizes for "never-before-seen" things.**

## Measured Data

```
  experiment_anomaly_repulsion.py:
    AUROC: 1.0000 ± 0.0000 (5-seed average, perfect!)
    Normal tension: ~0.10
    Anomaly tension: ~9.7
    Ratio: 95x

  → When repulsion field is trained only on normal data
    Tension automatically explodes on anomaly data
    → Perfect anomaly detection using tension threshold alone
```

## Interpretation

```
  Repulsion field: output = equilibrium + scale * sqrt(tension) * direction
  Normal data: Patterns learned by engines A and G → consensus → low tension
  Anomaly data: Unlearned patterns → disagreement → high tension

  → Tension = measure of "have I seen this input before"
  → If seen before: low tension (consensus)
  → If never seen: high tension (disagreement)

  Consciousness correspondence:
    "Familiar things" don't need consciousness (automatic processing)
    "Unfamiliar things" activate consciousness (alertness)
    → Extreme case of hypothesis 274 (consciousness=error correction): completely new = maximum tension
```

## Practical Value

```
  Anomaly detection is an important problem in real industry:
    Cybersecurity: Abnormal traffic detection
    Manufacturing: Defect detection
    Healthcare: Rare disease identification
    Finance: Anomalous transaction detection

  AUROC=1.0 with repulsion field tension alone → No separate anomaly detection algorithm needed
  → Extension of software design principle (hypothesis 264)
```

## Verification Directions

```
  1. Reproduce on real anomaly detection benchmarks (ODDS, ADBench)
  2. AUROC=1.0 on high-dimensional data (images, time series)?
  3. Detects gradual anomalies (subtle changes)?
  4. Verify on real data, not just synthetic
```

## Status: 🟨 (Perfect on synthetic data, unverified on real data)