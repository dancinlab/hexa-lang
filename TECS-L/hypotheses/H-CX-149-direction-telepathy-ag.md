# H-CX-149: Direction Telepathy — Engine A's Direction Predicts G's Next Output
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> Can A's dir → regression on G's next output? Information transfer without direct connection.

## Background

In the Golden MoE architecture, multiple engines (Experts) communicate only indirectly through the router.
Engine A (analyzer) and Engine G (generator) have no direct connection, but
processing the same input sequence indirectly influences each other's outputs.

H-CX-339 / H-CX-341 proposed the hypothesis that "direction = concept."
If each engine's direction vector represents the concept the engine "focuses on,"
Engine A's direction should be able to predict Engine G's next output.

This is analogous to information transfer between different brain areas:
- Visual cortex → prefrontal cortex: information transfer without direct connection, through intermediate areas
- The visual cortex's activation pattern can predict the next state of the prefrontal cortex
- Measurable via Granger causality

In this hypothesis, "Telepathy" is a metaphor for information transfer without direct connection.
The actual mechanism is the indirect path through shared input and the router.

## Predictions

| Measurement | Predicted value | Meaning |
|------------|----------------|---------|
| corr(dir_A, out_G) per dim | > 0.3 | weak-to-moderate correlation |
| Granger causality p-value | < 0.01 | A → G causal direction |
| regression R^2 | > 0.1 | dir_A explains 10%+ variance of out_G |
| Reverse corr(dir_G, out_A) | < 0.1 | asymmetric (A→G only) |

```
A direction dim[0] vs G output dim[0] (predicted):

G out |
 0.4  |    .  . * .
 0.2  |  . * . * * .
 0.0  | . * * . . .
-0.2  |  . * . .
-0.4  | .  .
      +--+--+--+--+-->
     -0.4 -0.2 0  0.2 0.4
         A direction dim[0]

      Prediction: weak positive correlation (r ~ 0.3)
```

Key predictions:
1. A→G direction shows significant correlation; G→A direction is weak or absent (asymmetric)
2. The dimension with the strongest correlation is the class-discriminative dimension
3. Correlation is stronger for "hard" inputs (high Tension)

## Verification Methods

1. Extract intermediate representations of Engine A and Engine G from Golden MoE model
   - A's direction vector: d_A(t) for each timestep t
   - G's output: o_G(t+1) for next timestep
2. Calculate per-dimension Pearson correlation: corr(d_A[i](t), o_G[j](t+1))
3. Granger causality test: d_A(t-k:t) → o_G(t+1)
4. Reverse contrast: d_G(t) → o_A(t+1)
5. Conditional analysis: compare correlation for high vs low Tension samples

```python
# Verification code sketch
from statsmodels.tsa.stattools import grangercausalitytests
# direction_A: (T, D), output_G: (T, D)
for dim in range(D):
    data = np.column_stack([output_G[1:, dim], direction_A[:-1, dim]])
    result = grangercausalitytests(data, maxlag=3)
```

## Related Hypotheses

- **H-CX-148**: Tension Resonance Telepathy (Tension-level synchronization)
- **H-CX-150**: Silent Consensus (convergence between Experts)
- **H-CX-339/341**: Direction = Concept (meaning of direction vector)
- **H-CX-151**: Cross-Layer Tension Signal

## Limitations

1. The premise "without direct connection" is incomplete since there is an indirect path through the router
2. Even if correlation appears, it may be spurious correlation due to shared input
3. Confirming A→G causal direction via Granger causality requires sufficient time series length
4. Per-dimension analysis requires multiple comparison correction
5. Extracting intermediate representations from current Golden MoE implementation may be technically challenging

## Verification Status

- [ ] Implement intermediate representation extraction
- [ ] Per-dimension correlation analysis
- [ ] Granger causality test
- [ ] Reverse contrast experiment
- Currently: **unverified**
