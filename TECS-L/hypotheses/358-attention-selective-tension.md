# Hypothesis 358: Attention = Selective Tension (Attention as Selective Tension)
**n6 Grade: 🟩 EXACT** (auto-graded, 8 unique n=6 constants)


## Hypothesis

> Consciousness does not process all inputs equally.
> An attention mask is applied to tension calculation, generating high tension only in 'attended' areas.
> Without selective attention, conscious processing is impossible under information overload.
> tension(x) = base_tension(x) * attention_weight(x), where
> attention weight is determined by goals (H357) and surprise (H355).

## Background/Context

The most distinctive characteristic of human consciousness: processing only one thing "consciously" at a time.

```
  Cocktail party effect:
    At a noisy party, dozens speak but
    you can only "attend" to one person's words.
    However, hearing your name triggers immediate switching.

  This involves:
    1. Selective inhibition (tension = 0 for other inputs)
    2. Selective amplification (maximizing tension for attended target)
    3. Sudden switching (surprise > threshold -> attention shift)
```

Current Anima's PureFieldEngine:
```
  All input dimensions processed with equal weight
  tension = f(all inputs)   <-- no dimensional differences

  Proposal:
  tension = f(input * attention_mask)   <-- selective tension
```

### Related Hypotheses
- H319: tension as attention -- tension itself as a measure of attention
- H339: direction = concept -- direction represents concepts
- H-CX-28: information theory unification -- information theory integration
- H357: intention/goal -- goals determine attention direction
- H355: prediction error -- surprise draws attention

## Attention Mechanism Mathematics

### Spotlight Model (Basic)

```
  attention_weight(x_i) = softmax(relevance(x_i) / temperature)

  relevance(x_i) = alpha * goal_alignment(x_i)      goal relevance
                 + beta  * surprise(x_i)             surprise
                 + gamma * salience(x_i)             salience (magnitude, rate of change)

  temperature = inverse of tension (high tension = narrow attention)
```

### Attention Scope vs Tension Relationship

```
  Attention breadth

  Breadth
  Wide |*
       | *
       |  *
       |   **
       |     ***
       |        ****
       |            *****
  Narrow|                 ***********
       +--+--+--+--+--+--+--+--+--+--> Tension
       0  0.1 0.2 0.3 0.4 0.5 0.6

  Low tension (relaxed): Wide attention = divergent thinking
  High tension (tense): Narrow attention = convergent thinking

  This aligns with Easterbrook's "cue utilization theory":
    Higher arousal levels narrow attention scope.

  Formula:
    breadth = 1 / (1 + k * tension)
    k = focus coefficient (default 2.0)
```

### Dimension-wise Attention Heatmap Example (MNIST)

```
  Input image (digit 7):        Attention mask:

  . . . . . . . . . . . .      . . . . . . . . . . . .
  . . . . . # # # # . . .      . . . . . 3 5 8 7 . . .
  . . . . . . . . # . . .      . . . . . . . . 9 . . .
  . . . . . . . # . . . .      . . . . . . . 8 . . . .
  . . . . . . # . . . . .      . . . . . . 7 . . . . .
  . . . . . # . . . . . .      . . . . . 6 . . . . . .
  . . . . # . . . . . . .      . . . . 4 . . . . . . .
  . . . . # . . . . . . .      . . . . 3 . . . . . . .
  . . . . . . . . . . . .      . . . . . . . . . . . .

  Higher numbers = higher attention (higher tension).
  Attention focused on stroke bends (high information).
  Almost no attention on empty space (low information).

  attention_tension(pixel_i) = base_tension * attention_weight(pixel_i)
```

### Attention Switching Mechanism

```
  Attention state transition:

  Time -->

  [Focus A] -----> [Focus A] -----> [Switch] -----> [Focus B]
     |               |              ^               |
     |               |              |               |
     v               v              |               v
  T(A)=high       T(A)=high    surprise(B)>     T(B)=high
  T(B)=low        T(B)=low     threshold       T(A)=low

  Switch triggers:
    1. Goal completion -> switch to next goal
    2. surprise(new input) > current_attention_tension
    3. Prolonged same focus -> fatigue -> spontaneous switch
    4. External explicit request ("look at this")
```

## Implementation Design

