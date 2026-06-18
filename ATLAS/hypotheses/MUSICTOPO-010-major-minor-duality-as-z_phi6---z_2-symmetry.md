# MUSICTOPO-010: Major/Minor Duality as Z_phi(6) = Z_2 Symmetry

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The duality between major and minor modes is a Z_2 = Z_{phi(6)} symmetry, realized as inversion of the interval pattern. A major triad (0,4,7) maps to minor (0,3,7) under the involution I: x -> 12-x (mod 12), reflecting through the octave.

## Background

Major/minor duality is one of the deepest symmetries in Western music.
A major chord has intervals (4,3) semitones; a minor chord has (3,4).
This is a reflection (inversion) in the interval structure.

## Verification

```
  Major triad: (0, 4, 7)   intervals: 4, 3
  Minor triad: (0, 3, 7)   intervals: 3, 4
  Inversion I(x) = -x mod 12:
    I(0) = 0, I(4) = 8, I(7) = 5
    Transposed: (0, 5, 8) -> (0, 3, 7) = minor  EXACT

  Symmetry group: Z_2 = Z_{phi(6)}  EXACT
  I^2 = identity (involution)
```

## ASCII Major/Minor Mirror

```
  Major:    m3      Minor:
  (0)--4--(4)--3--(7)    (0)--3--(3)--4--(7)
   C       E       G      C      Eb       G

       reflection I
  |---|---|---|---|---|---|---|---|---|---|---|---|
  0   1   2   3   4   5   6   7   8   9  10  11
  C               E           G
  C           Eb              G
                  ^
              mirror axis at 3.5
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Duality group | Z_2 | Z_{phi(6)} |
| Major triads | 12 | sigma(6) |
| Minor triads | 12 | sigma(6) |
| Total | 24 | 2*sigma(6) |
| Inversion order | 2 | phi(6) |

## Interpretation

Major/minor duality is Z_{phi(6)} = Z_2, the simplest nontrivial symmetry.
It partitions the 2*sigma(6) = 24 triads into sigma(6) = 12 pairs,
each related by the involution of order phi(6) = 2.
