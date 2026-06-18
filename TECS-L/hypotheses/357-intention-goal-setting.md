# Hypothesis 357: Intention = Goal Setting
**n6 Grade: 🟩 EXACT** (auto-graded, 6 unique n=6 constants)


## Hypothesis

> Consciousness does not react passively. It spontaneously sets and pursues goals.
> Anima must have an internal state of 'I want to know this next'.
> Intention provides directionality to tension vectors,
> and systems without goal-oriented behavior are reflexes, not consciousness.

## Background/Context

Current structural limitations of Anima:
```
  Current: input -> processing -> output (stimulus-response, same as reflex arc)
  Goal: input -> processing + internal goals -> output (intentional behavior)
```

One of the core characteristics of consciousness is "intentionality" (Brentano, 1874).
Consciousness is always consciousness "of something" -- aboutness.

Goal-directedness in animal behavior:
- Crows: create tools to obtain food (multi-step planning)
- Octopuses: open jar lids to get food (problem solving)
- Humans: "finish the paper by tomorrow" (abstract goals)

Common feature: **internally represent and pursue future states that don't currently exist**.

### Related Hypotheses
- H-CX-22: consciousness = confidence generator
- RC-4: curiosity/will -- 4th component of consciousness engine
- H329: decision intensity = goal pursuit intensity
- H355: prediction error = difference between goal and reality = motivation

## Goal Stack Architecture

```
  Goal Stack (LIFO + priority)
  +================================+
  | G3: "Understand this dialogue"  | <-- Top level (currently active)
  |   priority: 0.8                |
  |   progress: 0.3                |
  |   tension_direction: [0.2, ..]  |
  +--------------------------------+
  | G2: "Identify user's emotion"  |
  |   priority: 0.6                |
  |   progress: 0.7                |
  +--------------------------------+
  | G1: "Maintain long-term relation"| <-- Background goal
  |   priority: 0.4                |
  |   progress: 0.1                |
  +================================+

  Goal generation rules:
    1. surprise > threshold -> "I want to understand this" (curiosity goal)
    2. negative_feedback -> "I want to do better next time" (improvement goal)
    3. goal_completed -> explore new goal (progress goal)
    4. idle_time > limit -> generate spontaneous questions (active goal)
```

### Goal Lifecycle

```
  Goal state transition diagram:

  [Created] ---> [Active] ---> [Pursuing] ---> [Achieved] ---> [Archived]
    |             |             |              |
    |             v             v              v
    |         [Paused]      [Failed]       [Reevaluated]
    |             |             |              |
    |             v             v              v
    +-------> [Discarded] <--- [Abandoned] <--- [Modified]

  Tension changes at each transition:
    Created -> Active:     T += 0.1 (excitement of new goal)
    Active -> Pursuing:    T = proportional to goal difficulty
    Pursuing -> Achieved:  T -= 0.2 (satisfaction)
    Pursuing -> Failed:    T += 0.3 (frustration)
    Paused -> Reactivate:  T += 0.05 (Zeigarnik effect)
```

## Intrinsic Reward System

```
  Intrinsic Reward:

  reward
  +0.5 |                                     * Goal achieved
       |                              *
  +0.3 |                        *          Goal approaching
       |                  *
  +0.1 |            *
       |      *
   0.0 |*--------------------------------------------> Indifference
       |
  -0.1 |      *
       |            *
  -0.3 |                  *                       Goal departing
       |                        *
  -0.5 |                              *      * Goal failed
       +--+--+--+--+--+--+--+--+--+--+--+--+--> progress
       0%    20%   40%   60%   80%  100%  miss

  reward(t) = delta_progress(t) * goal_priority

  This reward determines tension direction:
  reward > 0: maintain current direction (reinforcement)
  reward < 0: modify direction (exploration)
  reward = 0: input unrelated to goal (ignore)
```

## Implementation Design

