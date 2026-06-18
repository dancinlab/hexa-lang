# H-EE-40: Spectral Gap 1/2 — Optimal SGD Mixing on N6 Architectures

## Hypothesis

> The spectral gap of the SGD Markov chain on R=1 architectures is 1/2, achieving the fastest possible mixing time. delta_+ = 1/6 + 1/3 = 1/2 (from n=6 divisor reciprocals). SGD converges at the theoretically optimal rate on n=6 architectures.

## Background

- Spectral gap: lambda_1 - lambda_2 of the transition matrix
- Larger gap = faster mixing = faster convergence
- Maximum possible gap for reversible chains = 1/2 (Cheeger inequality bound)
- delta_+ = 1/6 + 1/3 = 1/2 (sum of two smallest divisor reciprocals of 6)
- SEDI uses delta_+ as a key detection frequency

## Predictions

1. SGD convergence rate is maximized on R=1 architectures (measured by autocorrelation decay)
2. The effective spectral gap is measurably higher for R=1 vs R<1
3. Momentum SGD becomes less necessary at R=1 (already at optimal mixing)
4. The mixing time scales as O(1/delta_+) = O(2) steps per "mixing event"

## Key Implications

- SGD is not just "a good optimizer" — it's the optimal sampler for n=6 landscapes
- Adam's adaptive rates compensate for non-optimal spectral gaps in R<1 architectures
- At R=1, SGD = Adam (both achieve the same convergence rate)

## Conclusion

H-EE-40: Spectral gap optimality for SGD on n=6 architectures. The most training-practical of the extreme hypotheses.

**Status:** Testable — requires eigenvalue analysis of SGD transition matrix
**Bridge:** SEDI delta_+ ↔ Markov chain theory ↔ SGD convergence
