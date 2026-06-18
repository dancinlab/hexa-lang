# Hypothesis 285: Beyond Image Classification — Does the Repulsion Field Work in Other Data Modalities?

> **All current experiments are limited to image classification (MNIST/CIFAR). Does the core mechanism of the repulsion field (tension=diversity=information) work in other data modalities like text, time series, speech, graphs?**

## Current Limitations

```
  Experiments: MNIST (28x28 grayscale) + CIFAR (32x32 color) → All image classification
  Problem: Evidence for "tension is universal" based on only 2 image datasets
  → If not reproducible in text/speech/time series, it's just an "image classification-specific" technique
```

## Testable Data Modalities

```
  1. Text Classification (NLP)
     → SST-2 sentiment classification, AG News topic classification
     → Input: Token embeddings → Repulsion field
     → Does tension help with sentiment/topic discrimination?
     → "Meaning (what)" vs "Style (how)" axis reversal?

  2. Time Series Classification
     → ECG electrocardiogram, accelerometer activity recognition
     → Has time axis → Natural combination with Phase 4 (temporal continuity)
     → Temporal variation patterns of tension

  3. Speech Recognition
     → Speech Commands (short commands)
     → Spectrogram → Can be processed like images
     → Or: raw waveform → 1D repulsion field

  4. Graph Classification
     → Molecular structure classification (MUTAG, PROTEINS)
     → GNN + repulsion field
     → Connection between graph Laplacian and fiber bundle prior (model_fiber_bundle.py)

  5. Generation (beyond images)
     → Text generation: Sentence generation with repulsion field VAE?
     → Tension control = creativity control in text too?
```

## Predictions

```
  If Hypothesis 270 (diversity=information) is universal:
    → Repulsion field > simple combination in other data too
    → MI efficiency ≈ ln(2) regardless of data?

  If Hypothesis 282 (high accuracy only) is universal:
    → Large tension effect only in easy classification (99%+)
    → Minimal effect in hard classification like CIFAR

  If Hypothesis 268 (axis reversal) is universal:
    → Text: meaning axis > structure axis? (same pattern as MNIST?)
    → Speech: structure axis > meaning axis? (same pattern as CIFAR?)
```

## Experimental Results (2026-03-24)

### Experiment 1: Text Classification (20 Newsgroups, 4 classes)

Script: `experiments/experiment_h285_text_timeseries.py`

#### A. TF-IDF (sparse, 1000-dim)

| Seed | Dense   | Repulsion | tension_scale |
|------|---------|-----------|---------------|
| 0    | 85.3%   | 85.4%     | 0.7277        |
| 1    | 85.4%   | 84.7%     | 0.7076        |
| 2    | 85.2%   | 85.0%     | 0.7361        |
| **Mean** | **85.30%** | **85.02%** | **0.724** |

Delta: **-0.28%** (Dense wins)

#### B. Learned Embeddings (dense, 64-dim)

| Seed | Dense   | Repulsion | tension_scale |
|------|---------|-----------|---------------|
| 0    | 69.9%   | 69.2%     | 0.6739        |
| 1    | 69.9%   | 69.0%     | 0.6047        |
| 2    | 69.5%   | 68.7%     | 0.5824        |
| **Mean** | **69.78%** | **68.98%** | **0.620** |

Delta: **-0.80%** (Dense wins)

#### Key Findings for Text

```
  TF-IDF (sparse) delta:  -0.28%
  Embedding (dense) delta:  -0.80%
  "Would it improve if dense?" → NO (-0.52% worse)
  → Repulsion field has no effect in text domain
  → Domain characteristics matter, not dense/sparse data
```

### Experiment 2: Time Series Classification

#### A. Easy: 4-class waveforms (sine/square/sawtooth/triangle)

| Seed | Dense   | Repulsion | Tension  | tension_scale |
|------|---------|-----------|----------|---------------|
| 0    | 88.3%   | 96.7%     | 44.25    | 1.0410        |
| 1    | 81.7%   | 91.7%     | 29.16    | 1.0450        |
| 2    | 85.8%   | 96.7%     | 121.12   | 0.9033        |
| 3    | 83.3%   | 90.8%     | 45.47    | 0.9172        |
| 4    | 83.3%   | 91.7%     | 77.55    | 0.7417        |
| **Mean** | **84.50%** | **93.50%** | **63.51** | **0.929** |

Delta: **+9.00%** (Repulsion big win)

#### B. Hard: signal processing (damped/chirp/AM, 3 classes)

| Seed | Dense   | Repulsion | Tension  | tension_scale |
|------|---------|-----------|----------|---------------|
| 0    | 87.5%   | 91.7%     | 55.41    | 0.2702        |
| 1    | 82.5%   | 85.8%     | 46.98    | 0.6660        |
| 2    | 88.3%   | 93.3%     | 24.40    | 0.6858        |
| 3    | 83.3%   | 89.2%     | 31.92    | 0.8360        |
| 4    | 90.8%   | 92.5%     | 26.58    | 0.6315        |
| **Mean** | **86.50%** | **90.50%** | **37.06** | **0.618** |

