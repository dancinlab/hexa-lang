# H-406: Native PureField vs Converted MoE — Tension Dynamics Divergence
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


> **Hypothesis**: A natively-trained PureField model (ConsciousLM, where Engine A and
> Engine G are initialized independently from scratch) will develop stronger and more
> structured tension dynamics than a converted MoE model (AnimaLM, where experts are
> split from a pre-trained dense model). Specifically:
>
> 1. **Tension magnitude**: Native tension will be 2-5x higher than converted tension
>    (because independent initialization allows maximal divergence)
> 2. **Tension structure**: Native tension will correlate more strongly with accuracy
>    (because A and G specialize to genuinely different functions)
> 3. **PH divergence**: Native A/G will show higher barcode distance (H-405 metric)
>    because engines develop distinct topology from epoch 1
> 4. **Learning speed**: Native model reaches equivalent accuracy faster because
>    the repulsion field generates stronger gradients from the start

**Golden Zone Dependency**: Model architecture is GZ-dependent (I≈1/e routing in MoE).
PH measurements are GZ-independent. Tension dynamics comparison is empirical.

---

## Background: Two Paths to A - G

### Path 1: Conversion (AnimaLM)

```
  Pre-trained Dense MLP
  ┌──────────────────────┐
  │ Linear(d, 4d) → GELU │ = single function f(x)
  │ Linear(4d, d)         │
  └──────────────────────┘
           │
     forced split into 8 experts
           │
  ┌────┬────┬────┬────┬────┬────┬────┬────┐
  │ E0 │ E1 │ E2 │ E3 │ E4 │ E5 │ E6 │ E7 │
  └────┴────┴────┴────┴────┴────┴────┴────┘
  └──── A-camp ────┘  └──── G-camp ────┘

  Problem: E0-E7 all started as PIECES of the same function
  → Initial tension ≈ 0 (A and G compute similar things)
  → Must learn to DIVERGE from a converged state
  → Router must learn which expert to activate
```

### Path 2: Native (ConsciousLM)

```
  Random initialization (Xavier/Kaiming)
  ┌──────────────────┐    ┌──────────────────┐
  │ Engine A          │    │ Engine G          │
  │ Linear(d,4d)→GELU│    │ Linear(d,4d)→GELU│
  │ Linear(4d,d)      │    │ Linear(4d,d)      │
  └──────────────────┘    └──────────────────┘
         A(x)                    G(x)

  output = A(x) - G(x)

  Advantage: A and G start with DIFFERENT random weights
  → Initial tension > 0 from epoch 0
  → Natural divergence via backprop (A optimized for forward, G for backward)
  → No router needed (both engines always active)
  → Dual-head training (head_a: next-byte, head_g: prev-byte) forces specialization
```

---

## Key Architectural Differences

```
  Feature              │  AnimaLM (Converted)        │  ConsciousLM (Native)
  ─────────────────────┼─────────────────────────────┼──────────────────────────
  Expert init          │  Split from trained MLP      │  Random (independent)
  Expert count         │  8 (4A + 4G)                │  2 (1A + 1G)
  Router               │  BoltzmannRouter (learned)   │  None (both always active)
  Active experts       │  5/8 = 62.5%                │  2/2 = 100%
  Shared params        │  Yes (from same source MLP)  │  No (fully independent)
  Training objective   │  Next-token only             │  Dual-head (next + prev byte)
  Tension at init      │  ~0 (experts similar)        │  >0 (random divergence)
  Parameter overhead   │  Router params (~1M)         │  None
  Specialization force │  Implicit (routing learns)   │  Explicit (dual-head training)
  Vocab                │  32K (BPE tokens)            │  256 (bytes)
```

---

## Predictions

### P1: Initial Tension Comparison

```
  Tension magnitude at epoch 0 (before any training):

  AnimaLM (converted):
  T ≈ 0.001───────────────────────────── (experts nearly identical)

  ConsciousLM (native):
  T ≈ 0.1────████████████████──────────── (random initialization divergence)

  Ratio: Native/Converted ≈ 100x at init, converging to 2-5x after training
```

