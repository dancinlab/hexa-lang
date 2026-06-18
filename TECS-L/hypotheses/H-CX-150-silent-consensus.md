# H-CX-150: Silent Consensus — Consensus via Router Only, Without Direct Expert Connection
**n6 Grade: 🟧 CLOSE** (auto-graded, 3 unique n=6 constants)


> Router weight similarity converges during training. Consensus forms without direct communication.

## Background

In the Mixture of Experts (MoE) architecture, each Expert is trained independently.
There is no direct information exchange path between Experts; only the router (gate network)
distributes inputs to Experts and weighted-sums Expert outputs.

Nevertheless, as training progresses, Experts form "role divisions,"
and Experts specialized in specific classes emerge naturally.
This is consensus forming without direct communication.

This hypothesis measures this phenomenon more concretely:
In two independently trained Golden MoE models, whether the class centroid
of each Expert (feature average of the classes mainly processed by that Expert)
becomes similar across models.

This is analogous to functional specialization in the brain:
just as the same area handles the same function in different brains,
if Experts show similar specialization in models trained with different seeds,
this becomes evidence that the input structure determines Expert differentiation.

## Predictions

| Measurement | Predicted value | Meaning |
|------|--------|------|
| class centroid cosine sim (inter-model) | > 0.5 | similar specialization |
| Expert-class assignment match rate | > 60% | same Expert handles same class |
| router weight correlation | > 0.4 | similar distribution pattern |
| match after Expert order permutation | > 0.7 at optimal permutation | structure matches regardless of order |

```
Expert specialization comparison (two models):

Model A:  Expert 1 → {cat, dog, deer}     (animals)
          Expert 2 → {car, truck, ship}    (vehicles)
          Expert 3 → {plane, bird, frog}   (mixed)

Model B:  Expert 2 → {cat, deer, frog}    (animals+)
          Expert 3 → {car, truck, plane}   (vehicles+)
          Expert 1 → {dog, ship, bird}     (mixed)

Prediction: 60%+ match after permutation alignment
```

Key predictions:
1. Experts specialize based on semantic clusters (animal vs vehicle)
2. Specialization patterns differ only in order (permutation) across models, structure is similar
3. Models trained within the Golden Zone show more distinct specialization (near I = 1/e)

## Verification Methods

1. Train 2 Golden MoE models independently with different random seeds
2. Record routing weights per Expert for each model:
   - R_a[e, c] = average weight assigned to class c by Expert e
3. Find optimal permutation for Expert-class assignment matrix using Hungarian algorithm
4. Calculate cosine similarity and correlation after alignment

```python
# Verification code sketch
from scipy.optimize import linear_sum_assignment
# R_a: (num_experts, num_classes), R_b: (num_experts, num_classes)
cost = -cosine_similarity(R_a, R_b)  # (E, E) matrix
row_ind, col_ind = linear_sum_assignment(cost)
aligned_sim = np.mean([-cost[r, c] for r, c in zip(row_ind, col_ind)])
```

## Related Hypotheses

- **H-CX-148**: Tension Resonance Telepathy (tension-level synchronization)
- **H-CX-149**: Direction Telepathy (Engine A → G information transfer)
- **H-CX-151**: Cross-Layer Tension Signal (information transfer mechanism)
- Golden MoE empirical results (MNIST 97.7%, CIFAR 53.0%)

## Limitations

1. Expert differentiation in MoE is a well-known phenomenon and calling it "consensus" may be an exaggeration
2. Training with the same data and same loss function makes convergence self-evident
3. With few Experts (2-3), the number of combinations is small, making coincidental matching more likely
4. CIFAR-10's 10 classes naturally split into animal/vehicle with 2-3 Experts
5. True verification requires 100+ Experts and 100+ classes (ImageNet, etc.)

## Verification Status

- [ ] Train 2-seed models and extract routing weights
- [ ] Hungarian algorithm alignment
- [ ] cosine similarity calculation
- [ ] Large-scale experiment (increasing Expert/class count)
- Currently: **unverified**
