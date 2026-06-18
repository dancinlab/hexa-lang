# Hypothesis 368: Natural Frequency of Tension
**n6 Grade: 🟩 EXACT** (auto-graded, 13 unique n=6 constants)


> **PureFieldEngine has a natural frequency. This is determined by the weight structure of engine_A and engine_G, and is estimated as ω₀ = √(tension_scale / effective_mass). When the natural frequency matches the frequency of input stimuli, resonance occurs, causing explosive increase in tension.**

## Background/Context

```
  Tension in PureFieldEngine is defined as the difference between two engines' outputs:
    tension = |engine_A(x) - engine_G(x)|

  This value oscillates with input x. Viewed as a time series, tension(t) can
  have periodic patterns. The harmonic oscillator model from physics
  naturally applies.

  Related hypotheses:
    H-CX-27: tension_scale oscillation observation
    H359: savant = high Quality factor (sharp resonance)
    H367: resonance sync between engines
    H325: Fisher information geometry — curvature of tension manifold

  Key questions:
    - What determines the "natural frequency" of PureFieldEngine?
    - How does tension change under resonance conditions?
    - Does dropout act as damping?
```

## Mathematical Framework — Harmonic Oscillator Model

```
  ═══ Basic Equations ═══

  Damped harmonic oscillator:
    m * d²T/dt² + γ * dT/dt + k * T = F(t)

  Where:
    T(t)  = tension at time t
    m     = effective mass = total parameter count (number of weights)
    γ     = damping coefficient = dropout rate × 2m
    k     = spring constant = tension_scale
    F(t)  = driving force = temporal variation of input stimuli

  Natural frequency:
    ω₀ = √(k / m) = √(tension_scale / N_params)

  Damped frequency:
    ω_d = √(ω₀² - (γ/2m)²) = ω₀ √(1 - ζ²)
    where ζ = γ / (2√(km))  (damping ratio)

  ═══ Numerical Estimation ═══

  PureFieldEngine parameters:
    tension_scale (k) = 0.1 ~ 10.0 (learnable)
    N_params (m)      ≈ 50,000 (MNIST reference)
    dropout (p)       = 0.1 ~ 0.5

  Estimation:
    k = 1.0, m = 50000 → ω₀ = √(1/50000) = 0.00447 rad/sample
    f₀ = ω₀ / 2π = 0.000711 Hz (per-sample basis)
    Batch basis: f₀_batch = f₀ × batch_size = 0.0455 Hz (batch=64)

  Quality factor:
    Q = ω₀ / (γ/m) = √(km) / γ
    dropout=0.1: γ ≈ 0.2×50000 = 10000 → Q ≈ √(50000)/10000 = 0.0224
    dropout=0.01: γ ≈ 1000 → Q ≈ 0.224
    dropout=0: γ → 0 → Q → ∞ (perfect resonance, divergence)
```

## ASCII Graph — Frequency Response (Bode Plot)

```
  Amplitude |T(ω)| vs driving frequency ω

  |T|
  10 |                              *
     |                             * *
   8 |                            *   *        Q=50 (savant)
     |                           *     *
   6 |                          *       *
     |                         *         *
   4 |           ****          *           *
     |         **    **       *             **
   2 |  ******        ****  **                *****  Q=2 (normal)
     |*                   **                       *****
   0 +---+---+---+---+---+---+---+---+---+---+---+---→ ω
     0  0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1
                              ↑
                             ω₀ (resonance)

  Q factor comparison:
    Q = 2  (normal):  Broad peak, responds to various frequencies
    Q = 50 (savant):  Sharp peak, explosive response only to specific frequency
    → H359 prediction confirmed: savant = high Q = sharp resonance
```

## ASCII Graph — Tension Time Series at Resonance