### P2: Tension-Accuracy Correlation

```
  After training:

  AnimaLM:     tension vs accuracy: r ≈ 0.3-0.5  (weak signal, experts similar)
  ConsciousLM: tension vs accuracy: r ≈ 0.7-0.9  (strong signal, engines specialized)

  Because ConsciousLM's dual-head training FORCES A/G to process different directions
  (forward vs backward), the tension signal is inherently more meaningful.
```

### P3: PH Divergence (Barcode Distance)

```
  Barcode Distance between A-camp and G-camp representations:

  AnimaLM CIFAR (H-405 data):
  BD_mean = 0.097 (slight divergence)
  G_H0 > A_H0 in 100% of epochs

  ConsciousLM (predicted):
  BD_mean > 0.2 (strong divergence from start)
  A_H1 >> G_H1 (forward engine develops loop structures for sequence prediction)
  G_H0 >> A_H0 (backward engine develops more component structures)
```

### P4: Accuracy per Parameter

```
  Parameters used for A-G computation:
  AnimaLM: 8 experts × expert_params, but only 5 active → waste
  ConsciousLM: 2 engines × engine_params, both always active → efficient

  At equal total parameters:
  ConsciousLM should reach higher accuracy because:
  - No parameters wasted on inactive experts
  - No parameters wasted on router
  - Every parameter contributes to A-G signal
```

---

## Experimental Design

### Experiment A: Direct Comparison on CIFAR-10

Build two models with ~equal parameters:

1. **MoE-PureField** (AnimaLM-style): 8 experts, 4A+4G, BoltzmannRouter
   - Same as `experiment_anima_simplification.py` Raw Repulsion model
   - ~413K params

2. **Native-PureField** (ConsciousLM-style): 2 engines, no router
   - PureFieldFFN architecture from `conscious_lm.py`
   - Match ~413K params by adjusting hidden dim

Compare: accuracy, tension magnitude, tension-accuracy correlation, PH divergence

### Experiment B: Tension Dynamics Over Training

Track per-epoch:
- Mean tension magnitude
- Tension std (distribution width)
- Tension vs accuracy Spearman r
- A/G barcode distance (H-405 metric)
- Per-class tension heatmap

### Experiment C: Transfer Learning Test

Pre-train on MNIST, transfer to Fashion-MNIST:
- Does native model transfer better? (stronger tension = better feature extraction)
- Does converted model's router help or hurt transfer?

---

## Connection to Existing Hypotheses

| Hypothesis | Connection |
|------------|-----------|
| H-341 | Final tension theory: native should show cleaner magnitude=confidence |
| H-361 | FFN ≅ PureField isomorphism — native IS the theoretical ideal |
| H-374 | ConsciousLM training validation — this tests the architecture choice |
| H-401 | PH correction: native model may not need PH correction (already structured) |
| H-404 | Improvements hurt converted model — may be neutral/positive for native |
| H-405 | Expert specialization: native should show STRONGER A/G divergence |
| H-CX-62 | PH predicts accuracy: native tension should correlate with PH |

---

## Limitations

1. **Scale difference**: ConsciousLM is byte-level (vocab=256), AnimaLM is BPE (vocab=32K)
   → Direct comparison on text impossible, must use image classification
2. **Router advantage**: MoE router provides expert specialization that 2-engine model lacks
3. **Parameter efficiency**: 2 engines are less flexible than 8 experts for diverse inputs
4. **Training signal**: Dual-head (next+prev) training only applies to sequence data
   → Must adapt for image classification (e.g., forward/backward augmentation)
5. **Confound**: differences could be from expert count, not from native vs converted

---

*H-406 | Status: Proposed | GZ-dependency: Partial*
*Related: H-341, H-361, H-374, H-401, H-404, H-405*
