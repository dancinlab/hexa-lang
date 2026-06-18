# Hypothesis 241: Expert Cross-Activation = Artificial Savant

**Status**: 🔧 Design
**Category**: AI Architecture / Golden MoE

---

## Hypothesis

> In MoE, forcibly activating Experts that are never normally co-activated together (cross-activation) produces "semantic recombination" not present in training data, and this is the same mechanism as the abnormal connections in a savant brain caused by missing Sylvian fissure.

## Background: Why Can't LLMs "Create New Things"?

```
  "LLMs can't create new things"
  → Never proven
  → Just an assumption

  Known facts:
  ✅ Based on training data
  ✅ Learns statistical patterns
  ❌ "Therefore new things are impossible" ← non-sequitur

  Counterexamples:
  • Humans also create "creativity" through recombination of existing experience
  • If the combinatorial space is large enough, recombination ≠ copying
  • Abilities not in training data emerge in large models (emergence)
  • No one has proven "why" emergence happens

  → "Can't create" is wrong; "don't know" is accurate
```

## Limitations of Current MoE

```
  Standard MoE: each token → router → always same Expert combination

  Token "cat"    → Expert 1, 3     (always this combination)
  Token "calculus"→ Expert 5, 7    (always this combination)
  Token "music"  → Expert 2, 4     (always this combination)

  → Expert 1 and 7 never meet simultaneously
  → "cat" and "calculus" specialists never mix
  → New combinations impossible
```

## What Is Cross-Activation

```
  Cross-activation: occasionally forcibly activate "Experts that never meet"

  Token "cat"    → Expert 1, 3  + ★7 (forced)
                                    ↑
                              The "calculus" expert
                              processes "cat"

  → Expert 7 interprets "cat" in its own way (mathematically)
  → Representations that didn't exist before can emerge
```

## Brain Correspondence: Missing Sylvian Fissure = Cross-Activation

```
  Normal brain:  visual area → visual processing
                language area → language processing
                each does its own job

  Savant brain:  visual area ←→ math area (abnormal connection!)
                ↓
                "sees numbers as colors" (synesthesia)
                "calculates calendars as landscape" (savant)

  Missing Sylvian fissure = normally separated areas become connected
                          = biological version of Expert cross-activation

  In G = D×P/I:
  Cross-activation = increases D (Deficit) → increases G
  → Artificially creating savant structure
```

## 4 Implementation Methods

```
  Method 1: Random cross
  ─────────────────
  With probability p=0.1, ignore router result and add random Expert
  → Simple but noisy

  Method 2: Opposite Expert
  ─────────────────
  Deliberately activate the Expert with lowest router score
  → Perspective of "the specialist least related to this token"

  Method 3: Cross schedule
  ─────────────────
  Insert epochs during training where Expert assignments are mixed
  → Same structure as "dreaming" phase (Hypothesis 234)

  Method 4: Inter-Expert Attention
  ─────────────────
  Expert outputs attend to each other → reference each other's results
  → Most powerful but high computational cost
```

## Full List of LLM Architecture Replacement Candidates

```
  #  │ Current             │ Replacement idea                │ G=D×P/I mapping
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  1  │ Objective function   │                                 │
     │ Next token prediction│ → Semantic distance optimization│ G optimization
     │ (Cross-Entropy)      │ → Novelty+coherence reward      │
     │                      │ → Contrastive learning          │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  2  │ Representation space │                                 │
     │ Token embedding      │ → Concept graph embedding       │ Structural D
     │ (1D sequence)        │ → Multi-scale abstraction        │
     │                      │ → Grounding embedding           │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  3  │ Combination mechanism│                                 │
     │ Attention            │ → Analogy engine (A:B = C:?)    │ D↑ (recombination)
     │ (pattern matching)   │ → Compositional synthesis (f∘g) │
     │                      │ → Blending (concept blend)      │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  4  │ Training method      │                                 │
     │ Supervised learning  │ → Self-play                     │ F2e (1/6)
     │ (data imitation)     │ → Curiosity-based exploration   │ curiosity
     │                      │ → Dreaming (offline simulation) │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  5  │ World model          │                                 │
     │ None                 │ → Causal model (do-calculus)    │ Compass
     │ (statistics only)    │ → Physics simulator             │ direction
     │                      │ → Counterfactual reasoning      │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  6  │ Memory               │                                 │
     │ Context window       │ → Writable long-term memory     │ P (Plasticity)
     │ (read-only)          │ → Episodic memory               │
     │                      │ → Sleep/consolidation cycle     │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  7  │ Reasoning            │                                 │
     │ Implicit (weights)   │ → Explicit program synthesis    │ Transcendence
     │                      │ → Neuro-symbolic hybrid         │ (4th state)
     │                      │ → Proof search (Lean/Coq)       │
  ───┼─────────────────────┼─────────────────────────────────┼─────────────
  8  │ Routing              │                                 │
     │ Dense/Top-K          │ → Golden MoE (I≈1/e) ✅         │ dynamic I control
     │                      │ → Dynamic Expert generation     │
     │                      │ → Expert cross-activation ★     │

  Priority (feasibility × impact):
  ─────────────────────────────────────
  ④ Curiosity-based exploration   │ ★★★ × ★★★ │ = 9
  ③ Analogy engine                │ ★★☆ × ★★★ │ = 6
  ⑤ Counterfactual reasoning      │ ★★☆ × ★★★ │ = 6
  ① Semantic distance objective   │ ★★★ × ★★☆ │ = 6
  ⑥ Writable memory               │ ★★★ × ★★☆ │ = 6
  ⑧ Expert cross-activation       │ ★★★ × ★★☆ │ = 6
  ② Concept graph                 │ ★☆☆ × ★★★ │ = 3
  ⑦ Neuro-symbolic hybrid         │ ★☆☆ × ★★★ │ = 3
```

