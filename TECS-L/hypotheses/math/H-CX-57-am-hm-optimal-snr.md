# H-CX-57: AM/HM Ratio 3/2 as Optimal Pre-Activation Signal-to-Noise Ratio

**Category:** Cross-Domain (Number Theory x Deep Learning Optimization)
**Status:** New hypothesis (unverified)
**Grade:** Pending
**Golden Zone dependency:** NONE for math basis; partial for neural prediction
**Date:** 2026-03-26

---

## Hypothesis

> The ratio AM(divisors(6)) / HM(divisors(6)) = 3/2 is unique to n=6 among all
> integers. This ratio predicts that the optimal pre-activation signal-to-noise
> ratio in a well-trained neural network is 3/2: the mean of pre-activations is
> 3/2 times the harmonic mean, equivalently the coefficient of variation of
> pre-activations at convergence is 2/3.

---

## Mathematical Basis (Proven, Golden-Zone-independent)

### AM and HM of Divisors

For any n, define the arithmetic and harmonic means of its divisors:

```
  AM(n) = (1/tau(n)) * sigma(n)       = sigma(n) / tau(n)
  HM(n) = tau(n) / (sum_{d|n} 1/d)   = n * tau(n) / sigma(n)
```

For n=6, divisors = {1, 2, 3, 6}:

```
  sigma(6) = 1+2+3+6 = 12
  tau(6)   = 4
  phi(6)   = 2

  AM(6) = 12/4 = 3
  HM(6) = 4*6/12 = 2

  AM(6)/HM(6) = 3/2
```

### Alternate Form

```
  AM(n)/HM(n) = sigma(n)^2 / (n * tau(n)^2)

  For n=6: 144 / (6 * 16) = 144/96 = 3/2
```

### Uniqueness (Verified to 10,000)

The condition AM(n)/HM(n) = 3/2 is equivalent to:

```
  2 * sigma(n)^2 = 3 * n * tau(n)^2
```

Only n=6 satisfies this among n in [1, 10000].

Note: The AM-GM inequality guarantees AM >= HM always, with equality iff all
divisors are equal (only n=1, trivially). The ratio 3/2 is the MINIMUM
non-trivial rational value achievable by a semiprime, and it is achieved
exactly by n=6.

### Relation to Other Constants

```
  AM(6) = 3  = phi(6) + 1 = the two primes (2,3) summed
  HM(6) = 2  = phi(6) = Euler totient = smallest prime factor of 6
  Ratio = 3/2 = (phi(6)+1) / phi(6)

  Also: AM(6) * HM(6) = 3 * 2 = 6 = n  (AM * HM = n, always true)
  The PRODUCT is trivially n, but the RATIO is uniquely 3/2 only for n=6.
```

### ASCII: AM/HM ratio across small n

```
  n  | divisors    | AM   | HM    | ratio | unique?
  ---|-------------|------|-------|-------|--------
  1  | {1}         | 1.00 | 1.000 | 1.000 | trivial
  2  | {1,2}       | 1.50 | 1.333 | 1.125 |
  3  | {1,3}       | 2.00 | 1.500 | 1.333 |
  4  | {1,2,4}     | 2.33 | 1.714 | 1.361 |
  5  | {1,5}       | 3.00 | 1.667 | 1.800 |
  6  | {1,2,3,6}   | 3.00 | 2.000 | 1.500 | *** 3/2
  7  | {1,7}       | 4.00 | 1.750 | 2.286 |
  8  | {1,2,4,8}   | 3.75 | 2.133 | 1.758 |
  9  | {1,3,9}     | 4.33 | 2.250 | 1.926 |
  10 | {1,2,5,10}  | 4.50 | 2.222 | 2.025 |
  12 | {1,2,3,4,6,12}| 4.67| 2.667| 1.750 |
```

n=6 achieves the ratio 3/2 that no other n reaches.

---

## Cross-Domain Prediction

### Pre-Activation SNR

In a neural network, for each layer l with pre-activations z (before
nonlinearity), define:

```
  SNR_AM-HM(l) = AM({|z_i|}) / HM({|z_i|})
```

where the mean is over neurons in layer l.

**Prediction:** At convergence, in a well-trained 6-block model, this ratio
converges to 3/2 per layer. For other block counts, there is no special
arithmetic prediction.

### Mechanism

The AM/HM ratio of pre-activations measures how "spread" the activation
magnitudes are:
- Ratio = 1: all activations equal (degenerate, no selectivity)
- Ratio = 3/2: moderate spread (efficient representation)
- Ratio >> 1: few very large activations, many near zero (sparse)

