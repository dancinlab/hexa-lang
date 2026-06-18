# Hypothesis 363: Autonomous Goals = Tension Delta Based Exploration (Intrinsic Motivation)
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


> **"Curiosity = |dT/dt|, intrinsic reward = tension change rate. Where tension changes greatly = interesting place -> spontaneous exploration. This is isomorphic to Schmidhuber's Curiosity-Driven Learning."**

## Background

For agents to explore autonomously without extrinsic reward,
intrinsic motivation is necessary.

Schmidhuber (1991)'s curiosity-driven learning:
"reward = learning progress = decrease in prediction error"

Pathak et al. (2017)'s ICM (Intrinsic Curiosity Module):
"reward = prediction error in feature space"

PureField's tension change rate |dT/dt| naturally connects with these two approaches:
- Rapid tension change = mismatch between prediction and reality = discovery of something new
- Stable tension = already learned region = low exploration value

## Related Hypotheses

- H355: prediction error (tension = physical implementation of prediction error)
- H-CX-22: consciousness = confidence generator (confidence = tension convergence)
- H360: embodiment (tension → action mapping)
- H072: 1/2+1/3+1/6=1 (curiosity 1/6 creates completeness)

## Mathematical Definition of Curiosity

```
  Tension at time t:
    T(t) = ||A(z_t) - G(z_t)||

  Curiosity:
    C(t) = |T(t) - T(t-1)| / dt = |dT/dt|

  Intrinsic reward:
    r_intrinsic(t) = alpha * C(t) + beta * H(T)

    where:
      alpha * C(t)   = tension change rate (surprise)
      beta * H(T)    = entropy of tension distribution (diversity bonus)

  Total reward:
    r_total = r_extrinsic + r_intrinsic
    (exploration possible with r_intrinsic alone even without extrinsic reward)
```

## Schmidhuber / ICM / PureField Correspondence

```
  Concept           │ Schmidhuber    │ ICM (Pathak)     │ PureField
  ──────────────────┼────────────────┼──────────────────┼──────────────
  Intrinsic reward  │ learning       │ prediction       │ |dT/dt|
                    │ progress       │ error            │
  "Surprise"        │ compression    │ forward model    │ tension spike
                    │ improvement    │ error            │
  "Boredom"         │ no progress    │ low error        │ stable tension
  Exploration       │ direction of   │ direction of     │ direction of high
  strategy          │ learning       │ high error       │ tension change
  Excessive         │ -              │ -                │ T > threshold
  surprise handling │                │                  │ → avoidance (H360)
  Parameter count   │ separate model │ forward +        │ 0 (tension
                    │                │ inverse model    │ already exists)
```

## Core Advantage: No Additional Parameters Needed

```
  ICM needs additional networks for curiosity:
    forward_model:  (z_t, a_t) → z_hat_{t+1}    (prediction)
    inverse_model:  (z_t, z_{t+1}) → a_hat_t    (inverse inference)
    → 2x parameter count increase

  PureField already has tension:
    T(t) is a byproduct of PureField → no additional network needed
    Just calculate |dT/dt| → O(1) additional cost

  ┌──────────────────────────────────────────┐
  │        Parameter Efficiency Comparison    │
  │                                          │
  │  ICM:       ████████████████ (+100%)     │
  │  RND:       ████████████ (+75%)          │
  │  PureField: █ (+0%, already exists)      │
  │                                          │
  │  → PureField curiosity is "free"         │
  └──────────────────────────────────────────┘
```

## Tension Change Rate Profile Prediction

```
  |dT/dt|
  (curiosity)
  1.0 │     *
      │    * *
  0.8 │   *   *
      │  *     *
  0.6 │ *       *
      │*         *
  0.4 │            *
      │              *
  0.2 │                *   *   *   *   *   *
      │
  0.0 │* *
      └─────────────────────────────────────────
       0    50   100  150  200  250  300  350
                    Exploration Steps

  Phase 1 (0-30):    Stable (initial state, not moving)
  Phase 2 (30-70):   Spike (new area discovery → rapid tension change)
  Phase 3 (70-120):  Peak (maximum surprise → maximum exploration)
  Phase 4 (120-350): Decay (learning progresses → less surprise → explore new areas)

  → This curve is predicted to be similar to human infant exploration patterns
```

