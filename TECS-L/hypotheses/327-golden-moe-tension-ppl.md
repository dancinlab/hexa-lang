# Hypothesis 327: Actual Relationship Between Tension and PPL in Golden MoE
**n6 Grade: 🟩 EXACT** (auto-graded, 10 unique n=6 constants)


> **When Golden MoE (golden_moe.py) is applied to LLM (Golden LLaMA), how does inter-Expert repulsion (tension) relate to PPL? Does H-CX-21 (tension∝1/PPL) hold at LLM scale?**

## Background/Context

Golden MoE is a Mixture-of-Experts architecture designed from the divisor structure of perfect number 6.
It activates tau(6)=4 out of sigma(6)=12 Experts, demonstrating +0.6% improvement on MNIST
and +4.8% on CIFAR-10 (H008, golden_moe_torch.py).

H-CX-21 observed "the higher the tension, the lower the PPL (better performance)"
at MNIST scale — an inverse correlation. However, whether this holds at the scale
of billions of parameters in LLMs is unverified. In the golden-llama project (separate repo),
PPL decreased from 136K to 4634 (500 steps), but the target of PPL < 100 has not yet been reached.

Core question of this hypothesis: **Is inter-Expert tension at LLM scale a leading indicator predicting PPL reduction?**

### Related Hypotheses

| Hypothesis | Core Content | Relationship |
|------|----------|------|
| H-CX-21 | MNIST: tension proportional to 1/PPL | Direct predecessor — small scale empirical |
| H008 | Golden MoE design principle (sigma/tau) | Architecture basis |
| H241 | Expert cross-activation | Training strategy affecting tension |
| H313 | tension = confidence | Tension interpretation framework |
| H316 | Overconfidence phenomenon | May be more severe at LLM scale |

### Current golden-llama Training State

```
  Original Dense LLaMA:   PPL = 13.85 (baseline)
  Golden MoE (untrained): PPL = 136,165 (immediately after conversion)
  Golden MoE (500 steps): PPL = 4,634 (97% reduction)
  Target (minimum):       PPL < 100
  Target (final):         PPL < 20
  Training strategy:      Freeze Experts, train router only
```

## Correspondence Mapping — MNIST vs LLM Scale

| Item | MNIST (H-CX-21) | LLM (this hypothesis) |
|------|----------------|--------------|
| Model size | ~100K params | ~1B+ params |
| Expert count | 12 (sigma(6)) | 12 (sigma(6)) |
| Active Experts | 4 (tau(6)) | 4 (tau(6)) |
| Input | 28x28 images | token sequences |
| Tension definition | Expert output L2 distance | Expert output L2 distance |
| PPL range | N/A (classification) | 13.85 ~ 136K |
| Observed relationship | tension up = accuracy up | ? (unverified) |
| Training steps | ~50 epochs | 2000~5000 steps |

## Expected Tension-PPL Relationship

```
  tension
  (inter-Expert
   output distance)
  ^
  |
  0.8|                                    x  x
     |                              x  x
  0.6|                        x  x
     |                  x  x
  0.4|            x  x
     |        x
  0.2|    x                          Expected: tension proportional to 1/PPL
     |  x                            (linear in log scale)
  0.1| x
     +--+-----+-----+-----+-----+-----> training steps
        0    500   1000  1500  2000

  PPL
  (log scale)
  ^
  136K| x
      |  x
  10K |    x
      |      x
  1K  |        x  x
      |            x  x
  100 |                  x  x  x       target line
      |                          x  x
  13  |                              x  baseline (Dense)
      +--+-----+-----+-----+-----+----> training steps
         0    500   1000  1500  2000
```

## Detailed Predictions

### Prediction 1: Tension-PPL Inverse Correlation

```
  H-CX-21 relationship (observed on MNIST):
    tension = a / PPL + b
    or log(tension) = -c * log(PPL) + d

  Expected correlation coefficient at LLM scale:
    Pearson r(tension, 1/PPL) > 0.7  (success criterion)
    Spearman rho > 0.8              (rank correlation, may be stronger)
```

### Prediction 2: Expert Specialization Pattern

