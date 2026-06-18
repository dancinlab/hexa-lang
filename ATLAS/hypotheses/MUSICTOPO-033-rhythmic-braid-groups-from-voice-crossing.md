# MUSICTOPO-033: Rhythmic Braid Groups from Voice Crossing

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> When rhythmic voices (polyrhythmic layers) cross in intensity or register, they generate elements of the braid group B_n. For n = P1/2 = 3 simultaneous rhythmic layers, the braid group B_3 encodes all possible crossing patterns.

## Background

Braid groups generalize permutation groups by tracking HOW strands cross,
not just the final permutation. In polyrhythmic music, different layers
may cross in prominence, creating braid-like patterns.

## Construction

```
  3 rhythmic layers (e.g., bass, mid, treble patterns):
    Layer 1: x . . x . . x . . x . .    (period 3)
    Layer 2: x . x . x . x . x . x .    (period 2)
    Layer 3: x x . x x . x x . x x .    (period 3, shifted)

  When layers cross in volume/register:
    -> generates elements of B_3 (braid group on P1/2 strands)
    B_3 generators: sigma_1, sigma_2 (phi(6) = 2 generators)
```

## ASCII Rhythmic Braid

```
  Time --->

  Layer 1: ====\========/====\====
                \      /      \      sigma_1
  Layer 2: =====\====/========\===
                 \  /           \    sigma_2
  Layer 3: ======\/=============\==

  Crossings encode rhythmic interactions
```

## Braid Data

| Property | Value | n=6 Link |
|----------|-------|----------|
| Layers | 3 | P1/2 |
| Generators | 2 | phi(6) |
| Surjects to | S_3 | order P1 |
| Center | Z | infinite cyclic |

## Interpretation

Rhythmic braids on P1/2 = 3 layers use phi(6) = 2 generators and
surject to S_{P1/2} of order P1. Grade: WEAK because the braid model
for rhythm is a theoretical framework, not an established music-theoretic fact.