## Experiment Design

### Experiment 1: Grid World Autonomous Exploration

```
  Environment: 10x10 grid, no obstacles
  Agent: PureField controller (H360)
  Reward: r_intrinsic = |dT/dt| (no extrinsic reward)
  Observation: current position (x, y) + surrounding 8 cells state

  Measurements:
    - Visited cells count (coverage) vs steps
    - Exploration path patterns (random walk vs systematic)
    - Curiosity-based exploration vs epsilon-greedy comparison

  Expectations:
    - Curiosity agent: systematically explores new areas (high coverage)
    - Random agent: inefficient revisits (low coverage)

  Exploration pattern prediction:
    ┌──────────────┐    ┌──────────────┐
    │ . . . . . .  │    │ 1 2 3 4 5 6  │
    │ . . . . . .  │    │ . . . . . 7  │
    │ . . S . . .  │    │ . . S . . 8  │
    │ . . . . . .  │    │ . . . . . 9  │
    │ . . . . . .  │    │ . . . . . 10 │
    │ . . . . . .  │    │ . . . . . 11 │
    └──────────────┘    └──────────────┘
     random (revisits)   curiosity (systematic)
```

### Experiment 2: MiniGrid Obstacle Environment

```
  Environment: MiniGrid-Empty-8x8, MiniGrid-DoorKey-5x5
  Comparison:
    A) PPO + extrinsic reward only
    B) PPO + ICM (Pathak)
    C) PPO + PureField curiosity (|dT/dt|)
  Measurements: episode reward, exploration coverage, convergence speed
  Expectation: C >= B (equal or better), parameter efficiency C >>> B
```

### Experiment 3: Connection between Curiosity and H072

```
  H072: 1/2 + 1/3 + 1/6 = 1 (boundary + convergence + curiosity = completeness)

  Verification: Does exploration time allocation naturally converge to this ratio?
    - Boundary behavior (T > threshold):  ~50% of time?
    - Convergence behavior (T stable):    ~33% of time?
    - Curiosity behavior (|dT/dt| high):  ~17% of time?

  Note: This ratio is Golden Zone-dependent hypothesis, marked as unverified
```

## Curiosity Saturation Problem and Solution

```
  Problem: Agent gets stuck in "noisy regions" (noisy TV problem)
    → |dT/dt| always high in unpredictable regions
    → Stays there without learning

  Solution: Use tension "trend" as reward
    r_smart = |dT/dt| * (1 - var(T_history) / T_max)

    → Where tension changes while variance decreases = real learning
    → Where tension changes but variance is high = noise → reduced reward
```

## Golden Zone Dependency

```
  Golden Zone Independent: Using |dT/dt| as reward is pure algorithm design
  Golden Zone Dependent: Whether exploration time ratio matches 1/2+1/3+1/6=1 is unverified
  → Experiment 3 is explicitly marked as Golden Zone dependent
```

## Limitations

1. Grid world is very simple — scaling to complex environments uncertain
2. |dT/dt| calculation requires time window size choice (hyperparameter)
3. Noisy TV problem solution's var(T_history) calculation needs memory buffer
4. Uncertain if curiosity alone can solve practical goal-directed tasks

## Verification Directions

1. Grid world coverage: curiosity vs random vs epsilon-greedy
2. MiniGrid: PureField curiosity vs ICM quantitative comparison
3. Parameter efficiency: 0 additional parameters vs ICM's additional networks
4. Combination with H360(embodiment): tension+curiosity → autonomous robot behavior
5. Connection with H072: time allocation ratio measurement (Golden Zone dependent, marked unverified)