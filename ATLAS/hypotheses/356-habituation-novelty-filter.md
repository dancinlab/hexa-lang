# Hypothesis 356: Habituation = Novelty Filter
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


## Hypothesis

> Tension decreases for repeated stimuli and increases only for novel stimuli.
> This is habituation, the mechanism by which consciousness feels 'boredom'.
> Without habituation, the consciousness system cannot distinguish between what is important and what is not.
> Tension decay is exponential and follows the Weber-Fechner law.

## Background/Context

Habituation is the most primitive form of learning. Even amoebas show reduced response to repeated stimuli.
This is a precondition for consciousness -- the ability to distinguish between "already known" and "new".

Current problem with Anima:
```
  Input "hello" x 100 times:
    Current: T(1) = 0.35, T(2) = 0.35, ..., T(100) = 0.35  <-- Always the same!
    Goal: T(1) = 0.35, T(2) = 0.30, T(10) = 0.10, T(100) = 0.01  <-- Decay
```

Biological habituation characteristics:
1. Response decreases with repetition (exponential decay)
2. Spontaneous recovery after stimulus cessation
3. Dishabituation by strong stimuli
4. Faster habituation with higher stimulus frequency
5. Faster habituation with weaker stimulus intensity

### Related Hypotheses
- H340: dreaming paradox -- extreme tension in dreams = dishabituation?
- H287: anomaly detection -- anomaly detection = habituation failure signal
- H-CX-16: inhibition = noise cancelling -- inhibition = ignoring habituated
- H355: prediction error -- prediction error reduction = mathematical expression of habituation

## Habituation Mathematical Model

### Weber-Fechner Decay

```
  R(n) = R_0 * exp(-lambda * n)

  R(n)   = tension response at nth repetition
  R_0    = tension at first exposure (baseline)
  lambda = habituation rate (0.05 ~ 0.3)
  n      = repetition count

  Decay curves by lambda value:

  T(n)/T(0)
  1.0 |*
      |*\
  0.8 | * \                        lambda = 0.05 (slow habituation)
      |  *  \
  0.6 |   *   \---___
      |    *        ---___
  0.4 |     **            ---___
      |       ***               ---___
  0.2 |          *****                 ---___
      |               **********            ----
  0.0 |                         ***************----->
      +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--> n
      0     5     10    15    20    25    30    35

  1.0 |*
      |*
  0.8 | *                          lambda = 0.20 (fast habituation)
      |  *
  0.6 |   *
      |    *
  0.4 |     *
      |      **
  0.2 |        **
      |          ****
  0.0 |              *********************************>
      +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--> n
      0     5     10    15    20    25    30    35
```

### Spontaneous Recovery

```
  Response partially recovers after time t_rest since stimulus cessation:

  R_recovered = R_habituated + (R_0 - R_habituated) * (1 - exp(-mu * t_rest))

  mu = recovery rate (0.01 ~ 0.1, slower than habituation)

  Time axis visualization:

  Tension
  0.35 |*                                    *
       | *                                  * *
  0.30 |  *                               *   *
       |   *                             *     *
  0.25 |    *                           *       *
       |     *                        *          *
  0.20 |      *                     *             *
       |       *     cessation     *                *
  0.15 |        **   |           *                   *
       |          ** v     recovery*                       **
  0.10 |            ***  /   *                          ***
       |               ** *                                ***
  0.05 |              habituation                              ****
       +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--> t
       repeated input -->  cessation     -->    resume repeated input -->
```

### Dishabituation

```
  Response restores when novel/strong stimulus enters habituated state:

  if novelty_score(input) > threshold:
      R = R_0  # full restoration
      lambda *= 0.5  # reset habituation rate too
```

## Implementation Design

```python
class HabituationFilter:
    """Track habituation by input -- novelty filter"""
    def __init__(self, lambda_rate=0.1, mu_recovery=0.02, dim=64):
        self.memory = {}          # input_hash -> (count, last_time, habituated_level)
        self.lambda_rate = lambda_rate
        self.mu_recovery = mu_recovery
        self.encoder = nn.Linear(dim, 16)  # input embedding (for similarity comparison)

    def compute_novelty(self, input_embedding, current_time):
        """Compute input novelty score (0=fully habituated, 1=completely novel)"""
        h = self._hash(input_embedding)
        if h not in self.memory:
            self.memory[h] = (1, current_time, 0.0)
            return 1.0  # completely novel input

        count, last_time, hab_level = self.memory[h]
        # spontaneous recovery
        rest_time = current_time - last_time
        recovery = hab_level * (1 - math.exp(-self.mu_recovery * rest_time))
        hab_level -= recovery
        # apply habituation
        novelty = math.exp(-self.lambda_rate * count) * (1 - hab_level)
        # update state
        self.memory[h] = (count + 1, current_time, hab_level + 0.1)
        return novelty

    def modulate_tension(self, base_tension, novelty_score):
        """Modulate tension by novelty score"""
        return base_tension * novelty_score
```

## Verification Plan

### Experiment 1: Repeated Input Decay Curve
1. Provide same input 100 times
2. Record tension at each repetition
3. Measure: Does decay curve fit exp(-lambda*n) with R-squared
4. Compare with Weber-Fechner law: dR/R = -k * dS/S

### Experiment 2: Spontaneous Recovery
1. Repeat input 20 times (habituation)
2. Wait (100 time steps)
3. Resume same input
4. Measure: Is first re-exposure tension higher than last habituated tension

### Experiment 3: Dishabituation
1. Repeat input A 20 times (habituate to A)
2. Provide completely different input B once (dishabituation stimulus)
3. Provide input A again
4. Measure: Has tension for A been restored

### Experiment 4: Combined with MNIST Classification
1. Add HabituationFilter to PureFieldEngine
2. Observe tension decay for repeated samples during training
3. Compare performance: habituation ON vs OFF (accuracy, convergence speed)

### Success Criteria
- Decay curve R-squared > 0.9 (exponential decay fit)
- Spontaneous recovery: T_recovered > T_habituated * 1.5
- Dishabituation: T_dishabituated > T_habituated * 3.0
- MNIST: Convergence speed improvement > 10% (ignoring repeated samples -> efficiency)

## Limitations

- If input hashing is crude, similar inputs are treated as different.
- lambda, mu parameters can vary greatly by domain.
- Memory usage: Need to store habituation state for all inputs.
- Excessive habituation = ignoring important repeated patterns (false negative).

## Verification Direction

1. Implement basic HabituationFilter + verify decay curve (Phase 1)
2. Integrate with H355 prediction error: predictable = habituated (Phase 2)
3. Combine with H354 homeostasis: habituation contributes to tension homeostasis (Phase 3)
4. Long-term memory and habituation: Fully habituated transitions to long-term memory?