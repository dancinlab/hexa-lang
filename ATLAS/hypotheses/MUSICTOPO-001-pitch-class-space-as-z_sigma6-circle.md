# MUSICTOPO-001: Pitch Class Space as Z_sigma(6) Circle

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The pitch class space in Western music is the cyclic group Z_12 = Z_{sigma(6)}, geometrically realized as the circle S^1 with 12 equally spaced points. The number of pitch classes equals sigma(6) = 12, the divisor sum of the first perfect number.

## Background

Western music divides the octave into 12 equal semitones. Each pitch class
(C, C#, D, ..., B) is an element of Z_12. This is precisely Z_{sigma(6)}.

## Structural Verification

```
  sigma(6) = 1 + 2 + 3 + 6 = 12
  Pitch classes: {C, C#, D, D#, E, F, F#, G, G#, A, A#, B}
  |pitch classes| = 12 = sigma(6)  EXACT
```

## Topological Structure

```
       C
    B     C#
  A#        D
  A          D#      S^1 = R / 12Z
  G#        E
    G     F
       F#

  Fundamental group: pi_1(S^1) = Z
  Each loop = one octave = 12 semitones = sigma(6)
```

## Algebraic Verification

```
  Group structure:  (Z_12, +)
  Generator:        1 (semitone)
  Order:            12 = sigma(6)
  Subgroups:        Z_1, Z_2, Z_3, Z_4, Z_6, Z_12
  Number of subgroups = tau(12) = 6 = P1  EXACT
```

## Interpretation

The 12-tone system is not arbitrary but reflects sigma(6) = 12. The number of
subgroups of Z_12 equals P1 = 6, giving the perfect number full control over
the algebraic structure of pitch class space.
