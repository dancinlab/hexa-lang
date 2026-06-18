# H-CX-447: MoE Expert Specialization Follows Perfect Number Structure
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


**Status**: NOT SUPPORTED (P1 fails, P3 inconclusive)
**Golden Zone Dependency**: None (number theory + empirical ML)
**Related**: H-EE-10 (Phi-MoE confirmed), H-EE-12 (4/3 FFN ratio)

> **Hypothesis**: In a 24-expert MoE network, expert activation patterns at convergence
> reflect properties of perfect number 6: exactly sigma(6)=12 experts become active,
> they form tau(6)=4 clusters, and top_k=tau(6)=4 routing is optimal.

## Background

H-EE-10 confirmed that 24 narrow experts (phi-bottleneck, 85 hidden) beat 8 wide experts
(256 hidden) with 65% fewer active parameters. But WHY 24 and not 20 or 32?

24 = sigma(6) * sigma_-1(6) = 12 * 2. If the expert system self-organizes to match
n=6 arithmetic, we expect:
- P1: sigma(6)=12 of 24 experts become meaningfully active
- P2: Expert load forms tau(6)=4 natural clusters
- P3: Optimal routing uses tau(6)=4 experts per token (not k=2)

## Experiment

- 24-expert MoE on MNIST, expert_hidden=85
- Compare top_k = {2, 4, 6}
- Train 10 epochs each
- Measure: accuracy, active expert count, load distribution, clustering

## Predictions

| Metric | Predicted | n=6 connection |
|--------|-----------|----------------|
| Active experts (>2x uniform) | 12 | sigma(6)=12 |
| Expert clusters | 4 | tau(6)=4 |
| Best top_k | 4 | tau(6)=4 |

## Results

### Performance comparison

| top_k | Accuracy | Active (>2x uniform) | Load Std |
|-------|----------|---------------------|----------|
| 2     | 97.32%   | 2                   | 0.0228   |
| **4** | **97.34%** | 0                 | 0.0172   |
| 6     | 97.34%   | 0                   | 0.0158   |

### Expert load distribution (top_k=2, most uneven)

```
  E03: ██████████████████████████████ 0.095  (most active)
  E06: ██████████████████████████     0.084
  ...
  E09: ████████████                   0.040  <-- 12th expert
  E12: ████████████                   0.039  <-- 13th expert (gap here?)
  ...
  E13: ██                             0.008  (least active)
```

### Prediction outcomes

| Prediction | Result | Verdict |
|-----------|--------|---------|
| P1: 12 active experts | 2 (top_k=2), 0 (k=4,6) | NOT CONFIRMED |
| P2: 4 clusters | Not measured | INCONCLUSIVE |
| P3: top_k=4 optimal | Tied with k=6 (97.34%) | INCONCLUSIVE (0.02% diff) |

## Interpretation

Load balancing loss distributes load relatively evenly across all 24 experts.
Without balance loss, experts might collapse to fewer active ones, but that
would be a training artifact, not a structural property.

The sigma(6)=12 prediction fails because MoE expert selection is driven by
data distribution + load balancing, not number-theoretic properties of the
expert count. The near-identical performance across top_k values suggests
MNIST is too simple for 24 experts (all configs reach ~97.3%).

## Limitations

- MNIST is too easy for 24-expert MoE (oversaturated)
- Load balancing loss (0.01x) forces uniform distribution, masking natural patterns
- Accuracy differences <0.1% are within noise
- Need harder task (CIFAR-100, language modeling) to see real expert specialization