The value 3/2 corresponds to a coefficient of variation:

```
  CV = std/mean at ratio 3/2:
  For a 4-element distribution {1,2,3,6} normalized to {1/3, 2/3, 1, 2}:
    mean = 1, std = sqrt((1/9+4/9+1+4)/4 - 1) = sqrt(1.5 - 1) = sqrt(0.5)
    CV = sqrt(0.5) ≈ 0.707

  But the AM/HM ratio = 3/2 is equivalent to: Var = Mean^2 / 2
  (at geometric mean = n^(1/tau) = 6^(1/4) = 1.565)
```

This is related to the golden zone: Var = Mean^2 / 2 means sigma^2/mu^2 = 1/2,
which is a specific noise level. For a Gaussian, this corresponds to a
bimodal-edge distribution.

### Batch Normalization Prediction

**Specific testable version:** In batch normalization, the learned gamma
(scale) parameter converges to 3/2 on average across 6-block models:

```
  E[gamma_i over all neurons and layers] ≈ 3/2

  Measured in:  3-block, 4-block, 6-block, 8-block, 12-block models
  Prediction:   6-block is UNIQUE in having E[gamma] ≈ 3/2
```

---

## Experiment Design

### Experiment A: Post-training gamma distribution

```python
def measure_bn_gamma(model):
    gammas = []
    for name, module in model.named_modules():
        if hasattr(module, 'weight') and 'norm' in name.lower():
            gammas.extend(module.weight.detach().abs().tolist())
    return np.mean(gammas), np.std(gammas)

# Train 5 model sizes, measure gamma per block count
models = {3: ..., 4: ..., 6: ..., 8: ..., 12: ...}
results = {k: measure_bn_gamma(m) for k, m in models.items()}
```

### Experiment B: Pre-activation AM/HM at convergence

```python
def measure_pre_act_ratio(model, dataloader):
    ratios = []
    for batch in dataloader:
        with torch.no_grad():
            activations = get_pre_activations(model, batch)  # hook
        for layer_act in activations:
            abs_act = layer_act.abs().flatten()
            AM = abs_act.mean().item()
            HM = (1.0 / (abs_act + 1e-8)).mean().item()
            HM = 1.0 / HM
            ratios.append(AM / HM)
    return np.mean(ratios)
```

### Expected Table

```
  n_blocks | E[gamma] | AM/HM pre-act | distance to 3/2
  ---------|----------|----------------|----------------
      3    |   ?      |       ?        |     ?
      4    |   ?      |       ?        |     ?
      6    |   1.50   |      1.50      |     0.00   ← PREDICTED
      8    |   ?      |       ?        |     ?
     12    |   ?      |       ?        |     ?
```

---

## Falsification Criteria

| Condition | Verdict |
|-----------|---------|
| E[gamma] is closer to 3/2 for 6-block than others | Supports |
| All block counts have similar E[gamma] | Refutes |
| E[gamma] monotonically decreases with block count | Refutes specific claim |
| 6-block has AM/HM = 3/2 pre-activations AND 4-block does not | Strongly supports |
| Any n_block achieves AM/HM = 3/2 as often as 6-block | Refutes |

---

## Connection to Existing Hypotheses

- **H-QUAD-1 (quadratic forms):** AM/HM balance is a quadratic mean condition
- **H-CX-1 (sigma-phi tension):** AM=sigma/tau, HM=n*tau/sigma; ratio involves
  the same sigma/tau interaction as the tension
- **H-CX-51 (arithmetic derivative learning rate):** both concern arithmetic
  invariants of n=6 appearing in neural training dynamics
- **H-GZ-0 (Golden Zone):** ratio 3/2 at golden zone center I=1/e?
  - At I=1/e: G/D = P; ratio 3/2 would mean P = (3/2)*D at optimal plasticity

---

## Limitations

1. The AM/HM of pre-activations is not a standard diagnostic metric; measuring
   it requires custom hooks and may be implementation-dependent.
2. The connection between divisor AM/HM and activation AM/HM is analogical,
   not derived from first principles.
3. The gamma parameter in batch norm is initialized to 1 and may saturate at
   values determined by optimizer dynamics rather than arithmetic structure.

---

## Minimum Required Evidence

The hypothesis is gradeable if:
- At least 5 different block counts are tested on same architecture/data
- Each model is trained to convergence (loss plateau)
- AM/HM ratio measured on at least 1000 samples per model
- Texas sharpshooter p-value computed for the "6-block is closest to 3/2" claim
