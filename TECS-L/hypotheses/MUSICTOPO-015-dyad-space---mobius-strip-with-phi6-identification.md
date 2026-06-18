# MUSICTOPO-015: Dyad Space = Mobius Strip with phi(6) Identification

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The space of unordered 2-note chords (dyads) is a Mobius strip, obtained from the torus T^2 by identifying (x,y) with (y,x) via Z_2 = Z_{phi(6)}. The number of distinct dyad types (interval classes) is P1 = 6.

## Background

An interval class is an unordered pitch-class interval: the distance
between two notes, ignoring direction and octave. There are exactly
6 interval classes in the 12-tone system.

## Verification

```
  Dyad space: T^2 / Z_2 = Mobius strip
  Identification group: Z_2 = Z_{phi(6)}  EXACT

  Interval classes (unordered):
    ic1 = {1, 11}   minor second / major seventh
    ic2 = {2, 10}   major second / minor seventh
    ic3 = {3, 9}    minor third / major sixth
    ic4 = {4, 8}    major third / minor sixth
    ic5 = {5, 7}    perfect fourth / perfect fifth
    ic6 = {6}       tritone (self-inverse)

  Number of interval classes: 6 = P1  EXACT
```

## ASCII Interval Classes

```
  Semitones:  1  2  3  4  5  6  7  8  9  10 11
  Pair with: 11 10  9  8  7  6  5  4  3   2  1
             |__|__|__|__|__|  |  same pairs reversed
             ic1 ic2 ic3 ic4 ic5 ic6

  Count: floor(12/2) = 6 = P1
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Identification | Z_2 | Z_{phi(6)} |
| Interval classes | 6 | P1 |
| Self-inverse interval | 1 (tritone) | -- |
| Topology | Mobius strip | non-orientable |

## Interpretation

The P1 = 6 interval classes are a direct consequence of dividing
sigma(6) = 12 semitones by the phi(6) = 2 equivalence. The tritone
(ic6 = P1) is unique: it is the only self-inverse interval.
