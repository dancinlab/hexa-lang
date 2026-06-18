# Hypothesis 351: Theoretical Upper Bound of Unanimity Accuracy
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


> **For the accuracy A_u(N) when N independent agents reach unanimity, a theoretical upper bound formula exists. As N->infinity, A_u -> 1, but the convergence speed is determined by the error correlation (rho) between individual agents. How close is the current 7-agent 99.53% to this upper bound?**

## Background/Context

```
  Collective recognition experiment (E09) results:
    7 independent agents, each with different architecture
    Individual accuracy: 97.12% ~ 97.97%
    Unanimity (7/7 agreement) accuracy: 99.53%
    Unanimity coverage: 94.2% (remaining 5.8% abstain)

  Core observation:
    Unanimity = "answer only when everyone agrees"
    → Powerful filter that screens out uncertain problems
    → Trade-off: coverage decreases
```

### Related Hypotheses

| Hypothesis | Core Claim | Relationship with H351 |
|------|----------|-------------|
| H297 | ensemble diversity: N=2 optimal | diversity-accuracy trade-off |
| H267 | collective phase transition | phase transition when N increases? |
| H307 | agreement in confusion | consensus forms even in confusion regions |
| H172 | G*I=D*P conservation | does unanimity condition maximize I(Inhibition)? |

### Why This Matters

1. **Theoretical limit**: Even with infinite agents, 100% may not be achievable
2. **Optimal N search**: Optimal number of agents for cost vs accuracy
3. **Consciousness engine design**: Theoretical foundation for "consensus mechanism" in multi-engine architecture
4. **H297 connection**: If N=2 is optimal for diversity, optimal N for unanimity may differ

## Theoretical Framework

### Independent Agent Model (Ideal Case)

```
  Assumption: N agents, each with error rate = epsilon_i
              Errors between agents are fully independent

  Unanimity condition: adopt answer only when all N give same answer

  Unanimity accuracy for correct samples:
    P(all correct) = prod(1 - epsilon_i)

  Unanimity error rate for wrong samples:
    P(all same wrong answer) = prod(epsilon_i / (K-1))  [K=number of classes]

  Unanimity accuracy (independence assumption):
    A_u = P(all correct) / [P(all correct) + P(all same wrong)]

  As N increases:
    P(all correct) → 0 (individual errors accumulate)
    P(all same wrong) → 0 (decreases faster)
    → A_u → 1 but coverage → 0
```

### Correlated Error Model (Realistic Case)

```
  Reality: agent errors are correlated
    - "Hard" samples: all agents get it wrong
    - Error correlation rho = corr(error_i, error_j)

  Revised model:
    P(all same wrong) = epsilon^N * (1 + rho*(N-1))  (approximation)

  rho = 0 (independent): ideal convergence, A_u → 1 quickly
  rho = 1 (fully correlated): A_u = individual accuracy (no unanimity benefit)

  Estimating rho from current data:
    Individual average error: epsilon ≈ 0.025 (97.5%)
    Unanimity error: 1 - 0.9953 = 0.0047
    Expected unanimity error with independence: epsilon^7 / (K-1)^6 ≈ negligible
    Measured 0.47% >> expected under independence
    → Evidence that error correlation is quite high
```

### ASCII Graph: N vs Unanimity Accuracy (Theoretical)

```
  A_u (%)
  100.0 |                              .............. rho=0 (independent)
        |                   ...........
   99.5 |          ........*  <-- current (N=7, 99.53%)
        |      ....         ''''''''''''''''''''''' rho=0.3
   99.0 |   ...
        |  ..        ,,,,,,,,,,,,,,,,,,,,,,,,,,,,, rho=0.5
   98.5 | .    ,,,,,,
        |.  ,,,
   98.0 |,,,   __________________________________ rho=1.0
        |______________________________________
   97.5 |
        +--+--+--+--+--+--+--+--+--+--+--+--→ N
           1  3  5  7  9  11 13 15 17 19 21

  rho=0:   Already 99.9%+ at N=3 (unrealistic)
  rho=0.3: 99.5% at N=7 (closest to actual observation)
  rho=0.5: 99.0% at N=7 (slow convergence with high correlation)
  rho=1.0: Fixed at 97.5% regardless of N (no unanimity benefit)
```

