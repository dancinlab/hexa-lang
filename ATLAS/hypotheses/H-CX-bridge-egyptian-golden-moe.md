# H-CX-Bridge-6: Egyptian MoE {1/2,1/3,1/6} = Golden MoE Optimal Weights

> **Hypothesis**: The Egyptian fraction 1/2+1/3+1/6=1 used in energy-efficiency's routing is identical to golden-moe's #1 ranked Meta fixed weights.

## Grade: 🟩 CONFIRMED (cross-repo bridge)

## Bridge: energy-efficiency ↔ golden-moe

| Repo | Technique | Weights | Result |
|------|-----------|---------|--------|
| energy-efficiency | Egyptian MoE routing | {1/2, 1/3, 1/6} | Better expert utilization |
| golden-moe | Meta fixed routing | {1/2, 1/3, 1/6} | #1 on MNIST 97.75%, CIFAR 53.52% |

**Same weights, independently discovered in different contexts.**

## Why {1/2, 1/3, 1/6}?

These are the reciprocals of the non-unit divisors of 6: div(6)\{1} = {2, 3, 6}.
Their sum = 1/2+1/3+1/6 = 1 exactly. This is a property of **perfect numbers**.

For n=28: {1/2, 1/4, 1/7, 1/14, 1/28} = 1, but needs 5 weights (more complex).
n=6 gives the **simplest** (3-term) perfect decomposition.

## Additional Connection

FFT-Mix speedup = 3x = sigma(6)/tau(6) = same ratio as golden-moe expert activation.
