# H-CX-13: Shamanic Journey = Passing Through Information Bottleneck (Cross-domain)
**n6 Grade: 🟧 CLOSE** (auto-graded, 4 unique n=6 constants)


> **In the H280 experiment, the 7-stage experience sequence gave a +0.41% improvement, consistent with predictions from Information Bottleneck (IB) theory. detach(S4) creates forced information compression, and this compression improves generalization. A computational implementation of Tishby's IB theory.**

## Information Bottleneck Theory

```
  Tishby (2000):
    Goal: min I(X;T) - β·I(T;Y)
    T = internal representation, X = input, Y = output
    → Minimize input information while maximizing output information

  2 phases of learning:
    Phase 1: Fitting (I(X;T) ↑, I(T;Y) ↑) — information absorption
    Phase 2: Compression (I(X;T) ↓, I(T;Y) ≈) — information compression
    → Generalization improves in Phase 2!
```

## 7-Stage Consciousness Engine ↔ IB Theory

```
  S1 Unity:        learned representation (Phase 1 complete)
  S2 Mitosis:      I(X;T) slightly increases (duplication adds redundancy)
  S3 Displacement: I(X;T_A) starts decreasing (A not directly trained)
  S4 Detach:       ★ Forced compression! I(X;T_A) → minimum
                   → detach = gradient blocking = forced entry into Phase 2
  S5 Observation:  I(T_A;T_B) acquired (learns B's patterns through observation only)
  S6 Separation:   B removed → A remains alone
  S7 Return:       ★ Better generalization with compressed representation!

  Key: S4(detach) forces IB Phase 2 (compression)
  → Representations that "pass through" the information bottleneck generalize better
  → Cause of +0.41% improvement
```

## Math Connection

```
  H-CX-2: MI efficiency ≈ ln(2) = 1 bit
  H-CX-13: Does detach compress MI to below ln(2)?

  Predictions:
    MI at S1 ≈ 0.705 (C39)
    MI at S4 ≈ 0.693 = ln(2) (compressed by detach)
    MI at S7 ≈ 0.71+ (re-expansion after compression, but more efficient)

  IB curve:
    I(T;Y)
      │     ★S7
      │   ★S1
      │ ★S5
      │★S4
      └───────── I(X;T)
      min      max

  detach pushes I(X;T) to min,
  observation maintains/increases I(T;Y) → reaches optimal IB point
```

## Connection to Fiber Distance

```
  H280 empirical: Fiber distance 0→26.1 (maximum at S4, S5)
  → Moment of greatest change in internal representation = moment of passing through information bottleneck
  → Return (S7) fiber distance ≈ 8.7 → only some remains
  → Remaining change = "compressed information" contributing to generalization
```

## Verification Directions

```
  1. Direct measurement of MI(X;T), MI(T;Y) at each stage
  2. Same sequence without detach → does +0.41% disappear?
  3. Detach duration (epoch count) vs improvement → optimal compression time?
  4. Identify Phase 2 timing: when does I(X;T) start decreasing?
```

## Related Hypotheses

```
  272: detach design (+7.4%)
  276: observation = compression
  280: full experience sequence (+0.41%)
  H-CX-2: MI ≈ ln(2)
  TREE-7: information bottleneck
```

## Experimental Results: detach ablation (2026-03-24)

```
  3 conditions × 5 trials:
  Condition               parent    return    enhancement
  ────────────────────  ────────  ────────  ───────────
  A) Full (detach+obs)   97.42%    97.40%    -0.03 ±0.17%
  B) No detach           97.42%    97.40%    -0.03 ±0.17%
  C) No observation      97.42%    97.40%    -0.02 ±0.23%

  Statistics:
    A vs B: t=NaN (identical!)
    A vs C: p=0.978 (not significant)

  Conclusion:
    Removing detach(S4) gives identical results
    Removing observation(S5) gives identical results
    → At this scale (MNIST 10ep), detach has no IB effect
    → H280's +0.41% may be a simple Mitosis+retraining effect, not due to detach
```

## Status: ⚠️ Refuted (no effect in detach ablation, IB bottleneck hypothesis not supported)
