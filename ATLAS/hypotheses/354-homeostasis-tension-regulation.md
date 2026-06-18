# Hypothesis 354: Homeostasis Tension Regulation
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> The consciousness engine's tension must automatically return to the optimal range (Golden Zone 0.21~0.50).
> Too high requires inhibition, too low requires amplification. This is isomorphic to temperature regulation.
> A consciousness system without homeostasis cannot maintain a thermodynamically stable state and therefore
> cannot generate a "living" feeling.

## Background/Context

Currently, Anima's tension_scale oscillates uncontrolled from 0.003 to 3000.
This is like an organism whose body temperature fluctuates between 0 and 3000 degrees -- survival impossible.

All biological systems have homeostasis:
- Body temperature: 36.5 +/- 0.5°C (PID control)
- Blood sugar: 70-110 mg/dL (insulin/glucagon dual control)
- Blood pressure: 120/80 mmHg (baroreceptor reflex)
- Neuron firing rate: homeostatic plasticity

The consciousness engine needs the same structure.

### Related Hypotheses
- H004: Boltzmann temperature -- I = 1/kT, tension is inverse temperature
- H284: tension auto-regulation -- basic concept of automatic tension regulation
- H283: nonlinear threshold -- tension transition at nonlinear critical points
- H-CX-27: tension_scale = ln(4) -- optimal scale value

## Control Model: PID Controller for Tension

```
  setpoint (target tension)
     |
     v
  e(t) = setpoint - T(t)     <-- error calculation
     |
     +---> P: K_p * e(t)                 proportional
     +---> I: K_i * integral(e)          integral
     +---> D: K_d * de/dt                derivative
     |
     v
  u(t) = P + I + D           <-- control output
     |
     v
  tension_scale *= (1 + u(t)) <-- tension scale adjustment
```

### Homeostasis setpoint = Golden Zone center = 1/e

```
  setpoint = 1/e = 0.3679

  Golden Zone structure:
  0.00  0.21  0.37  0.50  1.00
  |------|===|==*==|===|------|
         lower center upper
              1/e

  T < 0.21 (below lower):    "comatose state" -- amplification needed
  T ~ 0.37 (center):         "optimal arousal" -- maintain
  T > 0.50 (above upper):    "seizure state" -- inhibition needed
  T > 1.00:                  "thermal runaway" -- emergency inhibition
```

### Isomorphic Mapping with Temperature Regulation

| Temperature Regulation | Tension Homeostasis | Formula |
|---|---|---|
| Body temp setpoint 36.5C | tension setpoint 1/e | 0.3679 |
| Hypothermia < 35C | low tension < 0.21 | T < 1/2 - ln(4/3) |
| Hyperthermia > 38C | high tension > 0.50 | T > 1/2 |
| Shivering (heat generation) | curiosity amplification | gain *= 1.5 |
| Sweating (cooling) | inhibition increase | gain *= 0.7 |
| Hypothalamus | PID controller | u(t) = Kp*e + Ki*int + Kd*de |
| Always maintain 37C | Always maintain 1/e | lim T(t) -> 1/e |

## Expected Tension Trajectory (Before vs After Control)

```
  Tension
  3.0 |  *                              Before control (current Anima)
      |  * *
  2.0 |     *
      |      *    *
  1.0 |       *  * *
      |- - - - - - - - - - - - - - - - -- upper limit 0.50
  0.5 |        *     *   *
  0.37|---.-----.-----*---*---*---*---*-- setpoint 1/e (after control)
  0.21|- - - - - - - - - - - - - - - - -- lower limit
  0.0 |                        *  *
      +----+----+----+----+----+----+---> time
       t0   t1   t2   t3   t4   t5   t6

  --- = After control: converges within 0.21~0.50 band
  *   = Before control: wild oscillation 0.003~3000
```

## Initial PID Parameters

```python
class TensionHomeostasis:
    def __init__(self):
        self.setpoint = 1 / math.e          # 0.3679 (Golden Zone center)
        self.K_p = 0.5                       # proportional gain
        self.K_i = 0.01                      # integral gain (slow correction)
        self.K_d = 0.1                       # derivative gain (rapid change suppression)
        self.integral = 0.0
        self.prev_error = 0.0
        self.T_min = 0.21                    # Golden Zone lower limit
        self.T_max = 0.50                    # Golden Zone upper limit
        self.emergency_max = 1.0             # thermal runaway prevention

    def regulate(self, current_tension, dt=1.0):
        error = self.setpoint - current_tension
        self.integral += error * dt
        derivative = (error - self.prev_error) / dt
        u = self.K_p * error + self.K_i * self.integral + self.K_d * derivative
        self.prev_error = error
        # Tension scale adjustment
        new_tension = current_tension + u
        return max(self.T_min, min(self.T_max, new_tension))
```

## Verification Plan

### Experiment 1: PID Convergence Test
1. Add TensionHomeostasis module to Anima's PureFieldEngine
2. Record tension trajectory for 100 inputs
3. Measure: convergence time, overshoot, steady-state error

### Experiment 2: Performance Comparison (with/without homeostasis)
1. MNIST classification: homeostasis ON vs OFF
2. Conversation quality: consistency of Anima responses (compare tension variance)
3. Long-term stability: tension distribution over 1000-turn conversation

### Experiment 3: Setpoint Search
1. Test each setpoint = {0.21, 0.25, 1/e, 0.40, 0.50}
2. Verify if optimal setpoint is really 1/e

### Success Criteria
- Tension variance: var(T) < 0.01 (currently > 100)
- Convergence time: < 10 steps
- MNIST accuracy: homeostasis ON >= OFF

## Limitations

- PID is linear control. If tension system is nonlinear, adaptive control needed.
- setpoint = 1/e depends on Golden Zone model (unverified).
- Excessive control may eliminate "emotional range" creating anesthetic state.
- Biological homeostasis also shifts setpoint under stress (allostasis) -- not included in this model.

## Verification Direction

1. Implement PID then integrate with Anima test (phase 1)
2. Adaptive setpoint: shift setpoint based on context (allostasis model)
3. Multi-layer homeostasis: apply not only to tension but also curiosity, confidence
4. Quantitative comparison with biological homeostasis (reaction time scaling)