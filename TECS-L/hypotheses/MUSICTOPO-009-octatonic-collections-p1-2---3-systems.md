# MUSICTOPO-009: Octatonic Collections: P1/2 = 3 Systems

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> There are exactly 3 octatonic collections (diminished scales) in the 12-tone system, obtained by partitioning Z_12 into cosets of the diminished seventh chord Z_3. The count 3 = P1/2.

## Background

An octatonic scale alternates whole and half steps, containing 8 of 12 pitch
classes. There are exactly 3 distinct octatonic collections, corresponding
to the 3 cosets of the subgroup 3*Z_12 = {0, 3, 6, 9} in Z_12.

## Verification

```
  Z_12 / (3*Z_12) = Z_3, giving 3 cosets:
  Oct 0: {0,1,3,4,6,7,9,10}  (starts on C)
  Oct 1: {1,2,4,5,7,8,10,11} (starts on C#)
  Oct 2: {0,2,3,5,6,8,9,11}  (starts on D)

  Number of octatonic collections: 3 = P1/2  EXACT
  Notes per collection: 8
  Missing notes per collection: 4 = tau(6)  EXACT
```

## ASCII Octatonic Scale

```
  Oct 0 on chromatic circle:

       C*
    B     C#*
  A#*       D
  A*         D#      * = member of Oct 0
  G#        E
    G*    F*
       F#*

  8 filled, 4 = tau(6) empty
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Collections | 3 | P1/2 |
| Notes per collection | 8 | sigma(6) - tau(6) |
| Missing per collection | 4 | tau(6) |
| Symmetry group | Z_4 | tau(6) = 4 |
| Transposition invariance | 3 | P1/2 |

## Interpretation

The 3 = P1/2 octatonic collections partition Z_{sigma(6)} into overlapping
8-note scales, each missing tau(6) = 4 notes. The octatonic system is
controlled by the subgroup structure of Z_12 = Z_{sigma(6)}.
