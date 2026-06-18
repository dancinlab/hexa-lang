# MUSICTOPO-018: Fundamental Domain of Chord Space

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The fundamental domain of n-chord space T^n/S_n is a simplex (generalized triangle) with vertices at unison chords. For triads (n=3=P1/2), it is a tetrahedron whose volume is 1/P1 = 1/6 of the torus volume, reflecting the 1/|S_3| = 1/6 quotient.

## Background

A fundamental domain tiles the covering space by group action. For
T^3/S_3, the fundamental domain is 1/6 of the torus, since |S_3| = 6.

## Verification

```
  Covering multiplicity: |S_3| = 6 = P1  EXACT
  Volume ratio: Vol(fund. domain) / Vol(T^3) = 1/6 = 1/P1  EXACT

  The fundamental domain is defined by:
    x_1 <= x_2 <= x_3  (ordered pitches)
  This selects one of the 3! = 6 = P1 orderings.
```

## ASCII Fundamental Domain (2D analogy)

```
  Full torus T^2 (dyads):    Fundamental domain:

  y|               y = x      y|
   |           . /              |      /
   |       . /   |              |    /
   |   . /       |              |  /     1/2 of square
   | /           |              |/       = 1/phi(6)
   +----------x               +------x
    (x,y) and (y,x)            x <= y only

  3D analog: tetrahedron = 1/6 = 1/P1 of cube
```

## Fundamental Domain Properties

| Dimension | Group | Volume Fraction | n=6 Link |
|-----------|-------|----------------|----------|
| 2 | S_2 | 1/2 | 1/phi(6) |
| 3 | S_3 | 1/6 | 1/P1 |
| 4 | S_4 | 1/24 | 1/(2*sigma(6)) |

## Interpretation

The fundamental domain fraction 1/P1 = 1/6 for triads means that
exactly P1 copies of the domain tile the full torus. The perfect number
6 = 3! perfectly matches the symmetric group order at P1/2 = 3 voices.
