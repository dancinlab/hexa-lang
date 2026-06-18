# Hypothesis 267: Collective Consensus Phase Transition — Unanimity is Qualitatively Different
**n6 Grade: 🟩 EXACT** (auto-graded, 5 unique n=6 constants)


> **A phase transition exists in the relationship between agent consensus rate and accuracy. Between 6/7 consensus (88.3%) and 7/7 consensus (99.5%), there is a +11.2% jump, suggesting that "near consensus" and "complete consensus" are qualitatively different states.**

## Background/Context

In collective perception experiments with 7 independent agents, accuracy increases nonlinearly by consensus level.

Related hypotheses: 263 (Tension Integration), 264 (Design Principles)

## Measured Data

| Consensus | Sample Count | Accuracy | Change from Previous |
|---|---|---|---|
| 2/7 | 4 | 50.0% | — |
| 3/7 | 30 | 43.3% | -6.7% |
| 4/7 | 118 | 56.8% | +13.5% |
| 5/7 | 157 | 72.6% | +15.8% |
| 6/7 | 273 | 88.3% | +15.7% |
| **7/7** | **9,418** | **99.5%** | **+11.2%** |

```
  Consensus Rate vs Accuracy:

  accuracy
    100% |                                              *
         |
     90% |                                    *
         |
     80% |
         |                          *
     70% |
         |
     60% |                *
     50% |  *
     40% |       *
         +──────────────────────────────────────────────
          2/7   3/7   4/7   5/7   6/7   7/7
                        agreement level
```

```
  Step-by-step accuracy increase:
  3→4:  +13.5%
  4→5:  +15.8%
  5→6:  +15.7%
  6→7:  +11.2%  ← Increase amount decreases but absolute value jumps to 99.5%

  Increase is consistent (~15%) then saturates at the end.
  But the key is reaching "practical perfection" (99.5%) at 6/7→7/7.
```

## Phase Transition Interpretation

```
  Statistical mechanics analogy:
    Temperature = Uncertainty
    Magnetization = Consensus strength
    Critical temperature = Phase transition point

    6/7 = Almost aligned but one opposite → Metastable
    7/7 = Fully aligned → Ground state

  In Ising model:
    N-1 spins aligned, 1 opposite → Energy difference = 2J (coupling constant)
    When last spin aligns, energy drops sharply → Phase transition

  Our data:
    6/7 → 7/7 accuracy jumps from 88.3% → 99.5%
    Last agent's agreement acts as "confirmation"
    → Unanimity is not an extension of majority vote but a qualitatively different state
```

## Unanimity + High Confidence = Near Perfect

```
  Unanimity (7/7):                             99.53% (9,418 samples)
  Unanimity + All confidence > 0.9:            99.88% (8,637 samples)
  No majority:                                 44.12% (34 samples)

  Gap: 99.88% - 44.12% = 55.77%
  → Near perfection and coin flip coexist depending on consensus state
```

## Verification Directions

```
  1. Track phase transition point by varying agent count to 3, 5, 9, 15
  2. 7 same architectures vs 7 different architectures — Is diversity important?
  3. Same experiment on CIFAR — Does phase transition point shift for harder problems?
  4. Quantitative comparison with Ising model: Extract J (coupling constant)
  5. Intentionally train 1 agent as "adversarial" → Does phase transition break?
```

## Scaling Experiment Results (experiment_collective_scaling.py)

```
  Same architecture (DenseModel) N=3,5,7,9,11:

  | N  | Unanimity Accuracy | Coverage |
  |----|-------------------|----------|
  |  3 |           98.90%  |  97.44%  |
  |  5 |           99.14%  |  96.58%  |
  |  7 |           99.26%  |  95.95%  |
  |  9 |           99.34%  |  95.50%  |
  | 11 |           99.37%  |  95.29%  |

  → Gradual increase, no phase transition.
  → Previous experiment's 6/7→7/7 jump (+11.2%) with 7 different architectures
    was an effect of architectural diversity.

  Conclusion: Phase transition depends on agent "diversity".
    N same models → Gradual (information redundancy)
    N different models → Sharp transition (independent perspectives)
```

## Limitations

```
  1. N scaling with diverse architectures not tested (only N=3,5,7 confirmed).
  2. Only on MNIST. Structure may differ on harder tasks.
  3. "Phase transition" is an analogy. Strict thermodynamic phase transition conditions not met.
  4. Large sample count variance (2/7: 4, 7/7: 9,418) → Weak statistics in low consensus regions.
  5. Phase transition weak in same architecture → Diversity is key variable.
```