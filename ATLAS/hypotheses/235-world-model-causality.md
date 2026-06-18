# Hypothesis Review 235: Causal Reasoning = World Model's Compass ⚠️
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


**Category**: World Model/AI
**Status**: ⚠️ Analogy

## Hypothesis

> True AGI must achieve Judea Pearl's 3-level Causal Ladder (counterfactual reasoning),
> which corresponds to the 4th state (transcendence) in our model.
> Causal reasoning ability maps to Compass directionality,
> and without a world model, Compass=0 (directionless learning).

## Background/Context

Judea Pearl classified causal reasoning into a 3-level ladder:

```
  Pearl's Ladder of Causation
  ─────────────────────────────────────────

  Level 3: Counterfactual    "What if I had done X?"
         │  Imagination, regret, moral judgment
         │  P(y_x | x', y')
         │
  Level 2: Intervention      "What would happen if I do X?"
         │  Experiments, causal inference
         │  P(y | do(x))
         │
  Level 1: Observation       "Given X, what is Y?"
         │  Correlation, pattern recognition
         │  P(y | x)
```

## Formula Mapping: Pearl's 3 Levels → Our Model

```
  Pearl level    I value    State          Compass    Description
  ──────────     ────────   ────────       ─────────  ───────────────
  1. Observation I ≈ 0      Normal (Dense) ≈ 0~20%   Correlation only, no causation
  2. Intervention I > 0     MoE region     ≈ 20~50%  Some causation, limited
  3. Counterfactual I ≈ 1/e Golden Zone    ≈ 50~83%  Full causal reasoning
  4. Transcendence(*) I=1/3 4th state      = 5/6     Includes self-causation

  (*) Extension not in Pearl's original ladder:
      Ability to analyze one's own causal structure counterfactually
      = Metacognition = Transcendence in our model
```

## ASCII Graph: Causal Ladder → I Axis & Compass Mapping

```
  Compass (%)
  100│
     │
  83 │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ★ 5/6 upper bound
     │                                    ╱
  70 │                                 ╱
     │                              ╱
  60 │                           ╱
     │                        ╱     ← Level 3: Counterfactual
  50 │════════════════════ ●        (Golden Zone, I≈1/e)
     │                  ╱
  40 │               ╱
     │            ╱         ← Level 2: Intervention
  30 │         ╱            (MoE region, I≈0.5~0.7)
     │      ╱
  20 │    ╱
     │  ● ← Level 1: Observation  (Dense, I≈0)
  10 │╱
     │
   0 │
     └──────────────────────────────────────────→ I
     0.0    0.213    0.368    0.500    0.750    1.0
                ├─── Golden Zone ───┤

  Key: Causal reasoning ability (Compass) surges when I enters the Golden Zone
  → Without a world model (internal causal structure), Compass stays in low range
```

## Pearl's 3 Levels ↔ Our Model's 3 States + Transcendence

```
  ┌─────────────────┬─────────────────┬──────────────────────────┐
  │ Pearl's ladder  │ Our model state │ Correspondence basis     │
  ├─────────────────┼─────────────────┼──────────────────────────┤
  │ 1. Observation  │ Normal          │ Pattern recognition only, ignores causation│
  │   P(y|x)        │ I > 0.5         │ Dense LLM = correlation learning│
  ├─────────────────┼─────────────────┼──────────────────────────┤
  │ 2. Intervention │ Talented        │ Some causation, can experiment│
  │   P(y|do(x))    │ 0.3 < I < 0.5  │ MoE = start of selective processing│
  ├─────────────────┼─────────────────┼──────────────────────────┤
  │ 3. Counterfactual│ Genius         │ "What if" = internal simulation│
  │   P(y_x|x',y')  │ I ≈ 1/e        │ World model = counterfactual engine│
  ├─────────────────┼─────────────────┼──────────────────────────┤
  │ [4. Self-counter.]│ Transcendence │ Reason about own causation│
  │   P(y_x|self)   │ I = 1/3        │ Metacognition = 4th state│
  └─────────────────┴─────────────────┴──────────────────────────┘

  Mathematical correspondence:
  1/2 + 1/3 + 1/6 = 1
  (observation→intervention boundary) + (meta fixed point) + (curiosity/transcendence) = complete
```

