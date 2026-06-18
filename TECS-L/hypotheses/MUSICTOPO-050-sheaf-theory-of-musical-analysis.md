# MUSICTOPO-050: Sheaf Theory of Musical Analysis

**Domain**: Topology of Music | **Grade**: 🟧 WEAK
**GZ Dependency**: None (pure structural topology)

## Hypothesis

> Musical analysis can be modeled as a sheaf on the time axis: local harmonic analysis assigns chord labels to time intervals, and the sheaf condition requires consistency on overlaps. The stalk at each time point has up to sigma(6) = 12 possible pitch classes.

## Background

A sheaf assigns data (sections) to open sets with consistency conditions
on overlaps. In music, the "data" is harmonic analysis: which chord or
key is active at each time interval.

## Construction

```
  Base space: time axis R (or circle S^1 for repeating pieces)
  Presheaf F:
    F(U) = set of harmonic analyses on time interval U
    = assignments of chords from Z_12 = Z_{sigma(6)} to each moment

  Sheaf condition:
    If analyses agree on overlaps U_i cap U_j,
    they glue to a global analysis on union U_i cup U_j

  Stalk at t:
    F_t = possible pitch classes at time t
    |F_t| <= 12 = sigma(6)
```

## ASCII Sheaf Structure

```
  Harmonic analysis sheaf:

  Section over [0,4]:  C major
  Section over [3,8]:  G major      overlap [3,4]: must agree
  Section over [7,12]: C major      overlap [7,8]: must agree

  Time: 0---1---2---3---4---5---6---7---8---9--10--11--12
        |---C major---|                |---C major----|
                   |---G major---|
                   ^             ^
                   gluing regions (sheaf condition)
```

## Sheaf Data

| Property | Value | n=6 Link |
|----------|-------|----------|
| Stalk size | <= 12 | sigma(6) |
| Key labels | 24 | 2*sigma(6) |
| Chord types | varies | -- |
| Consistency | sheaf axiom | overlap agreement |

## Interpretation

Sheaf theory provides a rigorous framework for the intuition that
harmonic analysis must be locally consistent and globally coherent.
The stalk at each point draws from Z_{sigma(6)} pitch classes.
Grade: WEAK because sheaf theory is a powerful but general framework;
the n=6 connection is through the 12-element pitch class set.
