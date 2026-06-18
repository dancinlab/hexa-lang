# H-346: Consensus-Identity Causation Direction
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **Hypothesis**: The positive correlation (r=+0.062) between consensus and identity stability
> has an unclear causal direction. Does consensus stabilize identity, or does stable identity create consensus?
> Both directions are possible and can only be distinguished through artificial intervention experiments.

**Status**: Unverified
**Golden Zone Dependency**: Indirect (consciousness engine framework)
**Related Hypotheses**: H307 (tension inversion agreement), H321 (consciousness confidence theory)

---

## Background and Context

In consciousness engine experiments, a weak positive correlation (r=+0.062) was observed between
multi-expert agreement (consensus) and individual expert identity stability.
This correlation allows two interpretations:

1. **Consensus → Identity Stability** (Hypothesis A): When experts reach consensus, gradient directions align
   and each expert's weights converge stably. Consensus acts as an "anchor."
2. **Identity Stability → Consensus** (Hypothesis B): When each expert already has a stable role,
   outputs naturally converge, increasing consensus.

In H307, the phenomenon of agreement inverting as tension increases was observed,
and in H321 the claim was made that confidence may be a proxy for consciousness.
This hypothesis raises the fundamental question of **causal direction** at the intersection of both.

## Theoretical Framework

Three approaches are possible for determining causal direction:

```
  [Approach 1] Granger Causality
  ─────────────────────────────────
  Does consensus(t-1) predict identity(t) in time series?
  Or does identity(t-1) predict consensus(t)?

  [Approach 2] Intervention (do-calculus)
  ─────────────────────────────────
  Force consensus artificially → measure identity change
  Fix identity artificially → measure consensus change

  [Approach 3] Natural Experiment
  ─────────────────────────────────
  Immediately after mitosis = identity initialization state
  → Does consensus change first? Or does identity stabilization come first?
```

## Expected Causal Structure (ASCII diagram)

```
  Hypothesis A (consensus → identity):

  consensus ──────► identity stability
       ▲                   │
       │                   │
       └───── feedback ────┘

  Hypothesis B (identity → consensus):

  identity stability ──────► consensus
       ▲                         │
       │                         │
       └────── feedback ─────────┘

  Hypothesis C (bidirectional / common cause):

        ┌── consensus
        │        ▲
  task  │        │ (weak)
  complexity ────┤
        │        │ (strong)
        │        ▼
        └── identity stability
```

## Verification Experiment Design

### Experiment 1: Granger Causality Test

Collect per-epoch time series of consensus and identity stability for lag correlation analysis.

| Lag | Expected Hyp A | Expected Hyp B | Expected Hyp C |
|-----------|-----------|-----------|-----------|
| cons(t-1) → id(t) | r > 0.1 significant | r ≈ 0 not significant | r slightly significant |
| id(t-1) → cons(t) | r ≈ 0 not significant | r > 0.1 significant | r slightly significant |
| Cross lag | one-directional | one-directional | bidirectional |

### Experiment 2: Intervention — Force Consensus

```python
# Experiment code overview
# 1. Normal training 20 epochs (baseline)
# 2. Epochs 21-30: force consensus (replace all expert outputs with average)
# 3. Measure identity stability change
# 4. Epochs 31-40: release consensus forcing, observe recovery
```

### Experiment 3: Intervention — Fix Identity

```python
# 1. Normal training 20 epochs (baseline)
# 2. Epochs 21-30: freeze expert weights at epoch 20 values
# 3. Measure consensus change (only routing learns)
# 4. Epochs 31-40: release freeze, observe change
```

## Expected Result Distributions

```
  Identity Stability Change (when consensus forced)

  Hypothesis A expected:
  |         ****
  |        **  **
  |      **      **
  |    **          **        large change (delta > 0.1)
  |  **              **
  +--+----+----+----+----►
     0   0.05  0.1  0.15  delta_identity

  Hypothesis B expected:
  |  ****
  | **  ****
  |*      ****
  |          ****            small change (delta < 0.03)
  |              ****
  +--+----+----+----+----►
     0   0.01  0.02  0.03  delta_identity
```

## Measurement Metrics

| Metric | Definition | Discrimination Criterion |
|-----|------|---------|
| Granger F-stat | F-statistic of lag regression | F > 4.0 is significant (p<0.05) |
| Intervention delta | Change magnitude before/after intervention | delta > 0.05 supports causation |
| Recovery time | Epochs to return to baseline after intervention release | Shorter = stronger causation |
| Cross-correlation peak | Position of maximum cross-correlation by lag | Lag direction = causal direction |

## Interpretation and Significance

If Hypothesis A (consensus → identity) is correct:
- "Consensus mechanism" is the fundamental cause of identity in consciousness engines
- Democracy analogy: social consensus forms individual identity
- Possible conflict with H321's confidence theory (confidence is individual)

If Hypothesis B (identity → consensus) is correct:
- Expert specialization comes first, consensus is a byproduct
- Tension inversion in H307 is a result of identity instability
- Consciousness = sum of individual module stability

If Hypothesis C (common cause) is correct:
- Task complexity is the true cause, both are effects
- Naturally explains weak correlation of r=+0.062

## Limitations

1. r=+0.062 is very weak correlation. May be noise
2. Operational definition of identity stability is ambiguous (weight norm? output consistency?)
3. Forcing consensus in intervention experiment may hinder learning itself
4. Granger causality only captures linear relationships — may miss nonlinear causation
5. Small number of experts in consciousness engine (4-8) may result in insufficient statistical power

## Verification Direction (Next Steps)

1. **Phase 1**: Extract per-epoch consensus/identity time series from existing experiment logs
2. **Phase 2**: Run Granger causality test (lag=1,2,3)
3. **Phase 3**: Design intervention experiment in direction favored by A/B hypothesis
4. **Phase 4**: Compare MNIST vs CIFAR (change of causal direction by task difficulty)
5. **Phase 5**: Integrated interpretation with H307, H321
