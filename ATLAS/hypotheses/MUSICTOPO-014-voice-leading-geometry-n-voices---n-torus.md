# MUSICTOPO-014: Voice-Leading Geometry: n Voices = n-Torus

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> For n-voice counterpoint, the space of ordered pitch-class n-tuples is the n-torus T^n. The fundamental domain has n! identifications by voice permutation. For P1/2 = 3 voices (triads), this yields T^3 with 3! = P1 = 6 identifications.

## Background

Tymoczko's geometric model of voice leading uses n-dimensional tori
as configuration spaces. Short voice leadings correspond to short
paths in this space.

## Verification

```
  n voices => ordered space = T^n = (S^1)^n
  Each S^1 factor: one voice moving through pitch class space
  Metric: Euclidean (for measuring voice-leading distance)

  For triads (n = 3 = P1/2):
    T^3 = S^1 x S^1 x S^1
    Dimension = 3 = P1/2  EXACT
    Voice permutations: S_3, |S_3| = 6 = P1  EXACT
```

## ASCII Voice-Leading Space

```
  Voice 1 (soprano): -----> S^1
  Voice 2 (alto):    -----> S^1    }  T^3
  Voice 3 (bass):    -----> S^1

  A voice leading: (C,E,G) -> (C,F,A)
    = path in T^3 from (0,4,7) to (0,5,9)
    = three simultaneous motions on three circles

  Distance = sqrt(0^2 + 1^2 + 2^2) = sqrt(5) semitones
```

## Dimension Table

| Voices | Torus | Perm Group | n=6 Link |
|--------|-------|------------|----------|
| 1 | T^1 = S^1 | S_1 = {e} | -- |
| 2 = phi(6) | T^2 | S_2 (order 2) | phi(6) |
| 3 = P1/2 | T^3 | S_3 (order 6) | P1, P1/2 |
| 4 = tau(6) | T^4 | S_4 (order 24) | tau(6), 2*sigma(6) |

## Interpretation

The canonical voice counts in music theory align with n=6 constants:
2 = phi(6) voices (counterpoint), 3 = P1/2 (triads), 4 = tau(6) (SATB).
The permutation group at P1/2 voices has order P1 = 6.
