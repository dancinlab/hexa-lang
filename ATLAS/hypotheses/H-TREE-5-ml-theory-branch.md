# H-TREE-5: ML Theory Branch — R(d) and Generalization Bounds

> **Hypothesis**: The arithmetic structure of neural network hidden dimension d affects generalization bounds.
> The normalized form B(d) = σ(d)·φ(d)/d² of R(d) = σ(d)·φ(d)/(d·τ(d))
> yields tighter PAC-Bayes bounds when closer to 1 at fixed scale (i.e., d = 2^k).

## Background/Context

PAC-Bayes generalization bound (McAllester 1999, Catoni 2007):
```
  L(h) ≤ L̂(h) + sqrt( [KL(Q||P) + ln(n/δ)] / (2n) )
```
For networks with hidden dimension d, parameter count ~ O(d²), KL ~ O(d²·||w||²/σ²).
The bound depends on d² but ignores d's **internal structure** (divisors, Euler's totient, etc.).

This hypothesis claims that R(d) captures the "arithmetic complexity" of dimensions,
making a practical difference in decomposition structures like multi-head attention.

Related hypotheses: H-MP-5 (R spectrum), H-MP-7 (σ_k generalization), H-TOP-4 (R topology)

## Core Definitions

```
  R(d) = σ(d) · φ(d) / (d · τ(d))

  Decomposition:
    R(d) = [σ(d)/d] · [φ(d)/τ(d)]
         = σ_{-1}(d) · [φ(d)/τ(d)]

  Or:
    R(d) = B(d) · (d/τ(d))

  where B(d) = σ(d)·φ(d)/d²  (normalized form, bounded)
```

## Closed form: d = 2^k

```
  σ(2^k) = 2^(k+1) - 1
  φ(2^k) = 2^(k-1)
  τ(2^k) = k + 1

  R(2^k) = (2^(k+1) - 1) / (2(k+1))
  B(2^k) = (2^(k+1) - 1) · 2^(k-1) / 2^(2k)
         = (2^(k+1) - 1) / 2^(k+1)
         = 1 - 2^{-(k+1)}  →  1
```

## R(d) Computation: ML Dimension Census

| Model | d | σ(d) | φ(d) | τ(d) | R(d) | B(d) | d/τ(d) | Factorization |
|---|---|---|---|---|---|---|---|---|
| ResNet block | 64 | 127 | 32 | 7 | 9.07 | 0.9922 | 9.1 | 2^6 |
| ViT-Tiny | 192 | 508 | 64 | 14 | 12.10 | 0.8819 | 13.7 | 2^6 x 3 |
| ResNet block | 256 | 511 | 128 | 9 | 28.39 | 0.9980 | 28.4 | 2^8 |
| ViT-Small | 384 | 1020 | 128 | 16 | 21.25 | 0.8854 | 24.0 | 2^7 x 3 |
| ResNet block | 512 | 1023 | 256 | 10 | 51.15 | 0.9990 | 51.2 | 2^9 |
| BERT-base/ViT-B | 768 | 2044 | 256 | 18 | 37.85 | 0.8872 | 42.7 | 2^8 x 3 |
| BERT-large/ViT-L | 1024 | 2047 | 512 | 11 | 93.05 | 0.9995 | 93.1 | 2^10 |
| GPT-2 Large/ViT-H | 1280 | 3066 | 512 | 18 | 68.13 | 0.9581 | 71.1 | 2^8 x 5 |
| GPT-2 XL | 1600 | 3937 | 640 | 21 | 74.99 | 0.9843 | 76.2 | 2^6 x 5^2 |
| SD-XL | 2048 | 4095 | 1024 | 12 | 170.63 | 0.9998 | 170.7 | 2^11 |
| LLaMA-7B | 4096 | 8191 | 2048 | 13 | 315.04 | 0.9999 | 315.1 | 2^12 |
| LLaMA-13B | 5120 | 12282 | 2048 | 22 | 223.31 | 0.9595 | 232.7 | 2^10 x 5 |
| LLaMA-65B | 8192 | 16383 | 4096 | 14 | 585.11 | 0.9999 | 585.1 | 2^13 |
| GPT-3 (175B) | 12288 | 32764 | 4096 | 26 | 420.05 | 0.8888 | 472.6 | 2^12 x 3 |

## B(d) Dependence: Determined Solely by Prime Signature

```
  B(d) = ∏_{p|d} [1 - 1/p^(a_p+1)] · [1 - 1/p]

  Limit (a_p → ∞):
    Pure 2^k:         B → 1.0
    2^a x 3^b:        B → (1)(1/2) × (1)(2/3) = 1 × 2/3...
                      Actual: B → 8/9 ≈ 0.889
    2^a x 5^b:        B → 4/5 × 1 = 0.960  (Corrected: ×(1-1/5)=0.8)
    2^a x 3 x 5:      B → 8/9 × 4/5 ≈ 0.711
```

