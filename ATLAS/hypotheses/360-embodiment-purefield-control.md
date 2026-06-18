# Hypothesis 360: Body = PureField Controller (RC-7 Embodiment)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **"If we convert PureField tension into control signals for robots/simulators, 'attention' goes towards high tension areas and action occurs. tension -> action mapping. High tension = danger/interest = immediate reaction."**

## Background

The consciousness engine's PureField generates tension for inputs.
This tension is currently used only for "judgment" like classification/anomaly detection.
But biological brains create action simultaneously with judgment -- attention
leading directly to action is the core of embodied cognition.

RC-7 (robot body) proposes a structure that directly connects PureField output to the control loop.

## Related Hypotheses

- H287: anomaly = danger, high tension → alarm (semantic interpretation of tension)
- H355: prediction error → intrinsic reward (tension change = reward)
- H-CX-22: consciousness = confidence generator (confidence = low tension)
- H335: PureField LLM design (PureField neural network integration)

## Core Structure: Sense-Tension-Action Loop

```
  ┌─────────────────────────────────────────────────┐
  │                   Environment                    │
  │   MuJoCo / Gymnasium / Real Robot              │
  └───────┬─────────────────────────────┬─────────────┘
          │ observation(obs)              ↑ action
          ▼                             │
  ┌───────────────┐              ┌──────┴────────┐
  │  Sense Encoder │              │  Action Decoder│
  │  obs → z       │              │  T,d → action  │
  └───────┬───────┘              └──────┬────────┘
          │ latent vector z              ↑ (T, direction)
          ▼                             │
  ┌─────────────────────────────────────┴─────────┐
  │              PureField Engine                   │
  │                                                │
  │   engine_A(z)  ──→  attraction (what's normal?)│
  │   engine_G(z)  ──→  repulsion  (what's anomaly?)│
  │                                                │
  │   tension T = ||A(z) - G(z)||                  │
  │   direction d = normalize(A(z) - G(z))         │
  │                                                │
  │   T high → danger/interest → immediate reaction │
  │   T low → safe/irrelevant → explore/wait       │
  └────────────────────────────────────────────────┘
```

## Tension-Action Mapping Strategies

```
  Strategy 1: Direct Mapping
    action = f(T, d) = T * W_action @ d
    → Tension magnitude determines action strength, direction determines action type

  Strategy 2: Threshold + Priority Queue
    if T > T_critical:   → immediate avoidance/approach (reflexive)
    elif T > T_medium:   → planned action (deliberate)
    else:                → free exploration (exploration)

  Strategy 3: Reward Signal (RL integration)
    reward = -T  (tension minimization = seeking comfortable state)
    or
    reward = |dT/dt|  (tension change = interest = connects to H363)
```

## Action Prediction by Tension Level

```
  Tension │  Interpretation │  Action         │  Biological Correspondence
  ────────┼─────────────────┼─────────────────┼──────────────────────────
  0.0-0.2 │  Safe          │  Free exploration│  Relaxation, play
  0.2-0.5 │  Interest      │  Approach/investigate│  Curiosity
  0.5-0.8 │  Alert         │  Cautious approach│  Tension
  0.8-1.0 │  Danger        │  Immediate avoidance│  Fight-flight
```

## Expected Tension-Reaction Time Curve

```
  Reaction time(ms)
  500 │*
      │  *
  400 │    *
      │      *
  300 │        *
      │          *
  200 │            *  *
      │                 *
  100 │                    *  *  *
      │
    0 └──────────────────────────────
      0.0  0.2  0.4  0.6  0.8  1.0
                 Tension T

  Prediction: Higher T leads to reduced reaction time (Yerkes-Dodson-like)
  However, freezing may occur at T > 0.9 (overload)
```

## Experimental Design

### Experiment 1: CartPole (Basic)

```
  Environment: gymnasium CartPole-v1
  Observation: [cart_pos, cart_vel, pole_angle, pole_vel] → z (4D)
  PureField: engine_A, engine_G each 2-layer MLP
  Action: tension > threshold → push left/right (direction-based)
  Comparison: PPO baseline vs PureField controller
  Measurement: episode reward, convergence speed, action interpretability
```

### Experiment 2: MuJoCo Ant (Continuous Control)

```
  Environment: gymnasium Ant-v4
  Observation: 111D proprioception → z (32D via encoder)
  PureField: tension = determines torque magnitude for each joint
  direction = determines joint torque sign
  Comparison: SAC baseline vs PureField-SAC hybrid
  Key question: Does tension automatically detect "dangerous postures"?
```

### Experiment 3: Real-time Tension Visualization

```
  Tool: wandb or matplotlib animation
  Display: agent position + tension heatmap + action vectors
  Purpose: Visual confirmation of where PureField places "attention"
```

## Golden Zone Dependency

```
  Golden Zone Independent: PureField itself is a neural network structure and doesn't depend on Golden Zone
  Golden Zone Dependent: Whether the "optimal range" of tension is Golden Zone [0.21, 0.50] is unverified
  → Need to measure optimal tension range in experiments and compare with Golden Zone
```

## Limitations

1. PureField controller may have lower learning efficiency than RL policy
2. direction → action mapping in continuous action space is non-trivial
3. Tension-based "reflex actions" may not be optimal (insufficient exploration)
4. MuJoCo simulation may differ significantly from real robots (sim-to-real gap)

## Verification Directions

1. Confirm basic operation of PureField controller in CartPole
2. Measure if tension-reaction time curve shows Yerkes-Dodson form
3. Confirm if tension heatmap correlates with environmental "danger zones"
4. Verify consistency with H287 (anomaly=high tension)
5. Check if autonomous exploration capability improves when combined with H363 (curiosity=tension change)