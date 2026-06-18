# H-CS-3: σφ/(nτ) Ratio and RSA Security

> **Hypothesis**: For n=pq, the farther σφ/(nτ) is from 1, the harder factorization becomes, and the stronger RSA security is.

## Background
- RSA: n=pq, security = difficulty of computing φ(n)=(p-1)(q-1)
- n=6: σφ/(nτ)=1 (balanced, easy)
- Large pq: σφ/(nτ)≫1 (imbalanced, difficult)

## σφ/(nτ) for n=pq
```
  n=pq: σφ/(nτ) = (p²-1)(q²-1)/(4pq)
  As p,q grow → ≈ pq/4 → n/4 (linear growth)
```

## Verification Directions
1. [ ] Calculate σφ/(nτ) for RSA-100, RSA-200, etc.
2. [ ] Analyze correlation between factorization time and ratio
3. [ ] Theoretical: Is ratio related to factorization algorithm complexity?

## Difficulty: Medium | Impact: ★★