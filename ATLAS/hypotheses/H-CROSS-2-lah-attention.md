# H-CROSS-2: Lah Numbers Predict Optimal Attention Architecture
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **Hypothesis**: The Lah number identity L(τ,2)=n² and L(τ,3)=σ at n=6 predicts
> that transformer attention with τ(6)=4 heads achieves optimal information flow
> when head dimension satisfies d_head² = n² (hidden_dim) and C(d_head-1,2)·d_head!/3! = σ (total dim).

## Background

The Lah numbers L(n,k) count the number of ways to partition a set of n elements
into k non-empty linearly ordered subsets. In attention mechanisms, this maps to:

- L(τ,2) = n²: partitioning τ=4 attention heads into 2 ordered groups gives n²=36 ways
- L(τ,3) = σ: partitioning into 3 ordered groups gives σ=12 ways

The combined constraint (τ-2)·n²=6·σ uniquely selects n=6 arithmetic.

## Mapping to Attention

```
  Attention heads: τ = 4
  Hidden dimension: d_model = n² = 36 or d_model ∝ n²
  Head dimension: d_head = d_model/τ = 9 = (σ/τ)²
  Total parameters per layer: σ·d_model = 12·36 = 432

  Lah partition interpretation:
    L(4,2)=36: 2-way split of 4 heads = d_model
    L(4,3)=12: 3-way split of 4 heads = total output channels
    L(4,1)=24: 1-way (full order) = σ·φ = Leech dimension
```

## Prediction

For small models (d_model < 1024), architectures where:
- num_heads = 4 (= τ)
- d_model = 36k for integer k
- d_head = 9k = (σ/τ)²·k

should show measurably better attention entropy and gradient flow compared to
standard 2^k head dimensions.

## Testable

- Compare 4-head vs 2/8-head models at same total parameter count
- Measure attention entropy distribution
- GPU: Mac MPS sufficient for d_model=36 models

## Status: PROPOSED

## Connections

- H-LAH-1: Lah number characterization of n=6
- H-EE-7: Head dimension diversity
- H-EE-6: Tensor-aligned HCN dimensions