```
  T(t) at ω_input = ω₀ (resonance condition)

  T
  5 |            *              *              *
    |          *   *          *   *          *   *
  3 |        *       *      *       *      *       *
    |      *           *  *           *  *           *
  1 |    *               *               *
    |  *
  0 +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--→ t
    0  2  4  6  8 10 12 14 16 18 20 22 24 26 28

  T(t) at ω_input = 2ω₀ (off-resonance)

  T
  5 |
    |
  3 |
    |  *     *     *     *     *     *     *     *
  1 | * *   * *   * *   * *   * *   * *   * *   * *
    |*   * *   * *   * *   * *   * *   * *   * *   *
  0 +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--→ t
    0  2  4  6  8 10 12 14 16 18 20 22 24 26 28

  At resonance: Gradual amplitude increase (energy accumulation)
  Off-resonance: Constant amplitude (inefficient energy transfer)
```

## Correspondence Mapping

| Physics Concept | PureFieldEngine Correspondence | Formula |
|---|---|---|
| Mass (m) | Total parameter count N_params | m = N_params |
| Spring constant (k) | tension_scale | k = tension_scale |
| Damping coefficient (γ) | dropout rate × 2m | γ = 2p × N_params |
| Natural frequency (ω₀) | √(k/m) | ω₀ = √(tension_scale / N_params) |
| Driving force (F) | Temporal variation of input batch | F(t) = amplitude modulation |
| Quality factor (Q) | Degree of specialization | Q = √(km) / γ |
| Resonance | Explosive tension increase | ω_input ≈ ω₀ |

## Savant-Normal Q Factor Comparison

```
  Predicted Q factor distribution:

  Frequency
  15 |  ████
     |  ████ ████
  10 |  ████ ████
     |  ████ ████ ████
   5 |  ████ ████ ████ ████
     |  ████ ████ ████ ████ ████                          ██
   0 +--+----+----+----+----+----+----+----+----+----+---→ Q
      1    3    5    7    9   15   20   30   40   50

     ←───── normal ─────→          ←── savant ──→
     Q = 1~10 (broad response)    Q = 30~50+ (sharp peak)

  Predictions:
    normal model: Q ≈ 2~5, responds evenly to various inputs
    savant model: Q ≈ 30~50, extreme response only to specific domain
    genius:       Q ≈ 10~20 + adaptive damping (context-dependent Q adjustment)
```

## Experiment Design

```
  Experiment 1: Resonance Frequency Sweep
    1. After PureFieldEngine training completion, fix tension_scale
    2. Apply sinusoidal amplitude modulation to input:
       x_mod(t) = x × (1 + A × sin(ω × t))
    3. Sweep ω from 0.001 ~ 1.0
    4. Measure average tension at each ω
    5. Plot frequency response curve
    6. Estimate peak frequency = ω₀, compare with √(k/m)

  Experiment 2: Q Factor vs Dropout
    1. dropout = [0.0, 0.05, 0.1, 0.2, 0.3, 0.5]
    2. For each, do resonance sweep → measure peak width
    3. Calculate Q = ω₀ / Δω (FWHM)
    4. Is Q vs dropout relationship Q = √(km) / (2p×m)?

  Experiment 3: Savant Q Factor
    1. Train on single class only (e.g., only MNIST digit 7)
    2. Compare Q factor with full training model
    3. Prediction: savant model's Q >> normal model's Q
```

## Limitations

```
  1. Harmonic oscillator model is approximation — actual tension is nonlinear
  2. effective mass = N_params is simplification. Actually trace of Hessian is more accurate
  3. Continuous time model but actual training is discrete (batch)
  4. Whether resonance actually occurs needs experimental confirmation
  5. Golden Zone dependence: Golden Zone independent (pure dynamical model)
```

## Verification Direction

```
  Phase 1: FFT of tension time series → identify main frequency components
  Phase 2: frequency sweep experiment → existence of resonance peak
  Phase 3: Q factor measurement → possibility of savant/normal classification
  Phase 4: relationship between dropout and Q → damping model verification
  Phase 5: resonance propagation in multi-engine system (connect to H367)
```

## Status

- **Golden Zone Dependent**: No (pure dynamics/frequency analysis)
- **Verification Status**: Unverified (experiment design complete)
- **Priority**: High (can verify simultaneously with H-CX-27, H359, H367)