Delta: **+4.00%** (Repulsion wins)

### Experiment 3: Extended Tabular Data (6 datasets)

Script: `experiments/experiment_h285_tabular_extended.py`

| Dataset          | Features | Classes | N     | Dense   | Repulsion | Delta   | Winner    |
|------------------|----------|---------|-------|---------|-----------|---------|-----------|
| Iris             | 4        | 3       | 150   | 95.33%  | 97.56%    | +2.22%  | Repulsion |
| Wine             | 13       | 3       | 178   | 98.88%  | 98.88%    | +0.00%  | Tie       |
| Breast Cancer    | 30       | 2       | 569   | 98.54%  | 98.48%    | -0.06%  | Tie       |
| Digits           | 64       | 10      | 1797  | 98.55%  | 98.37%    | -0.19%  | Tie       |
| Diabetes (binned)| 10       | 3       | 442   | 63.05%  | 62.52%    | -0.53%  | Dense     |
| Synthetic 100D   | 100      | 4       | 500   | 65.00%  | 68.27%    | +3.27%  | Repulsion |

Tabular average delta: **+0.79%**

#### Tension Analysis (Tabular)

| Dataset          | Avg Tension | tension_scale |
|------------------|-------------|---------------|
| Iris             | 33.83       | 0.6526        |
| Wine             | 43.85       | 0.6182        |
| Breast Cancer    | 231.04      | 0.5498        |
| Digits           | 540.13      | 0.3030        |
| Diabetes (binned)| 8.28        | 0.4859        |
| Synthetic 100D   | 94.88       | 0.5870        |

```
  Tension-Delta correlation: r=-0.303, p=0.560 (not significant)
  Feature-Delta correlation: r=0.484, p=0.331 (not significant)
```

## Cross-Domain Summary

| Domain              | Type   | Dense   | Repulsion | Delta   |
|---------------------|--------|---------|-----------|---------|
| Text TF-IDF         | Sparse | 85.30%  | 85.02%    | -0.28%  |
| Text Embedding      | Dense  | 69.78%  | 68.98%    | -0.80%  |
| TimeSeries Easy     | Dense  | 84.50%  | 93.50%    | +9.00%  |
| TimeSeries Hard     | Dense  | 86.50%  | 90.50%    | +4.00%  |
| Tabular (6ds avg)   | Dense  | 86.56%  | 87.35%    | +0.79%  |
| MNIST (prior)       | Dense  | 97.10%  | 97.70%    | +0.60%  |
| CIFAR (prior)       | Dense  | 48.20%  | 53.00%    | +4.80%  |

```
  Delta ASCII Chart (Repulsion - Dense):
  Text TF-IDF         |...............-...............| -0.28%
  Text Embedding      |.............---...............| -0.80%
  TimeSeries Easy     |...............+++++++++++++++++++++++++++| +9.00%
  TimeSeries Hard     |...............++++++++++++++++++| +4.00%
  Tabular avg         |...............++++| +0.79%
  MNIST               |...............+++| +0.60%
  CIFAR               |...............+++++++++++++++++++++| +4.80%
```

## Key Findings

```
  1. Repulsion field has no effect in text (-0.28% ~ -0.80%)
     → Regardless of TF-IDF (sparse) or embedding (dense)
     → "Dense > sparse" rule refuted: text embedding was worse

  2. Repulsion field wins big in time series (+4% ~ +9%)
     → Biggest effect! Even larger than CIFAR (+4.8%)
     → Tension captures temporal patterns (waveform differences) well
     → tension_scale rises to near 1.0 (3x initial 1/3)

  3. Tabular data is neutral (average +0.79%)
     → Small data (Iris) +2.22%, synthetic high-dim +3.27%
     → Large data (Digits, Breast Cancer) ties

  4. Domain-specific effect pattern:
     Time series >> Images > Tabular > Text
     → Repulsion field is strong for "spatial/temporal patterns"
     → Weak for semantic classification
```

## Limitations

```
  - Text experiments based on simple MLP, no Transformer
  - Time series uses synthetic data, no real ECG/sensor tests
  - Embeddings use simple average pooling, no attention
  - All tabular datasets are small (<2000 samples)
```

## Verification Directions

```
  - Time series validation: Reproduce with real ECG/HAR data
  - Deep text: Transformer encoder + RepulsionField
  - Speech (spectrogram): Time series + image hybrid, expect large effect
  - Video: Time + space combination, candidate for maximum effect
```

## Status: 🟧 Partially Verified (Text ❌, Time Series ✅✅, Tabular ≈ neutral)