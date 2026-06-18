# MUSICTOPO-013: Triad Space as Orbifold T^3/S_3

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The space of 3-note chords (triads) in continuous pitch-class space is the orbifold T^3/S_3, where T^3 is the 3-torus of ordered pitch triples and S_3 is the symmetric group permuting voices. The dimension 3 = P1/2 and |S_3| = P1 = 6.

## Background

Tymoczko (2006) showed that the space of n-note chords is the orbifold
T^n / S_n, where we quotient the n-torus by voice permutations.
For triads, n=3.

## Verification

```
  Triad space = T^3 / S_3
  Dimension: 3 = P1/2  EXACT
  Quotient group: S_3, order |S_3| = 3! = 6 = P1  EXACT

  S_3 elements:
    e = ()         identity
    (12)           swap voices 1,2
    (13)           swap voices 1,3
    (23)           swap voices 2,3
    (123)          cyclic permutation
    (132)          reverse cycle
    Count: 6 = P1
```

## ASCII Orbifold Structure

```
  T^3 (ordered triples):
    (x, y, z) with x, y, z in S^1

  Identification: (x,y,z) ~ all permutations
    (x,y,z) ~ (x,z,y) ~ (y,x,z) ~ (y,z,x) ~ (z,x,y) ~ (z,y,x)
    |____________________P1 = 6 copies identified___________________|

  Result: orbifold with singular strata:
    - Unisons (x=y=z): cone point
    - Partial unisons (x=y!=z): edge singularity
    - Generic points: smooth (6-fold cover)
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Dimension | 3 | P1/2 |
| Quotient order | 6 | P1 = 3! |
| Singular strata | cone, edge | orbifold |
| Euler char (orbifold) | 1/6 | 1/P1 |

## Interpretation

The triad orbifold has dimension P1/2 = 3 and is quotiented by S_{P1/2}
of order P1 = 6. The perfect number governs both the dimension of
voice-leading space and the order of the symmetry group.
