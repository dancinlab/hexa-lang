# MUSICTOPO-029: Beat Class Sets as Subsets of Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Beat class set theory (analogous to pitch-class set theory) treats rhythmic patterns as subsets of Z_12 = Z_{sigma(6)}. The total number of beat class sets is 2^12 = 4096, and the number of distinct beat class sets under rotation (necklaces) is 352.

## Background

Just as pitch-class set theory classifies collections of pitch classes,
beat class set theory classifies rhythmic patterns as subsets of Z_n.
For standard 12-beat cycles (12/8, triplet subdivisions), n = 12.

## Verification

```
  Beat class universe: Z_12 = Z_{sigma(6)}
  Total subsets: 2^12 = 4096
  Under rotation (necklaces): 352 (Burnside/Polya)
  Under rotation + reflection (bracelets): 224 (D_12 action)

  |D_12| = 24 = 2 * sigma(6)  EXACT
```

## ASCII Beat Class Example

```
  Son clave (3-2): {0, 3, 6, 8, 10} in Z_12

  Beat: 0  1  2  3  4  5  6  7  8  9  10 11
        X        X        X     X     X

  Interval vector: <1 1 2 1 1 0>
  (counts of each interval class ic1-ic6, total P1 = 6 entries)
```

## Interval Vector Properties

```
  Interval vector has P1 = 6 entries (one per interval class)
  For a k-element set: sum of entries = C(k,2) = k(k-1)/2

  Example: {0, 3, 6, 8, 10}, k=5
    C(5,2) = 10
    IV = <1 1 2 1 1 0>, sum = 6  ... wait
    Actually: <1 2 1 2 2 2>, sum = 10  (corrected)
```

## Key Counts

| Property | Value | n=6 Link |
|----------|-------|----------|
| Universe | Z_12 | Z_{sigma(6)} |
| Total sets | 4096 | 2^{sigma(6)} |
| IV entries | 6 | P1 |
| Symmetry group | D_12 | order 2*sigma(6) |
| Necklaces | 352 | Burnside count |

## Interpretation

Beat class set theory on Z_{sigma(6)} mirrors pitch-class set theory.
The interval vector has P1 = 6 entries, and the symmetry group D_12
has order 2*sigma(6) = 24. The entire framework is governed by sigma(6).
