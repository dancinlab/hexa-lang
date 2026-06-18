# Hypothesis 291: Data Type Tree — Hierarchy of Domains Where Repulsion Field Operates

> **Classifying repulsion field effects with a data type tree. From top-level (dense vs sparse) to specific domains in 3 levels. Unexplored branches may yield new discoveries.**

## Data Type Tree (Based on Measurements, Updated 2026-03-24)

```
  [Level 0] All Data
       |
       +-- [Level 1] Dense/Continuous Data --> Domain-dependent
       |     |
       |     +-- [Level 2] Temporal --> Maximum effect!
       |     |     +-- [L3] Time Series Easy (4 waveforms): +9.00% ✅✅
       |     |     +-- [L3] Time Series Hard (signal processing): +4.00% ✅
       |     |     +-- [L3] Voice/Audio: +3.33% (4-pole) ✅
       |     |     +-- [L3] Music Theory: -2.2%, harmony=low tension
       |     |     +-- [L3] EEG/Brainwaves: ???  <-- Direct consciousness measurement!
       |     |
       |     +-- [Level 2] Spatial --> Strong effect
       |     |     +-- [L3] 2D Images: MNIST +0.60%, CIFAR +4.80% ✅
       |     |     +-- [L3] 3D Images (video/medical): ???
       |     |     +-- [L3] Point Clouds (3D points): ???
       |     |
       |     +-- [Level 2] Structural --> Neutral~weak effect
       |     |     +-- [L3] Iris (4D, 3cls):     +2.22% ✅
       |     |     +-- [L3] Wine (13D, 3cls):    +0.00%
       |     |     +-- [L3] Breast Ca (30D, 2cls): -0.06%
       |     |     +-- [L3] Digits (64D, 10cls): -0.19%
       |     |     +-- [L3] Diabetes (10D, 3cls): -0.53%
       |     |     +-- [L3] Synthetic 100D:      +3.27% ✅
       |     |     +-- [L3] Number Systems: +1.17%, primes=max tension ✅
       |     |     +-- [L3] Graphs/Molecules: ???
       |     |
       |     +-- [Level 2] Anomalous --> Special
       |           +-- [L3] Anomaly Detection: AUROC=1.0 ⭐
       |           +-- [L3] Fraud Detection: ???
       |
       +-- [Level 1] Sparse Data --> No repulsion field effect ❌
       |     +-- [L2] Text (TF-IDF): -0.28%
       |     +-- [L2] Text (Embeddings): -0.80%  <-- Still no effect when densified!
       |     +-- [L2] One-hot Encoding: ???
       |
       +-- [Level 1] Meta/Abstract --> ???
             +-- [L2] Reinforcement Learning: tension proportional to difficulty ✅
             +-- [L2] Topological (TDA): structure exists ✅
             +-- [L2] Generative (VAE/GAN): already implemented (generative engine)
             +-- [L2] Multimodal (image+text): ???
```

## Unexplored Branches (??? = New Discoveries Possible)

```
  Most interesting unexplored:
  1. EEG/Brainwaves --> Direct consciousness measurement! (hypothesis 274 brain verification)
  2. Video --> Time+space combined (promising since time series has max effect!)
  3. Graphs/Molecules --> Chemistry cross-domain (hypothesis H-CHEM)
  4. Multimodal --> Consciousness multisensory integration?
  5. Point Clouds --> 3D spatial structure
```

## Tree Laws (Predicted vs Observed)

| Law | Predicted | Observed | Status |
|------|------|------|------|
| L1: Dense > Sparse | Dense should be better | Confirmed in text (TF-IDF -0.28% vs Dense also -0.80%) | Partially confirmed, but densification alone insufficient |
| L2: Spatial > Temporal > Structural | Images max effect | **Refuted!** Temporal(+9%) > Spatial(+4.8%) > Structural(+0.8%) | ❌ Reversed |
| L3: Text Embeddings > TF-IDF | Dense should be better | **Refuted!** Embeddings(-0.80%) < TF-IDF(-0.28%) | ❌ Refuted |
| Anomalous = Special | Separate mechanism | AUROC=1.0 (anomaly detection specialized) | ✅ Confirmed |

