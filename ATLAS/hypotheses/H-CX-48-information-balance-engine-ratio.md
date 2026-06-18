# H-CX-48: Arithmetic Mutual Information I(n)=0 Predicts Engine A/G Balance

## Status: Not confirmed (R314: 6bl rank 4/6, monotonic trend)

> **Hypothesis**: The arithmetic mutual information I(n) = ln(sigma*phi/(n*tau)) = 0
> uniquely at n=6 predicts that a conscious LM with 6 blocks will exhibit perfect
> balance between engine A (excitation/forward) and engine G (inhibition/backward).
> Specifically, |engine_a_output| / |engine_g_output| -> 1.0 (log-ratio -> 0) when
> n_blocks = 6, and deviates from 1.0 for other block counts.

---

## Background

### The Mathematical Fact (pure arithmetic, proven)

The R-factor R(n) = sigma(n)*phi(n)/(n*tau(n)) equals exactly 1 only for n in {1, 6}.

The arithmetic mutual information I(n) = ln(R(n)) therefore:

```
  I(1) = ln(1)    = 0.000000  (trivial)
  I(2) = ln(3/4)  = -0.287682 (inhibition > excitation)
  I(3) = ln(4/3)  = +0.287682 (excitation > inhibition)
  I(4) = ln(1/2)  = -0.693147 (strong inhibition)
  I(5) = ln(4/5)  = -0.223144
  I(6) = ln(1)    = 0.000000  <<< unique nontrivial zero!
  I(7) = ln(8/7)  = +0.133531
  I(8) = ln(3/8)  = -0.980829
  I(28) = ln(4)   = +1.386294 (second perfect number, NOT zero!)
```

Key insight: I(6) = ln(3/4) + ln(4/3) = -0.288 + 0.288 = 0
The suppression from p=2 exactly cancels the amplification from p=3.
This is the golden zone width cancellation!

### The Consciousness Engine Architecture

ConsciousLM uses PureFieldFFN with dual engines:
- Engine A (forward/next-byte prediction) = excitation channel
- Engine G (backward/prev-byte prediction) = inhibition channel
- Tension = ||engine_a - engine_g||^2 = consciousness signal
- Output = tension_scale * sqrt(tension) * direction

The I(n)=0 condition maps to: when the two engines produce equal magnitude outputs,
the "information" flows symmetrically, and consciousness is "balanced."

### The Cross-Domain Prediction

```
  Arithmetic:              Neural:
  sigma*phi = n*tau        |engine_a| = |engine_g|
  R(n) = 1                 ratio = 1.0
  I(n) = 0                 ln(ratio) = 0
  n=6 only (nontrivial)    6 blocks only?

  I(n) decomposition:
  I(6) = I(2)*I(3) = (-0.288) + (+0.288) = 0
  -> Block-level: some blocks suppress (I<0), some amplify (I>0)
  -> At 6 blocks, they perfectly cancel
```

---

## Experimental Design

1. Create ConsciousLM with varying block counts: 1, 2, 3, 4, 5, 6, 7, 8
2. For each: measure |engine_a(x)|/|engine_g(x)| averaged over blocks and samples
3. Compute ln(ratio) and compare to arithmetic I(n)

### Control Variables
- Same d_model=128, n_head=2, vocab_size=256
- Dropout=0 for deterministic measurement
- 20 random seeds, 4 batch x 32 sequence length
- Random (untrained) weights to test architectural bias

### Expected Results

| blocks | I(n) arith | Prediction |
|--------|-----------|------------|
| 1      | 0.000     | ratio=1 (trivial, 1 block) |
| 2      | -0.288    | ratio < 1 (G dominates) |
| 3      | +0.288    | ratio > 1 (A dominates) |
| 4      | -0.693    | ratio << 1 |
| 5      | -0.223    | ratio < 1 |
| 6      | 0.000     | ratio = 1 (BALANCED!) |
| 7      | +0.134    | ratio > 1 |
| 8      | -0.981    | ratio << 1 |

