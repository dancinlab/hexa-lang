# Hypothesis 303: Does Anomaly Tension Fall Within the Golden Zone?
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **If the center of the tension distribution for normal data falls within the Golden Zone (0.21~0.50) and anomaly data tension lies outside the Golden Zone, then Golden Zone = "normal energy range". Anomaly detection = "detecting deviation from the Golden Zone".**

## Golden Zone Review

```
  Golden Zone (CLAUDE.md):
    Upper bound = 1/2 = 0.5000 (Riemann critical line)
    Lower bound = 1/2 - ln(4/3) ≈ 0.2123
    Center ≈ 1/e ≈ 0.3679
    Width = ln(4/3) ≈ 0.2877
```

## Hypothesis

```
  Normalized tension: T_norm = T / T_max

  Prediction:
    Normal data: T_norm ∈ [0.21, 0.50] (within Golden Zone)
    Anomaly data: T_norm > 0.50 or T_norm < 0.21 (outside Golden Zone)

  H287 measured:
    Normal mean tension: 2.34
    Anomaly mean tension: 222.79
    Ratio: 222.79/2.34 = 95.2x

    T_norm(normal) = 2.34/222.79 = 0.0105
    T_norm(anomaly) = 222.79/222.79 = 1.0

    -> Normal is below Golden Zone, anomaly is above Golden Zone
    -> Normal is "below the edge of chaos" (stable)
    -> Anomaly is in "chaos" region (unstable)

  Re-normalization needed:
    Can we redefine T_norm to fit the Golden Zone?
    T_renorm = T / (T + T_scale) -> 0~1 range
    T_scale = T_parent/e ≈ expected normal tension

  Or:
    T_rank = CDF(T) -> rank-based normalization
    Normal CDF center ≈ 1/e? (Golden Zone center)
```

## Verification Experiment

```
  1. Extract tension distribution of all test samples after MNIST classification training
  2. Separate normal (correct) / anomaly (wrong)
  3. Normalize tension in various ways:
     a) min-max: T_norm = (T - T_min)/(T_max - T_min)
     b) CDF: T_rank = percentile(T)
     c) sigmoid: T_sig = 1/(1 + exp(-T/T_scale))
  4. Does the normal center fall in the Golden Zone (0.21~0.50) for each normalization?
  5. Is the anomaly center outside the Golden Zone?
```

## If Confirmed

```
  Golden Zone = "stable region" of consciousness
  -> Normal cognition: tension oscillates within Golden Zone
  -> Anomaly detection: tension deviates from Golden Zone
  -> Arousal (surprise): tension exceeds Golden Zone upper bound (1/2)
  -> Sleep: tension falls below Golden Zone lower bound (0.21)

  Langton λ_c = 0.27 ≈ Golden Zone lower bound
  -> "Consciousness" operates at the edge of chaos
  -> Normal = just inside the edge
  -> Anomaly = beyond the edge into chaos
```

## Status: 🟨 Untested (Golden Zone-dependent hypothesis, CLAUDE.md warning applies)
