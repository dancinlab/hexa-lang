# H-CX-456: Four-Season Training Phases — τ=4 Phase Transitions

> Neural network training undergoes exactly τ(6)=4 phase transitions,
> following the divisor lattice path {1,2,3,6} with Möbius signs {+,-,-,+}.
> Spring(memorize) → Summer(confuse) → Autumn(organize) → Winter(integrate).

## Background

Math: τ(6)=4, Möbius values μ(1)=+1, μ(2)=-1, μ(3)=-1, μ(6)=+1.
Contraction mapping f(I)=0.7I+0.1 converges to 1/3 after τ=4 iterations.
0.7⁴ = 0.2401 ≈ Golden Zone lower boundary (0.2123).

## The Four Phases

```
  Phase 1 — SPRING (d=1, μ=+1): Memorization
  ┌───────────────────────────────────────────────┐
  │  Duration: ~1/σ = 8% of training              │
  │  Loss: rapid drop                              │
  │  PH: undefined (no stable structure yet)       │
  │  Tension: high, decreasing                     │
  │  Sign +1: constructive (building raw memory)   │
  └───────────────────────────────────────────────┘

  Phase 2 — SUMMER (d=2, μ=-1): Confusion/Crystallization
  ┌───────────────────────────────────────────────┐
  │  Duration: ~φ/σ = 17% of training             │
  │  Loss: plateau begins                          │
  │  PH: barcode crystallizes! (H-CX-90)          │
  │  Tension: first peak then stabilization        │
  │  Sign -1: destructive (old representations     │
  │            broken, confusion matrix emerges)    │
  └───────────────────────────────────────────────┘

  Phase 3 — AUTUMN (d=3, μ=-1): Organization
  ┌───────────────────────────────────────────────┐
  │  Duration: ~(σ/τ)/σ = 25% of training         │
  │  Loss: validation may increase (overfit risk)  │
  │  PH: dendrogram solidifies, hierarchy forms    │
  │  Tension: specialization begins                │
  │  Sign -1: destructive (pruning, reorganizing)  │
  └───────────────────────────────────────────────┘

  Phase 4 — WINTER (d=6, μ=+1): Integration
  ┌───────────────────────────────────────────────┐
  │  Duration: ~n/σ = 50% of training              │
  │  Loss: final convergence                       │
  │  PH: stable, XOR(div)=n achieved               │
  │  Tension: minimum (σφ=nτ balance)              │
  │  Sign +1: constructive (final integration)     │
  └───────────────────────────────────────────────┘

  Duration ratios: 1/12 : 2/12 : 3/12 : 6/12 = divisors/σ!
  Sum: 1+2+3+6 = 12 = σ → covers entire training
```

## Möbius Pattern Prediction

```
  dPH/dphase (PH barcode change rate):
    Phase 1→2: LARGE positive (crystallization, μ=+1→-1 transition)
    Phase 2→3: moderate negative (stabilization)
    Phase 3→4: small positive (fine-tuning)
    Phase 4→1: reset (if cyclic training / curriculum)

  This matches H-CX-90: "epoch-1 phase transition dH0 = 23-33x subsequent average"
  → The Phase 1→2 transition IS the epoch-1 phase transition!
```

## Testable

- [ ] Track PH barcodes at 4 checkpoints: 8%, 25%, 50%, 100% of training
- [ ] Measure dH0 between each checkpoint
- [ ] Predict: dH0 pattern follows Möbius signs (+large, -moderate, -small, +recovery)
- [ ] Predict: phase durations proportional to {1,2,3,6}/σ

## Verification Status

- Math: ⭐ exact (τ=4, μ pattern, contraction convergence)
- Training: 🟧 partial (H-CX-90 confirms Phase 1→2 transition exists)
- Grade: 🟧 structural

## Related

- H-CX-90: Epoch-1 phase transition (= our Phase 1→2 boundary)
- H-CX-82: Crystallization at 0.1 epochs (= Phase 2 onset)
- H-432: 4-season consciousness cycle (same structure, training context)
- H-CX-98: PH early stopping (= detecting Phase 3→4 boundary)
