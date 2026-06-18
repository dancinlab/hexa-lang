# H-EE-3: Phi6Simple Training Stability
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


## Hypothesis

> Phi6Simple's bounded output range [0.75, 7.0] prevents gradient explosion
> without needing gradient clipping.

## Background

GELU and SiLU can produce unbounded outputs for large inputs, potentially
causing gradient explosion during training. Phi6Simple clamps inputs to [-2,2],
giving a bounded output range. Does this translate to better training stability?

## Test Design

1. Normal LR (0.01) without clipping -- baseline stability
2. High LR stress test (0.05, 0.1, 0.5, 1.0) without clipping
3. With vs without gradient clipping (clip_norm=1.0)
4. Gradient norm evolution over training

## Results

### Test 1: Normal LR (0.01), No Clipping

| Activation | Survived | Final Loss | Max GradNorm | Mean GradNorm | Max Act |
|-----------|---------|-----------|-------------|-------------|---------|
| GELU      | 500     | 3.3895    | 0.4524      | 0.3872      | 0.89    |
| ReLU      | 500     | 3.3607    | 0.5519      | 0.4707      | 1.06    |
| SiLU      | 500     | 3.3936    | 0.4422      | 0.3773      | 0.77    |
| **Phi6**  | 500     | **3.1055**| 4.2079      | 1.7321      | 3.67    |

Surprise: Phi6 has **10x higher gradient norms** than GELU despite bounded output.
This is consistent with H-EE-2 findings (E[f'(x)] = -1, large gradients).

### Test 2: High LR Stress Test

| Activation | LR=0.05 | LR=0.10 | LR=0.50 | LR=1.00 |
|-----------|---------|---------|---------|---------|
| GELU      | 3.301   | 3.118   | 1.726   | 1.594 (6 spikes) |
| ReLU      | 3.241   | 2.982   | 1.661   | 1.586 (7 spikes) |
| SiLU      | 3.309   | 3.143   | 1.853   | 1.593 (3 spikes) |
| Phi6      | 2.854   | 2.289   | 2.331   | 5.421 (1 spike) |

All activations survive all LR values (200 steps). But at LR=1.0, Phi6 diverges
to loss 5.42 while GELU converges to 1.59.

```
  Stability score (survived + loss < 50):
    GELU: 4/4    ReLU: 4/4    SiLU: 4/4    Phi6: 4/4
```

### Test 3: Gradient Clipping Effect

| Activation | Clipping | LR   | Final Loss | Max GradNorm |
|-----------|---------|------|-----------|-------------|
| GELU      | None    | 0.01 | 3.4319    | 0.4524      |
| GELU      | 1.0     | 0.01 | 3.4319    | 0.4524      |
| GELU      | None    | 0.10 | 2.8693    | 0.4994      |
| GELU      | 1.0     | 0.10 | 2.8693    | 0.4994      |
| Phi6      | None    | 0.01 | 3.2795    | 4.2079      |
| Phi6      | 1.0     | 0.01 | 3.3885    | 4.3707      |
| Phi6      | None    | 0.10 | 1.8292    | 4.2079      |
| Phi6      | 1.0     | 0.10 | 2.2832    | 4.2079      |

Key finding: Gradient clipping **HURTS** Phi6 performance (loss increases from
1.83 to 2.28 at LR=0.1). GELU is unaffected because its gradients are already <1.

### Test 4: Gradient Norm Evolution (ASCII)

```
  Gradient Norm (y: 0..2.22, x: step 1..300, LR=0.05)
  ---------------------------------------------------------------
  2.22 |P                                             P            |
  2.01 |   P          P                     P          P      P    |
  1.81 | P    P PP PP   PPP P  P   P   P     P  P       PP  P  PPP|
  1.61 |  P PP             P PP P P P     P   P  PPPPP    PP P P  |
  1.41 |       P  P  P P         P   PP PP P   P                  P|
       |                                                           |
  0.40 |        GG G  G  GG                 G   G G   GG      G   |
  0.20 |GGGGGGGG  G GG GG  GGGGGGGGGGGGGGGGG GGG G GGG  GGGGGG GGG|
  ---------------------------------------------------------------
  Legend: G=GELU  P=Phi6
```

Phi6 gradient norms are consistently 5-10x higher than GELU throughout training.

## Interpretation

1. **Bounded OUTPUT does not mean bounded GRADIENTS**: Phi6's derivative 2x-1 can be
   as large as 3 at x=-2 (or -5 at x=-2 in absolute terms). The clamp prevents
   output explosion but the derivative is still large.

2. **Phi6 trains well DESPITE large gradients**: Higher gradient norms actually help
   learning at moderate LRs (loss converges faster). The effective learning rate is
   lr * grad_norm, so Phi6 with lr=0.01 behaves like GELU with lr=0.05.

3. **Gradient clipping hurts Phi6**: Since Phi6 relies on large gradients for fast
   convergence, clipping them removes its advantage.

4. **At very high LR (1.0), Phi6 diverges**: The combination of high LR + high gradient
   norm causes instability. GELU's naturally smaller gradients are an advantage here.

## Limitations

- 2-layer MLP only -- deep networks may show different behavior
- No BatchNorm/LayerNorm which would normalize gradient magnitudes
- Structured task may not represent real-world training dynamics

## Verification Direction

- Test on deep networks (10+ layers) where gradient explosion matters more
- Add LayerNorm and re-test
- Test with Adam optimizer (adaptive LR compensates for gradient scale)

## Grade: PARTIAL (Borderline REFUTED)

Phi6's bounded output does NOT prevent gradient explosion -- its gradients are 10x
larger than GELU. However, all activations survive all test conditions, and Phi6
actually benefits from its large gradients at moderate LRs. The hypothesis mechanism
is wrong, but the practical outcome (stability) is partially correct.

## Script

`experiments/h_ee_3_training_stability.py`