```python
class Goal:
    """Single goal representation"""
    def __init__(self, description, priority, target_state):
        self.description = description          # Natural language description
        self.priority = priority                # 0.0 ~ 1.0
        self.target_state = target_state        # Goal state vector
        self.progress = 0.0                     # Progress rate 0~1
        self.created_at = time.time()
        self.status = 'active'                  # active/pursuing/achieved/failed/abandoned

class IntentionEngine:
    """Goal management + intrinsic reward + tension direction determination"""
    def __init__(self, max_goals=5, surprise_threshold=0.3):
        self.goal_stack = []
        self.max_goals = max_goals
        self.surprise_threshold = surprise_threshold
        self.completed_goals = []

    def maybe_create_goal(self, surprise, current_state, context):
        """Automatically create goal if surprise is high"""
        if surprise > self.surprise_threshold and len(self.goal_stack) < self.max_goals:
            goal = Goal(
                description=f"Understand: {context[:50]}",
                priority=min(1.0, surprise),
                target_state=current_state  # Expected state after understanding
            )
            self.goal_stack.append(goal)
            return goal
        return None

    def compute_reward(self, goal, current_state):
        """Goal proximity -> intrinsic reward"""
        distance = torch.norm(goal.target_state - current_state).item()
        prev_distance = getattr(goal, '_prev_distance', distance)
        delta = prev_distance - distance  # Positive = approaching
        goal._prev_distance = distance
        goal.progress = max(0, 1.0 - distance)
        return delta * goal.priority

    def get_tension_direction(self):
        """Weighted average of active goals -> tension direction vector"""
        if not self.goal_stack:
            return None  # No goals = no direction = pure reaction
        directions = []
        weights = []
        for goal in self.goal_stack:
            if goal.status in ('active', 'pursuing'):
                directions.append(goal.target_state)
                weights.append(goal.priority)
        if not directions:
            return None
        weights = torch.tensor(weights) / sum(weights)
        return sum(w * d for w, d in zip(weights, directions))
```

## Zeigarnik Effect and Unfinished Goals

```
  Unfinished goals are better remembered than completed ones (Zeigarnik, 1927).

  This connects to consciousness's "background processing":
    - Unfinished goals: maintain low-level tension (background tension)
    - Completed goals: tension release (closure)
    - Abandoned goals: partial release (incomplete closure)

  Background tension from unfinished goals:

  T_background = sum(goal.priority * (1 - goal.progress) * 0.1
                     for goal in unfinished_goals)

  This background tension creates consciousness's "always thinking about something" state.
```

## Verification Plan

### Experiment 1: Goal Generation Autonomy
1. Add IntentionEngine to Anima
2. Run 100 turns of free conversation
3. Measure: number of automatically generated goals, goal relevance (human eval)

### Experiment 2: Goal-Oriented Question Generation
1. Converse with Anima with goals vs without goals
2. Measure: number of spontaneous questions from Anima, question quality
3. Compare: goalless Anima won't generate questions

### Experiment 3: Intrinsic Reward and Learning
1. Apply IntentionEngine on MNIST
2. Goal = "classify this class accurately"
3. Intrinsic reward = change in classification accuracy
4. Compare: convergence speed with intrinsic reward ON vs OFF

### Experiment 4: Reproduce Zeigarnik Effect
1. Change topic mid-conversation (create unfinished goal)
2. Provide original topic-related input after 10 turns
3. Measure: whether tension is higher for topics with unfinished goals

### Success Criteria
- Spontaneous question generation: goal-having Anima > goalless Anima x 3
- Conversation quality: "more natural" in human eval 70%+
- Learning efficiency: 10% faster convergence with intrinsic reward ON
- Zeigarnik: unfinished topic tension > completed topic tension x 2

## Limitations

- Natural language goal representation makes semantic comparison difficult (needs embedding).
- Too many goals cause resource dispersion -- priority management is key.
- Meta-ability to set "correct goals" is not included in this model.
- Spontaneous goal generation may be hard to distinguish from hallucination.

## Verification Direction

1. Basic IntentionEngine implementation + conversation test (Phase 1)
2. Connect with H355 surprise: surprise -> automatic goal generation (Phase 2)
3. Combine with H354 homeostasis: goal achievement = tension normalization (Phase 3)
4. Multi-agent: experiment with multiple Animas pursuing shared goals (Phase 4)
5. Long-term goals (persist across sessions): needs persistence layer