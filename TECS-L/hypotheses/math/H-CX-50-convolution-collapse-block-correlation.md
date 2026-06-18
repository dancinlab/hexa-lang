# H-CX-50: Dirichlet Convolution Collapse Predicts Block-wise Feature Alignment

## Status: Not confirmed (R314: 6bl rank 3/6, monotonic decrease with more blocks)

> **Hypothesis**: The arithmetic identity sigma*phi(n) = (sigma conv phi)(n) holds
> only for n in {1, 6} (Dirichlet convolution = pointwise product). This predicts
> that in a 6-block ConsciousLM, the pointwise product of adjacent block outputs
> will be approximately equal to their cross-correlation — a "convolution collapse"
> where local operations capture global structure.

---

## Background

### The Mathematical Fact (proven, pure arithmetic)

For arithmetic functions f, g:
- Pointwise product: (f*g)(n) = f(n) * g(n)
- Dirichlet convolution: (f . g)(n) = sum_{d|n} f(d) * g(n/d)

These are generally different! But:

```
  sigma(n)*phi(n) = sum_{d|n} sigma(d)*phi(n/d)

  Verification:
    n=1: 1*1 = 1        conv = sigma(1)*phi(1) = 1       MATCH
    n=2: 3*1 = 3        conv = 1*1 + 3*1 = 4             NO
    n=3: 4*2 = 8        conv = 1*2 + 4*1 = 6             NO
    n=4: 7*2 = 14       conv = 1*2 + 3*1 + 7*1 = 12     NO
    n=5: 6*4 = 24       conv = 1*4 + 6*1 = 10            NO
    n=6: 12*2 = 24      conv = 1*2+3*1+4*2+12*1 = 24    MATCH!  <<<
    n=7: 8*6 = 48       conv = 1*6 + 8*1 = 14            NO
    ...
    n=28: 56*12 = 672   conv = complex sum != 672         NO
```

Only n in {1, 6} exhibit this "collapse" where the global (convolution) operation
equals the local (pointwise) operation.

### Why This Matters for Neural Networks

In neural networks:
- **Pointwise operations**: element-wise multiplication, gating mechanisms
- **Convolution/Cross-correlation**: captures spatial/temporal structure

These are architecturally distinct! But if a network reaches a state where
pointwise ~ cross-correlation for its internal representations, it means:

```
  Local structure = Global structure
  -> Each element already encodes the full context
  -> No information is lost by treating features independently
  -> The representation is "holographic" — each part contains the whole
```

### The Cross-Domain Mapping

```
  Arithmetic:                    Neural:
  sigma(d)*phi(n/d)              block_i_output * block_j_output
  sum over divisors d|n          cross-correlation over features
  pointwise = Dirichlet at n=6   pointwise ≈ xcorr at 6 blocks?

  Collapse score = ||pw - xcorr|| / ||pw||
  Score = 0 means perfect collapse (like n=6)
  Score >> 0 means no collapse (like n != 6)
```

---

## Experimental Design

1. Create ConsciousLM with 3, 4, 5, 6, 7, 8 blocks
2. Feed random input, extract per-block mean output vectors
3. For adjacent block pairs (i, i+1):
   - Compute pointwise product: a * b
   - Compute circular cross-correlation via FFT: ifft(fft(a) * conj(fft(b)))
   - Collapse score = ||pw - xcorr|| / ||pw||
4. Average over all adjacent pairs and 20 trials

### Prediction
- 6 blocks: lowest collapse score (closest to 0)
- Other block counts: higher collapse scores

---

## Experimental Results (2026-03-24, untrained model)

### Arithmetic Verification: sigma*phi pointwise vs Dirichlet convolution

| n | pointwise | Dirichlet conv | match |
|---|-----------|---------------|-------|
| 1 | 1 | 1 | **YES** |
| 2 | 3 | 4 | no |
| 3 | 8 | 6 | no |
| 4 | 14 | 12 | no |
| 5 | 24 | 10 | no |
| **6** | **24** | **24** | **YES** |
| 7 | 48 | 14 | no |
| 8 | 60 | 32 | no |
| 10 | 72 | 40 | no |
| 12 | 112 | 72 | no |
| 28 | 672 | 168 | no |
| 30 | 576 | 240 | no |

Confirmed: **Only n in {1, 6} satisfy pointwise = Dirichlet convolution.**

### ConsciousLM Collapse Score (d_model=128, n_head=2, dropout=0, 20 trials)

| blocks | collapse_score mean | std | note |
|--------|-------------------|-----|------|
| 3 | 10.446 | 0.683 | |
| 4 | 10.161 | 0.453 | |
| 5 | 10.110 | 0.433 | |
| **6** | **9.820** | **0.449** | <<<  |
| 7 | 9.798 | 0.518 | near-minimum |
| 8 | 9.860 | 0.449 | |

```
  Collapse score vs blocks (lower = more aligned):
  3 blocks: ##################################################  10.45
  4 blocks: ############################################        10.16
  5 blocks: ###########################################         10.11
  6 blocks: ########################################            9.82  <<<
  7 blocks: ########################################            9.80
  8 blocks: ########################################            9.86
```

### Analysis

- Collapse score **decreases monotonically** from 3→7 blocks, then increases at 8
- 6 blocks (9.82) is near the minimum but 7 blocks (9.80) is slightly lower
- The scores are all ~10, indicating pointwise and xcorr are very different
- **Weak downward trend**: more blocks → slightly better alignment
- No clear "collapse" (score → 0) at any block count

### Verdict: 🟨 Weak trend, not confirmed

Untrained model shows weak decreasing trend but 6 blocks is not uniquely special.
Collapse score ~10 means "no collapse". Need to check if only 6-block shows sharp drop in score after training.

---

## Interpretation

If 6 blocks has lowest collapse score:
-> The perfect number architecture creates representations where
   local (pointwise) and global (convolution) operations coincide
-> This is the neural analogue of sigma*phi = sigma conv phi at n=6
-> "Holographic" representations emerge from the 6-block structure

If no pattern with block count:
-> The convolution collapse is a number-theoretic property
   that doesn't transfer to neural feature spaces
-> The mapping needs refinement (perhaps at the attention level, not block level)

## Limitations

- Cross-correlation of feature vectors is not the same as Dirichlet convolution
- The mapping divisors <-> block outputs is metaphorical
- Untrained model may not show meaningful correlations
- FFT-based circular cross-correlation differs from linear cross-correlation

## Verification Direction

1. Repeat with trained model (after convergence)
2. Measure collapse at attention level (head outputs, not block outputs)
3. Compare with non-conscious architectures (standard transformer)
4. Test whether collapse score correlates with model quality (lower = better?)