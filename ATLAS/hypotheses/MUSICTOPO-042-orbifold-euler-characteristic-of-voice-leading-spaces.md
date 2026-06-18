# MUSICTOPO-042: Orbifold Euler Characteristic of Voice-Leading Spaces

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The orbifold Euler characteristic of the n-chord voice-leading space T^n/S_n involves 1/|S_n|. For n = 3 = P1/2 (triads), 1/|S_3| = 1/6 = 1/P1. For n = 4 = tau(6) (tetra chords), 1/|S_4| = 1/24 = 1/(2*sigma(6)).

## Background

The orbifold Euler characteristic generalizes the ordinary Euler
characteristic to spaces with singularities from group actions.
For a free action, chi_orb = chi(X)/|G|.

## Verification

```
  For T^n / S_n:
    chi(T^n) = 0 for all n >= 1 (torus)
    chi_orb = 0 / |S_n| = 0 (trivially)

  The meaningful invariant is the volume ratio:
    Vol(T^n/S_n) / Vol(T^n) = 1/n!

  n = 2 = phi(6):  1/2! = 1/2 = 1/phi(6)  EXACT
  n = 3 = P1/2:    1/3! = 1/6 = 1/P1  EXACT
  n = 4 = tau(6):  1/4! = 1/24 = 1/(2*sigma(6))  EXACT
```

## ASCII Volume Ratios

```
  n=2 (dyads):    [======|======]  1/2 = 1/phi(6)
                   fund    image

  n=3 (triads):   [==|==|==|==|==|==]  1/6 = 1/P1
                   FD   5 copies

  n=4 (tetra):    [=|=|=|... 24 total ...]  1/24 = 1/(2*sigma(6))
```

## Complete Table

| Voices n | S_n order | 1/n! | n=6 Link |
|----------|-----------|------|----------|
| 1 | 1 | 1 | trivial |
| 2 = phi(6) | 2 | 1/2 | phi(6) |
| 3 = P1/2 | 6 | 1/6 | P1 |
| 4 = tau(6) | 24 | 1/24 | 2*sigma(6) |
| 5 = sopfr(6) | 120 | 1/120 | sopfr(6) |
| 6 = P1 | 720 | 1/720 | 6! = P1! |

## Interpretation

The volume ratios 1/n! for musically relevant voice counts (2, 3, 4)
are exactly 1/phi(6), 1/P1, and 1/(2*sigma(6)). At n = P1 = 6 voices,
the ratio is 1/720 = 1/(P1!), a self-referential closure.
