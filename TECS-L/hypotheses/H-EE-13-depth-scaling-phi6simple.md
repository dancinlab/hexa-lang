# H-EE-13: Energy Savings Scale with Model Depth
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## Hypothesis

> Deeper models benefit MORE from Phi6Simple (more activation layers = more
> cumulative speed savings from replacing expensive GELU with cheap polynomial).

## Background

- GELU: ~14 ops (exp + tanh + multiply)
- Phi6Simple: ~4 ops (clamp + square + subtract + add)
- Theory: each layer saves ~10 ops per element, so deeper models = more total savings
- Expected: speed advantage increases linearly with depth

## Experimental Setup

- Architecture: transformer, d_model=64, 4 heads, d_ff=256, seq_len=32
- Task: Char-level LM on structured text (31 char vocab, 82K tokens)
- Steps: 500, LR: 1e-3, AdamW optimizer
- Depths tested: 2, 4, 6, 8 layers
- Comparison: GELU vs Phi6Simple at each depth

## Results

| Depth | GELU Loss | Phi6 Loss | Loss Delta(%) | GELU Time/step | Phi6 Time/step | Speed Delta(%) | Params |
|-------|-----------|-----------|---------------|----------------|----------------|----------------|--------|
| 2 | 0.1954 | 0.1759 | **-9.95%** | 15.7ms | 16.5ms | -5.4% | 106,112 |
| 4 | 0.1570 | 0.1617 | +3.00% | 31.3ms | 34.0ms | -8.8% | 206,080 |
| 6 | 0.1552 | 0.1646 | +6.10% | 52.0ms | 71.5ms | -37.6% | 306,048 |
| 8 | 0.1408 | 0.1483 | +5.29% | 88.5ms | 94.8ms | -7.2% | 406,016 |

### Speed Savings by Depth

```
  Depth 2: -5.4%  |----------
  Depth 4: -8.8%  |-----------------
  Depth 6: -37.6% |----------------------------------------
  Depth 8: -7.2%  |--------------
```

### Loss Delta by Depth (negative = Phi6Simple better)

```
  Depth 2: -9.95% |-------------------   <-- Phi6Simple WINS
  Depth 4: +3.00% |+++++
  Depth 6: +6.10% |++++++++++++
  Depth 8: +5.29% |++++++++++
```

### ASCII: Loss Comparison

```
  d= 2 GELU [0.1954] ###
       Phi6 [0.1759] ===   <-- Phi6 wins at depth 2!
  d= 4 GELU [0.1570] ###
       Phi6 [0.1617] ===
  d= 6 GELU [0.1552] ###
       Phi6 [0.1646] ===
  d= 8 GELU [0.1408] ##
       Phi6 [0.1483] ==
```

### Learning Curves (Depth 8)

| Step | GELU | Phi6Simple |
|------|------|------------|
|   50 | 2.2338 | 2.6043 |
|  100 | 1.7078 | 2.0724 |
|  150 | 0.9399 | 1.5805 |
|  200 | 0.3765 | 0.8250 |
|  300 | 0.1791 | 0.2066 |
|  400 | 0.1812 | 0.1821 |
|  500 | 0.1305 | 0.1377 |

## Key Findings

1. **Phi6Simple is SLOWER than GELU** at all depths (negative speed delta)
2. Speed penalty trend is inconsistent (-5.4%, -8.8%, -37.6%, -7.2%)
3. At depth 2, Phi6Simple achieves **better loss** (-9.95%) than GELU
4. At depths 4-8, GELU wins on loss by 3-6%
5. Loss penalty increases with depth (+15.24% trend from d=2 to d=8)

## Critical Finding: PyTorch's GELU is Highly Optimized

The speed result is counterintuitive: simpler Phi6Simple is SLOWER than GELU.
This is because:

1. **PyTorch GELU uses fused CUDA/MPS kernels** -- a single optimized op
2. Phi6Simple's `torch.clamp` + arithmetic is **3 separate ops** with intermediate tensors
3. Memory allocation for intermediates dominates at small batch sizes
4. GELU benefits from decades of library optimization; Phi6Simple has none

This means Phi6Simple's "4 ops vs 14 ops" advantage only materializes with:
- Custom fused kernels
- Large batch sizes (amortize kernel launch overhead)
- Direct hardware implementation (no Python/PyTorch overhead)

## Loss Quality: Depth-Dependent

```
  Depth 2: Phi6Simple is -9.95% better  (simpler activation = regularization benefit)
  Depth 4: Phi6Simple is +3.00% worse
  Depth 6: Phi6Simple is +6.10% worse
  Depth 8: Phi6Simple is +5.29% worse
```

At shallow depth, Phi6Simple's bounded output acts as regularization (preventing overfitting).
At deeper depths, the positive-only output (min 0.75) compounds, limiting expressiveness.

## Interpretation

The hypothesis is **REJECTED**. Deeper models do NOT benefit more from Phi6Simple:
- Speed: Phi6Simple is slower at all depths due to PyTorch kernel overhead
- Quality: Loss penalty increases with depth (compounds through layers)

However, the shallow-depth result (Phi6Simple beats GELU at d=2) is interesting and
may indicate a niche for Phi6Simple in very shallow, efficiency-focused architectures.

## Limitations

- CPU/MPS benchmarks (GELU is optimized for GPU; Phi6Simple has no GPU kernel)
- Small model scale
- Phi6Simple not fused into single kernel
- Single seed, single task
- 500 steps may be insufficient for deeper models

## Verdict

**REJECTED** -- Deeper models do NOT benefit more. Phi6Simple is slower than GELU
due to kernel optimization gap, and loss penalty increases with depth.

## Next Steps

- Write custom fused CUDA kernel for Phi6Simple
- Test on GPU (A100/RTX) where kernel optimization matters more
- Explore Phi6Simple only for shallow models (1-2 layers)
- Test centered Phi6Simple (min at 0 instead of 0.75) for deep models