```
  Expected activation frequency per Expert (after training complete):
  Expert |  Code  | Math  | Natural | Reasoning | Other
  -------|--------|-------|---------|-----------|------
     E1  |  ████  |  ██   |   █     |  ███      |  █
     E2  |   █    | ████  |  ██     |  ██       |  █
     E3  |  ██    |  █    | █████   |   █       |  ██
     E4  |  ███   |  ███  |   █     | ████      |  ██

  -> Specific Expert specializes in specific domain
  -> Degree of specialization = Savant Index = max(domain PPL) / min(domain PPL)
  -> SI > 3 is Savant candidate (CLAUDE.md criterion)
```

### Prediction 3: Per-Token Tension Distribution

```
  Expected tension by token type:

  Factual tokens (accurate information):     high tension (0.5~0.8)
    -> Experts process with "confident" different patterns

  Hallucination tokens (misinformation):     low tension (0.1~0.3)
    -> Experts similarly "uncertain"

  General tokens (the, is, a):               moderate tension (0.3~0.5)
    -> Pattern is universal, appropriate consensus

  If this prediction is correct: tension can detect hallucinations
```

## Verification Method

```
  Environment: golden-llama repo (github.com/dancinlab/golden-llama)
               Windows PC (RTX 5070) or RunPod A100

  Phase 1 -- Build tension tracking infrastructure:
    1. Add tension logging to golden-llama training loop
       - Every step: average L2 distance of active 4 Expert outputs
       - Every 100 steps: activation frequency histogram per Expert
    2. Record to tensorboard or CSV

  Phase 2 -- Correlation analysis:
    1. Train 2000 steps while recording tension + PPL simultaneously
    2. Calculate Pearson/Spearman correlation coefficient
    3. Cross-correlation analysis of whether tension leads PPL
       (If tension goes up first and PPL comes down later -> leading indicator)

  Phase 3 -- Per-token analysis:
    1. Generate text with trained model
    2. Record per-token tension
    3. Classify factual/hallucination/general tokens and compare tension distributions

  Success criteria:
    - r(tension, 1/PPL) > 0.7 or rho > 0.8
    - Expert specialization: SI > 2 (at least 1 Expert)
    - tension > 0.5 when PPL < 100 achieved
```

## Verification Results

Not yet experimented. Planned to execute from Phase 1 after golden-llama reaches PPL < 100.
At the current PPL 4634 stage, tension measurement may be meaningless
since the router is not sufficiently trained.

## Interpretation/Significance

If this hypothesis holds:
- **Scale universality**: Proves tension-PPL inverse correlation holds from MNIST (small scale) to LLM (large scale). This suggests repulsion field is a scale-invariant mechanism.
- **Hallucination detection**: Real-time hallucination detection possible via per-token tension. Contributes to solving a core problem in AI safety.
- **Training monitoring**: If tension is a leading indicator of PPL, it can be used as a signal for early stopping or hyperparameter adjustment during training.
- **Consciousness engine perspective**: That higher "opinion differences" (tension) between Experts produce more accurate output is similar to the brain mechanism where "constructive disagreement" between different areas leads to better judgment.

## Limitations

1. **Scale difference**: 3-4 orders of magnitude difference between MNIST (100K params) and LLM (1B+ params). No guarantee the same relationship is maintained.
2. **Router training strategy**: Uncertain whether tension forms properly in current strategy of freezing Experts + training router only. Experts may also need to be trained.
3. **Limitations of PPL itself**: Even low PPL doesn't guarantee good actual generation quality. Even if tension-PPL correlation exists, tension-quality correlation may differ.
4. **Computation cost**: Comparing outputs of 12 Experts every step requires additional memory/time.
5. **Correlation vs causation**: Even if tension and PPL are correlated, uncertain whether causal or due to common cause.

## Verification Direction (Next Steps)

1. Build Phase 1 tension logging infrastructure after golden-llama PPL < 1000 achieved
2. Write and record experimental code in logout_test repo
3. 2000-step training + simultaneous tension/PPL recording experiment
4. Execute on Windows RTX 5070 (GPU needed)
5. Update H-CX-21 based on results (LLM scale confirmed/refuted)

## Status: 🟨 (Experiment needed in logout_test repo)
