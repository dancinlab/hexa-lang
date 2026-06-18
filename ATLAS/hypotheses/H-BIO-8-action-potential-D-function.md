# H-BIO-8: Action Potential = D(n) Asymmetric Function

> **Hypothesis**: The sign structure of D(n)=σφ-nτ (D(2)=-1 unique negative, D(6)=0, D(n>6)>0) is isomorphic to the asymmetric structure of neuronal action potential.

## Core

```
  D(n):  ..., -1, 2, 2, 14, 0, 34, 28, ...
              n=2         n=6

  Action potential:
    Hyperpolarization → Threshold → Firing → Repolarization → Stable

  Correspondence:
    D(2)=-1: Unique "below threshold" = Repolarization/Hyperpolarization
    D(6)=0:  "Resting potential" = Equilibrium
    D(p)=(p-1)²-2: "Firing" = Rapid rise

  D(n) at primes = (p-1)²-2:
    p=2: -1 (negative)
    p=3: 2 (switch to positive!)
    p=5: 14
    p=7: 34
    → "Discrete action potential" where p=3 is "firing start"

  Proof: D(n)<0 ⟺ n=2 (unique!)
    primes: (p-1)²<2 iff p=2
    composites n≥3: R(n)≥7/6>1 → D>0
```

## Verdict: 🟧 Structural Analogy | Impact: ★★★