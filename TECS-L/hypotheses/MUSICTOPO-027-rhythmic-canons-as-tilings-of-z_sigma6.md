# MUSICTOPO-027: Rhythmic Canons as Tilings of Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> A rhythmic canon tiles Z_12 = Z_{sigma(6)} when a rhythm pattern A and its translates cover every beat exactly once: A + B = Z_12. The factorizations of Z_12 correspond to tilings, and the number of nontrivial factorizations reflects the rich divisor structure of 12 = sigma(6).

## Background

A rhythmic canon tiles Z_n if there exist sets A, B subset Z_n such that
every element of Z_n can be written uniquely as a + b with a in A, b in B.
This means A + B = Z_n (direct sum). This is closely related to the
Hajos-de Bruijn factorization problem.

## Verification

```
  Tiling condition: A + B = Z_12  (direct sum)
  |A| * |B| = 12 = sigma(6)  (necessary condition)

  Factor pairs (|A|, |B|) with |A|*|B| = 12:
    (1, 12), (2, 6), (3, 4), (4, 3), (6, 2), (12, 1)
    Count: 6 = P1  EXACT (including order)

  Examples:
    A = {0, 6}, B = {0, 1, 2, 3, 4, 5}  (|A|=2, |B|=6)
    A = {0, 4, 8}, B = {0, 1, 2, 3}     (|A|=3, |B|=4)
    A = {0, 3, 6, 9}, B = {0, 1, 2}     (|A|=4, |B|=3)
```

## ASCII Tiling

```
  A = {0, 4, 8}, B = {0, 1, 2, 3}

  Beat: 0  1  2  3  4  5  6  7  8  9  10 11
  A+0:  X           X           X
  A+1:     X           X           X
  A+2:        X           X           X
  A+3:           X           X           X
        ----------------------------------------
  Cover: 0  1  2  3  4  5  6  7  8  9  10 11  (complete tiling)
```

## Factor Pair Table

| |A| | |B| | |A|*|B| | Example A |
|-----|------|---------|-----------|
| 1 | 12 | 12 | {0} |
| 2 | 6 | 12 | {0, 6} |
| 3 | 4 | 12 | {0, 4, 8} |
| 4 | 3 | 12 | {0, 3, 6, 9} |
| 6 | 2 | 12 | {0, 2, 4, 6, 8, 10} |
| 12 | 1 | 12 | Z_12 |

## Interpretation

Rhythmic canon tilings of Z_{sigma(6)} require |A|*|B| = 12 = sigma(6),
and there are P1 = 6 ordered factor pairs. The divisor-rich structure of
12 = sigma(6) makes the 12-beat cycle especially fertile for rhythmic canons.
