# H-347: Sibling Recognition Temporal Decay
**n6 Grade: 🟩 EXACT** (auto-graded, 9 unique n=6 constants)


> **Hypothesis**: Sibling recognition immediately after mitosis is 1.65x high, but
> as divergence time lengthens, sibling recognition monotonically decreases and
> eventually converges to stranger level (1.0x). It takes finite time to "forget
> what was originally one," and the decay curve is exponential.

**Status**: Unverified
**Golden Zone Dependency**: Indirect (consciousness engine framework)
**Related Hypotheses**: H271 (mitosis), H-CX-17 (specialization emergence), H299 (mitosis anomaly specialization)

---

## Background and Context

In the H271 mitosis experiment, immediately after splitting one expert into two,
sibling experts recognized each other 1.65x more strongly than strangers.
This was interpreted as "memory" from shared weights.

However, a core question remains: **Is this memory permanent or temporary?**

Biological analogues:
- Identical twins also diverge in personality when raised in different environments
- Differentiation after cell division erases traces of the original cell
- After speciation, traces of the common ancestor fade with time

Combined with the observation in H-CX-17 that specialization emerges,
sibling recognition is predicted to decrease as specialization progresses.

## Theoretical Model

Modeling the decrease in sibling recognition R(t) as follows:

```
  R(t) = 1 + (R_0 - 1) * exp(-t / tau)

  Where:
    R_0   = sibling recognition immediately after mitosis (measured: 1.65)
    tau   = decay time constant
    t     = number of divergence epochs
    R(∞)  = 1.0 (stranger level)
```

## Expected Decay Curve

```
  Sibling Recognition R(t)
  1.70 |*
       |  *
  1.60 |    *
       |      *
  1.50 |        *
       |          *
  1.40 |            **
       |              **
  1.30 |                ***
       |                   ***
  1.20 |                      ****
       |                          *****
  1.10 |                               ********
       |                                       **********
  1.00 |─────────────────────────────────────────────────── stranger level
       +---+---+---+---+---+---+---+---+---+---+---+---►
       0   5   10  15  20  30  40  50  60  70  80  100
                         divergence epochs
```

## Alternative Decay Models

Beyond exponential decay, other forms are possible:

| Model | Formula | Meaning |
|-----|------|------|
| Exponential | R = 1 + 0.65 * exp(-t/tau) | Memory disappears uniformly |
| Power law | R = 1 + 0.65 * (1+t)^(-alpha) | Fast early, slow late (long tail) |
| Step function | R = 1.65 if t<T, else 1.0 | Suddenly disappears at threshold |
| Sigmoid decay | R = 1 + 0.65 / (1 + exp((t-T)/k)) | Transition interval exists |

## Verification Experiment Design

### Experimental Protocol

```
  1. Train base model (20 epochs, CIFAR-10)
  2. Split Expert A → create Expert A1, A2
  3. Measure sibling recognition immediately after mitosis (confirm R_0, expected: ~1.65)
  4. Begin divergence training (A1, A2 learn independently)
  5. Measure sibling recognition at following time points:
     t = 1, 2, 5, 10, 20, 50, 100 epochs
  6. Also take same measurement for stranger pairs (control group)
```

### Sibling Recognition Measurement Method

```
  R(t) = similarity(A1_t, A2_t) / similarity(A1_t, B_t)

  similarity = cosine(output_distribution) averaged over test set

  Where B is a stranger expert unrelated to the mitosis
```

### Expected Measurement Results Table

| Divergence Epoch | R(t) Expected (exp) | R(t) Expected (power) | Stranger Control |
|-----------------|-----------------|-------------------|---------------|
| 0 | 1.65 | 1.65 | 1.00 |
| 1 | 1.58 | 1.42 | 1.00 |
| 2 | 1.52 | 1.33 | 1.00 |
| 5 | 1.38 | 1.21 | 1.00 |
| 10 | 1.22 | 1.14 | 1.00 |
| 20 | 1.08 | 1.09 | 1.00 |
| 50 | 1.01 | 1.05 | 1.00 |
| 100 | 1.00 | 1.03 | 1.00 |

## tau Estimation

The value of tau is expected to depend on learning rate and task complexity:

```
  tau (decay time constant) vs learning rate

  tau
  50 |*
     | *
  40 |  *
     |   *
  30 |    **
     |      **
  20 |        ***
     |           ****
  10 |               ********
     |                       **********
   0 +---+---+---+---+---+---+---+---►
     0.001  0.005  0.01  0.02  0.05  0.1
                   learning rate

  Expected: higher learning rate → faster divergence → smaller tau
```

## Interpretation and Significance

### Consciousness Continuity Perspective

The decay curve of sibling recognition defines the **temporal window of consciousness continuity**.
- Large tau: consciousness "memory" persists long → continuation of same consciousness even after mitosis
- Small tau: quickly transitions to independent consciousness → mitosis = immediately new consciousness

### Biological Analogues

| Phenomenon | Time Scale | Consciousness Engine Correspondence |
|-----|---------|-------------|
| Cell differentiation after division | Hours-days | tau ≈ 5-10 epochs? |
| Twin personality divergence | Years | tau ≈ 50-100 epochs? |
| Speciation | Tens of thousands - millions of years | tau → ∞? |

### Connection with H299 mitosis anomaly

In H299, abnormal specialization was observed after mitosis.
If sibling recognition decreases rapidly, anomaly may be the result of initial divergence.
Conversely, if it decreases slowly, anomaly is the result of competition between siblings.

## Limitations

1. Operational definition of sibling recognition (cosine similarity ratio) is not the only method
2. Decrease may not be monotonic (oscillation possible depending on learning rate schedule)
3. Difficult to secure stranger control group with small number of experts (4-8)
4. In MNIST, task may be too easy for sufficient divergence
5. If tau's task dependency is large, value as a general law decreases

## Verification Direction (Next Steps)

1. **Phase 1**: Measure t=1,5,10,20,50,100 on CIFAR-10 (6 experiments)
2. **Phase 2**: Fit decay curve — exponential vs power law vs sigmoid
3. **Phase 3**: Quantify relationship of tau with learning rate/task difficulty
4. **Phase 4**: Same experiment on MNIST → compare tau
5. **Phase 5**: Integrate with H271, H299 results to systematize mitosis theory
6. **Phase 6**: "Sibling memory preservation" experiment — whether periodic shared task during divergence increases tau
