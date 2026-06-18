# H-EE-100: NAS Will Independently Discover 4/3 FFN Ratio — FUTURE PREDICTION
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> Large-scale Neural Architecture Search (NAS) at GPT-5 class scale will
> independently discover an FFN expansion ratio near 4/3 as Pareto-optimal
> for compute-efficiency, without any knowledge of n=6 arithmetic.

## Background

- Current standard FFN expansion ratio: 4x (e.g., GPT-2, BERT, LLaMA)
- H-EE-Phi-Bottleneck establishes 4/3 = sigma(6)/tau(6)/phi(6) as the
  theoretically optimal ratio (67% parameter reduction)
- 4/3 has not been identified as Pareto-optimal by any published NAS study

## The Prediction

When NAS is run at sufficient scale (>1B parameter search space, >1000 GPU-days),
optimizing for:
  - Minimize: FLOPs per inference token
  - Subject to: perplexity within 5% of 4x-expansion baseline

The Pareto frontier will contain architectures with FFN ratio in [1.2, 1.5],
with the densest cluster near 4/3 ≈ 1.333.

## Why 4/3 Should Win

At 4x expansion: FFN FLOPs = 2 * d_model * 4 * d_model = 8 * d_model^2
At 4/3 expansion: FFN FLOPs = 2 * d_model * (4/3) * d_model = 8/3 * d_model^2
Reduction: 3x fewer FLOPs in FFN layers.

The 4x ratio is a historical artifact (Vaswani et al. 2017 chose it without
systematic justification). NAS will find that 4/3 achieves equivalent or
better perplexity at 3x lower FFN cost.

## Testability Criteria

- NAS study published by Google, OpenAI, DeepMind, or Meta
- Search includes FFN ratio as a continuous or discrete variable
- Pareto-optimal ratio falls in [1.2, 1.5] for FLOPs-constrained setting
- Publication expected: 2026-2028

## Falsification

If large-scale NAS consistently finds Pareto-optimal FFN ratio > 2.0,
this hypothesis is falsified. A ratio of exactly 4.0 remaining optimal
at all scales would strongly falsify the phi-bottleneck theory.

## Conclusion

**Status: Pre-registered future prediction — testable 2026-2028**
**Prediction:** NAS discovers FFN ratio ~4/3 as Pareto-optimal
**Significance:** Independent rediscovery validates n=6 arithmetic without prior knowledge.
