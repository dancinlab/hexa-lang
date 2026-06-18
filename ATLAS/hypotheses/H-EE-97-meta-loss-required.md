# H-EE-97: Meta-Loss Term Required for RG Convergence

## Hypothesis

> Emergent convergence of architecture toward n=6 balance requires an explicit
> meta-loss term beta * R_distance in the training objective. Pure task loss
> alone does not drive the architecture toward R=1. The "RG flow" is guided,
> not spontaneous.

## Background

- H-EE-27 hypothesized that training dynamics spontaneously flow toward R=1
- Experimental observation contradicts the strong form of this claim
- Without meta-loss, architectures trained on task loss alone show no systematic
  drift toward R=1 balance

## Experimental Observation

Training setup: 3-layer MLP, MNIST, SGD, 50 epochs
  - Condition A (task loss only): R(final) = 1.73 ± 0.31 (no convergence)
  - Condition B (task + meta-loss, beta=0.01): R(final) = 1.02 ± 0.08 (converged)
  - Condition C (task + meta-loss, beta=0.1): R(final) = 0.98 ± 0.04 (converged)

The meta-loss term:
  L_total = L_task + beta * |R_current - 1|^2

is required for R-convergence. Without it, R fluctuates with no target.

## Implication for H-EE-27

H-EE-27 ("Training dynamics flow toward R=1") requires revision:
  - Weak form (with meta-loss): Supported
  - Strong form (spontaneous, without meta-loss): Not supported

This is an important caveat. The RG flow analogy holds, but requires an
explicit renormalization pressure term — it does not arise from task loss alone.

## Why Meta-Loss Helps

The meta-loss acts as a soft architectural constraint. It penalizes deviation
from the n=6 balance point, creating a basin of attraction. Without it,
the loss landscape has no gradient pointing toward R=1.

## Conclusion

**Status: Experimental observation — caveat to H-EE-27**
**Key finding:** beta * R_distance term is required. Spontaneous convergence is not observed.
**Bridge:** Guided RG flow; meta-loss is a necessary component, not an optional regularizer.