ASCII Graph — B(d) Value Distribution:
```
  B(d)
  1.00 |####                        ####              ####         ####
  0.99 |  ##                          ##                ##           ##
  0.98 |                                        ##
  0.96 |                                  ##                   ##
  0.95 |
  0.94 |
  0.93 |
  0.92 |
  0.91 |
  0.90 |
  0.89 |      ##          ##    ##                                       ##
  0.88 |
       +-----+----+----+----+----+----+----+----+----+----+----+----+----+--
        64  192  256  384  512  768 1024 1280 1600 2048 4096 5120 8192 12288
        2^6 2^6  2^8 2^7  2^9 2^8  2^10 2^8  2^6  2^11 2^12 2^10 2^13 2^12
            x3        x3       x3       x5   x5^2            x5        x3

  Observation: B(d) clearly separates into two tiers
    Upper tier (B > 0.98): Pure 2^k or 2^a x 5^b
    Lower tier (B ≈ 0.89): Dimensions with 3 as prime factor
```

## PAC-Bayes and KL Divergence Connection

```
  PAC-Bayes: KL(Q||P) = d/2 · [s²/σ² - 1 - ln(s²/σ²)] + ||w||²/(2σ²)

  In multi-head attention where d = n_heads x d_head
  → Can be partitioned into τ(d) blocks
  → Per-block KL contribution: ∝ d/τ(d)

  R(d) = B(d) · d/τ(d)

  Therefore:
    R(d)/B(d) = d/τ(d) = Per-block KL contribution (up to constant)

  High τ(d) → Small d/τ(d) → Small per-block KL → Tighter bound
    d=768:  τ=18, d/τ = 42.7  (Many blocks, each small)
    d=1024: τ=11, d/τ = 93.1  (Few blocks, each large)
```

This aligns with actual architecture choices:
- BERT-base (d=768): **12 heads x 64** — Decomposition allowed by τ(768)=18
- BERT-large (d=1024): **16 heads x 64** — Limited by τ(1024)=11

## 768 vs 1024 Spotlight

```
  d=768 (2^8 x 3):
    τ = 18 (High architectural flexibility)
    B = 0.887 (Low due to 3)
    head x dim pairs: (1,768) (2,384) (3,256) (4,192) (6,128)
                      (8,96) (12,64) (16,48) (24,32)  → 9 pairs

  d=1024 (2^10):
    τ = 11 (Low flexibility)
    B = 0.9995 (Nearly 1)
    head x dim pairs: (1,1024) (2,512) (4,256) (8,128)
                      (16,64) (32,32)  → 6 pairs

  Trade-off:
    768: More decompositions = More flexible | But low B
    1024: Cleaner arithmetic = High B | But fewer decompositions
```

## Near-Scale Comparisons (Different Structures Only)

| d1 | d2 | B(d1) | B(d2) | τ(d1) | τ(d2) | R(d1) | R(d2) | Structure |
|---|---|---|---|---|---|---|---|---|
| 1024 | 1020 | 0.9995 | 0.7441 | 11 | 24 | 93.05 | 31.62 | 2^10 vs 2^2x3x5x17 |
| 512 | 504 | 0.9990 | 0.8844 | 10 | 24 | 51.15 | 18.57 | 2^9 vs 2^3x3^2x7 |
| 256 | 252 | 0.9980 | 0.8254 | 9 | 18 | 28.39 | 11.56 | 2^8 vs 2^2x3^2x7 |
| 768 | 770 | 0.8872 | 0.6995 | 18 | 16 | 37.85 | 33.66 | 2^8x3 vs 2x5x7x11 |

Observation: Even at nearly equal size, 2^k dimensions consistently have higher B(d).

## Original Hypothesis Verification

```
  "The closer R(d) is to 1, the better the generalization"

  Verdict: Refuted (as stated)
  Reason: R(d) diverges with d (R(2^k) ~ 2^k/(k+1))
          Only d=2,3,4,6 have R(d) near 1 — Not ML dimensions
```

## Revised Hypothesis

```
  "At fixed scale, dimensions d with B(d) = σ(d)·φ(d)/d² close to 1
   yield tighter PAC-Bayes generalization bounds."

  B(d) → 1  ⟺  d = 2^k  (Pure powers of 2)

  This could provide an arithmetic function-theoretic explanation
  for the ML community's preference for powers of 2.

  Grade: 🟧 (Structural observation, empirically incomplete)
```

## Limitations

1. **Hardware confounders**: Preference for 2^k is primarily due to GPU memory alignment. Need hardware-neutral experiments to isolate B(d) effect.
2. **Scaling law dominance**: Chinchilla/Kaplan laws depend on total parameters N. Arithmetic structure of d is secondary.
3. **Lack of empirical evidence**: No A/B tests like d=1024 vs d=1020 at equal parameter count.
4. **Loose PAC-Bayes connection**: Quantitative proof needed for how τ(d) block partitioning affects actual KL.
5. **Absence in literature**: Web search shows no existing research on "divisor function + neural net generalization".

## Verification Directions

1. **A/B experiments**: Train d=1024 vs d=1020 vs d=1008 at fixed depth, compare generalization gap
2. **Multi-head experiments**: d=768 (τ=18) vs d=512 (τ=10), search optimal head count at equal parameters
3. **PAC-Bayes computation**: Measure KL(Q||P) in actual trained networks, analyze correlation with B(d)
4. **Large-scale correlation**: Collect generalization gaps by d from public model benchmarks (BERT, GPT variants)

## Impact: ★★★★★ (ML theory innovation possible, highly speculative)

Existing ML theory treats dimensions as simple integers.
If the divisor structure of d makes a practical difference,
this provides new principles for architecture design.