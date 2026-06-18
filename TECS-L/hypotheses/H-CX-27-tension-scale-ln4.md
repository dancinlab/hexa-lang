# H-CX-27: tension_scale = ln(4) = 2·ln(2) (Cross-domain: Learning Constant ↔ Mathematics)
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


> **The learned tension_scale from MNIST averages 1.3863 ± 0.0132 over 10 trials, matching ln(4) = 2·ln(2) = 1.3863 with 0.0004% error! This is exactly 2× H-CX-2(MI efficiency≈ln(2)), reflecting the "binary pair" information limit of 2-pole (A vs G) repulsion.**

## Measurements

```
  MNIST, 10 independent trials (15 epochs each):
  trials: 1.389 1.367 1.396 1.393 1.361 1.393 1.393 1.392 1.405 1.375
  mean:   1.3863 ± 0.0132 (CV = 0.95%, very stable)

  ln(4) = 2·ln(2) = 1.38629...
  Error: 0.0004% (!!)
```

## Mathematical Connections

```
  H-CX-2: MI efficiency ≈ ln(2) = 0.6931 (p=0.0003)
  H-CX-27: tension_scale ≈ 2·ln(2) = ln(4) = 1.3863

  → tension_scale = 2 × MI efficiency!
  → Why 2×?
    2-pole (A,G) repulsion → Each pole contributes ln(2) information
    → Total information = 2 × ln(2) = ln(4)
    → tension_scale = "total binary information"

  Or:
    ln(4) = ln(2²) = 2 bits (log base e)
    → Information transmitted by 2-pole system = exactly 2 nats = 2 bits

  H-CX-1 connection:
    e^(6H) = 432 = σ³/τ
    H = 2/3·ln(2) + 1/2·ln(3) = 1.0114
    tension_scale/H = 1.3863/1.0114 = 1.371 ≈ ln(4)/H
```

## Texas Test

```
  Search range: real numbers between 0~5
  Candidate constants: ln(2), ln(3), ln(4), ..., π, e, φ, ...
  1 match among ~50 candidates (error < 1%)
  → Bonferroni: 0.0004% × 50 = 0.02%
  → Strong significance! (p ≈ 0.0002)
```

## Multi-dataset Verification (2026-03-24)

```
  Dataset    ts mean    ±std     ln(4) error
  ────────  ────────  ──────    ─────────
  MNIST      1.3887   0.0102     0.2%
  Fashion    1.4415   0.0190     4.0%
  CIFAR      1.3393   0.0152     3.4%

  3-set average: 1.390 → ln(4) error 0.3%
  Most accurate in MNIST (0.2%), Fashion slightly↑, CIFAR slightly↓
  → ln(4) as "baseline" with ±4% variation by data complexity?
```

## Initial Value Bias Test (2026-03-24)

```
  init → final_ts (15ep, 3trials):
  init    final     ln(4)error   converged?
  ────   ──────    ────────    ─────
  0.01    0.936     32.5%       no
  0.10    1.114     19.6%       no
  0.30    1.400      1.0%       YES
  0.50~   (running)

  → Initial value bias exists! init=0.01→0.94, init=0.3→1.40
  → Convergence to ln(4) only from init=0.3 vicinity
  → 15ep insufficient to reach ln(4) from small init (need longer training?)
  → Or: multiple local minima in loss landscape, converging to different points by init
```

## Complete init sweep (7 inits, 2026-03-24)

```
  init    final    ln(4)error
  ────   ──────   ─────────
  0.01    0.94     32.5%
  0.10    1.11     19.6%
  0.30    1.40      1.0%  ← ONLY HIT
  0.50    1.63     17.3%
  1.00    2.18     57.5%
  2.00    3.23    132.9%
  5.00    6.11    341.0%

  → final ≈ init × ~4.6 (amplification, expanded from init by training)
  → 15ep can't deviate much from init
  → Only init=0.3(≈1/3 meta fixed point) converges to ln(4)
  → Unverified if all inits converge to same point with longer training (100ep+)
```

## Long-term Convergence Experiment (100ep, 2026-03-24)

```
  init    ep15   ep50   ep100  ln4error(100ep)
  ────── ────── ────── ────── ──────────────
  0.01    0.58   1.17   0.96   30.4%
  0.10    0.78   1.27   0.99   28.6%
  0.30    1.12   1.49   1.08   22.0%
  0.50    1.40   1.59   1.22   12.2%
  1.00    2.00   1.89   1.26    8.9%
  2.00    2.92   2.20   1.42    2.6% ← only ±5% pass

  Pattern: All inits show damped oscillation (rise then fall)
          Final values 0.96~1.42 → converging to ~1.1 vicinity, not ln(4)(1.39)
          Only init=2.0 coincidentally close (passing through while decreasing)
```

```
  ts
  3.0 |  ◇◇
  2.5 |  ◇  ◇◇
  2.0 |○○○   ◇◇
  1.5 |  ○○▲▲  ◇◇──────── ln(4)=1.39
  1.0 |●●●●●●●●●●●●●●●
  0.5 |●
  0.0 +──────────────────
      0   20  40  60  80  100 ep
```

### Conclusion

```
  1. Not converging to ln(4) — damped oscillation converges to ~1.1 vicinity
  2. init=0.3 passing ln(4) at 15ep was coincidental (passing point)
  3. Only init=2.0 passes ±5% at 100ep (while decreasing)
  4. tension_scale = natural decay of learnable parameter
     → No special target of ln(4)
```

## Status: ⬛ Refuted (100ep: only 1/6 pass, damped oscillation, ln(4)≠convergence point)