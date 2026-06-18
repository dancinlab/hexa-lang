# MUSICTOPO-021: Fiber Bundle: Pitch Register over Pitch Class Base

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The full pitch space has the structure of a fiber bundle with base space S^1 (pitch classes, 12 = sigma(6) points) and fiber Z (octave register). The projection map sends each pitch to its pitch class, and the structure group is Z acting by octave shifts.

## Background

A fiber bundle locally looks like Base x Fiber but may have global twist.
The pitch system naturally decomposes into "which note" (pitch class)
and "which octave" (register).

## Verification

```
  Total space E: all pitches (Z or R for continuous)
  Base space B: pitch classes S^1 (or Z_12 = Z_{sigma(6)})
  Fiber F: Z (octave labels: ..., -2, -1, 0, 1, 2, ...)
  Projection: p(pitch) = pitch mod 12

  Structure group: Z (acting by +/- octave)
  Bundle: trivial (E = B x F globally)
    R = S^1 x Z (discrete case) or R (continuous case: universal cover)

  Base space cardinality: 12 = sigma(6)  EXACT
```

## ASCII Fiber Bundle

```
  Register
  (fiber Z)
    |   C5  D5  E5  ...  B5
    |   C4  D4  E4  ...  B4     <- sections = melodies
    |   C3  D3  E3  ...  B3
    |   C2  D2  E2  ...  B2
    +---------------------------
        C   D   E   ...  B
        Base space S^1 (12 = sigma(6) points)
```

## Bundle Data

| Property | Value | n=6 Link |
|----------|-------|----------|
| Base points | 12 | sigma(6) |
| Fiber | Z | integers |
| Structure group | Z | -- |
| Triviality | trivial | product bundle |
| Sections | melodies | pitch assignment |

## Interpretation

A melody is a section of this fiber bundle: for each time, it selects
a pitch class and a register. The base space has sigma(6) = 12 elements,
making every melodic choice a selection from sigma(6) pitch classes.
