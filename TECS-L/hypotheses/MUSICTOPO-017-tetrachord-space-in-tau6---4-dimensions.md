# MUSICTOPO-017: Tetrachord Space in tau(6) = 4 Dimensions

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The space of 4-note chords (tetrachords) lives in 4 = tau(6) dimensions, as the orbifold T^4/S_4. The permutation group S_4 has order 24 = 2*sigma(6), and the quotient space is a 4-dimensional orbifold.

## Background

Tetrachords (dominant sevenths, diminished sevenths, etc.) require 4
voices, hence 4-dimensional configuration space. The SATB (soprano, alto,
tenor, bass) framework is fundamentally 4-dimensional.

## Verification

```
  Tetrachord space: T^4 / S_4
  Dimension: 4 = tau(6)  EXACT
  |S_4| = 4! = 24 = 2 * sigma(6)  EXACT

  Maximally symmetric tetrachord: diminished seventh
    {0, 3, 6, 9} = coset of 3*Z_12
    Isotropy: Z_4 (cyclic), |Z_4| = 4 = tau(6)  EXACT
```

## ASCII 4D Space Cross-section

```
  4 voices = 4 circles:

  Soprano: --o--> S^1  \
  Alto:    --o--> S^1   \  T^4 = 4-torus
  Tenor:   --o--> S^1   /  dim = tau(6)
  Bass:    --o--> S^1  /

  S_4 permutes the 4 circles (24 = 2*sigma(6) ways)
```

## Verification Table

| Property | Value | n=6 Link |
|----------|-------|----------|
| Dimension | 4 | tau(6) |
| Perm group order | 24 | 2*sigma(6) |
| Dim-7 isotropy | Z_4 | Z_{tau(6)} |
| Dim-7 chords | 3 | P1/2 |
| SATB voices | 4 | tau(6) |

## Interpretation

The 4-dimensional tetrachord space is controlled by tau(6) = 4.
The permutation symmetry S_4 has order 2*sigma(6) = 24, and the most
symmetric tetrachord (diminished seventh) has Z_{tau(6)} isotropy.
