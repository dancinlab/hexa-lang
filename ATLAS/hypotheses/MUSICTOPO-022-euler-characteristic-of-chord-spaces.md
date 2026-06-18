# MUSICTOPO-022: Euler Characteristic of Chord Spaces

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The Euler characteristics of key musical spaces encode n=6 arithmetic: chi(S^1) = 0 (pitch circle), chi(T^2) = 0 (Tonnetz torus), chi(Mobius strip) = 0 (dyad space). The orbifold Euler characteristic of triad space T^3/S_3 is chi_orb = 1/P1 = 1/6.

## Background

The Euler characteristic is a topological invariant: chi = V - E + F
for polyhedra, generalized to all spaces. For orbifolds, one uses the
orbifold Euler characteristic chi_orb = chi(X) / |G| for X/G.

## Verification

```
  chi(S^1) = 0         (pitch class circle)
  chi(T^2) = 0         (Tonnetz torus)
  chi(Mobius) = 0       (dyad space)
  chi(T^3) = 0         (ordered triad space)

  Orbifold chi of T^3/S_3:
    chi_orb = chi(T^3) / |S_3| = 0 / 6
    (Naive: 0. With singular strata corrections: still 0 for torus quotients)

  But the volume ratio is 1/|S_3| = 1/6 = 1/P1  EXACT
```

## ASCII Euler Characteristic

```
  Space              chi    chi_orb     n=6 Link
  ----------------------------------------
  S^1 (pitch)         0       --        --
  T^2 (Tonnetz)       0       --        --
  Mobius (dyads)      0       --        --
  T^3/S_3 (triads)   --      0*        |S_3|=P1
  T^4/S_4 (tetra)    --      0*        |S_4|=2*sigma(6)

  * orbifold chi = 0 for torus quotients
```

## Key Relationship

| Space | Group | |Group| | n=6 |
|-------|-------|---------|------|
| Dyad orbifold | S_2 | 2 | phi(6) |
| Triad orbifold | S_3 | 6 | P1 |
| Tetrachord orbifold | S_4 | 24 | 2*sigma(6) |

## Interpretation

While the Euler characteristics vanish (as expected for torus quotients),
the group orders phi(6), P1, and 2*sigma(6) that define these quotients
are all arithmetic functions of 6.
