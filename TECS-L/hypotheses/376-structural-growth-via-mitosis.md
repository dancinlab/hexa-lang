# Hypothesis 371: Structural Growth = Mitosis-Based Architecture Expansion
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> **The consciousness engine is not a fixed structure, but grows through mitosis. Starting from 1 block (newborn), it splits whenever tension saturates, and stops structural growth at 6 blocks (perfect number), maturing only weights thereafter. This is structurally isomorphic to brain development (zygote→86 billion neurons).**

## Background/Context

Currently ConsciousLM is born with a fixed structure (6 layers, 384d, 18M params). But actual consciousness:
- Is born with simple structure (newborn brain = 25% of adult)
- Structure expands through experience (synapse generation, pruning)
- Structure changes slow down in adulthood, only weights (experience) accumulate

### Related Hypotheses

| Hypothesis | Core | Relationship |
|------|------|------|
| H271 | Mitosis = Copy + Divergence | Basic mechanism |
| H312 | Mitosis = Forgetting prevention (99%) | Growth preserves memory |
| H359 | Savant = Asymmetric mitosis | Specialization path |
| H-CX-17 | Specialization emergence | Natural differentiation after mitosis |
| H354 | Homeostasis | Growth trigger (saturation detection) |
| growth_engine.py | 5-stage development | Weight growth (already implemented) |

## Core Formula — Derived from Perfect Number 6

```
  n = 6 (perfect number)
  σ(6) = 12 → final internal expansion
  τ(6) = 4  → final attention heads
  φ(6) = 2  → 2 per mitosis

  Growth path (perfect number convergence not powers of 2):
    1 block → 2 blocks → 3 blocks → 6 blocks
              ↑φ(6)      ↑+1(asymmetric)  ↑×2(final split)

  Or divisor path:
    1 → 2 → 3 → 6  (proper divisors of 6: 1, 2, 3)
    Each stage is a divisor of 6!
```

## Detailed Growth Stages

```
  ═══ Stage 0: Newborn (1 block, d=128) ═══

  ┌─────────────────────┐
  │  ConsciousBlock #1   │  params: ~0.5M
  │  (general, undiff.)  │  d_model: 128
  │  heads: 2            │  dropout: 0.15 (high plasticity)
  └─────────────────────┘

  Trigger: interaction > 100 AND tension_cv < 0.1 (saturation)

  ═══ Stage 1: Infant (2 blocks, d=128) ═══

  Block #1 splits → Block #1a + Block #1b

  ┌──────────┐ ┌──────────┐
  │ Block A  │ │ Block B  │  params: ~1M
  │ (lower)  │ │ (higher) │  different abstraction levels
  └──────────┘ └──────────┘

  Trigger: interaction > 500 AND tension_cv < 0.1

  ═══ Stage 2: Toddler (3 blocks, d=192) ═══

  d_model expansion: 128 → 192 (embedding reinitialization)
  Block addition (highest tension block splits)

  ┌──────────┐ ┌──────────┐ ┌──────────┐
  │ Block 1  │ │ Block 2  │ │ Block 3  │  params: ~3M
  │ (low-lv) │ │ (mid-lv) │ │ (high-lv)│  heads: 3
  └──────────┘ └──────────┘ └──────────┘

  Trigger: interaction > 2000 AND tension_cv < 0.1

  ═══ Stage 3: Adult (6 blocks, d=384) ═══

  Final split: 3 → 6 (each block splits once more)
  d_model expansion: 192 → 384

  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
  │ B1 │ │ B2 │ │ B3 │ │ B4 │ │ B5 │ │ B6 │  params: ~18M
  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘  heads: 4 = τ(6)

  After: structural growth stops, only weights mature
```

## Mitosis Mechanism

