# H-MP-19: Density of Integer R(n)

> **Hypothesis**: The density of n where R(n) is an integer converges to 0 as N→∞,
> and follows a power law count ~ C·N^α (α<1).

## Data

```
  N=10000:  52 (0.52%)
  N=50000: ~110 (0.22%)

  Density decreasing trend → possible convergence to 0
  52/10000 vs 110/50000: decreasing ratio
  log(110)/log(50000) ≈ 0.434
  log(52)/log(10000) ≈ 0.429
  → α ≈ 0.43?
```

## OEIS: R-011 candidate (n where R(n) integer)
## Verdict: 🟧 Numerical observation | Impact: ★★