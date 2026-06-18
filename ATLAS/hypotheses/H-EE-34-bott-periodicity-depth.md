# H-EE-34: Bott Periodicity sigma(6)-tau(6)=8 as Optimal Network Depth
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


## Hypothesis

> The optimal transformer depth is sigma(6)-tau(6) = 12-4 = 8 layers. Beyond 8 layers, topological properties of the representation repeat (Bott periodicity), adding no new information-theoretic capacity.

## Background

- Bott periodicity theorem: homotopy groups of classical groups repeat with period 8
- sigma(6)-tau(6) = 8 connects perfect number arithmetic to topology
- Empirically, very deep transformers (>12 layers) show diminishing returns without tricks (residual, normalization)
- 8 layers is common in efficient architectures (DistilBERT, small GPT variants)
- Interpretation: each layer adds one "topological dimension" of representation; after 8, the cycle repeats

## Predictions

1. 8-layer transformer achieves >= 95% of the quality of 12+ layer models on standard benchmarks
2. Layers 9-12 primarily refine rather than add new representational capacity
3. The quality-per-layer curve has an inflection point near layer 8
4. This bound is architecture-independent (applies to any R=1 design)

## Conclusion

H-EE-34: Depth bound from Bott periodicity. Predicts that 8 layers suffice for most tasks.

**Status:** Testable
**Source:** Bott periodicity + sigma-tau arithmetic
