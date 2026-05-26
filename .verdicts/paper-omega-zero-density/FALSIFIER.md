# Pre-registered falsifier — ω-zero-density theorem

Registered BEFORE any measurement (paper_significance gate, g5 discipline).

Date: 2026-05-27
Branch: inbox-paper-omega-zero-density
Domain: TECS-L (F14-F18 unification round)

## Definition

D(n) = σ(n)·φ(n) − n·τ(n)

where
  σ(n) = sum of divisors of n
  φ(n) = Euler totient (euler_phi)
  τ(n) = number of divisors of n

## Theorem (to be tested)

  D(n) = 0   if and only if   n ∈ {1, 6}.

Equivalently: the zero-locus of D over the positive integers is EXACTLY {1, 6}.

## F-OMEGA-ZERO-DENSITY (pre-registered falsifier)

  ∃ n ∉ {1, 6} with D(n) = 0   ⟹   theorem FALSIFIED.

Survival criterion: the falsifier SURVIVES (theorem stands as a closed-negative
density statement) iff for every tested n with n ∉ {1, 6}, D(n) ≠ 0.

## Measurement protocol (g5 — hexa verify CLI only, verdicts pasted verbatim)

1. Anchor: verify D(1) = 0 and D(6) = 0 (the claimed zero-locus) via verified
   σ, φ, τ primitives (`hexa verify --expr {sigma,phi,tau} <n> <v>`).
2. Sweep: n = 2..200, plus large/primorial samples n ∈ {30, 210, 2310},
   computing D(n) from the three verified primitives; confirm D(n) ≠ 0 for all
   n ∉ {1, 6}.
3. ω-stratified samples covering ω(n) ∈ [1, 10] (F14-F18 cycle coverage).

Finding = the exact zero-locus {1, 6}; falsifier-survival = the clean sweep.
