# H-EE-108: Finite-Size Effect — n=6 Benefits May Vanish at Scale

## Hypothesis

> The n=6 efficiency benefits are real but finite-size phenomena. They exist
> at ~100K parameter scale and may vanish at 1B+ parameters. This is the
> strongest version of H-EE-98 and the most critical open risk in the framework.

## Relationship to H-EE-98

H-EE-98 identified scale dependence as a concern. H-EE-108 sharpens this:
not merely "unvalidated at large scale" but specifically predicts that
the benefits are finite-size artifacts with a characteristic cutoff scale.

## The Finite-Size Effect Mechanism

In statistical physics, finite-size effects are systematic deviations from
bulk behavior that appear only in small systems. They disappear as N -> inf.

Analogy to neural networks:
  - Small networks: R=1 balance controls most of the representational geometry
  - Large networks: Attention patterns, residual stream, layer norm dominate
  - At sufficient scale: R=1 signal is overwhelmed by other structural factors

## Scale at Which Effects Should Vanish (Estimated)

If n=6 benefits come from parameter count ratios (sigma/tau balance):
  - At 100K params: 4/3 FFN ratio saves 50K params — significant
  - At 100B params: 4/3 FFN ratio saves 50B params — also significant in absolute terms
  - BUT: at 100B params, other bottlenecks (attention, compute, data) dominate
  - Efficiency gains may become unmeasurable against noise floor

## Three Versions of This Hypothesis

### Weak: Benefits diminish but persist
  R=1 architectures are always better, but the margin shrinks from 5% to 0.1%
  at 1B+ scale — statistically real but practically irrelevant.

### Moderate: Benefits disappear at a threshold
  There exists N* ~ 100M params above which R=1 provides no measurable benefit.
  Below N*: significant advantage. Above N*: no advantage.

### Strong: Large models perform WORSE with R=1 constraints
  Forcing R=1 at large scale may artificially constrain capacity that larger
  models need for performance. The "balance" may be a bottleneck at scale.

## Current Evidence

  All validated models: < 500K parameters
  Gap to claimed universality: 3-6 orders of magnitude
  Models where n=6 architecture is claimed to help: none at > 500K params

## What Would Resolve This

  1. Train a 100M parameter baseline vs R=1-constrained model on same data
  2. Measure perplexity, downstream task accuracy, efficiency
  3. If margin > 1%: finite-size hypothesis weakened
  4. If margin < 0.1%: finite-size hypothesis strengthened
  5. Repeat at 1B params

## Conclusion

**Status: Critical open risk — no large-scale evidence exists**
**Stronger than H-EE-98:** Predicts benefits are specifically finite-size artifacts
**Resolution requires:** Phase 4 experiments at 100M+ parameter scale
**Risk level:** If confirmed, limits framework to small-model applications only

*Written: 2026-03-28*
