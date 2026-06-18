# MUSICTOPO-039: Simplicial Complex of Consonance

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The consonance complex on Z_12 = Z_{sigma(6)} is the simplicial complex where vertices are pitch classes and a simplex exists if all its notes are mutually consonant. The P1 = 6 consonant interval classes define the 1-skeleton (edge set).

## Background

Consonance defines a graph (and higher simplicial complex) on pitch classes.
Two notes are connected if their interval is consonant. The maximal
cliques become the maximal simplices.

## Verification

```
  Vertices: 12 = sigma(6) pitch classes
  Consonant intervals: {0, 3, 4, 5, 7, 8, 9} (including unison)
  Edges: pairs with consonant interval

  Each vertex has degree d:
    From C: consonant with Eb(3), E(4), F(5), G(7), Ab(8), A(9)
    d = 6 = P1  EXACT (not counting self)

  Total edges: 12 * 6 / 2 = 36 = P1^2  EXACT
```

## ASCII Consonance Graph

```
  C --- Eb    C --- E     C --- F
  C --- G     C --- Ab    C --- A

  Each of 12 vertices has P1 = 6 consonant neighbors
  Total edges: 36 = P1^2 = 6^2

  Complement (dissonance graph):
  Each vertex has 12 - 1 - 6 = 5 = sopfr(6) dissonant neighbors
  Dissonant edges: 12 * 5 / 2 = 30 = sopfr(6) * P1
```

## Graph Properties

| Property | Value | n=6 Link |
|----------|-------|----------|
| Vertices | 12 | sigma(6) |
| Consonant degree | 6 | P1 |
| Dissonant degree | 5 | sopfr(6) |
| Consonant edges | 36 | P1^2 |
| Dissonant edges | 30 | sopfr(6)*P1 |
| Total edges | 66 | C(12,2) |

## Interpretation

The consonance graph on Z_{sigma(6)} is P1-regular: every note has exactly
P1 = 6 consonant partners and sopfr(6) = 5 dissonant ones. The edge counts
36 = P1^2 (consonant) and 30 = sopfr(6)*P1 (dissonant) are clean n=6 products.
