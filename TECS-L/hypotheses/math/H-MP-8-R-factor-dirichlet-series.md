# H-MP-8: Dirichlet Series of R-factor

> **Hypothesis**: F(s) = Σ_{n≥1} [σ(n)φ(n)/(nτ(n))] × n^{-s} has analytically interesting properties.

## Background
- σφ/(nτ) = Π f(p_i,a_i) multiplicative
- Euler product: F(s) = Π_p [Σ_{a≥0} f(p,a) p^{-as}]
- f(p,0)=1, f(p,1)=(p²-1)/(2p), f(p,2)=(p³-1)/(3p), ...

## Key Questions
What are the half-plane of convergence, singularities, and residue structure of F(s)?

## Verification Direction
1. [ ] Numerical: Σ_{n≤N} σφ/(nτ)×n^{-s} for s=1,2
2. [ ] Analysis of Euler product convergence conditions
3. [ ] Relationship with existing Dirichlet series (ζ, L-functions)

## Difficulty: High | Impact: ★★