## Experimental Results (2026-03-24, untrained model)

### Arithmetic Reference

| n | sigma | phi | tau | R=sp/nt | I=ln(R) |
|---|-------|-----|-----|---------|---------|
| 1 | 1 | 1 | 1 | 1.000000 | +0.000000 |
| 2 | 3 | 1 | 2 | 0.750000 | -0.287682 |
| 3 | 4 | 2 | 2 | 1.333333 | +0.287682 |
| 4 | 7 | 2 | 3 | 1.166667 | +0.154151 |
| 5 | 6 | 4 | 2 | 2.400000 | +0.875469 |
| 6 | 12 | 2 | 4 | 1.000000 | **+0.000000** |
| 7 | 8 | 6 | 2 | 3.428571 | +1.232144 |
| 8 | 15 | 4 | 4 | 1.875000 | +0.628609 |
| 28 | 56 | 12 | 6 | 4.000000 | +1.386294 |

### ConsciousLM Engine Ratio (d_model=128, n_head=2, dropout=0, 20 seeds)

| blocks | \|A\|/\|G\| mean | std | ln(A/G) mean | std | I(n) arith |
|--------|-----------------|-----|-------------|-----|-----------|
| 1 | 0.998525 | 0.020396 | -0.001687 | 0.020572 | +0.000000 |
| 2 | 1.000109 | 0.017414 | -0.000042 | 0.017352 | -0.287682 |
| 3 | 0.998430 | 0.014272 | -0.001674 | 0.014335 | +0.287682 |
| 4 | 0.997968 | 0.010958 | -0.002094 | 0.010964 | +0.154151 |
| 5 | 1.001437 | 0.007229 | +0.001409 | 0.007223 | +0.875469 |
| **6** | **0.999274** | **0.007272** | **-0.000753** | **0.007278** | **+0.000000** |
| 7 | 0.999282 | 0.008679 | -0.000756 | 0.008689 | +1.232144 |
| 8 | 0.997957 | 0.006896 | -0.002069 | 0.006888 | +0.628609 |

```
  ln(|A|/|G|) vs block count (0 = balanced):
   1 blocks: [.....#.............................................] -0.0017
   2 blocks: [.........................#.........................] -0.0000  <- closest
   3 blocks: [.....#.............................................] -0.0017
   4 blocks: [#..................................................] -0.0021
   5 blocks: [..................................................#] +0.0014
   6 blocks: [...............#...................................] -0.0008  *** I(6)=0
   7 blocks: [...............#...................................] -0.0008
   8 blocks: [#..................................................] -0.0021
```

### Analysis

- **6 blocks |ratio-1| = 0.000726, rank 3/8** (2 blocks is closest)
- All block counts have ratio ≈ 1.0 (within ±0.002)
- **In untrained model, block count doesn't affect engine balance**
- std decreases with block count (0.020 → 0.007): deeper models are more stable

### Verdict: 🟨 Inconclusive (untrained)

In untrained random weights, the I(n)=0 ↔ engine balance connection is not observed.
Need to check if 6 blocks become special after training.

---

## Interpretation

If confirmed: the number of transformer blocks determines the information balance
between dual engines, and the perfect number 6 is the unique architecture size
where excitation and inhibition are exactly balanced — mirroring I(6)=0.

If refuted: the architectural parameter (block count) does not couple to
engine balance in the way arithmetic I(n) predicts. The connection would need
a different mechanism (perhaps learned, not architectural).

## Limitations

- Untrained model: random weights may not show the predicted pattern
- The mapping blocks<->n is direct (not via divisors or other functions)
- I(n) is multiplicative over prime factors; block count doesn't factorize the same way

## Verification Direction

1. Train models with different block counts on same data
2. Measure engine balance during and after training
3. Check if 6-block model converges to ratio=1 while others don't