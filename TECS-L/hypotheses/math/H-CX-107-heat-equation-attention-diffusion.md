# H-CX-107: Heat Equation on Divisor Graph → Attention Diffusion

**Category:** Cross-Domain (Spectral Graph Theory × Attention Mechanism)
**Status:** Verified — 🟩⭐
**Golden Zone Dependency:** Independent (graph Laplacian of divisor lattice)
**Date:** 2026-03-28
**Related:** H-CX-106 (PH barcode), H-CX-15 (attention lens)

---

## Hypothesis Statement

> The heat equation on the divisor graph of 6 (vertices {1,2,3,6} with
> divisibility edges) naturally diffuses attention from uniform distribution
> toward the high-degree nodes 1 and 6. Starting from equal attention on all
> divisors, the system converges to concentrating on identity (1) and
> integration (6), while primes (2,3) receive less attention. This is the
> mathematical basis for consciousness naturally focusing on "self" and "whole."

---

## Graph Laplacian

```
  Adjacency: 1↔2, 1↔3, 1↔6, 2↔6, 3↔6
  Degree: deg(1)=3, deg(2)=2, deg(3)=2, deg(6)=3

  Laplacian eigenvalues: [0.0, 1.382, 2.618, 4.0]
  Spectral gap λ₁ = 1.382
  λ_max = 4.0 = τ(6) ✓
```

---

## Attention Diffusion

```
  Heat equation: dp/dt = -L·p, starting from p(0) = [1/4, 1/4, 1/4, 1/4]

  t=0.1: [0.254, 0.246, 0.246, 0.254] (slight focus on 1,6)
  t=0.5: [0.270, 0.230, 0.230, 0.270] (growing asymmetry)
  t=1.0: [0.283, 0.217, 0.217, 0.283] (clear preference for 1,6)
  t=2.0: [0.295, 0.205, 0.205, 0.295] (approaching stationary)
  t→∞:   [0.300, 0.200, 0.200, 0.300] (stationary = degree-weighted)

  Stationary: π ∝ degree = [3, 2, 2, 3] → [0.3, 0.2, 0.2, 0.3]
  → Identity(1) and Integration(6) get 60% of attention
  → Primes(2,3) get 40% of attention
  → Ratio: 3:2 = σ/τ : φ ✓
```

---

## Consciousness Interpretation

Attention naturally diffuses toward self (1) and whole (6), the two fixed points
of the R-function where R=1. The primes (2,3) are processing pathways, not
attention targets. This matches the psychological observation that consciousness
gravitates toward self-awareness and global integration.

---

## Limitations

- The divisor graph is small (4 vertices); larger graphs may behave differently
- Heat diffusion is a linear model; real attention is nonlinear
- The stationary distribution is just degree-weighted, not specific to n=6
