# MUSICTOPO-031: Time Signature as Lattice Point in Z^2

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> A time signature m/n represents a lattice point (m, n) in Z^2, where m = beats per measure and n = beat unit. Common time signatures cluster near small coordinates, with 6/8 directly encoding P1 = 6.

## Background

Time signatures describe metric structure. While the denominator is
conventionally a power of 2, the numerator can be any positive integer.
The most common time signatures involve small numbers.

## Verification

```
  Common time signatures and n=6 connections:
    2/4:  beats = phi(6), unit = tau(6)
    3/4:  beats = P1/2, unit = tau(6)
    4/4:  beats = tau(6), unit = tau(6)
    6/8:  beats = P1, unit = 8
    12/8: beats = sigma(6), unit = 8

  Direct P1 encoding: 6/8 has numerator = P1 = 6  EXACT
  sigma encoding: 12/8 has numerator = sigma(6) = 12  EXACT
```

## ASCII Lattice

```
  beats
  (m)
   |
  12|          *                sigma(6)/8
   |
   9|       *                  9/8
   |
   6|    *     *               P1/4, P1/8
   |
   4| *  *     *               tau(6)/4, etc.
   3| *  *                     P1/2
   2| *  *                     phi(6)
   +--+--+--+--+---> unit (n)
      2  4  8  16
```

## Frequency Table

| Time Sig | Beats | n=6 Link | Usage |
|----------|-------|----------|-------|
| 2/4 | 2 | phi(6) | march |
| 3/4 | 3 | P1/2 | waltz |
| 4/4 | 4 | tau(6) | common |
| 6/8 | 6 | P1 | compound duple |
| 12/8 | 12 | sigma(6) | compound quadruple |

## Interpretation

The most common beat counts {2, 3, 4, 6, 12} are exactly the divisors
of 12 = sigma(6), and simultaneously the nontrivial divisors of P1 = 6
plus sigma(6) itself. Grade: WEAK because common time signatures are
culturally influenced, not purely mathematical.
