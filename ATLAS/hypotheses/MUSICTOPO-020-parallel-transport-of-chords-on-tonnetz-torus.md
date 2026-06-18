# MUSICTOPO-020: Parallel Transport of Chords on Tonnetz Torus

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Transposing a chord on the Tonnetz corresponds to parallel transport on the torus T^2. Since T^2 is flat (zero curvature), parallel transport is path-independent, which corresponds to the musical fact that transposition preserves interval structure exactly.

## Background

Parallel transport on a manifold moves a vector along a path while
keeping it as "constant" as possible. On a flat manifold (zero curvature),
parallel transport is path-independent: the holonomy group is trivial.

## Verification

```
  Tonnetz topology: T^2 (flat torus)
  Gaussian curvature: K = 0  (flat)
  Holonomy group: trivial

  Musical consequence:
    Transposing C major triad by T_k:
      (C, E, G) -> (C+k, E+k, G+k)
    Intervals preserved exactly: (4, 3) -> (4, 3)
    = parallel transport preserves the "chord vector"  EXACT
```

## ASCII Parallel Transport

```
  On Tonnetz torus:

  C---E---G#         D---F#---A#
  |\  |\  |\   T_2   |\  |\  |\
  | \ | \ | \  ---->  | \ | \ | \
  Ab--C---E          Bb--D---F#

  Chord shape (triangle) preserved exactly
  = parallel transport on flat manifold
  = zero curvature => no holonomy
```

## Curvature Connection

| Manifold | Curvature | Holonomy | Musical Meaning |
|----------|-----------|----------|----------------|
| T^2 (Tonnetz) | K=0 flat | trivial | transposition exact |
| S^2 (sphere) | K>0 | SO(2) | would distort chords |
| H^2 (hyperbolic) | K<0 | -- | would distort chords |

## Interpretation

The flatness of the Tonnetz torus (K=0) is what makes transposition
an exact symmetry in music. On a curved surface, parallel transport
would distort chord shapes, and intervals would change under "transposition."
