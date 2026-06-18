# H-MP-6: Density of n where σφ/(nτ) ≈ 1

> **Hypothesis**: n values where σφ/(nτ) is close to 1 are extremely rare, and the "isolation" of 6 can be quantified.

## Background
- n=6: σφ/(nτ) = 1.000000 (unique)
- n=4: 1.167 (closest runner-up, 17% difference)
- n=2: 0.750 (only value less than 1)
- Average: ~N/12 proportional (diverges)

## Key Question
What is the asymptotic behavior of N(x, ε), the count of n where |σφ/(nτ) - 1| < ε, with respect to x?

## Verification Directions
1. [ ] Calculate N(10^k, ε) for ε=0.1, 0.01, 0.001
2. [ ] "Isolation radius" of n=6 — gap to the next closest value to 1
3. [ ] Possibility of Erdős–Kac theorem-like asymptotic analysis

## Verification Results (2026-03-24)

| ε | Count where |R-1|<ε (n=2..10000) | Ratio |
|---|---|---|
| 0.5 | 4 | 0.04% |
| 0.2 | 2 (n=4,6) | 0.02% |
| 0.1 | 1 (n=6 only!) | 0.01% |

Isolation radius of n=6 = 0.167 (to n=4). No other solutions within this radius.

## Difficulty: Medium | Impact: ★★ | Status: ✅ Verified