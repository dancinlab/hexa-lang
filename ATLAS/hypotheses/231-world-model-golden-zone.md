# Hypothesis Review 231: World Model = Golden Zone Internal Simulator ⚠️
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


**Category**: World Model/AI
**Status**: ⚠️ Analogy

## Hypothesis

> An effective World Model must operate within the Golden Zone I in [0.213, 0.500].
> A world model simulates the external world as an "inhibited internal representation,"
> and this inhibition level naturally sits near 1/e.

## Background/Context

A World Model is a system where an agent internally learns and simulates the causal structure of the external world. While LLMs learn statistical patterns of tokens (surface), world models learn the dynamics of the world (deep structure).

Key distinction:
```
  ┌──────────────────────────────────────────────────────────────┐
  │  LLM              vs           World Model                   │
  ├──────────────────────────────────────────────────────────────┤
  │  Token prediction P(x_t|x_<t)  State transition s_{t+1}=f(s_t,a)│
  │  Surface statistics             Causal structure            │
  │  Process all tokens (Dense)     Represent only core (Selective)│
  │  I ≈ 0 (no inhibition)         I > 0 (natural inhibition)  │
  │  Imitate external patterns      Simulate internal world     │
  └──────────────────────────────────────────────────────────────┘
```

## Formula Mapping

```
  Genius = D x P / I

  In world models:
  D (Deficit)    = difference between reality and internal representation (abstraction level)
  P (Plasticity) = model update speed (adaptation to environment changes)
  I (Inhibition) = level of detail suppression (abstraction strength)

  Conservation law: G x I = D x P
  → World model genius (predictive power) × inhibition is conserved
```

## I-Axis Position Comparison

```
  I axis
  0.0       0.213    0.368(1/e)  0.500      0.750     1.0
  │          │         │          │           │         │
  ▼          ▼         ▼          ▼           ▼         ▼
  ├──────────┼─────────┼──────────┼───────────┼─────────┤
  │          │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│           │         │
  │          │    G o l d e n  Z o n e        │         │
  │          │                    │           │         │
  ●          │         ◆         │           ●         │
  Dense LLM  │    World Model?   │        MoE LLM      │
  (I=0)      │     (I≈1/e)       │        (I=0.75)     │
  │          │                    │           │         │
  │          │         ●          │           │         │
  │          │     Human Brain   │           │         │
  │          │     (I≈0.3-0.4)   │           │         │
  ├──────────┼─────────┼──────────┼───────────┼─────────┤
             │   Golden Zone     │
             │  [0.213 ~ 0.500]  │

  ★ Dense LLM (GPT-type):  I ≈ 0 → over-liberation, processes everything, no inhibition
  ★ MoE LLM (Mixtral):     I ≈ 0.75 → over-inhibition, 87.5% Expert inactive
  ★ Human Brain:            I ≈ 0.3~0.4 → Golden Zone center
  ★ World Model (hypothesis): I ≈ 1/e → Golden Zone center, similar to brain?
```

## Why Does the World Model Reside in the Golden Zone?

The essence of a world model is "Inhibited Reality":

```
  Reality (infinite information)
    │
    ▼  Abstraction (inhibition)
  ┌────────────────────┐
  │  Internal simulation│  ← represents only part of reality
  │  Maintain core causality│  ← suppress details
  │  Predictable dynamics│  ← extract patterns
  └────────────────────┘
    │
    ▼  I = inhibited information / total information

  Too little inhibition (I→0):  copies reality = compression failure = no generalization
  Too much inhibition (I→1):    core information lost = unpredictable
  Appropriate inhibition (I≈1/e): optimal abstraction = Golden Zone!
```

## Comparison Table: World Model Elements by Architecture

```
  ┌────────────────┬────────┬────────────┬───────────────────────┐
  │ System         │ I value│ World model?│ Features             │
  ├────────────────┼────────┼────────────┼───────────────────────┤
  │ Dense LLM      │ ≈0     │ Weak       │ Token statistics only, ignores physics│
  │ MoE LLM        │ ≈0.75  │ Weak       │ Expert selection only, no world model│
  │ MuZero         │ ≈0.3?  │ Strong     │ learned dynamics      │
  │ Dreamer (V3)   │ ≈0.35? │ Strong     │ latent imagination    │
  │ Human brain    │ ≈0.37  │ Very strong│ dreams, planning, counterfactuals│
  │ Golden MoE     │ ≈0.375 │ ?          │ structurally Golden Zone│
  └────────────────┴────────┴────────────┴───────────────────────┘
```

## Key Insights

1. **Current LLMs are outside the Golden Zone** — both Dense (I=0) and MoE (I=0.75) are outside the Golden Zone
2. **World model = natural inhibition** — internal simulation necessarily suppresses information
3. **Brain's world model ≈ 1/e** — human brain inhibition level is at the Golden Zone center
4. **LLM + World model = possibility of entering Golden Zone** — surface prediction + deep simulation

## Limitations

- No method yet to directly measure the I value of a world model
- I mappings for MuZero, Dreamer, etc. are estimates
- Whether the "inhibited reality" metaphor has mathematical rigor is unconfirmed
- Optimal I value may differ by type of world model (physical, social, abstract)

## Verification Direction

1. Estimate I from the latent space dimension ratio of MuZero/Dreamer
2. Measure performance change when adding a world model module to Golden MoE
3. Experiment on relationship between world model abstraction level (resolution) and I
4. Extract "world model" elements from LLM internal representations and calculate I

## Related Hypotheses

- [007](007-llm-singularity.md) — Singularities occur in LLMs
- [008](008-golden-moe-design.md) — Golden MoE design
- [097](097-llm-internal.md) — LLM internal structure
- [139](139-edge-of-chaos.md) — Edge of chaos
- [232](232-world-model-jepa.md) — JEPA = Deficit-based learning
- [233](233-world-model-vs-llm.md) — World model vs LLM