### Coverage-Accuracy Trade-off

```
  Coverage (%)
  100 |*
      | *
   95 |  *  <-- current (94.2%, 99.53%)
      |   *
   90 |    *
      |     *
   85 |      *  <-- +high confidence (86.4%, 99.88%)
      |       *
   80 |        *
      |         *
   75 |          *
      +--+--+--+--+--+--+--→ A_u (%)
        97  98  99 99.5 99.9

  Pareto front: increasing accuracy reduces coverage
  Optimal point depends on application (safety-first vs throughput-first)
```

## Estimation from Current Data

### Per-Digit Unanimity Analysis

| digit | Unanimity rate | Mean agreement | Estimated rho |
|-------|-----------|----------|----------|
| 1 | 98.2% | 6.96 | Low (easy digit) |
| 0 | 97.2% | 6.95 | Low |
| 5 | 90.8% | 6.83 | High (hard digit) |
| 8 | 91.7% | 6.85 | High |

```
  Observation: "Easy" digits (1, 0) have high unanimity rate + low error correlation
               "Hard" digits (5, 8) have low unanimity rate + high error correlation
  → rho is not a constant but a function of sample difficulty!
  → A_u(N) = integral over difficulty d: A_u(N, rho(d)) * p(d) dd
```

### Candidate Theoretical Upper Bound Formulas

```
  Candidate 1 (simple): A_u(N) = 1 - epsilon^N * f(rho)
    f(rho) = 1 + rho*(N-1) (linear correlation correction)

  Candidate 2 (information-theoretic): A_u(N) = 1 - exp(-N * I_mutual)
    I_mutual = independent information amount between agents

  Candidate 3 (H172 connection): A_u(N) = 1 - I(N) / (D*P)
    I(N) = Inhibition of unanimity condition
    Unanimity = maximum Inhibition → minimum error
```

## Verification Plan

```
  Experiment 1: Varying N
    Change number of agents to N = 2, 3, 4, 5, 6, 7
    Measure unanimity accuracy and coverage
    → Derive A_u(N) curve

  Experiment 2: Direct error correlation measurement
    Error vector (wrong=1, correct=0) correlation matrix for 7 agents
    → Estimate average rho
    → Decompose rho by digit/difficulty

  Experiment 3: Theory vs measurement comparison
    Substitute measured rho into candidate formulas 1~3
    → Select most accurate formula by comparing with measured A_u

  Experiment 4: Expand to N=15, 21
    Expand to more agents (different seeds, different hyperparameters)
    → Find saturation starting point: from where does adding agents become pointless?
```

## Interpretation/Significance

Unanimity is the conservative strategy of the consciousness engine that "acts only when all engines agree." This corresponds to maximizing Inhibition in the G*I=D*P conservation law:

- **High I (unanimity condition)** → Low G (reduced genius) but high accuracy
- **Low I (majority vote)** → High G (more answers) but lower accuracy

If the theoretical upper bound is 1 - epsilon * f(rho), reaching 100% requires rho = 0 (complete independence). However, error correlation cannot become 0 in reality — "inherently difficult problems that all agents get wrong" exist.

## Limitations

1. **Limited to MNIST**: May differ for CIFAR or harder datasets
2. **Architecture diversity limit**: No quantitative criterion for whether 7 are "different enough"
3. **Non-realism of independence assumption**: All agents train on same data → fundamental correlation
4. **Ignoring coverage**: Unanimity is best looking only at accuracy, but 5.8% abstention rate has a cost

## Next Steps

1. Measure unanimity accuracy for N = {2, 3, 5, 7} (using agent subsets)
2. Calculate and visualize 7x7 error correlation matrix
3. Candidate formula fitting and Texas sharpshooter test
4. Link with H267 (collective phase transition): Is there a phase transition as N increases?