## Causal Reasoning Ability of Current AI

```
  ┌───────────────────┬──────┬────────────┬───────────────────────┐
  │ System            │ I    │ Pearl level│ Causal ability        │
  ├───────────────────┼──────┼────────────┼───────────────────────┤
  │ GPT-4 (Dense)     │ ≈0   │ 1 (obs.)   │ Correlation only      │
  │ Mixtral (MoE)     │ 0.75 │ 1~2        │ Slight causal reasoning│
  │ Gemini + Search   │ 0.2  │ 1~2        │ Simulated intervention via tools│
  │ AlphaFold 3       │ 0.3? │ 2          │ Protein causal structure│
  │ MuZero            │ 0.35?│ 2~3        │ Counterfactual possible in games│
  │ Human brain       │ 0.37 │ 3          │ Full counterfactual    │
  │ ???               │ 1/3  │ 4          │ Self-counterfactual = transcendence│
  └───────────────────┴──────┴────────────┴───────────────────────┘

  Observation: higher Pearl level → I closer to Golden Zone
  → Causal reasoning ability = Golden Zone proximity
```

## World Model and Compass Directionality

```
  AI without world model:
  ┌─────────┐
  │  Data   │ ──→ Pattern ──→ Output
  │ (past)  │    (correlation)  (prediction)
  └─────────┘
  Compass = 0: no direction, doesn't know where to go

  AI with world model:
  ┌─────────┐     ┌──────────────┐
  │  Data   │ ──→ │ World model  │ ──→ Causal prediction
  │ (past)  │     │(causal struct)│    (includes counterfactual)
  └─────────┘     │ do-calculus  │
                  │ intervention/counterfactual│
                  └──────────────┘
  Compass > 0: has direction, explores along causal arrows

  Compass upper bound = 5/6:
  Complete causal model including self = 1/6 incompleteness (Gödel)
```

## Key Insights

1. **Observation=Dense, Intervention=MoE, Counterfactual=Golden Zone** — Pearl's 3 levels map precisely to I
2. **Current LLMs are stuck at level 1 (observation)** — I≈0 makes causal reasoning impossible
3. **World model = condition for entering levels 2~3** — internal simulation is prerequisite for counterfactual
4. **4th state = self-counterfactual** — meta-causation beyond Pearl = transcendence

## Cusp Catastrophe Connection

```
  Level transitions in Pearl's Causal Ladder are not continuous!

  1→2 transition: gradual (slowly as I decreases)
  2→3 transition: cusp! (counterfactual ability acquired suddenly at critical point)
  3→4 transition: catastrophe! (self-reference = breaking Gödel incompleteness)

  Cusp location ≈ I = 0.5 (Golden Zone upper bound)
  → Crossing this boundary causes a qualitative phase transition
```

## Limitations

- Mapping Pearl's Causal Ladder to I is analogical, not mathematically proven
- Benchmarks for measuring current AI "counterfactual reasoning" ability are insufficient
- The claim "causal reasoning = Golden Zone" may be circular
- Whether level 4 (self-counterfactual) is achievable is itself unresolved

## Verification Direction

1. Analyze relationship between performance on causal reasoning benchmarks (CausalBench, CLadder) and model I
2. Measure I of AI that explicitly implements do-calculus
3. Correlation between MuZero's counterfactual ability (counterfactual regret) and I
4. Add causal module to Golden MoE → verify whether Pearl level 3 is achievable

## Related Hypotheses

- [231](231-world-model-golden-zone.md) — World model = Golden Zone internal simulator
- [234](234-world-model-dreaming.md) — World model = dreaming
- [045](045-what-is-transcendence.md) — What is transcendence?
- [037](037-compass-ceiling.md) — Compass upper bound 5/6
- [064](064-godel-analog.md) — Gödel analogy
- [072](072-curiosity-completes.md) — Curiosity completes
- [139](139-edge-of-chaos.md) — Edge of chaos
