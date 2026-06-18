# MUSICTOPO-034: Phase Space of Rhythmic Patterns

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The phase space of a rhythmic pattern on n beats is the set of all binary strings of length n, forming the hypercube {0,1}^n. For n = 12 = sigma(6), this is a 12-dimensional hypercube with 2^12 = 4096 vertices.

## Background

Every possible rhythmic pattern on n beats is a binary string: 1 = onset,
0 = rest. The collection of all patterns forms the vertices of an
n-dimensional hypercube (Boolean lattice).

## Verification

```
  n = 12 = sigma(6) beats
  Phase space: {0, 1}^12 (12-dimensional hypercube)
  Vertices: 2^12 = 4096
  Edges: 12 * 2^11 = 24576 = 2 * sigma(6) * 2^11
  Dimension: 12 = sigma(6)  EXACT

  Hamming distance between patterns = number of differing beats
  Maximum distance: 12 = sigma(6) (all beats flipped)
```

## ASCII Hypercube Projection

```
  Example in 4D (tau(6) dimensions):

      0000--------0001
     /|           /|
  0100--------0101 |
    | 1000------|-1001
    |/           |/
  1100--------1101

  Full phase space: 12D = sigma(6) dimensions
  Too large to draw, but same structure
```

## Hypercube Properties

| Property | Value | n=6 Link |
|----------|-------|----------|
| Dimension | 12 | sigma(6) |
| Vertices | 4096 | 2^{sigma(6)} |
| Edges | 24576 | -- |
| Diameter | 12 | sigma(6) |
| Automorphisms | 12! * 2^12 | huge |

## Interpretation

The rhythmic phase space is a sigma(6)-dimensional hypercube. Every
rhythmic pattern is a vertex, and neighboring patterns differ by one beat.
The dimension sigma(6) = 12 provides a vast space of 4096 rhythmic possibilities.
