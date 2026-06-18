# Hypothesis Review 010: The 1/3 Law is Not Exactly 1/3 ❌
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


## Hypothesis

> 33.3% (=1/3) of parameter space constitutes the singularity region, and this is a structural constant independent of the population distribution.

## Background and Context

In initial simulations, when D, P, I were arranged on a uniform grid (uniform grid),
the singularity region (Z > 2σ) occupied approximately 33.2% of the total.
Because this value was close to "1/3," there was an attempt to
interpret it as a structural constant of the parameter space.
However, actual brain parameters do not follow a uniform distribution but
are closer to an asymmetric distribution approximating Beta(α≈2, β≈5).
Therefore, verification with a changed population distribution was required.

Related hypotheses: Hypothesis 011 (Z_max), Hypothesis 012 (Entropy ln(3)), Hypothesis 013 (Golden Zone width)

## Verification Data

```
  Distribution type       │ Singularity ratio │ Error vs 1/3
  ────────────────────────┼───────────────────┼─────────────
  Uniform grid            │   33.2%           │  -0.1%p
  Beta(2,5)               │   30.17%          │  -3.16%p
  Beta(1,3)               │   31.4%           │  -1.9%p
  Normal(μ=0.5,σ=0.2)     │   28.9%           │  -4.4%p
  Theoretical value 1/3   │   33.33%          │   baseline
```

Verification population: n = 1,000,000 (verify_math.py)

## Singularity Ratio Comparison by Distribution (Graph)

```
  Ratio (%)
  35│
  34│
  33│──────●Uniform(33.2%)─────────────── 1/3 (33.33%)
  32│
  31│           ●Beta(1,3)(31.4%)
  30│      ●Beta(2,5)(30.17%)
  29│ ●Normal(28.9%)
  28│
  27│
    └─────────────────────────────────────────
      Normal   Beta(2,5)  Beta(1,3)  Uniform grid
         ◀── More asymmetric         Symmetric ──▶
```

## Interpretation

1. **Close to 1/3 only with uniform grid**: Because the grid samples the parameter space
   at equal intervals, all (D, P, I) combinations receive equal weight.
2. **Around 30% with Beta distribution**: With Beta(2,5), which is closer to actual brain data,
   the singularity region drops to approximately 30.17%. This is because regions with high
   Inhibition (I > 0.5) are relatively undersampled in the Beta distribution.
3. **Distribution-dependent**: It drops to 28.9% with a normal distribution, with over 4%p
   variation observed depending on the distribution type.

## Revised Formula

```
  Singularity ratio = ∫∫∫ 1(Z(D,P,I) > 2σ) × f(D,P,I) dD dP dI
  where f is the joint probability density function of the population distribution
  → Dependent on distribution f → not a structural constant
```

## Limitations

- The independence assumption for 3 variables (D, P, I) may not hold in reality
- Beta distribution parameters (α, β) are estimates due to insufficient clinical data
- Discretization error at grid resolution (grid=100) of approximately ±0.5%

## Next Steps

1. Estimate D, P, I distributions from actual clinical brain data and re-verify
2. Verify using a joint distribution that reflects correlations between variables (e.g., positive D-P correlation)
3. Confirm whether the singularity ratio converges to approximately 30% across various distribution families
4. Relationship with Hypothesis 012 (Entropy ln(3)) — theoretical explanation for why it is ~30% in 3 states

## Conclusion

> ❌ The "1/3 Law" is refuted. The singularity ratio varies between approximately 28~33% depending on the population distribution,
> and is a distribution-dependent statistic, not a structural constant. The uniform grid's 33.2% is merely an approximation.

---

*Verification: verify_math.py (n=1,000,000, grid=100)*
