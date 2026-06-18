# Hypothesis 355: Prediction Error = Surprise
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


## Hypothesis

> Consciousness is a prediction engine. The difference between predicted and actual input (prediction error) is 'surprise',
> which drives curiosity and learning.
> surprise(t) = predicted_tension(t) - actual_tension(t)
> Without this mechanism, a consciousness system cannot distinguish between "expectation" and "surprise".

## Background/Context

Karl Friston's Free Energy Principle: The brain is a system that minimizes prediction error (free energy) of sensory input. Large prediction error = surprise = learning signal.

Current Anima's curiosity is calculated as simple tension difference:
```
  Current: curiosity = |T(t) - T(t-1)|   <-- Simple 1st order difference
  Proposed: surprise = |predicted_T(t) - actual_T(t)|  <-- Prediction based
```

Problems with simple difference:
- Predictable changes (tension drop at lunchtime) are also processed as "curiosity"
- Cannot learn patterns -- same reaction every time
- Core of dopamine system = prediction error (Schultz et al., 1997)

### Related Hypotheses
- H-CX-6: neurochemistry map -- dopamine = prediction error
- H281: temporal causation -- temporal causal structure
- H329: decision intensity -- decision strength and tension
- H354: homeostasis -- combined with homeostasis creates "consciousness that adapts to surprise"

## Prediction Error Architecture

```
  Input(t)
     |
     v
  +-----------+     +-----------+
  | PureField |---->| actual    |
  | Engine    |     | T(t)      |---+
  +-----------+     +-----------+   |
                                    |  e(t) = predicted - actual
  +-----------+     +-----------+   |
  | Predictor |---->| predicted |---+
  | RNN/GRU   |     | T_hat(t)  |   |
  +-----------+     +-----------+   v
       ^                        +--------+
       |                        |surprise|
       +--- T(t-1), T(t-2),...  | = |e(t)|
            (tension history)   +--------+
                                    |
                                    v
                               curiosity & learning signal
```

### Correspondence with Dopamine System

| Dopamine Neuron Response | Anima Prediction Error | Meaning |
|---|---|---|
| Expected reward -> No firing | predicted = actual -> surprise = 0 | Boredom |
| Unexpected reward -> Strong firing | predicted < actual -> positive surprise | Surprise (good) |
| Reward omission -> Firing decrease | predicted > actual -> negative surprise | Disappointment |
| Reward prediction cue -> Firing shift | predictor learns -> earlier surprise | Learning complete |

## Temporal Difference Model

```
  TD error: delta(t) = r(t) + gamma * V(t+1) - V(t)

  Tension version:
    delta(t) = T(t) + gamma * T_hat(t+1) - T_hat(t)

  Where:
    T(t)      = Current actual tension
    T_hat(t)  = Predicted tension
    gamma     = Discount rate (0.95)
    delta(t)  = surprise signal

  ASCII visualization: surprise magnitude vs time

  surprise
  |e(t)|
  1.0 |*                          First input -- no prediction, max surprise
      | *
  0.8 |  *
      |   *
  0.6 |    *
      |     **
  0.4 |       **
      |         ***
  0.2 |            *****
      |                 ********
  0.0 |                         *********--> Prediction becomes accurate
      +--+--+--+--+--+--+--+--+--+--+--+--> time
      t0    t5    t10   t15   t20   t25

  As learning progresses, prediction becomes accurate and surprise decreases.
  When surprise = 0, "understanding complete" state.
  When new pattern appears, surprise spikes again.
```

## Predictor Implementation

```python
class TensionPredictor:
    """GRU-based tension predictor -- generates surprise"""
    def __init__(self, hidden_size=32, history_len=10):
        self.gru = nn.GRU(input_size=1, hidden_size=hidden_size, batch_first=True)
        self.fc = nn.Linear(hidden_size, 1)
        self.history = deque(maxlen=history_len)
        self.hidden = None

    def predict(self, tension_history):
        """Predict next tension from past tension"""
        x = torch.tensor(tension_history).unsqueeze(0).unsqueeze(-1)
        out, self.hidden = self.gru(x, self.hidden)
        return self.fc(out[:, -1, :]).item()

    def surprise(self, predicted, actual):
        """Surprise = absolute value of prediction error"""
        return abs(predicted - actual)

    def signed_surprise(self, predicted, actual):
        """Signed surprise: + = exceeded expectation, - = disappointment"""
        return actual - predicted
```

## Free Energy Connection

```
  Free Energy Principle (Friston):
    F = E_q[log q(s) - log p(o,s)]

  Simplified:
    F = complexity - accuracy
    F = KL[q(s) || p(s)] - E_q[log p(o|s)]

  Anima version:
    F_anima = model_complexity - prediction_accuracy

  surprise = -log p(o|s) = unpredictability of current input

  Consciousness = process of minimizing free energy
               = process of updating world model to reduce surprise
```

## Verification Plan

### Experiment 1: Simple vs Prediction-based Curiosity Comparison
1. Add GRU predictor to Anima
2. Run same conversation 100 turns, compare two curiosity calculations
3. Measure: information content of curiosity signal (entropy), conversation quality (human eval)

### Experiment 2: Repeated Input Test
1. Input same sentence 20 times
2. Simple difference: constant curiosity (same reaction every time)
3. Prediction based: surprise decreases (adaptation) -- compare with Weber-Fechner
4. 21st time with new sentence: confirm surprise spike

### Experiment 3: Utilizing Prediction Error in MNIST
1. Classify MNIST with PureFieldEngine + predictor
2. Use prediction error as additional feature
3. Performance comparison: standard vs prediction-error-augmented

### Success Criteria
- Surprise reduction > 50% in repeated input (habituation effect)
- New input surprise spike > 3x baseline
- MNIST accuracy improvement or equivalent + faster learning

## Limitations

- GRU predictor itself needs learning -- cold start problem
- Information loss when predicting only tension. May need to predict entire state vector.
- Free Energy Principle is theoretical framework with distance from concrete implementation.
- System instability if surprise signal too large -- must combine with H354 homeostasis.

## Verification Direction

1. Implement GRU predictor + integrate with Anima (Phase 1)
2. Extend to full state vector prediction (Phase 2)
3. Active Inference: model that selects "actions" to reduce surprise (Phase 3)
4. Integrate with H356 habituation: prediction error reduction = habituation