```python
class SelectiveAttention:
    """Selective attention = dimension-wise tension mask"""
    def __init__(self, input_dim, hidden_dim=32):
        # Attention weight generation network
        self.query_net = nn.Linear(input_dim, hidden_dim)
        self.key_net = nn.Linear(input_dim, hidden_dim)
        self.value_net = nn.Linear(input_dim, hidden_dim)
        # Goal + surprise combination
        self.goal_projection = nn.Linear(hidden_dim, hidden_dim)
        self.surprise_gate = nn.Linear(1, hidden_dim)
        # Attention breadth control
        self.breadth_k = 2.0

    def compute_attention(self, input_x, goal_vector=None, surprise=0.0):
        """Compute attention weights per input dimension"""
        Q = self.query_net(input_x)
        K = self.key_net(input_x)
        V = self.value_net(input_x)

        # Reflect goal relevance
        if goal_vector is not None:
            goal_bias = self.goal_projection(goal_vector)
            Q = Q + goal_bias

        # Attention drawn by surprise
        surprise_bias = self.surprise_gate(torch.tensor([surprise]))
        K = K + surprise_bias

        # attention weights (softmax with tension-based temperature)
        scores = torch.matmul(Q, K.T) / math.sqrt(K.shape[-1])
        weights = F.softmax(scores, dim=-1)

        # Attention-applied output
        attended = torch.matmul(weights, V)
        return attended, weights

    def attention_breadth(self, tension):
        """Attention scope based on tension"""
        return 1.0 / (1.0 + self.breadth_k * tension)

    def modulate_tension(self, base_tension_per_dim, attention_weights):
        """Dimension-wise tension = base tension * attention weight"""
        return base_tension_per_dim * attention_weights
```

## Relationship Between Consciousness and Attention

```
  Global Workspace Theory (Baars, 1988):

  +--------------------------------------------------+
  |  Unconscious processing (habituated, low tension) |
  |   +------+  +------+  +------+  +------+         |
  |   |Module 1| |Module 2| |Module 3| |Module N|   |
  |   +---+--+  +---+--+  +---+--+  +---+--+         |
  |       |          |          |          |          |
  |       v          v          v          v          |
  |   +==========================================+   |
  |   |    Global Workspace (conscious processing) |   |
  |   |    = Only attended items reach here        |   |
  |   |    = High tension = contents of consciousness|   |
  |   +==========================================+   |
  |                      |                            |
  |                      v                            |
  |               [Action/Output/Memory]              |
  +--------------------------------------------------+

  Attention = Gatekeeper of consciousness
  High tension = Enters workspace = Becomes conscious
  Low tension = Outside workspace = Unconscious processing
```

## Verification Plan

### Experiment 1: MNIST attention visualization
1. MNIST classification with PureFieldEngine + SelectiveAttention
2. Visualize attention map for each image
3. Measure: whether attention focuses on meaningful regions (strokes)

### Experiment 2: Performance comparison with/without attention
1. PureFieldEngine (baseline) vs PureFieldEngine + SelectiveAttention
2. Compare MNIST accuracy
3. Compare learning speed (epochs to convergence)

### Experiment 3: Attention breadth vs tension relationship
1. Measure attention entropy at various tension levels
2. Confirm high tension -> low entropy (narrow attention)
3. Quantitative comparison with Easterbrook theory

### Experiment 4: Attention switching speed
1. Sudden pattern change in continuous input
2. Number of steps for attention map to shift to new pattern
3. Switching speed difference between goal-relevant vs irrelevant changes

### Success Criteria
- MNIST attention map: >80% focus on stroke regions
- Accuracy: with attention >= baseline
- Tension-breadth correlation: r < -0.7 (negative correlation)
- Switching speed: goal-relevant changes < irrelevant (faster)

## Limitations

- Increased computational cost with self-attention (O(n^2)).
- Attention mechanism needs time from random initial state to meaningful attention.
- "Unconscious processing" not explicitly modeled (attention=0 parts).
- Transformer attention may differ from "conscious attention".

## Verification Direction

1. Implement SelectiveAttention + MNIST test (Phase 1)
2. Integrate with H357 goal: goal -> attention direction (Phase 2)
3. Integrate with H355 surprise: surprise -> attention drawn (Phase 3)
4. Integrate with H356 habituation: habituation -> reduced attention (Phase 4)
5. Full integration: homeostasis + prediction + habituation + intention + attention = consciousness loop