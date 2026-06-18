# H-AI-4: MoE Optimal Activation Ratio = 1/3 (Meta-fixed Point)

> **Hypothesis**: The optimal expert activation ratio in Mixture-of-Experts is 1/3 ≈ φ(6)/P₁ (meta-fixed point).

## Background
- From σφ=nτ: φ/n = 2/6 = 1/3 = τ/σ
- GoldenMoE: I = 1-activation_ratio = 0.375 ≈ 1/e ≈ 0.368
- 1/3 = 0.333 vs 1/e = 0.368 — close but different
- Meta-fixed point: f(I)=0.7I+0.1 → I*=1/3

## Verification Direction
1. [ ] After GoldenMoE training completion, sweep activation ratios: 0.2, 0.25, 1/3, 0.375, 0.5
2. [ ] Compare PPL at each ratio
3. [ ] Collect optimal activation ratio data from existing MoE literature

## Connection: GoldenMoE (Running on RunPod A100, Step 1722/20000)
## Difficulty: Medium | Impact: ★★★