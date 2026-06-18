# Hypothesis 279: A/G Dominance Ratio = Input Complexity Metric

> **The output norm ratio of Engine A (logic) vs Engine G (pattern) measures input complexity. Simple inputs (digit 1) are dominated by G (99%), complex inputs (digit 0) are dominated by A (75%). Can this ratio be used as a universal complexity metric?**

## Measured Data (experiment_force_direction.py)

```
  digit | A wins% | G wins% | |A|/|G| ratio | Interpretation
  ──────┼─────────┼─────────┼───────────────┼────────────
      0 |   75.4% |   24.6% |     1.82      | A dominant (closed curve → logic needed)
      1 |    1.0% |   99.0% |     0.31      | G dominant (straight line → pattern sufficient)
      2 |   24.4% |   75.6% |     0.74      | G dominant
      3 |   55.9% |   44.1% |     1.06      | Balanced
      4 |   66.3% |   33.7% |     1.33      | A dominant
      5 |   47.2% |   52.8% |     0.98      | Balanced
      6 |   56.4% |   43.6% |     1.10      | Slightly A
      7 |   33.5% |   66.5% |     0.76      | G dominant
      8 |    9.4% |   90.6% |     0.41      | G strong
      9 |   15.6% |   84.4% |     0.64      | G dominant
```

## Interpretation

```
  G dominant (|A|/|G| < 0.5): digits 1, 8 → simple strokes, pattern recognition sufficient
  A dominant (|A|/|G| > 1.0): digits 0, 3, 4, 6 → curves/structure, logical judgment needed
  Balanced (0.9~1.1): digits 3, 5, 6 → both engines needed

  → |A|/|G| = complexity metric?
    Low: simple input sufficient with patterns
    High: complex input requiring logic
```

## Verification Direction

```
  1. Same analysis on CIFAR → which classes are A dominant?
  2. Correlation between |A|/|G| and accuracy?
  3. Correlation between |A|/|G| and human cognitive complexity?
```

## CIFAR-10 Results (2026-03-24)

```
  class        |A|      |G|   |A|/|G|  acc%  tension
  ──────────  ──────  ──────  ──────  ─────  ───────
  airplane     25.17   12.58    2.00   64.9   346.9
  auto         17.91   17.87    1.00   70.7   177.3
  bird         14.17   15.40    0.92   40.7   230.3
  cat          13.02   17.20    0.76   24.9   228.9
  deer         10.15   15.09    0.67   50.7   146.1
  dog          13.21   20.29    0.65   43.7   242.0
  frog         10.30   17.73    0.58   59.1   283.7
  horse        14.20   14.25    1.00   55.9   125.1
  ship         20.28   13.51    1.50   61.0   186.2
  truck        18.32   13.32    1.38   55.8   141.4
```

### MNIST vs CIFAR Comparison

```
  Correlation:
    MNIST: |A|/|G| vs accuracy r = +0.006 (no correlation!)
    CIFAR: |A|/|G| vs accuracy r = +0.485 (moderate positive correlation)

  CIFAR A dominant = high accuracy:
    airplane(2.00) → 64.9%
    ship(1.50)     → 61.0%
    truck(1.38)    → 55.8%

  CIFAR G dominant = low accuracy:
    frog(0.58)  → 59.1% (exception!)
    dog(0.65)   → 43.7%
    cat(0.76)   → 24.9%

  Interpretation:
    MNIST: Too easy, A/G ratio unrelated to accuracy (r≈0)
    CIFAR: A (logic) helps in difficult problems (r=+0.49)
    → A/G ratio works as complexity metric "only in difficult problems"
```

## Status: 🟧 Partially confirmed (CIFAR r=+0.49, MNIST r≈0)