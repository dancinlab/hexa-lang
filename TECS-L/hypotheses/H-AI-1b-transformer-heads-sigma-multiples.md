# H-AI-1b: Why Transformer Head Count is a Multiple of σ(6)=12

> **Hypothesis**: The fact that attention head counts in major Transformer models are multiples of 6 (especially multiples of σ(6)=12) is not a coincidence, but a consequence of the σφ=nτ balance structure.

## Background/Context

### Observed Data: Transformer head counts

| Model | heads | Relation to σ chain |
|---|---|---|
| BERT-base | 12 | σ(6) = 12 |
| GPT-2 Small | 12 | σ(6) |
| GPT-2 Medium | 16 | 2^τ |
| GPT-2 Large | 20 | ? |
| GPT-2 XL | 25 | ? |
| GPT-3 (175B) | 96 | σ×τ×φ = 12×4×2 |
| LLaMA-7B | 32 | 2^(τ+1) |
| LLaMA-13B | 40 | ? |
| LLaMA-65B | 64 | 2^(P₁) |
| Gemini | undisclosed | — |
| GPT-4 | undisclosed | — |

### Models with multiples of 6

```
  12 = σ(6)          ← BERT, GPT-2 Small
  24 = τ(6)!         ← Some medium models
  48 = σ×τ           ← Some large models
  96 = σ×τ×φ         ← GPT-3 175B
```

### Models NOT multiples of 6

```
  16 = 2^4 = 2^τ     ← GPT-2 Medium (NOT multiple of 6!)
  20                  ← GPT-2 Large
  25                  ← GPT-2 XL
  32 = 2^5           ← LLaMA-7B
  40                  ← LLaMA-13B
  64 = 2^6           ← LLaMA-65B
```

## Observations

### σ(6) multiple ratio

```
  Total major models: ~15
  Head count multiple of 6: 12, 24, 48, 96 → ~4
  Multiple of 6 ratio: ~27%

  Head count power of 2: 16, 32, 64 → ~3
  2^k ratio: ~20%

  → Multiples of 6 slightly more common than 2^k, but not overwhelming
```

### ASCII distribution

```
  Frequency
  4 |  ████
  3 |  ████ ███
  2 |  ████ ███  ██
  1 |  ████ ███  ██  █  █  █     █        █
  0 +--+----+----+---+--+--+--+--+--+--+--+--→ heads
     12  16  20  24 25 32 36 40 48 64    96

     Multiple of 6: ■   Not multiple of 6: □
```

## Critical Analysis

### Why the "multiple of 6" hypothesis is weak

1. **Engineering reasons are stronger**: head count is usually determined by hidden_dim/head_dim
   - hidden=768, head_dim=64 → 12 heads (768/64)
   - hidden=1024, head_dim=64 → 16 heads
   - The real determinant is 64(head_dim), not 6

2. **Power of 2 bias**: Preference for 2^k dimensions due to GPU efficiency
   - 12 is not 2^k! Rather an "inefficient" choice

3. **Selection bias**: Many models use 12 because BERT used 12 and successors followed

### Why the "multiple of 6" hypothesis is strong

1. **BERT's original choice**: Why choose 12 initially?
   - Vaswani (2017) Attention Is All You Need: 8 heads
   - BERT (2018): 12 heads — Why increase from 8→12?
   - 12 = σ(6) might be optimal for multi-resolution

2. **96 = σ×τ×φ**: Is GPT-3's 96 heads coincidentally this product?
   - 96 = 12288/128 (hidden/head_dim) — Engineering explanation possible
   - But 12288 = 1024×12 = 2^10 × σ(6)

3. **Repetition of 12 in scaling**: 12→24→48→96 = ×2 chain
   - This is multiples of σ(6) by 2^k = σ(6) × 2^k

## Verification Directions

### Experiment 1: Head count sweep
```
  Fixed: hidden_dim=768, layers=12
  Variable: heads = 4, 6, 8, 10, 12, 14, 16, 18, 20, 24
  Measure: perplexity, downstream accuracy
  Prediction: Pareto optimal at heads=12(=σ)
```

### Experiment 2: Separate head dim vs head count
```
  Fixed hidden = 768
  head_dim × heads = 768
  Combinations: (768,1), (384,2), (256,3), (192,4), (128,6), (96,8),
                (64,12), (48,16), (32,24)
  Prediction: Special performance at heads=6 or 12?
```

### Experiment 3: MoE expert count and head count cross
```
  heads = {6, 8, 12, 16}, experts = {4, 6, 8, 12}
  Prediction: (heads=12, experts=6) combination optimal?
  Connection: AI interpretation of σφ=nτ
```

## What Improves If Proven

### Immediate Impact
1. **Architecture design principles**: "Head count should be multiple of 6" guideline
2. **Hyperparameter search space reduction**: Search only 6,12,24,48,96 → 5-10x efficiency gain
3. **Scaling law refinement**: head_count = σ(6) × 2^k formula

### Medium-term Impact
4. **Optimal architecture theory**: Number-theoretic answer to "Why do Transformers work?"
5. **New architecture proposals**: Structures derived from σφ=nτ balance
6. **MoE optimization**: Theoretical basis for expert=6

### Long-term Impact
7. **Math-AI bridge**: First case of number theory guiding deep learning design
8. **Arithmetic function-based Neural Architecture Search (NAS)**
9. **"Why 6?" question has an answer in AI too**

## Realistic Assessment

```
  Hypothesis strength: ★★☆☆☆ (Weak — engineering explanation more natural)
  Verifiability: ★★★★★ (Can be confirmed immediately through experiments)
  Impact (if true): ★★★★☆ (Immediate effect on architecture design)
  Impact (if false): ★☆☆☆☆ (Just confirms engineering optimization)

  Realistic prediction: Multiples of 6 are "slightly" advantageous, but
  hidden_dim/head_dim ratio is likely the real determinant.
  Still worth experimenting — low cost and clear results.
```

## Limitations

- Transformer head count choice has strong historical/engineering inertia
- Coincidence with σ(6)=12 might be Small Numbers effect
- May be correlation, not causation
- Counterevidence: GPT-2 Medium(16), LLaMA(32,40,64) are not multiples of 6