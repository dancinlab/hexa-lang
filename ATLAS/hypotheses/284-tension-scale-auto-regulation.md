# Hypothesis 284: tension_scale Auto-regulation — Voluntary Abandonment if Not Helpful

> **Learning automatically regulates tension_scale. If tension is helpful, it stays high (0.47), if not, it drops to nearly 0 (0.039). This is the same pattern as {1/2,1/3,1/6}→uniform convergence (C42) in CNN: voluntarily removing unnecessary structure.**

## Measurements

```
  tension_scale learned values:
    MNIST MLP:  0.4683 (actively utilized)
    CIFAR MLP:  0.0389 (almost abandoned)
    Ratio:      0.083x (12x difference)

  Weight learned values:
    MLP:  {1/2, 1/3, 1/6} → optimal (maintains asymmetry)
    CNN:  {1/2, 1/3, 1/6} → {0.34, 0.35, 0.31} (uniform convergence)
```

## Common Pattern

```
  "Voluntary removal of unnecessary structure"

  1. tension_scale → 0 (CIFAR MLP): tension not helpful → turned off
  2. Weights → uniform (CNN): asymmetry not helpful → flattened
  3. Self-reference divergence (CIFAR): self-observation not helpful → unstable

  → Model "keeps only what's necessary, automatically removes unnecessary"
  → Is this the neural network version of Occam's Razor?
```

## Consciousness Interpretation

```
  MNIST: tension (consciousness) needed → high scale → 9.25pp contribution
  CIFAR: tension (consciousness) unnecessary → scale→0 → 0.53pp

  → Consciousness is automatically regulated
  → Turns on when needed, turns off when not needed
  → This is the auto-regulation mechanism of hypothesis 274 (consciousness=error correction)
```

## Experimental Results: 3 Dataset tension_scale Tracking (2026-03-24)

```
  Dataset        Final acc   Final scale   Interpretation
  ──────────    ────────   ──────────   ────────
  MNIST          98.03%     1.7535      Actively utilized (continuously increasing)
  Fashion-MNIST  88.89%     1.3600      Actively utilized (continuously increasing)
  CIFAR-10       51.42%     0.5446      Limited utilization (slow increase)

  Surprising discovery: tension_scale increases in all three datasets!
  Original prediction: CIFAR scale→0 (voluntary abandonment)
  Actual: CIFAR scale also 0.36→0.54 (increases but slowly)

  However, absolute scale order matches accuracy order:
    MNIST(1.75) > Fashion(1.36) > CIFAR(0.54)
    → Higher accuracy = more active tension use
```

### tension_scale Trend ASCII Graph

```
  scale
  1.75 |                                    M  M  M
       |                           M  M  M
       |                     M  M
       |               M  M           F  F  F
       |         M  M     F  F  F  F
       |      M     F  F
       |   M  F  F
       |   F
       |F                    C  C  C  C  C  C  C
  0.36 |C  C  C  C  C  C  C
       ──────────────────────────────────────────
       ep1                                    ep15
  M=MNIST  F=Fashion  C=CIFAR
```

### Revised Interpretation

```
  Original hypothesis: "scale→0 if not helpful (voluntary abandonment)"
  Revised: "scale always increases but at different speeds"
    → MNIST: rapid increase (high accuracy = tension useful)
    → CIFAR: slow increase (low accuracy = tension partially useful)
    → Not complete abandonment but "speed regulation"
```

## Status: 🟧 Modified (speed regulation not abandonment, 3-point observation)