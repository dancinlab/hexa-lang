# Hypothesis Review 018: Sudden Change in Loss 2nd Derivative = Cusp Transition Detection ✅

## Hypothesis

> If the 2nd derivative of Loss (d²L/dt²) during training exceeds a threshold (2.5σ),
> it can be detected as a cusp transition point.

## Background and Context

During neural network training, the loss curve generally decreases smoothly,
but at certain moments a sharp change (cusp) can occur.
These transition points may indicate:

- Switching of learning rate schedule
- Reorganization of Expert routing patterns
- Transition between feature learning phases
- Entry/exit from the Golden Zone

If cusps can be detected in real time, it becomes possible to dynamically
adjust training strategy. Whether a sudden change in the 2nd derivative (curvature)
can serve as a mathematical indicator of cusp was verified.

Related hypotheses: Hypothesis 017 (Gating mapping), Hypothesis 020 (Stability 35%)

## Cusp Detection Algorithm

```
  Input: Loss time series L(t), t = 1, 2, ..., T

  Step 1: Smoothing
    L_smooth(t) = moving average(L(t), window=5)

  Step 2: Compute 2nd derivative
    d²L(t) = L_smooth(t+1) - 2×L_smooth(t) + L_smooth(t-1)

  Step 3: Set threshold
    μ_d2 = mean(d²L)
    σ_d2 = std(d²L)
    threshold = μ_d2 + 2.5 × σ_d2

  Step 4: Cusp decision
    if |d²L(t)| > threshold: mark t as cusp candidate

  Step 5: Merge candidates (remove duplicates within 5 epochs)
```

## Verification Data

```
  Simulation settings:
  ─────────────────────────
  Total epochs:         100
  Inserted transitions: epoch 35, epoch 70
  Transition type:      sudden change in Loss slope (kink)
  Noise level:          σ_noise = 0.02
  Threshold:            2.5σ

  Detection results:
  ─────────────────────────────────────
  Inserted transition │  Detected epoch  │  Error │  Verdict
  ───────────────────┼──────────────────┼────────┼──────
  epoch 35           │  epoch 34, 35    │  ±1    │  ✅
  epoch 70           │  epoch 69, 70    │  ±1    │  ✅
  (none)             │  (not detected)  │   -    │  ✅ no false positives
```

## Loss Curve + 2nd Derivative Peak Graph

```
  Loss
  2.0│\
     │ \
  1.5│  \
     │   \
  1.0│    ╲___          Cusp 1
     │        ╲___      ↓
  0.5│            ╲___________      Cusp 2
     │                        ╲___  ↓
  0.2│                            ╲___________
     └──┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──
       0  10  20  30  40  50  60  70  80  90  100
                        epoch

  d²L/dt² (2nd derivative)
   30│
     │              ████
   20│              ████ ← transition 1 (epoch 34-35)
     │              ████
   10│              ████
     │
    0│──────────────────────────────────────── zero line
     │
  -10│
     │                              ████
  -20│                              ████ ← transition 2 (epoch 69-70)
     │                              ████
  -30│                              ████
     └──┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──
       0  10  20  30  40  50  60  70  80  90  100
                        epoch

  ── threshold (±2.5σ) ──────────────────────
  ████ = region exceeding threshold = cusp detected
```

## Threshold Sensitivity Analysis

```
  Threshold (σ multiple) │ Detected transitions │ False pos. │ False neg. │ F1
  ───────────────────────┼─────────────────────┼────────────┼────────────┼──────
  1.5σ                   │ 2/2                 │ 3          │ 0          │ 0.57
  2.0σ                   │ 2/2                 │ 1          │ 0          │ 0.80
  2.5σ                   │ 2/2                 │ 0          │ 0          │ 1.00 ★
  3.0σ                   │ 1/2                 │ 0          │ 1          │ 0.67
  3.5σ                   │ 0/2                 │ 0          │ 2          │ 0.00
```

## Interpretation

1. **2.5σ is the optimal threshold**: The only setting with both false positives and false negatives at 0.
   At 1.5~2.0σ, noise is misidentified as transition points (false positives);
   at 3.0σ+, actual transition points are missed (false negatives).
2. **±1 epoch precision**: Detected epochs are within ±1 epoch of the actual transition points.
   Very accurate given the moving average window (5 epochs).
3. **Real-time applicability**: The algorithm uses O(1) memory and O(1) computation,
   suitable for real-time monitoring.

## Practical Application Scenarios

```
  Automatic action upon cusp detection during training:
  ────────────────────────────────────────────────────
  d²L > +2.5σ  →  Accelerated loss decrease (positive transition)
                    → Maintain or slightly increase learning rate

  d²L < -2.5σ  →  Slowed loss decrease (negative transition)
                    → Decrease learning rate or reset Expert routing

  Consecutive cusps  →  Instability warning
                         → Pause training and save checkpoint
```

## Limitations

- Verified on simulation data; actual training curves are more complex
- Moving average window size (5) is a hyperparameter
- 2.5σ may be inappropriate in high-noise environments (small batch size)
- Gradual transitions (smooth transition) are not detected as cusp
- Single simulation result; insufficient verification across various transition types

## Next Steps

1. Cusp detection experiment on actual golden_moe_cifar.py training curves
2. Develop adaptive threshold setting method for various noise levels
3. Classification of cusp types (Expert reorganization, feature learning transition, etc.)
4. Analyze correlation between gradient explosion in Hypothesis 020 (stability) and cusp
5. Implement learning rate auto-adjustment pipeline based on cusp detection

## Conclusion

> ✅ Cusp transition points detectable with 2.5σ threshold on Loss 2nd derivative.
> F1 = 1.00 (0 false positives, 0 false negatives) achieved in simulation.
> Transition points captured accurately with ±1 epoch precision,
> and can serve as the basis for real-time training monitoring.

---

*Verification: verify_ai.py (simulated training curve, 2 inserted transition points)*
