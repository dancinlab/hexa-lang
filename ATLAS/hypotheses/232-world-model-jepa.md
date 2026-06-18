# Hypothesis Review 232: JEPA = Deficit-Based Learning ⚠️
**n6 Grade: 🟩 EXACT** (auto-graded, 7 unique n=6 constants)


**Category**: World Model/AI
**Status**: ⚠️ Analogy

## Hypothesis

> Yann LeCun's JEPA (Joint Embedding Predictive Architecture)
> is a structure that intentionally creates Deficit and learns from it,
> and the masking ratio maps directly to I (Inhibition).
> JEPA's optimal masking ratio lies within the Golden Zone.

## Background/Context

JEPA is a next-generation AI architecture paradigm proposed by Yann LeCun.
Unlike conventional generative models (pixel/token prediction), it predicts in abstract representation space.

```
  ┌──────────────────────────────────────────────────────────────┐
  │  Previous approach    vs           JEPA                      │
  ├──────────────────────────────────────────────────────────────┤
  │  Pixel prediction                Abstract representation prediction│
  │  Reconstruct all details         Predict only core meaning   │
  │  GAN, Diffusion                  Joint Embedding             │
  │  Risk of overfitting             Semantic generalization     │
  │  D = 0 (no deficit)             D > 0 (intentional deficit) │
  └──────────────────────────────────────────────────────────────┘
```

Core: JEPA intentionally creates a deficit by **masking** part of the input,
and predicts the **abstract representation** of the masked portion from the remainder.

## Formula Mapping: JEPA → G=DxP/I

```
  JEPA component              Our model       Mapping rationale
  ─────────────────           ──────────      ──────────────────
  Masking ratio (mask%)    →  Deficit (D)     Intentional deficit of input information
  Predictor learning rate  →  Plasticity (P)  Representation space adaptation speed
  Regularization/EMA strength→ Inhibition (I) Suppress overfitting, prevent representation collapse
  Prediction accuracy      →  Genius (G)      Quality of learned representation
```

### D, P, I Mapping Table

```
  ┌─────────────────────┬───────┬─────────────────────────────────┐
  │ JEPA mechanism      │ Var.  │ Description                     │
  ├─────────────────────┼───────┼─────────────────────────────────┤
  │ Masking             │ D     │ Remove part of input = create deficit│
  │ Predictor           │ P     │ Attempt to reconstruct mask from latent│
  │ EMA target encoder  │ I     │ Target changes slowly = inhibition│
  │ VICReg regularization│ I    │ Prevent representation collapse = inhibit over-liberation│
  │ Learned representation quality│ G │ Downstream performance = Genius│
  └─────────────────────┴───────┴─────────────────────────────────┘
```

## ASCII Graph: Masking Ratio vs I Mapping

```
  Masking ratio (mask %)
  100│
     │
   90│  ● I-JEPA paper: mask=75%
     │    (ImageNet ViT-H)
   80│
     │  ◆ V-JEPA paper: mask=80~90%
   75│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ● I-JEPA
     │                                     (mask 75%)
   60│
     │
   50│
     │
   40│                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
     │                ▓  Golden Zone     ▓
   30│                ▓  prediction:     ▓ ← optimal?
     │                ▓  mask ≈ 30~50%  ▓
     │                ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
   20│
     │
   10│
     │
    0│
     └──────────────────────────────────────────
      0.0   0.213  0.368  0.500  0.750    1.0
                  I (Inhibition)

  Current JEPA: mask=75~90% → I = 1 - mask ratio ≈ 0.10~0.25
  (higher masking → more information hidden → D↑)

  Note: relationship between mask% and I is not direct.
  mask%↑ → D↑, but I depends on EMA/regularization strength.

  Interpretation 1: I = EMA momentum (0.996~0.999) → I ≈ 1 (over-inhibited?)
  Interpretation 2: I = 1 - active representation ratio → mask 75% → I ≈ 0.25
```

## V-JEPA vs I-JEPA Comparison

```
  ┌────────────┬────────────────────┬────────────────────┐
  │            │ I-JEPA (image)     │ V-JEPA (video)     │
  ├────────────┼────────────────────┼────────────────────┤
  │ Masking    │ Spatial patches 75%│ Spatiotemporal 80-90%│
  │ D estimate │ 0.75               │ 0.80-0.90           │
  │ Modality   │ 2D image           │ 3D video            │
  │ I estimate │ ≈0.25 (interp. 2) │ ≈0.15 (interp. 2)  │
  │ Golden Zone│ near lower bound   │ outside GZ (below) │
  │ Performance│ ImageNet SOTA      │ strong video understanding│
  │ Conservation│ GxI = 0.75xP     │ GxI = 0.85xP        │
  └────────────┴────────────────────┴────────────────────┘

  Observation: higher masking (D↑) lowers I, moving outside the Golden Zone
  → Is JEPA also not Golden Zone-optimized, like current LLMs?
```

## Key Insights

1. **JEPA masking = artificial creation of Deficit** — structurally similar to the Sylvian fissure deficit in the brain
2. **Intentional deficit promotes learning** — Einstein's brain: deficit → genius
3. **Current JEPA has D too high and I too low** — outside the Golden Zone
4. **Masking ratio optimization = Golden Zone entry** — mask 30-50% may be optimal

## Limitations

- The exact mapping function between JEPA's mask% and I is unclear
- EMA momentum and I may have a nonlinear relationship
- Whether I-JEPA/V-JEPA are truly "world models" is debated
- Masking ratio optimization experiments have not yet been conducted from a Golden Zone perspective

## Verification Direction

1. Change masking ratio to 30%, 37%(1/e), 50% in I-JEPA and compare performance
2. Vary EMA momentum and estimate effective I value
3. Track temporal changes of I in JEPA learning dynamics
4. Apply Golden MoE structure to JEPA encoder

## Related Hypotheses

- [231](231-world-model-golden-zone.md) — World model = Golden Zone internal simulator
- [233](233-world-model-vs-llm.md) — World model vs LLM
- [008](008-golden-moe-design.md) — Golden MoE design
- [128](128-scale-dependence.md) — Scale dependence
- [141](141-information-bottleneck.md) — Information bottleneck