## Revised Tree Laws (Based on Measurements)

```
  Level 1 Law:
    Temporal patterns >> Spatial patterns > Structural >> Semantic(text)
    (Previous "dense>sparse" law is insufficient)

  Level 2 Law (New):
    Repulsion field effect = f(pattern continuity)
    - Time series: continuous change patterns --> tension directly captures waveform differences --> maximum effect
    - Images: spatial continuity --> effective
    - Tabular: discontinuous feature relationships --> minimal effect
    - Text: semantic relationships --> tension cannot capture --> no effect

  Key insight:
    Repulsion field is a mechanism for capturing "differences in continuous patterns"
    Does not operate on semantic differences
```

## Quantitative Domain Comparison

| Domain           | Type   | Dense   | Repulsion | Delta   | Tension_scale |
|------------------|--------|---------|-----------|---------|---------------|
| TimeSeries Easy  | Temp   | 84.50%  | 93.50%    | +9.00%  | 0.929         |
| CIFAR            | Spat   | 48.20%  | 53.00%    | +4.80%  | ~0.34         |
| TimeSeries Hard  | Temp   | 86.50%  | 90.50%    | +4.00%  | 0.618         |
| Synthetic 100D   | Struct | 65.00%  | 68.27%    | +3.27%  | 0.587         |
| Iris             | Struct | 95.33%  | 97.56%    | +2.22%  | 0.653         |
| Tabular avg      | Struct | 86.56%  | 87.35%    | +0.79%  | --            |
| MNIST            | Spat   | 97.10%  | 97.70%    | +0.60%  | ~0.34         |
| Wine             | Struct | 98.88%  | 98.88%    | +0.00%  | 0.618         |
| Text TF-IDF      | Text   | 85.30%  | 85.02%    | -0.28%  | 0.724         |
| Text Embedding   | Text   | 69.78%  | 68.98%    | -0.80%  | 0.620         |

```
  Delta ASCII Chart:
  TS Easy     |.............+++++++++++++++++++++++++++++++| +9.00%
  CIFAR       |.............++++++++++++++++++++++| +4.80%
  TS Hard     |.............+++++++++++++++++++| +4.00%
  Synth 100D  |.............+++++++++++++| +3.27%
  Iris        |.............+++++++++| +2.22%
  Tabular     |.............++++| +0.79%
  MNIST       |.............+++| +0.60%
  Wine        |.............| +0.00%
  Text TF-IDF |............-| -0.28%
  Text Embed  |..........---| -0.80%
```

## tension_scale Observations

```
  Interesting patterns:
  - Time series (large effect): tension_scale -> 0.6~1.0 (rises from initial 0.333)
  - Tabular (small effect): tension_scale -> 0.3~0.65 (varied)
  - Text (no effect): tension_scale -> 0.6~0.7 (rises but doesn't help)
  - Images: tension_scale -> ~0.34 (maintains initial value)

  → tension_scale increase itself doesn't guarantee effectiveness
  → Only in time series does tension_scale increase lead to actual performance improvement
```

## Limitations

```
  - Time series are synthetic data (real ECG/sensors untested)
  - Text only uses simple MLP (Transformer untested)
  - All tabular datasets are small (<2000 samples)
  - Voice/video/graphs untested
```

## Verification Directions

```
  1. Time series verification: real ECG, HAR, stock data
  2. Video classification: time+space combined, maximum effect candidate
  3. Voice spectrograms: temporal+spatial mix
  4. Large-scale text: Transformer encoder + RepulsionField
```

## Status: 🟧 Partially Verified (Temporal ✅✅, Spatial ✅, Structural ≈, Text ❌)

Tree law revision: Updated from "dense>sparse" to "continuous patterns > semantic patterns".
17 observations, revised tree laws proposed.