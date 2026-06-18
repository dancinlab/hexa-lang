# MUSICTOPO-048: Topological Data Analysis of Musical Structure

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> TDA applied to musical datasets reveals persistent topological features. The natural distance metric on pitch-class space Z_12 = Z_{sigma(6)} has maximum distance 6 = P1 (the tritone), and the Vietoris-Rips complex at radius P1 covers all pitch classes.

## Background

In TDA, one builds simplicial complexes at varying scales (radii) and
tracks topological features. On Z_12 with the circular metric, the
maximum distance between any two points is 6 = P1.

## Verification

```
  Circular distance on Z_12:
    d(a, b) = min(|a-b|, 12-|a-b|)
    Maximum: d(0, 6) = 6 = P1  EXACT

  Vietoris-Rips complex at radius r:
    VR(r): simplex on points within distance r
    VR(0): 12 isolated points (beta_0 = 12 = sigma(6))
    VR(1): connect semitone neighbors (cycle C_12)
    VR(6): complete graph K_12 (all connected)
    VR(P1): fully connected  EXACT
```

## ASCII Filtration

```
  r=0:  * * * * * * * * * * * *    beta_0 = 12 = sigma(6)
        (12 isolated points)

  r=1:  *-*-*-*-*-*-*-*-*-*-*-*   beta_0 = 1, beta_1 = 1
        (cycle graph C_12)

  r=3:  dense graph                beta_0 = 1, beta_1 > 1

  r=6:  complete K_12              beta_0 = 1, beta_1 = 0
        (all connected at r = P1)
```

## Persistence Data

| Radius r | beta_0 | beta_1 | n=6 Link |
|----------|--------|--------|----------|
| 0 | 12 | 0 | sigma(6) |
| 1 | 1 | 1 | -- |
| 2 | 1 | >1 | -- |
| 6 = P1 | 1 | 0 | P1 (max dist) |

## Interpretation

The maximum circular distance 6 = P1 on Z_{sigma(6)} means the complete
Rips complex is reached at radius P1. The filtration from sigma(6) isolated
points to full connectivity at P1 encodes the topology of the pitch space.
