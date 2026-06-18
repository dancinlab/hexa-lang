# H-EE-36: Fisher Information Metric is Flat at R=1

## Hypothesis

> The Fisher information metric on the parameter manifold of R=1 architectures has zero Ricci curvature. Natural gradient descent equals ordinary gradient descent at R=1, meaning optimization proceeds without geometric resistance.

## Background

- Fisher information matrix: F_ij = E[d(log p)/d(theta_i) * d(log p)/d(theta_j)]
- Natural gradient: theta_new = theta - F^{-1} * grad
- If F = identity (flat metric): natural gradient = ordinary gradient
- Flat metric means parameter space is Euclidean — no curvature, no resistance
- R=1 architectures are conjectured to have F ~ I (identity) up to scaling

## Predictions

1. Condition number of Fisher matrix is minimized at R=1
2. Natural gradient and ordinary gradient converge at R=1 (angle -> 0)
3. Adam optimizer's adaptive learning rates become uniform at R=1
4. Training convergence speed is maximized at R=1 (no curvature penalty)

## Key Implications

- R=1 architectures are "geometrically simple" — the optimization landscape is flat
- This explains why n=6 architectures train faster: no need to fight curvature
- Natural gradient methods become unnecessary at R=1

## Conclusion

H-EE-36: Information-geometric flatness at R=1. The most training-relevant of the geometric hypotheses.

**Status:** Testable — requires Fisher matrix computation
**Bridge:** Information geometry ↔ optimization ↔ R(n)
