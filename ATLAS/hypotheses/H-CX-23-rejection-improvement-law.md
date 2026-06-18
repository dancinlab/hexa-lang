# H-CX-23: Rejection Improvement Law — improvement ≈ ln(K) × √(error_rate)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **The improvement margin from confidence-based rejection follows ln(K)×√(100-base). Here K=number of classes (10), ln(10)=2.30. This is the same constant as C57 (C48/τ(6)≈ln(10)), and reflects the "information capacity" of 10-class classification.**

## Measured Data

```
  3 datasets, 90% rejection result:
  Dataset    base    100-base   √(100-base)  improvement  imp/√(err)
  ────────  ──────  ─────────  ───────────  ───────────  ──────────
  MNIST      97.72    2.28       1.51         1.48        0.980
  Fashion    87.99   12.01       3.47         9.81        2.831
  CIFAR      51.55   48.45       6.96        15.18        2.181

  Fitting: improvement = 2.31 × (100-base)^0.49
  coefficient = 2.31 ≈ ln(10) = 2.303 (error 0.4%!)
  exponent = 0.49 ≈ 1/2 = Golden Zone upper bound = Riemann critical line!
```

## Mathematical Meaning

```
  improvement ≈ ln(K) × √(error_rate)

  ln(K): information entropy of K=10 classes (uniform distribution)
    = log₂(10) × ln(2) ≈ 3.32 × 0.693 = 2.303
    = "maximum uncertainty of 10 choices"

  √(error_rate): square root of error
    = "standard deviation scale" (√N scaling by CLT)
    = "width" of errors removable by rejection

  Summary: "errors that rejection can reduce" = "information capacity" × "error width"
```

## Connection to C57

```
  C57: C48/τ(6) ≈ ln(10)
    C48 = -9.25pp (tension causal effect)
    τ(6) = 4 (number of divisors)
    C48/τ(6) = 9.25/4 = 2.3125 ≈ ln(10)

  H-CX-23: improvement coefficient = 2.3117 ≈ ln(10)

  → The same constant (ln(10)) appears in two places:
    1. Tension causal effect / number of divisors = ln(K)
    2. Rejection improvement coefficient = ln(K)
    → Is ln(10) a "fundamental constant" in 10-class classification?
```

## Caution

```
  3-point fitting: 1 degree of freedom (2 parameters, 3 data points)
  MNIST is an outlier (0.98 vs 2.18, 2.83)
  → Needs validation with K other than 10
  → Check whether coefficient = ln(K) for K=2, K=5, K=26
```

## K Variation Validation (2026-03-24)

```
  K vs coefficient:
  K     coeff   ln(K)   ratio
  ───   ─────   ─────   ─────
  2     0.22    0.69    0.31  (base=99.95%, improvement nearly absent)
  5     0.76    1.61    0.47  (base=99.42%, small improvement)
  10    2.31    2.30    1.00  ← match!

  → Mismatch at K=2, K=5!
  → Reason: base accuracy too high, leaving no room for improvement
  → ln(K) relationship holds only at K=10 → possible coincidence

  coefficient ≈ 2.31 = ln(10) is not because of "information capacity of 10 classes"
  but possibly a coincidental match with base accuracy and error distribution of those datasets?
```

## Status: ⚠️ Weakened (matches only at K=10, mismatch at K=2,5 → possible coincidence)
