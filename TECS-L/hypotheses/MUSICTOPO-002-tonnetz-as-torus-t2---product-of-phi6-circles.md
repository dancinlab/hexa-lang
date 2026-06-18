# MUSICTOPO-002: Tonnetz as Torus T^2 = Product of phi(6) Circles

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The Tonnetz (tone network) is topologically a torus T^2 = S^1 x S^1, the product of phi(6) = 2 circles. One circle represents major thirds (Z_3), the other minor thirds (Z_4), and 3 x 4 = sigma(6) = 12.

## Background

The Tonnetz, introduced by Euler (1739), arranges pitch classes in a grid
where horizontal motion = perfect fifths, diagonal = major/minor thirds.
When wrapped with octave equivalence, it becomes a torus.

## Topological Verification

```
  Tonnetz topology: T^2 = S^1 x S^1
  Number of S^1 factors: 2 = phi(6)  EXACT

  Axis decomposition:
    Major third cycle: C-E-G#-C  (period 3)
    Minor third cycle: C-Eb-Gb-A-C  (period 4)
    3 x 4 = 12 = sigma(6)  EXACT
```

## ASCII Tonnetz (fragment)

```
     F#---A----C----Eb---F#
    / \ / \ / \ / \ / \
   D----F----Ab---B----D
  / \ / \ / \ / \ / \
  Bb---Db---E----G----Bb
  / \ / \ / \ / \ / \
  G----B----D----F----G
        ^                ^
        |-- identified --|   (torus wrapping)
```

## Verification Table

| Property | Musical Value | n=6 Constant | Match |
|----------|-------------|-------------|-------|
| Dimension | 2 | phi(6) = 2 | EXACT |
| Horizontal period | 12 | sigma(6) = 12 | EXACT |
| Third cycle product | 3 x 4 = 12 | P1/2 x tau(6) = 12 | EXACT |
| Euler char chi(T^2) | 0 | -- | torus |

## Interpretation

The Tonnetz torus has dimension phi(6) = 2, and its fundamental cycles
decompose 12 = sigma(6) into 3 x 4 = (P1/2) x tau(6). Every structural
constant traces back to the arithmetic of the perfect number 6.