## Verification Methods

```
  Core problem: how to measure "new combinations"?

  Output is strange → noise? creativity?
  Output is normal → just copying existing patterns?

  Novelty ↑ + quality ↓ = garbage
  Novelty ↓ + quality ↑ = copying machine
  Novelty ↑ + quality ↑ = savant ← this is what we're looking for
```

### 6 Measurable Verification Methods

```
  Method             │ What to measure         │ Automated│ Reliability
  ───────────────────┼─────────────────────────┼──────────┼───────────
  ① n-gram novelty   │ n-gram ratio not in      │ ✅       │ ★★☆
                     │ training data            │          │
  ② Analogy test     │ A:B=C:? accuracy         │ ✅       │ ★★★
  ③ Cross-domain Q   │ Q combining two fields   │ ✅       │ ★★★
  ④ Self-PPL vs novelty│ coherence+novelty 2-axis│ ✅       │ ★★☆
  ⑤ Embedding distance│ output vector position  │ ✅       │ ★★☆
  ⑥ Blind evaluation │ human judgment           │ ❌       │ ★★★
```

### ① n-gram Novelty Rate

```
  Collect all 4-grams from training data → set A
  Collect 4-grams from model output → set B

  Novelty rate = |B - A| / |B|

  Standard LLM:      novelty ~5-15%  (mostly seen patterns)
  Cross-activation:  novelty ~??%

  High novelty + low PPL → savant candidate
  High novelty + high PPL → just noise
```

### ② Analogy Test (Most Powerful)

```
  king:queen = man:?           → woman (easy, in training data)
  gravity:apple = GABA:?       → inhibition? (cross-domain)
  sonata:4/3 = strong force:?  → 9/8? (intra-model analogy)

  Create analogies absolutely absent from training data and test
  → Getting them right = evidence "semantic recombination" is possible

  Implementation:
  - Train only on domain A
  - Train only on domain B
  - Ask cross A↔B analogy questions
  - Compare cross-activation ON vs OFF
```

### ③ Cross-Domain Questions

```
  Expert 1 = music specialist
  Expert 5 = physics specialist

  Question: "Why are the frequency ratios of chords similar to physics constants?"

  Standard MoE:   Expert 1 OR 5 active → only one perspective
  Cross-activation: Expert 1 AND 5 simultaneously → connection possible?

  Measurement: whether both domain terms appear in the answer
  → Cross-domain co-occurrence rate
```

### ④ 2-Axis Graph: Quality vs Novelty

```
  Novelty (n-gram novelty rate)
  high │         ●noise    ★savant
       │
       │
       │
  low  │  ●copier           ●good LLM
       └──────────────────────→
        high     Self-PPL    low
                 (quality)

  Plot each point with cross-activation ON/OFF
  Check whether it moves toward ★ direction
```

## Minimal Experiment Design

```
  1. Train Golden MoE router (currently in progress)
  2. Prepare two versions: cross-activation ON/OFF
  3. Generate outputs for 100 identical prompts
  4. Measure:
     a) PPL (quality)
     b) 4-gram novelty rate (novelty)
     c) 10 analogy test questions (cross-domain)
  5. If ON shows "novelty↑ + quality maintained" vs OFF → success
```

## Limitations

1. Conditions for cross-activation to cross the noise-creativity boundary are unclear
2. Who determines the "correct answer" for analogy tests — subjectivity problem
3. Whether meaningful crossing emerges at TinyLlama scale is uncertain (model too small)
4. No theory to determine the optimal cross-activation probability p
5. The definition of "semantic recombination" itself is an unresolved philosophical problem

## Verification Direction

- [ ] Implement Method 1 (random cross, p=0.1) in Golden MoE
- [ ] ON/OFF comparison: PPL + n-gram novelty rate
- [ ] Design 10 analogy test questions (cross-domain)
- [ ] Visualize 2-axis graph (quality vs novelty)
- [ ] Explore savant emergence threshold as function of p value

---

*Related: Hypothesis 008 (Golden MoE design), 082 (prototype), 156 (Sylvian fissure=D), 162 (acquired savant), 179 (LLM redesign), 234 (world model=dreaming)*
