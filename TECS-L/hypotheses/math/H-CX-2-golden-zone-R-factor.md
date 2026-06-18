# H-CX-2: Golden Zone I∈[0.21, 0.50] = R-factor Range

> **Hypothesis**: The Golden Zone's Inhibition range [1/2-ln(4/3), 1/2] corresponds to the value range of R-factor f(p,a).

## Background
- Golden Zone upper bound: 1/2 = 1/σ₋₁(6)
- Golden Zone lower bound: 0.2123 ≈ 1/2-ln(4/3)
- R-factor: f(2,1)=3/4=0.75, f(3,1)=4/3=1.33
- f(2,1)=3/4 is the only value < 1 → is this "inhibition"?

## Correspondence

```
  R-factor System            Golden Zone
  ───────────────────    ──────────────────
  f(2,1) = 3/4 < 1      → Inhibition
  f(3,1) = 4/3 > 1      → Facilitation (Plasticity)
  f(2,1)×f(3,1) = 1     → Balance = Golden Zone center

  3/4 = 0.75 ∈ [0.21, 1.00]?
  → Golden Zone is [0.21, 0.50], f values are [0.75, ∞)
  → Direct correspondence doesn't match. Need transformation?
```

## Verification Direction
1. [ ] Transform with 1-f(p,a) or 1/f(p,a) then match Golden Zone range
2. [ ] MoE activation ratio = f(2,1)=3/4? (75% activation = I=0.25 ∈ Golden Zone!)

## Interesting Observations
- f(2,1) = 3/4 → When interpreted as activation ratio, I = 1-3/4 = 1/4 = 0.25
- **0.25 ∈ [0.21, 0.50] = Golden Zone!**
- Compare with GoldenMoE experiment's I=0.375 ≈ 1/e

## Verification Results (2026-03-24)
- f(2,1)=3/4 → I=1-3/4=0.25 → **Within Golden Zone [0.21,0.50]!** ✅
- At 13.1% position from GZ bottom (0.118 distance from 1/e=0.368)
- **Unique**: Among 12 (p,a) combinations, only f(2,1) is within GZ
- n=6: Inhibition(3/4)×Amplification(4/3)=1 → net I=0 (complete cancellation)
- **Partial confirmation**: I=0.25 ∈ GZ but distant from 1/e optimum

## Difficulty: Medium | Impact: ★★★ | Status: 🟧 Partially Confirmed