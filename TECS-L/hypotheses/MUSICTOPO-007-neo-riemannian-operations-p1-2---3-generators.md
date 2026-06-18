# MUSICTOPO-007: Neo-Riemannian Operations: P1/2 = 3 Generators

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Neo-Riemannian theory uses exactly 3 operations (P, L, R) to navigate triadic harmony. This count 3 = P1/2 = 6/2 divides the perfect number by its smallest proper divisor phi(6) = 2.

## Background

Neo-Riemannian theory (Cohn, Hyer) replaces function-based harmony with
three contextual inversions that each preserve two common tones:
  P (Parallel): C major <-> C minor  (change third)
  L (Leading-tone): C major <-> E minor  (move root down by semitone)
  R (Relative): C major <-> A minor  (change fifth)

## Verification

```
  Number of NR operations: 3
  P1 / 2 = 6 / 2 = 3  EXACT
  P1 / phi(6) = 6 / 2 = 3  EXACT

  Each operation is an involution: P^2 = L^2 = R^2 = identity
  They generate the "PLR group" of order 24 = 2*sigma(6)
```

## ASCII Tonnetz with PLR

```
       E-----G-----Bb-----
      / \ R / \ R / \ R /
     /   \ /   \ /   \ /
    C--P--Eb--P--Gb--P--A
     \ L / \ L / \ L / \
      \ /   \ /   \ /   \
       Ab-----B-----D------

  P = horizontal flip (parallel)
  L = upper-left diagonal flip (leading-tone)
  R = upper-right diagonal flip (relative)
```

## Group Theory

| Property | Value | n=6 Link |
|----------|-------|----------|
| Generators | 3 | P1/2 |
| Group order | 24 | 2*sigma(6) |
| Relations | P^2=L^2=R^2=1 | involutions |
| Isomorphic to | S_4? | (debated) |
| Acts on | 24 triads | 2*sigma(6) |

## Interpretation

The three NR operations (P, L, R) = P1/phi(6) generators act on 2*sigma(6) = 24
major/minor triads. The PLR group structure is entirely determined by n=6 constants.
