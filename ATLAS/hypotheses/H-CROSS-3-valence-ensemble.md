# H-CROSS-3: Totient Valence Cascade Predicts Optimal Ensemble Size
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


> **Hypothesis**: The totient valence cascade v(φ)=σ/τ, v(τ)=τ, v(σ)=n
> at n=6 predicts that ensemble models with 3 sub-models (=σ/τ=v(φ)) achieve
> self-referential error correction, where each model's uncertainty is bounded
> by 1/τ of the ensemble variance.

## Background

Totient valence v(k) = |{n : φ(n)=k}| counts how many integers have totient k.
For n=6: v maps {φ,τ,σ} = {2,4,12} to {3,4,6} = {σ/τ, τ, n}.

```
  v(φ(6)=2) = 3 = σ/τ   ← number of integers with same "symmetry" as P₁
  v(τ(6)=4) = 4 = τ      ← SELF-REFERENTIAL (fixed point!)
  v(σ(6)=12) = 6 = n     ← includes P₂=28 among solutions!

  Solutions of φ(x)=2: {3, 4, 6}
  Solutions of φ(x)=4: {5, 8, 10, 12}
  Solutions of φ(x)=12: {13, 21, 26, 28, 36, 42}
```

## Mapping to ML

The totient valence measures "degeneracy" — how many different structures share
the same symmetry count. In ML:

- v(φ)=3: an ensemble of 3 models suffices to cover the symmetry class
- v(τ)=τ: the number of attention heads equals its own degeneracy (self-stabilizing)
- v(σ)=n: the total capacity needed equals the base dimension

```
  Ensemble architecture:
    ┌─── Model A (φ=2 symmetry) ───┐
    │    Model B (φ=2 symmetry)     │ → Consensus → Output
    │    Model C (φ=2 symmetry)     │
    └───────────────────────────────┘
    3 models = σ/τ = v(φ) = minimum for coverage

  Prediction: 3-model ensemble > 2-model or 4-model
  at same total parameter budget.
```

## Testable Prediction

Train 3 identical architectures with different random seeds on same data.
Compare ensemble accuracy vs:
- 2-model ensemble (undercoverage)
- 4-model ensemble (redundant)
- 6-model ensemble (full v(σ) coverage)

Measure: accuracy, calibration (ECE), uncertainty estimation quality.

## Status: PROPOSED

## Connections

- H-TVAL-1: Totient valence cascade characterization of n=6
- H-SEDI-8: Multi-engine consensus
- H-ROB-11: Silent consensus distributed systems
