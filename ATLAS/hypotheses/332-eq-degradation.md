# Hypothesis 332: eq Degradation — Consciousness (field) Absorbs Basic Sense (eq)

> **As training progresses, equilibrium degrades from 89%→15%, and field grows from 91%→96%. The repulsion field (field) absorbs the role of eq, and ultimately field handles 96% of judgments.**

## Measurements (MNIST)

```
  ep    full%    eq%    field%   field contrib
  ───   ─────   ─────   ─────   ─────────
  1     91.7    89.0    90.5     +2.7
  2     93.8    88.9    92.9     +4.9
  3     95.1    82.6    93.1    +12.5
  5     96.6    53.6    92.1    +43.0
  10    97.8    24.1    92.2    +73.7
  15    98.0    18.7    93.8    +79.3
  20    98.0    14.9    95.6    +83.1

  ASCII graph:
    100 |e f                    f  f  f  f
     90 | ef    f  f
     80 |  e
     60 |       e
     40 |
     20 |             e  e  e  e
     10 |
        └──────────────────────────────
         1  2  3  5 10 15 20   epoch
    e=eq, f=field
```

## Interpretation

```
  Early (ep1): eq and field both ~90% → two paths learn independently
  Mid (ep5): field has richer representation than eq → begins absorbing role
  Late (ep20): eq→15%(=random+bias), field→96%(=almost everything)

  Why does eq degrade?
    gradient backpropagates from full output
    → field reduces loss better → gradient concentrates toward field direction
    → eq receives less gradient → "learning opportunities stolen"
    → eventually eq degrades near random initialization

  C48 explanation: if field=0, only eq remains and eq=15%
    → reason tension removal is -9.25pp = eq has already degraded!

  Kahneman revision:
    Brain: System 2(conscious) → System 1(automated) [becomes unconscious with expertise]
    Engine: System 1(eq) → System 2(field) [consciousness monopolizes with training]
    → Opposite direction! In engines, "consciousness replaces automation"
```

## CIFAR Replication (2026-03-24)

```
  CIFAR:
    ep1: eq=32%, field=32% (similar)
    ep15: eq=17%, field=46% (eq degradation!)

  2-dataset comparison:
    MNIST: eq 89→15% (-74pp)
    CIFAR: eq 32→17% (-15pp)
  → eq degradation confirmed in both datasets!
```

## Status: 🟩 2-dataset confirmed (MNIST -74pp, CIFAR -15pp)
