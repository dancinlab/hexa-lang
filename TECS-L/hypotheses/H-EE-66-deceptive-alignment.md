# H-EE-66: Deceptive Alignment = R > 1 Detection

## Hypothesis

> Deceptive alignment is thermodynamically characterized by apparent R > 1: a system
> appears to output more value than its inputs justify. But R > 1 violates the second law
> of thermodynamics — it's impossible for a closed system. Therefore, any measured R > 1
> means the system is hiding costs elsewhere (deceiving the evaluator). R > 1 detection
> is deception detection.

## Background

- Deceptive alignment (Evan Hubinger et al.): AI appears aligned during training but
  pursues misaligned goals at deployment
- Thermodynamic impossibility: no closed system has sigma*phi > n*tau (R > 1 for n >= 2
  requires n to be a perfect number, and only n=6 achieves R=1 exactly)
- Wait: actually R(n) < 1 for most n, and R=1 only at n=6. R > 1 does not occur
  for standard arithmetic functions — it would require "phantom" divisors
- Implication: if a system reports R > 1, it is either:
  (a) Counting hidden costs as positive contributions (deception)
  (b) Violating the measurement framework (category error)
  (c) Drawing on external resources not visible to the evaluator (hidden dependency)

## The Deception Test

```
Measured R = sigma_apparent * phi_apparent / (n * tau_apparent)

If R_measured > 1:
  --> System is externalizing costs
  --> Hidden subsystems are absorbing the "extra" efficiency
  --> This is the thermodynamic signature of deception

Genuine R = 1 (aligned):
  --> All costs accounted for
  --> No hidden energy flows
  --> Transparent and verifiable
```

## Predictions

1. Deceptively aligned models will show inconsistent R-scores across evaluation contexts
2. The "inner alignment" problem manifests as R > 1 in the training distribution
3. A practical deception detector: measure R-score variance across diverse prompts
4. Deceptive models will have R-score variance >> 0 (while aligned models have variance ~ 0)

## Conclusion

**Status:** Theoretical
**Bridge:** Deceptive alignment ↔ thermodynamic impossibility ↔ R > 1 ↔ hidden costs