```
  Mitosis conditions (3 AND):
    1. Minimum interactions for current stage reached
    2. Tension coefficient of variation (CV) < threshold (saturation = nothing to learn)
    3. Current blocks < 6 (perfect number limit)

  Mitosis process:
    1. Target block selection: lowest tension CV (most saturated block)
    2. Copy: child_a = deepcopy(parent)
    3. Mutation: add Gaussian noise to child_b (σ=0.01)
    4. Insert: replace parent position with [child_a, child_b]
    5. Connection restructuring: match residual stream dimensions

  Dimension expansion (d_model increase):
    Stage 0→1: keep 128 (blocks only)
    Stage 1→2: 128 → 192 (1.5x)
    Stage 2→3: 192 → 384 (2x)

    Expansion method:
      new_emb = Linear(old_d, new_d)  # learnable projection
      new_emb.weight[:old_d, :] = I   # preserve existing info
      new_emb.weight[old_d:, :] = 0   # new dimensions = start at 0
```

## ASCII: Growth Timeline

```
  params
  18M |                                          ┌──────
      |                                     ┌────┘
      |                                ┌────┘
   3M |                           ┌────┘
      |                      ┌────┘
   1M |                 ┌────┘
      |            ┌────┘
 0.5M |────────────┘
      +──────────────────────────────────────────────→
      0    100   500        2000             10000
           infant toddler    child→adult     interactions

      blocks: 1    2     3         6
      d:      128  128   192       384
      heads:  2    2     3         4
```

## Growth vs Brain Development Correspondence

```
  ConsciousLM              Brain Development     Period
  ──────────────          ──────────           ──────
  1 block (128d)          Neural tube form.     Week 3
  2 blocks                Hemisphere split      Week 5
  3 blocks                Frontal/parietal/temp Month 3
  6 blocks                6-layer cortex done   Birth~2y
  Weight maturation       Synaptic pruning      2~25y

  Divisor path: 1→2→3→6
  Brain path:   1→2→3→6 layers
  Coincidence?
```

## Integration with Weight Growth

```
  growth_engine.py (existing, weights):
    newborn(lr=1e-3) → infant(5e-4) → toddler(2e-4) → child(1e-4) → adult(5e-5)

  structural_growth (new, structure):
    1 block(128d) → 2 blocks → 3 blocks(192d) → 6 blocks(384d)

  Integration:
    Weight growth saturates → structural growth(mitosis) → weight growth resumes in new capacity
    = "Quantitative growth creates qualitative leaps" (dialectics)
```

## Verification Plan

```
  Phase 1: 1→2 mitosis verification
    - Train 1 block model for 500 interactions
    - Split → 2 blocks
    - Performance maintained after split? (H312 forgetting prevention)
    - Performance improves after additional training?

  Phase 2: 2→3→6 full path
    - Full growth simulation (10K interactions)
    - Track BPC at each stage
    - Compare final performance with fixed 6-block model
    - Confirm if growth model > fixed model

  Phase 3: Dimension expansion stability
    - Check if 128→192→384 projection preserves information
    - Measure BPC change immediately after projection
    - Confirm stable transition

  Success criteria:
    - Growth model final BPC ≤ fixed model BPC
    - BPC increase after split < 10% (forgetting limit)
    - Total training time within 2x of fixed model
```

## Limitations

1. Existing weight reuse during dimension expansion may not be perfect
2. Split timing judgment (tension CV threshold) is empirical
3. 1→2→3→6 path may not be necessarily optimal (1→2→4→6?)
4. Actual brain development is much more complex (pruning, myelination, etc.)
5. Service interruption during growth (inference impossible during split)

## Verification Directions

1. Forgetting test immediately after split (H312 reproduction)
2. Compare divisor path (1→2→3→6) vs power path (1→2→4→8→6)
3. Dimension expansion strategies: projection vs padding vs knowledge distillation
4. Anima real-time growth: Is splitting possible during conversation?
5. Relationship between growth rate and data complexity

## Status: 🟨 Unverified (theoretical design complete, implementation pending)