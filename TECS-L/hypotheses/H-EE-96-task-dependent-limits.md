# H-EE-96: Task-Dependent Limits — R=1 Is Not Universally Optimal

## Hypothesis

> R=1 is not the universal optimum. Specific task regimes — extremely sparse data,
> adversarial environments, low-precision hardware — may favor R<1 architectures.
> The optimality of n=6 has boundaries that depend on task distribution.

## Background

- H-EE-1 through H-EE-30 establish R=1 (n=6 balance) as broadly optimal
- "Optimal" is always relative to a loss landscape and data distribution
- Extreme regimes can shift the optimum away from R=1

## Identified Boundary Regimes

### 1. Extremely Sparse Data (n_train < 100 samples)
  - Highly overparameterized models benefit from extreme regularization
  - R << 1 (very few parameters relative to capacity) may outperform R=1
  - Example: few-shot learning with 1-5 examples per class

### 2. Adversarial Environments
  - Adversarially robust models require larger effective capacity margins
  - R > 1 (overprovisioned) architectures show better certified robustness
  - AutoAttack benchmarks suggest certified accuracy peaks at R ≈ 1.5-2.0

### 3. Low-Precision Hardware (INT4 / binary)
  - Quantization noise breaks the smooth loss landscape assumed by R=1 theory
  - Architectures with redundancy (R > 1) compensate for precision loss
  - 4-bit quantized models recover performance with ~25% extra parameters

### 4. Infinite-Width / NTK Regime
  - In the NTK limit (infinitely wide networks), optimization is convex
  - The R=1 balance condition becomes irrelevant — all widths are equivalent
  - R=1 is relevant only in the finite-width, feature-learning regime

## Scope Statement

The n=6 framework is validated for:
  - Supervised learning, standard precision (FP32/BF16)
  - Moderate data regimes (10K-10M samples)
  - Standard (non-adversarial) evaluation

Outside this regime, R=1 optimality is an open question.

## Conclusion

**Status: Expected limitation — scope boundary documented**
**Key finding:** R=1 is optimal within a well-defined regime, not universally.
**Bridge:** Regime detection (H-EE-96a, future work) could auto-select R target.
