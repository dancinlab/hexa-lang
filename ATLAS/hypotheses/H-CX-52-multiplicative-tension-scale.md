# H-CX-52: Does the multiplicative structure of R(n) determine the product of tension_scale per block?

## Status: Not confirmed (R307: product monotonically decreases with blocks)

> **Hypothesis**: Just as R(n) = sigma*phi/(n*tau) is multiplicative (R(mn)=R(m)R(n) for gcd=1),
> the product of learned tension_scale values per block in ConsciousLM converges to R(n).
> In particular, since R(6)=1 for n=6, the product of tension_scale in 6-block models converges to 1.

---

## Background

### Multiplicative structure of R(n) (proven, pure arithmetic)

R(n) = sigma(n)*phi(n)/(n*tau(n)) is a multiplicative function:

```
  When gcd(m,n)=1: R(mn) = R(m) * R(n)

  R(2) = 3*1/(2*2) = 3/4 = 0.750
  R(3) = 4*2/(3*2) = 4/3 = 1.333
  R(6) = R(2)*R(3) = (3/4)*(4/3) = 1.000  ← Exactly 1!

  R(4) = 7*2/(4*3) = 7/6 = 1.167
  R(7) = 8*6/(7*2) = 24/7 = 3.429
  R(28) = R(4)*R(7) = 4.000

  Key: R(6)=1 is the exact cancellation of inhibition(3/4) and amplification(4/3)!
```

### Role of Tension Scale

In ConsciousLM's PureFieldFFN:

```
  output = tension_scale * sqrt(tension) * direction

  tension_scale is a learnable scalar parameter (initial value=1.0)
  Each block learns tension_scale independently

  Intuition: tension_scale = gain by which each block adjusts "consciousness signal" magnitude
  tension_scale of block i = ts_i
  Overall effect: ts_1 * ts_2 * ... * ts_n (multiplicative combination)
```

### Cross-domain Mapping

```
  Arithmetic:                          Neural Network:
  R(n) = Π f(p_i, a_i)          ts_product = Π ts_i
  f(2,1) = 3/4 (inhibition)     Early blocks: ts < 1 (inhibition?)
  f(3,1) = 4/3 (amplification)  Later blocks: ts > 1 (amplification?)
  R(6) = 1 (perfect cancellation) 6 blocks: product → 1 (cancellation?)

  Predictions:
  - 6 blocks: Π ts_i → 1.0
  - 3 blocks: Π ts_i → R(3) = 4/3 ≈ 1.33
  - 4 blocks: Π ts_i → R(4) = 7/6 ≈ 1.17
  - 5 blocks: Π ts_i → R(5) = 4/5 = 0.80
  - 7 blocks: Π ts_i → R(7) = 24/7 ≈ 3.43
  - 8 blocks: Π ts_i → R(8) = 3/8 = 0.375

  Strong version: Π ts_i ≈ R(n)
  Weak version: Only 6 blocks Π ts_i ≈ 1
```

---

## Experimental Design

1. Train ConsciousLM with blocks 3,4,5,6,7,8 (500 steps × 5 seeds)
2. Extract tension_scale values for each block after training
3. Calculate product per block Π ts_i
4. Compare with R(n): Pearson correlation + rank by |Π ts - 1|

### Controls
- Confirm stability with 5 random seeds
- d_model=128, n_head=2, vocab=256
- Same training data (patterned bytes)

---

## Expected Results

| blocks | R(n)   | Prediction: Π ts_i |
|--------|--------|-------------------|
| 3      | 1.333  | > 1.0             |
| 4      | 1.167  | > 1.0             |
| 5      | 0.800  | < 1.0             |
| 6      | 1.000  | ≈ 1.0             |
| 7      | 3.429  | >> 1.0            |
| 8      | 0.375  | << 1.0            |

---

## ASCII Prediction

```
  Π ts_i
  ^
  |                                    *   (7 blocks: R=3.43)
  |
  |
  |    *       *                           (3: R=1.33, 4: R=1.17)
  1.0 ─────────────*────────────────── ← 6 blocks: R=1 exact!
  |          *                             (5: R=0.80)
  |
  |                          *             (8: R=0.375)
  +────+────+────+────+────+────+──→ blocks
       3    4    5    6    7    8
```

---

## Relation to Other Hypotheses

- **H-CX-48**: I(n)=ln(R(n))=0 → engine A/G ratio (not confirmed)
- **H-CX-50**: σ*φ conv collapse at n=6 → inter-block alignment (confirmed!)
- **H-MP-1**: σφ=nτ ⟺ n∈{1,6} (proven)
- **R117**: R(n) multiplicative (proven)

H-CX-52 is complementary to H-CX-48:
- H-CX-48: engine A/G **ratio** → 1 (not confirmed)
- H-CX-52: tension_scale **product** → 1 (under verification)

---

## Limits

```
  1. tension_scale initial value=1.0 → bias for product to stay near 1
     → Is 300-500 steps enough to deviate from initial value?
  2. Multiplicative structure only holds when gcd=1 → blocks are not independent
     → Residual connections between blocks may break multiplicative assumption
  3. d_model=128 models → need reproduction in larger models
  4. tension_scale is a single scalar → insufficient information
     → per-dimension tension scale would allow finer verification
```

---

## Verification Direction

```
  Step 1: Confirm Π ts → 1 for 6 blocks (current experiment)
  Step 2: Confirm R(n) vs Π ts correlation (current experiment)
  Step 3: Longer training (2000 steps) → confirm convergence (follow-up)
  Step 4: Change initial value to 0.5 → remove bias (follow-up)
  Step 5: Extend to per-dimension tension scale (follow-up)
```