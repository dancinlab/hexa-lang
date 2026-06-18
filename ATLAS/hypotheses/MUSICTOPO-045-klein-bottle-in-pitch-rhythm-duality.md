# MUSICTOPO-045: Klein Bottle in Pitch-Rhythm Duality

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> If pitch classes (Z_12) and beat classes (Z_12) are both circles, and the identification between them reverses orientation (pitch up = time backward in retrograde inversion), the resulting space is a Klein bottle K = S^1 x_twist S^1, a non-orientable surface.

## Background

A Klein bottle is formed by identifying opposite edges of a square
with one pair reversed. In music, retrograde inversion combines
pitch inversion with time reversal, suggesting a non-orientable
identification.

## Construction

```
  Pitch circle: Z_12 = Z_{sigma(6)}  (mod octave)
  Time circle:  Z_12 = Z_{sigma(6)}  (mod measure in 12/8)

  Normal identification (torus): (p, t) ~ (p+12, t) ~ (p, t+12)
  Retrograde-inversion: (p, t) ~ (12-p, 12-t)
    This reverses orientation in both coordinates

  If we identify with twist: (p, 0) ~ (12-p, 12)
    Result: Klein bottle  (non-orientable)
```

## ASCII Klein Bottle Construction

```
  Square [0,12] x [0,12]:

  Pitch
   12 <----A-----B
    |             |          A-B identified normally (left-right)
    |             |          C-D identified with reversal (top-bottom)
    |             |
    0  ---->C-----D

  Torus: both pairs same direction
  Klein: one pair reversed (retrograde inversion)

  chi(Klein bottle) = 0
  Non-orientable, no boundary
```

## Properties

| Property | Torus | Klein Bottle |
|----------|-------|-------------|
| Orientable | yes | no |
| chi | 0 | 0 |
| pi_1 | Z x Z | Z semidirect Z |
| H_1 | Z^2 | Z + Z_2 |
| Musical meaning | pitch+time | pitch+retrograde |

## Interpretation

The Klein bottle model captures retrograde inversion as a topological twist.
Both circles have sigma(6) = 12 elements. Grade: WEAK because the Klein
bottle interpretation is a theoretical construction, not a standard
music-theoretic result.
