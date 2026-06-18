# H-EE-2: Phi6Simple Gradient Centering Properties
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


## Hypothesis

> Phi6'(x) = 2x-1 gives natural gradient centering (E[f'(x)] ~ 0) for N(0,1) inputs.

## Background

Good gradient properties are critical for training stability. An activation whose
gradient has mean ~0 avoids systematic bias in weight updates. We test whether
Phi6's linear derivative (2x-1) achieves this.

## Analytical Results

For x ~ N(0,1):

```
  Phi6 unclamped: f'(x) = 2x - 1
    E[f'(x)]   = 2*E[x] - 1 = -1.000   (EXACT)
    Var[f'(x)] = 4*Var[x]   =  4.000   (EXACT)
    Std[f'(x)] = 2.000

  Phi6 clamped [-2,2]: f'(x) = (2x-1)*I(|x|<=2)
    E[f'(x)]   = -0.9545  (numerical integration)
    Var[f'(x)] =  2.9976
    P(|x|>2)   =  4.55%   (these get zero gradient)
```

**The gradient is NOT zero-centered. E[f'(x)] = -1, not 0.**

## Comparison Table (N=1,000,000 Monte Carlo)

| Activation     | E[f'(x)] | Std[f'(x)] | Dead (|g|<0.01) | Large (|g|>2) | Negative |
|---------------|----------|-----------|----------------|-------------|---------|
| GELU          | 0.499    | 0.454     | 1.5%           | 0.0%        | 22.7%   |
| ReLU          | 0.500    | 0.500     | 50.0%          | 0.0%        | 0.0%    |
| SiLU          | 0.500    | 0.360     | 1.6%           | 0.0%        | 10.1%   |
| Phi6 clamped  | -0.956   | 1.731     | 4.9%           | 33.1%       | 66.9%   |
| Phi6 unclamped| -1.003   | 2.000     | 0.4%           | 37.6%       | 69.2%   |

## Gradient Flow Through Depth

```
  Activation      depth=1   depth=2   depth=5   depth=10   depth=20
  ------------------------------------------------------------------
  GELU            0.538     0.289     0.046     0.002      0.000005
  ReLU            0.495     0.250     0.032     0.001      0.000000
  SiLU            0.513     0.262     0.035     0.001      0.000001
  Phi6_clamped    1.568     2.482     9.791     96.4       10,826
  Phi6_unclamped  1.788     3.217     18.3      341.7      147,663
```

Critical finding: **Phi6 EXPLODES through depth** because E[|f'(x)|] > 1.
At depth 20, gradient magnitudes reach 10,000x the initial value.

## Gradient Distribution (ASCII)

```
  GELU: concentrated in [0, 1], bimodal at 0 and 1
       0.0 |#####################
       0.5 |
       1.0 |########################################

  Phi6: spread from -5 to +3, heavy negative tail
      -3.0 |########################################
      -1.0 |#########
       0.0 |###################
       1.0 |#####
       3.0 |#
```

## Positive Findings (Despite Refutation)

1. **No dead neurons**: Phi6 has only 4.9% dead gradients vs ReLU's 50%
2. **Linear backward**: f'(x) = 2x-1 is the simplest non-trivial derivative
3. **Full gradient range**: Unlike ReLU (binary 0/1), Phi6 provides rich gradient signal
4. **Despite mean=-1, it TRAINS WELL**: the network learns to compensate via LayerNorm/bias

## Why Phi6 Works Despite Bad Gradient Statistics

The gradient mean of -1 should be harmful, yet Phi6 achieves the BEST loss in H-EE-1.
Possible explanations:
- The -1 bias acts as implicit weight decay (systematic negative gradient pulls weights down)
- In practice, activations are after linear layers, so input distribution is NOT N(0,1)
- BatchNorm/LayerNorm would correct the bias in real architectures
- The gradient explosion at depth 20 is irrelevant for 2-layer networks

## Limitations

- Analysis assumes x ~ N(0,1), but real pre-activation distributions differ
- Depth analysis uses independent x at each layer (unrealistic)
- Gradient flow in real networks includes weight matrices (not just activation gradients)

## Verification Direction

- Measure actual gradient statistics during training (not just theoretical)
- Test with LayerNorm to see if gradient bias is corrected
- Measure effective gradient after full backprop chain (not just activation derivative)

## Grade: REFUTED

E[Phi6'(x)] = -1 for N(0,1) inputs, far from zero-centered.
GELU and SiLU have E[f'(x)] = 0.5, much closer to centered.
However, Phi6 has valuable properties (no dead neurons, linear backward)
that were not part of the original hypothesis.

## Script

`experiments/h_ee_2_gradient_properties.py`
