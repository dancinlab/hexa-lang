# MUSICTOPO-011: Transposition Group T = Z_sigma(6)

**Domain**: Topology of Music | **Grade**: 🟩 EXACT
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> The transposition group of pitch classes is T = Z_12 = Z_{sigma(6)}, a cyclic group of order 12. Transposition by k semitones is the group element k in Z_12, and the group acts freely and transitively on the 12 pitch classes.

## Background

Transposition moves every note by the same interval. The 12 possible
transpositions (T_0 through T_11) form the cyclic group Z_12.

## Verification

```
  Transposition group: T = Z_12 = Z_{sigma(6)}
  |T| = 12 = sigma(6)  EXACT

  Action on pitch classes: T_k(x) = x + k (mod 12)
  Orbits: single orbit of size 12 (transitive action)
  Stabilizer: trivial (free action)

  Orbit-Stabilizer: |T| = |orbit| * |stab| = 12 * 1 = 12
```

## ASCII Transposition Action

```
  T_0:  C  C# D  D# E  F  F# G  G# A  A# B
  T_1:  C# D  D# E  F  F# G  G# A  A# B  C
  T_7:  G  G# A  A# B  C  C# D  D# E  F  F#
        ^                                    ^
        |-------- 12 = sigma(6) elements ----|

  T_k shifts entire row by k positions
```

## Subgroup Lattice

```
  Z_12
  |  \  \
  Z_6  Z_4
  |  X  |
  Z_3  Z_2
   \ |  /
    Z_1

  Subgroups: Z_1, Z_2, Z_3, Z_4, Z_6, Z_12
  Count: 6 = P1  EXACT
```

## Interpretation

The transposition group Z_{sigma(6)} has exactly P1 = 6 subgroups,
and each subgroup corresponds to a musically meaningful equal division
of the octave (whole tones, augmented triads, diminished sevenths, tritones).
