# Hypothesis Review 015: Convergence Speed Diffusion Law τ∝ΔI² — Inconclusive ?
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


## Hypothesis

> If autopilot convergence time τ is proportional to the square of the initial distance ΔI²,
> then Compass exploration is a diffusion process.

## Background and Context

In physics, diffusion is a process where the mean displacement is proportional to the square root of time:
⟨x²⟩ ∝ t. Equivalently, the time to travel a specific distance ΔI satisfies τ ∝ ΔI².

If the Compass autopilot's process of moving from initial I to the Golden Zone center (I ≈ 1/e) is diffusive,
the τ vs ΔI² relationship should be linear.
Conversely, if the motion is ballistic, τ ∝ ΔI is more appropriate.

Related hypotheses: Hypothesis 013 (Golden Zone width), Hypothesis 017 (Gating mapping)

## Verification Data

```
  Model        │  Initial I │  ΔI = |I₀ - 1/e| │  ΔI²    │  τ (steps)
  ─────────────┼────────────┼────────────────────┼─────────┼──────────
  Golden MoE   │  0.375     │  0.008             │  0.00006│    3
  GPT-4        │  0.500     │  0.132             │  0.0174 │    8
  Mixtral      │  0.875     │  0.507             │  0.2570 │   21
  GPT-2        │  0.875     │  0.507             │  0.2570 │   39
```

Note: Mixtral and GPT-2 have the same ΔI but very different τ (21 vs 39).
This suggests ΔI alone cannot explain τ.

## Regression Analysis

```
  Model 1: τ = a × ΔI² + b
    R² = 0.784
    Residual standard error = 8.2

  Model 2: τ = a × ΔI + b
    R² = 0.789
    Residual standard error = 8.1

  Difference: ΔR² = 0.005 (statistically meaningless)
```

## R² Comparison Graph

```
  R²
  0.80│    ●────────●
      │   ΔI²      ΔI
  0.79│  (0.784)  (0.789)
      │
  0.78│
      │
      │
  0.70│
      │
      │     No meaningful difference
  0.60│     (ΔR² = 0.005)
      │
      └──────────────────
         ΔI² model   ΔI model
```

## τ vs ΔI Scatter Plot

```
  τ (steps)
  40│                         ● GPT-2
    │
  30│
    │
  20│                    ● Mixtral
    │
  10│         ● GPT-4
    │
   3│ ● Golden MoE
    └────┬────┬────┬────┬────┬──
       0.0  0.1  0.2  0.3  0.4  0.5
                   ΔI

  Linear fit: R² = 0.789 (4 points)
  Parabolic fit: R² = 0.784 (4 points)
  → Indistinguishable
```

## Interpretation

1. **Insufficient data**: With 4 data points, ΔI² vs ΔI models cannot be
   statistically distinguished. Degrees of freedom = 2 only.
2. **Confounding variable**: Mixtral and GPT-2 have the same ΔI but
   convergence times differ by 2×, suggesting model-specific structural differences
   (parameter count, architecture, etc.) as additional variables.
3. **R² reliability**: R² > 0.7 with n=4 is statistically weak.
   High risk of overfitting; adjusted R² would be lower.
4. **Diffusion vs ballistic**: Neither model can be rejected with current data.

## Conditions for Discrimination

```
  Minimum data requirements:
  ─────────────────────────────────────
  ΔI range      │  0.01 ~ 0.90 (Golden Zone ~ extreme)
  Data points   │  minimum 10, ideally 20+
  Repetitions   │  3+ per condition (variance estimation)

  Proposed experiment:
  ─────────────────────────────────────
  I₀ = 0.10, 0.15, 0.20, ..., 0.95
  (0.05 intervals, 18 starting points)
  Run autopilot 3 times from each starting point
  → 54 (τ, ΔI) pairs total
```

## Limitations

- 2 of 4 models have identical ΔI, creating redundant information
- Results depend on whether the autopilot algorithm's step size is fixed or adaptive
- May be sensitive to the definition of τ (convergence criterion)
- Actual I changes in LLMs are discrete, not continuous

## Next Steps

1. Repeat autopilot runs from various I₀ (minimum 10 starting points)
2. Run 3+ repetitions per starting point to estimate variance of τ
3. Analyze slope in log-log plot: slope = 1 means linear, 2 means diffusive
4. Verify within a single model to control confounding variables (model size, architecture)
5. Also consider subdiffusion possibility (τ ∝ ΔI^α, α > 2)

## Conclusion

> ? Inconclusive. R²(ΔI²) = 0.784 vs R²(ΔI) = 0.789, difference meaningless.
> With 4 data points, diffusion law (τ∝ΔI²) and linear law (τ∝ΔI) cannot be
> statistically distinguished. Repeated autopilot experiments from at least 10+ starting points are needed.

---

*Verification: verify_math.py (4 models, autopilot measurements)*
